import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_buddy/core/data/tariff_repository.dart';
import 'package:travel_buddy/core/models/app_models.dart';
import 'package:travel_buddy/core/services/gemini_proxy_service.dart';
import 'package:travel_buddy/features/airport_fares/presentation/airport_prepaid_fares_screen.dart';
import 'package:travel_buddy/features/price_checker/presentation/check_price_input_screen.dart';
import 'package:travel_buddy/features/price_checker/presentation/widgets/price_quick_presets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleDataset = AirportPrepaidFareDataset(
    source: 'LGBI Airport Pre-paid Taxi Counter, Guwahati',
    effectiveDate: null,
    verified: true,
    origin: 'LGBI Airport, Guwahati',
    originLat: 26.1061,
    originLng: 91.5859,
    baseFare: 200.0,
    perKmRate: 24.0,
    routes: const [
      FixedRouteTariff(
        origin: 'LGBI Airport, Guwahati',
        destinationName: 'Ganeshguri',
        destinationNameHi: 'गणेशगुड़ी',
        aliases: ['Ganesh Guri', 'Dispur'],
        km: 31.0,
        fare: 680.0,
        category: 'Local',
        source: 'LGBI Airport Pre-paid Taxi Counter, Guwahati',
      ),
      FixedRouteTariff(
        origin: 'LGBI Airport, Guwahati',
        destinationName: 'Shillong (Police Bazar)',
        destinationNameHi: 'शिलांग (पुलिस बाजार)',
        aliases: ['Police Bazar', 'PB', 'Shillong PB'],
        km: 110.0,
        fare: 2600.0,
        category: 'Out of state',
        flags: ['check_against_printed_list'],
        source: 'LGBI Airport Pre-paid Taxi Counter, Guwahati',
      ),
    ],
  );

  group('Phase 4: SCREENS - Airport Prepaid Fare Integration Tests', () {
    testWidgets('1. AirportPrepaidFaresScreen renders official header, routes, and report button', (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            airportPrepaidDatasetProvider.overrideWith((ref) async => sampleDataset),
          ],
          child: const MaterialApp(
            home: AirportPrepaidFaresScreen(),
          ),
        ),
      );

      // Loading pump
      await tester.pumpAndSettle();

      // Check Header Source Badge & Note
      expect(find.text('OFFICIAL TARIFF'), findsOneWidget);
      expect(find.text('LGBI Airport Pre-paid Taxi Counter, Guwahati'), findsOneWidget);
      expect(find.textContaining('effective date not stated'), findsOneWidget);
      expect(find.text('Report a wrong fare'), findsOneWidget);

      // Check Route rows
      expect(find.text('Ganeshguri'), findsOneWidget);
      expect(find.text('₹680'), findsOneWidget);
      expect(find.text('31 km'), findsOneWidget);
      expect(find.text('₹21.9/km'), findsOneWidget);

      expect(find.text('Shillong (Police Bazar)'), findsOneWidget);
      expect(find.text('₹2600'), findsOneWidget);
      expect(find.text('110 km'), findsOneWidget);
      expect(find.text('Confirm at counter'), findsOneWidget);

      // Test Report wrong fare modal
      await tester.tap(find.text('Report a wrong fare'));
      await tester.pumpAndSettle();
      expect(find.text('Report a Wrong Fare'), findsOneWidget);
      expect(find.text('Requires contributor login or traveler verification'), findsOneWidget);
      await tester.tap(find.byType(ElevatedButton).last); // close or submit
      await tester.pumpAndSettle();
    });

    testWidgets('2. Search filtering and Hindi toggle on AirportPrepaidFaresScreen', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            airportPrepaidDatasetProvider.overrideWith((ref) async => sampleDataset),
          ],
          child: const MaterialApp(
            home: AirportPrepaidFaresScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Toggle Hindi names
      expect(find.text('गणेशगुड़ी'), findsNothing);
      await tester.tap(find.text('Hindi (हिंदी)'));
      await tester.pumpAndSettle();
      expect(find.text('गणेशगुड़ी'), findsOneWidget);

      // Search input
      await tester.enterText(find.byType(TextField).first, 'Shillong');
      await tester.pumpAndSettle();
      expect(find.text('Shillong (Police Bazar)'), findsOneWidget);
      expect(find.text('Ganeshguri'), findsNothing);
    });

    testWidgets('3. Check a Price Screen shows fixed fare top banner when pickup is airport', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            airportPrepaidDatasetProvider.overrideWith((ref) async => sampleDataset),
          ],
          child: const MaterialApp(
            home: CheckPriceInputScreen(
              initialPickupName: 'LGBI Airport, Guwahati',
              initialDropName: 'Ganeshguri',
              initialQuotedPrice: 1200,
              initialServiceType: ServiceType.taxi,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Banner should be visible
      expect(
        find.text('The pre-paid taxi counter has fixed fares. Compare before you agree with a driver.'),
        findsOneWidget,
      );
      expect(
        find.text('View all official LGBI Airport pre-paid fares →'),
        findsOneWidget,
      );
    });

    testWidgets('4. Quick presets includes Airport → Ganeshguri ₹1,200 (Scam)', (tester) async {
      bool presetSelected = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PriceQuickPresets(
              onSelect: (type, pickup, drop, quote) {
                if (pickup.contains('LGBI Airport') && drop == 'Ganeshguri' && quote == 1200) {
                  presetSelected = true;
                }
              },
            ),
          ),
        ),
      );

      expect(find.text('Airport → Ganeshguri ₹1,200 (Scam)'), findsOneWidget);
      await tester.tap(find.text('Airport → Ganeshguri ₹1,200 (Scam)'));
      await tester.pump();
      expect(presetSelected, isTrue);
    });

    testWidgets('5. Ask Buddy local fallback answers Shillong prepaid query with [Official tariff]', (tester) async {
      final proxyService = GeminiProxyService();
      final response = await proxyService.sendAgentMessage(
        history: [
          AgentMessage(
            id: 'm1',
            sender: 'user',
            text: 'How much is a prepaid taxi to Shillong?',
            timestamp: DateTime.now(),
          ),
        ],
        currentPlace: 'Guwahati',
      );

      expect(response.text.contains('[Official tariff]'), isTrue);
      expect(response.text.contains('Shillong (Police Bazar): ₹2,600'), isTrue);
      expect(response.actions.any((a) => a.type == 'getAirportPrepaidFare'), isTrue);
    });
  });
}
