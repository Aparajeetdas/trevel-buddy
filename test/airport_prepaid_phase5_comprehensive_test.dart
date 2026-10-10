import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:travel_buddy/core/data/tariff_repository.dart';
import 'package:travel_buddy/core/models/app_models.dart';
import 'package:travel_buddy/core/services/airport_prepaid_matcher.dart';
import 'package:travel_buddy/core/utils/pricing_engine.dart';
import 'package:travel_buddy/features/airport_fares/presentation/airport_prepaid_fares_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ganeshguriRoute = FixedRouteTariff(
    origin: 'LGBI Airport, Guwahati',
    destinationName: 'Ganeshguri',
    destinationNameHi: 'गणेशगुड़ी',
    aliases: ['Ganesh Guri', 'Dispur', 'Ganeshguri Chariali'],
    km: 31.0,
    fare: 680.0,
    category: 'Local',
    source: 'LGBI Airport Pre-paid Taxi Counter, Guwahati',
  );

  const shillongPBRoute = FixedRouteTariff(
    origin: 'LGBI Airport, Guwahati',
    destinationName: 'Shillong (Police Bazar)',
    destinationNameHi: 'शिलांग (पुलिस बाजार)',
    aliases: ['Police Bazar', 'PB', 'Shillong PB'],
    km: 110.0,
    fare: 2600.0,
    category: 'Out of state',
    flags: ['check_against_printed_list'],
    source: 'LGBI Airport Pre-paid Taxi Counter, Guwahati',
  );

  const shillongBarapaniRoute = FixedRouteTariff(
    origin: 'LGBI Airport, Guwahati',
    destinationName: 'Shillong (Barapani)',
    destinationNameHi: 'शिलांग (बारापानी)',
    aliases: ['Barapani', 'Umiam'],
    km: 95.0,
    fare: 2300.0,
    category: 'Out of state',
    flags: ['check_against_printed_list'],
    source: 'LGBI Airport Pre-paid Taxi Counter, Guwahati',
  );

  const shillongNehuRoute = FixedRouteTariff(
    origin: 'LGBI Airport, Guwahati',
    destinationName: 'Shillong (NEHU/Mawlai)',
    destinationNameHi: 'शिलांग (नेहू/मावलई)',
    aliases: ['NEHU', 'Mawlai'],
    km: 100.0,
    fare: 2400.0,
    category: 'Out of state',
    flags: ['check_against_printed_list'],
    source: 'LGBI Airport Pre-paid Taxi Counter, Guwahati',
  );

  const testTariffs = [
    ganeshguriRoute,
    shillongPBRoute,
    shillongBarapaniRoute,
    shillongNehuRoute,
  ];

  final testDataset = AirportPrepaidFareDataset(
    source: 'LGBI Airport Pre-paid Taxi Counter, Guwahati',
    effectiveDate: null,
    verified: true,
    origin: 'LGBI Airport, Guwahati',
    originLat: 26.1061,
    originLng: 91.5859,
    baseFare: 200.0,
    perKmRate: 24.0,
    routes: testTariffs,
  );

  group('Phase 5: Destination Matching Tests', () {
    test('1. Exact matching: matches exact destination name', () {
      final result = AirportPrepaidMatcher.matchDestination(
        destination: 'Ganeshguri',
        tariffs: testTariffs,
      );

      expect(result.status, AirportMatchStatus.confident);
      expect(result.matchedTariff, isNotNull);
      expect(result.matchedTariff!.destinationName, 'Ganeshguri');
      expect(result.matchedTariff!.fare, 680.0);
    });

    test('2. Alias matching: matches destination via aliases', () {
      final res1 = AirportPrepaidMatcher.matchDestination(
        destination: 'Dispur',
        tariffs: testTariffs,
      );
      expect(res1.status, AirportMatchStatus.confident);
      expect(res1.matchedTariff!.destinationName, 'Ganeshguri');

      final res2 = AirportPrepaidMatcher.matchDestination(
        destination: 'Police Bazar',
        tariffs: testTariffs,
      );
      expect(res2.status, AirportMatchStatus.confident);
      expect(res2.matchedTariff!.destinationName, 'Shillong (Police Bazar)');
    });

    test('3. Hindi matching: matches Devanagari Hindi destination name', () {
      final result = AirportPrepaidMatcher.matchDestination(
        destination: 'गणेशगुड़ी',
        tariffs: testTariffs,
      );

      expect(result.status, AirportMatchStatus.confident);
      expect(result.matchedTariff, isNotNull);
      expect(result.matchedTariff!.destinationName, 'Ganeshguri');
    });

    test('4. Fuzzy matching: matches destination with minor typos / punctuation', () {
      final result = AirportPrepaidMatcher.matchDestination(
        destination: 'Ganesguri!',
        tariffs: testTariffs,
      );

      expect(result.status, AirportMatchStatus.confident);
      expect(result.matchedTariff, isNotNull);
      expect(result.matchedTariff!.destinationName, 'Ganeshguri');
    });

    test('5. Ambiguous matching (Shillong): detects multiple candidates without silent guessing', () {
      final result = AirportPrepaidMatcher.matchDestination(
        destination: 'Shillong',
        tariffs: testTariffs,
      );

      expect(result.status, AirportMatchStatus.ambiguous);
      expect(result.candidates.length, greaterThanOrEqualTo(3));
      final candidateNames = result.candidates.map((c) => c.destinationName).toList();
      expect(candidateNames, contains('Shillong (Police Bazar)'));
      expect(candidateNames, contains('Shillong (Barapani)'));
      expect(candidateNames, contains('Shillong (NEHU/Mawlai)'));
    });

    test('6. Not listed matching: unlisted destination returns notListed status', () {
      final result = AirportPrepaidMatcher.matchDestination(
        destination: 'Timbuktu Central',
        tariffs: testTariffs,
      );

      expect(result.status, AirportMatchStatus.notListed);
      expect(result.matchedTariff, isNull);
    });
  });

  group('Phase 5: Pricing Engine Behavior Tests', () {
    test('1. At Fare: quoted equals official fare -> Fair verdict, zero spread, score 0', () {
      final input = PriceCheckInput(
        serviceType: ServiceType.taxi,
        pickupName: 'LGBI Airport, Guwahati',
        dropName: 'Ganeshguri',
        distanceKm: 31.0,
        quotedPrice: 680.0,
      );

      final result = PricingEngine.evaluate(
        input: input,
        fixedRouteTariff: ganeshguriRoute,
      );

      expect(result.fairMin, 680.0);
      expect(result.fairMax, 680.0);
      expect(result.level, PriceVerdictLevel.fair);
      expect(result.riskScore, 0);
      expect(result.sources.first.sourceName, 'LGBI Airport Pre-paid Taxi Counter, Guwahati');
      expect(result.sources.first.details, contains('effective date not stated'));
      expect(result.factors.any((f) => f.evidence.contains('Ask the counter whether tolls are included')), isTrue);
    });

    test('2. +5% tolerance window: quoted 714 (<= 680 * 1.05 = 714) -> Fair verdict, score 0', () {
      final input = PriceCheckInput(
        serviceType: ServiceType.taxi,
        pickupName: 'LGBI Airport, Guwahati',
        dropName: 'Ganeshguri',
        distanceKm: 31.0,
        quotedPrice: 714.0,
      );

      final result = PricingEngine.evaluate(
        input: input,
        fixedRouteTariff: ganeshguriRoute,
      );

      expect(result.level, PriceVerdictLevel.fair);
      expect(result.riskScore, 0);
    });

    test('3. +30% markup: quoted 884 (~1.3x) -> Suspicious verdict', () {
      final input = PriceCheckInput(
        serviceType: ServiceType.taxi,
        pickupName: 'LGBI Airport, Guwahati',
        dropName: 'Ganeshguri',
        distanceKm: 31.0,
        quotedPrice: 884.0,
      );

      final result = PricingEngine.evaluate(
        input: input,
        fixedRouteTariff: ganeshguriRoute,
      );

      expect(result.level, PriceVerdictLevel.suspicious);
    });

    test('4. +60% markup (> 1.5x): quoted 1200 (~1.76x) -> High Risk verdict with 1.8x explanation', () {
      final input = PriceCheckInput(
        serviceType: ServiceType.taxi,
        pickupName: 'LGBI Airport, Guwahati',
        dropName: 'Ganeshguri',
        distanceKm: 31.0,
        quotedPrice: 1200.0,
      );

      final result = PricingEngine.evaluate(
        input: input,
        fixedRouteTariff: ganeshguriRoute,
      );

      expect(result.level, PriceVerdictLevel.highRisk);
      expect(result.explanation, contains('1.8x the official prepaid fare'));
    });

    test('5. Below 0.6x: quoted 350 (< 0.6 * 680 = 408) -> flagged as unusually low / hidden charge risk', () {
      final input = PriceCheckInput(
        serviceType: ServiceType.taxi,
        pickupName: 'LGBI Airport, Guwahati',
        dropName: 'Ganeshguri',
        distanceKm: 31.0,
        quotedPrice: 350.0,
      );

      final result = PricingEngine.evaluate(
        input: input,
        fixedRouteTariff: ganeshguriRoute,
      );

      expect(result.isUnusuallyLow, isTrue);
      expect(result.explanation, contains('below 0.6x official prepaid fare'));
    });

    test('6. Flagged rows (check_against_printed_list): Medium confidence & counter check factor', () {
      final input = PriceCheckInput(
        serviceType: ServiceType.taxi,
        pickupName: 'LGBI Airport, Guwahati',
        dropName: 'Shillong (Police Bazar)',
        distanceKm: 110.0,
        quotedPrice: 2600.0,
      );

      final result = PricingEngine.evaluate(
        input: input,
        fixedRouteTariff: shillongPBRoute,
      );

      expect(result.confidence, ConfidenceLevel.medium);
      expect(result.factors.any((f) => f.evidence.contains('Confirm at the counter')), isTrue);
    });
  });

  group('Phase 5: Estimate Fallback & Reverse Direction Tests', () {
    test('1. Unlisted destination from airport uses derived estimate formula (base 200 + 24 * km)', () {
      final input = PriceCheckInput(
        serviceType: ServiceType.taxi,
        pickupName: 'LGBI Airport, Guwahati',
        dropName: 'Dudhnai Remote Area',
        distanceKm: 85.0,
        quotedPrice: 2240.0,
      );

      // No matching fixed route tariff passed
      final result = PricingEngine.evaluate(
        input: input,
        isAirportTrip: true,
      );

      // derivedEstimate = 200 + 24 * 85 = 2240, fairMin = 2016 (0.9x), fairMax = 2464 (1.1x)
      expect(result.confidence, ConfidenceLevel.low);
      expect(result.fairMin, 2016.0);
      expect(result.fairMax, 2464.0);
      expect(result.sources.any((s) => s.type == 'official'), isFalse); // Never official!
      final estimateSrc = result.sources.firstWhere(
        (s) => s.sourceName == 'Estimated from airport prepaid rates',
      );
      expect(estimateSrc.amount, 2240.0);
      expect(result.factors.any((f) => f.sourceTag.contains('[Estimated from airport prepaid rates]')), isTrue);
      expect(result.factors.any((f) => f.label.contains('Unlisted Airport Route')), isTrue);
    });

    test('2. Trip TO airport (reverse direction) is labeled with reverse direction warning', () {
      final input = PriceCheckInput(
        serviceType: ServiceType.taxi,
        pickupName: 'Dispur, Guwahati',
        dropName: 'LGBI Airport, Guwahati',
        distanceKm: 31.0,
        quotedPrice: 1000.0,
      );

      final result = PricingEngine.evaluate(
        input: input,
        isToAirport: true,
      );

      expect(result.confidence, ConfidenceLevel.low);
      expect(result.factors.any((f) => f.label.contains('Reverse Direction')), isTrue);
      expect(result.factors.any((f) => f.evidence.contains('Trip is TO the airport')), isTrue);
    });
  });

  group('Phase 5: Language / Hindi Toggle Widget Tests', () {
    testWidgets('Toggling Hindi switch on AirportPrepaidFaresScreen displays Hindi area names', (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            airportPrepaidDatasetProvider.overrideWith((ref) async => testDataset),
          ],
          child: const MaterialApp(
            home: AirportPrepaidFaresScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially English names are visible, Hindi names hidden
      expect(find.text('Ganeshguri'), findsOneWidget);
      expect(find.text('गणेशगुड़ी'), findsNothing);

      // Tap Hindi filter chip
      await tester.tap(find.text('Hindi (हिंदी)'));
      await tester.pumpAndSettle();

      // Now Hindi names are displayed
      expect(find.text('Hindi ON (हिंदी)'), findsOneWidget);
      expect(find.text('गणेशगुड़ी'), findsOneWidget);
      expect(find.text('शिलांग (पुलिस बाजार)'), findsOneWidget);

      // Tap again to toggle off
      await tester.tap(find.text('Hindi ON (हिंदी)'));
      await tester.pumpAndSettle();
      expect(find.text('गणेशगुड़ी'), findsNothing);
    });
  });
}
