import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_buddy/core/data/tariff_repository.dart';
import 'package:travel_buddy/core/models/app_models.dart';
import 'package:travel_buddy/core/services/airport_prepaid_matcher.dart';
import 'package:travel_buddy/features/price_checker/presentation/widgets/airport_destination_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2 - MATCHING: Airport Pickup Detection Tests', () {
    test('Pickup within 1.5 km of origin coordinates detects airport pickup', () {
      // LGBI Airport coordinates: 26.1061, 91.5859
      // Point 500m away (lat: 26.1080, lng: 91.5870)
      final isAirport = AirportPrepaidMatcher.isAirportPickup(
        lat: 26.1080,
        lng: 91.5870,
        name: 'Terminal 1 Departures',
      );
      expect(isAirport, isTrue);
    });

    test('Pickup beyond 1.5 km without airport keyword returns false', () {
      // Point ~10 km away in Jalukbari (lat: 26.1450, lng: 91.6620)
      final isAirport = AirportPrepaidMatcher.isAirportPickup(
        lat: 26.1450,
        lng: 91.6620,
        name: 'Jalukbari Rotary',
      );
      expect(isAirport, isFalse);
    });

    test('Pickup with name containing LGBI detects airport pickup even without coordinates', () {
      expect(
        AirportPrepaidMatcher.isAirportPickup(name: 'LGBI Airport Exit Gate 2'),
        isTrue,
      );
      expect(
        AirportPrepaidMatcher.isAirportPickup(name: 'Prepaid Taxi Stand, LGBI'),
        isTrue,
      );
    });

    test('Pickup with name containing Guwahati airport detects airport pickup', () {
      expect(
        AirportPrepaidMatcher.isAirportPickup(name: 'Guwahati airport arrival lounge'),
        isTrue,
      );
      expect(
        AirportPrepaidMatcher.isAirportPickup(name: 'Guwahati Airport T1'),
        isTrue,
      );
    });

    test('Trip TO the airport detects airport dropoff', () {
      expect(
        AirportPrepaidMatcher.isAirportDropoff(name: 'LGBI Guwahati Airport Terminal'),
        isTrue,
      );
      expect(
        AirportPrepaidMatcher.isAirportDropoff(lat: 26.1061, lng: 91.5859),
        isTrue,
      );
      expect(
        AirportPrepaidMatcher.isAirportDropoff(name: 'Paltan Bazar Station'),
        isFalse,
      );
    });
  });

  group('Phase 2 - MATCHING: Destination Normalization & Matching Tests', () {
    late List<FixedRouteTariff> tariffs;

    setUpAll(() async {
      final repo = LocalGovTariffRepository();
      tariffs = await repo.getAirportPrepaidTariffs();
    });

    test('Normalization strips punctuation, diacritics, and handles case', () {
      expect(AirportPrepaidMatcher.normalize('Ganesh-Guri!'), 'ganesh guri');
      expect(AirportPrepaidMatcher.normalize('  Paltan   Bazar  '), 'paltan bazar');
      expect(AirportPrepaidMatcher.normalize('Café & Tea'), 'cafe tea');
      // Preserves Hindi characters
      expect(AirportPrepaidMatcher.normalize('गणेशगुरी!'), 'गणेशगुरी');
    });

    test('Exact destination match (Ganeshguri)', () {
      final result = AirportPrepaidMatcher.matchDestination(
        destination: 'Ganeshguri',
        tariffs: tariffs,
      );

      expect(result.status, AirportMatchStatus.confident);
      expect(result.matchedTariff, isNotNull);
      expect(result.matchedTariff!.destinationName, 'Ganeshguri');
      expect(result.matchedTariff!.fare, 680.0);
    });

    test('Alias match (Dispur Ganeshguri -> Ganeshguri)', () {
      final result = AirportPrepaidMatcher.matchDestination(
        destination: 'Dispur Ganeshguri',
        tariffs: tariffs,
      );

      expect(result.status, AirportMatchStatus.confident);
      expect(result.matchedTariff, isNotNull);
      expect(result.matchedTariff!.destinationName, 'Ganeshguri');
    });

    test('Hindi name match (गणेशगुरी -> Ganeshguri)', () {
      final result = AirportPrepaidMatcher.matchDestination(
        destination: 'गणेशगुरी',
        tariffs: tariffs,
      );

      expect(result.status, AirportMatchStatus.confident);
      expect(result.matchedTariff, isNotNull);
      expect(result.matchedTariff!.destinationName, 'Ganeshguri');
    });

    test('Fuzzy matching with minor typo or extra words (Ganeshguri Flyover)', () {
      final result = AirportPrepaidMatcher.matchDestination(
        destination: 'Ganeshguri Flyover Crossing',
        tariffs: tariffs,
      );

      expect(result.status, AirportMatchStatus.confident);
      expect(result.matchedTariff?.destinationName, 'Ganeshguri');
    });

    test('Google Place details neighborhood/locality matching', () {
      final placeDetails = GooglePlaceDetails(
        placeId: 'sample_place_id',
        name: 'Apollo Hospital Guwahati',
        formattedAddress: 'GS Road, Christian Basti, Guwahati, Assam',
        latitude: 26.155,
        longitude: 91.780,
        fetchedAt: DateTime.now(),
        isLiveGoogle: false,
        addressComponents: [
          {'long_name': 'Christian Basti', 'types': ['neighborhood']},
          {'long_name': 'Ganeshguri', 'types': ['sublocality_level_1']},
          {'long_name': 'Guwahati', 'types': ['locality']},
        ],
      );

      final result = AirportPrepaidMatcher.matchDestination(
        destination: 'Apollo Hospital',
        placeDetails: placeDetails,
        tariffs: tariffs,
      );

      expect(result.status, AirportMatchStatus.confident);
      expect(result.matchedTariff?.destinationName, 'Ganeshguri');
    });

    test('Ambiguous query (Shillong) triggers Ambiguous status with 3 Shillong candidates', () {
      final result = AirportPrepaidMatcher.matchDestination(
        destination: 'Shillong',
        tariffs: tariffs,
      );

      expect(result.status, AirportMatchStatus.ambiguous);
      expect(result.matchedTariff, isNull); // Must NOT guess silently!
      expect(result.requiresPicker, isTrue);

      final candidateNames = result.candidates.map((c) => c.destinationName).toList();
      expect(candidateNames, contains('Shillong (Police Bazar)'));
      expect(candidateNames, contains('Shillong (Barabazar)'));
      expect(candidateNames, contains('Shillong (Happy Valley)'));
    });

    test('Specific query for one Shillong variant is confident (Shillong Police Bazar)', () {
      final result = AirportPrepaidMatcher.matchDestination(
        destination: 'Shillong Police Bazar',
        tariffs: tariffs,
      );

      expect(result.status, AirportMatchStatus.confident);
      expect(result.matchedTariff?.destinationName, 'Shillong (Police Bazar)');
      expect(result.matchedTariff?.fare, 2800.0);
    });

    test('Unlisted destination returns notListed', () {
      final result = AirportPrepaidMatcher.matchDestination(
        destination: 'Marine Drive, Mumbai',
        tariffs: tariffs,
      );

      expect(result.status, AirportMatchStatus.notListed);
      expect(result.matchedTariff, isNull);
    });
  });

  group('Phase 2 - MATCHING: AirportDestinationPicker Widget Tests', () {
    testWidgets('Renders candidates, selection returns chosen tariff, Not Listed returns null', (tester) async {
      final candidate1 = FixedRouteTariff(
        origin: 'LGBI Airport, Guwahati',
        destinationName: 'Shillong (Police Bazar)',
        destinationNameHi: 'शिलांग (पुलिस बाज़ार)',
        km: 120.0,
        fare: 2800.0,
        category: 'Out of state',
        source: 'LGBI Airport Pre-paid Taxi Counter, Guwahati',
      );

      final candidate2 = FixedRouteTariff(
        origin: 'LGBI Airport, Guwahati',
        destinationName: 'Shillong (Barabazar)',
        destinationNameHi: 'शिलांग (बड़ा बाज़ार)',
        km: 122.0,
        fare: 2850.0,
        category: 'Out of state',
        source: 'LGBI Airport Pre-paid Taxi Counter, Guwahati',
      );

      FixedRouteTariff? selectedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AirportDestinationPicker(
              query: 'Shillong',
              candidates: [candidate1, candidate2],
              isAmbiguous: true,
              onSelect: (tariff) => selectedResult = tariff,
            ),
          ),
        ),
      );

      // Verify header and candidates render
      expect(find.text('Select Specific Area'), findsOneWidget);
      expect(find.text('Shillong (Police Bazar)'), findsOneWidget);
      expect(find.text('₹2800'), findsOneWidget);
      expect(find.text('Shillong (Barabazar)'), findsOneWidget);
      expect(find.text('₹2850'), findsOneWidget);
      expect(find.text('Not listed / Other area'), findsOneWidget);

      // Tap first candidate
      await tester.tap(find.text('Shillong (Police Bazar)'));
      await tester.pump();
      expect(selectedResult, candidate1);

      // Tap 'Not listed' button
      await tester.tap(find.byKey(const Key('airport_picker_not_listed_btn')));
      await tester.pump();
      expect(selectedResult, isNull);
    });
  });
}
