import 'package:flutter_test/flutter_test.dart';
import 'package:travel_buddy/core/models/app_models.dart';
import 'package:travel_buddy/core/utils/pricing_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final ganeshguriTariff = FixedRouteTariff(
    origin: 'LGBI Airport, Guwahati',
    destinationName: 'Ganeshguri',
    destinationNameHi: 'गणेशगुरी',
    aliases: const ['Ganesh Guri', 'Dispur Ganeshguri'],
    km: 28.0,
    fare: 680.0,
    category: 'Local',
    flags: const [],
    source: 'LGBI Airport Pre-paid Taxi Counter, Guwahati',
    effectiveDate: null,
    verified: true,
  );

  final shillongFlaggedTariff = FixedRouteTariff(
    origin: 'LGBI Airport, Guwahati',
    destinationName: 'Shillong (Police Bazar)',
    destinationNameHi: 'शिलांग (पुलिस बाज़ार)',
    aliases: const ['Shillong Police Bazaar'],
    km: 120.0,
    fare: 2800.0,
    category: 'Out of state',
    flags: const ['check_against_printed_list'],
    source: 'LGBI Airport Pre-paid Taxi Counter, Guwahati',
    effectiveDate: null,
    verified: true,
  );

  group('Phase 3 - PRICING BEHAVIOR: Matched Official Route', () {
    test('Official fare match has zero spread (fairMin == fairMax == fare)', () {
      final input = PriceCheckInput(
        serviceType: ServiceType.taxi,
        distanceKm: 28.0,
        quotedPrice: 680.0,
        timeOfDay: DateTime(2026, 4, 1, 14, 0),
        pickupName: 'LGBI Airport Arrivals',
        dropName: 'Ganeshguri',
      );

      final result = PricingEngine.evaluate(
        input: input,
        fixedRouteTariff: ganeshguriTariff,
      );

      expect(result.fairMin, 680.0);
      expect(result.fairMax, 680.0);
      expect(result.level, PriceVerdictLevel.fair);
      expect(result.confidence, ConfidenceLevel.high);

      final official = result.sources.firstWhere((s) => s.type == 'official');
      expect(official.sourceName, 'LGBI Airport Pre-paid Taxi Counter, Guwahati');
      expect(official.details, contains('Official prepaid fare Rs 680 (about 28 km)'));
      expect(official.details, contains('effective date not stated'));

      // Check tolls note
      expect(
        result.factors.any((f) => f.evidence.contains('Ask the counter whether tolls are included')),
        isTrue,
      );
    });

    test('Night ride does NOT add night surcharges or tolls on top of official fare', () {
      final inputNight = PriceCheckInput(
        serviceType: ServiceType.taxi,
        distanceKm: 28.0,
        quotedPrice: 680.0,
        timeOfDay: DateTime(2026, 4, 1, 23, 30), // Night time
        pickupName: 'LGBI Airport',
        dropName: 'Ganeshguri',
      );

      final result = PricingEngine.evaluate(
        input: inputNight,
        fixedRouteTariff: ganeshguriTariff,
      );

      // Remains exactly Rs 680 (no surcharge added)
      expect(result.fairMin, 680.0);
      expect(result.fairMax, 680.0);
      expect(result.level, PriceVerdictLevel.fair);
    });

    test('Flagged row with check_against_printed_list yields Medium confidence and counter note', () {
      final input = PriceCheckInput(
        serviceType: ServiceType.taxi,
        distanceKm: 120.0,
        quotedPrice: 2800.0,
        timeOfDay: DateTime(2026, 4, 1, 10, 0),
        pickupName: 'LGBI Airport',
        dropName: 'Shillong (Police Bazar)',
      );

      final result = PricingEngine.evaluate(
        input: input,
        fixedRouteTariff: shillongFlaggedTariff,
      );

      expect(result.fairMin, 2800.0);
      expect(result.fairMax, 2800.0);
      expect(result.confidence, ConfidenceLevel.medium); // Medium confidence!
      expect(
        result.factors.any((f) => f.evidence.contains('Confirm at the counter')),
        isTrue,
      );
    });
  });

  group('Phase 3 - PRICING BEHAVIOR: Scoring, Tolerance & Risk Thresholds', () {
    test('Exact fare (680) -> Fair', () {
      final input = PriceCheckInput(
        serviceType: ServiceType.taxi,
        distanceKm: 28.0,
        quotedPrice: 680.0,
        timeOfDay: DateTime(2026, 4, 1, 12, 0),
        pickupName: 'LGBI Airport',
        dropName: 'Ganeshguri',
      );

      final result = PricingEngine.evaluate(
        input: input,
        fixedRouteTariff: ganeshguriTariff,
      );

      expect(result.level, PriceVerdictLevel.fair);
      expect(result.riskScore, 0);
    });

    test('+5 percent tolerance (714) -> Fair', () {
      // 680 * 1.05 = 714
      final input = PriceCheckInput(
        serviceType: ServiceType.taxi,
        distanceKm: 28.0,
        quotedPrice: 714.0,
        timeOfDay: DateTime(2026, 4, 1, 12, 0),
        pickupName: 'LGBI Airport',
        dropName: 'Ganeshguri',
      );

      final result = PricingEngine.evaluate(
        input: input,
        fixedRouteTariff: ganeshguriTariff,
      );

      expect(result.level, PriceVerdictLevel.fair);
      expect(result.riskScore, 0);
    });

    test('+30 percent markup (884) -> Suspicious', () {
      // 680 * 1.30 = 884
      final input = PriceCheckInput(
        serviceType: ServiceType.taxi,
        distanceKm: 28.0,
        quotedPrice: 884.0,
        timeOfDay: DateTime(2026, 4, 1, 12, 0),
        pickupName: 'LGBI Airport',
        dropName: 'Ganeshguri',
      );

      final result = PricingEngine.evaluate(
        input: input,
        fixedRouteTariff: ganeshguriTariff,
      );

      expect(result.level, PriceVerdictLevel.suspicious);
    });

    test('+60 percent markup (1088) -> High Risk', () {
      // 680 * 1.60 = 1088 (> 1.5x)
      final input = PriceCheckInput(
        serviceType: ServiceType.taxi,
        distanceKm: 28.0,
        quotedPrice: 1088.0,
        timeOfDay: DateTime(2026, 4, 1, 12, 0),
        pickupName: 'LGBI Airport',
        dropName: 'Ganeshguri',
      );

      final result = PricingEngine.evaluate(
        input: input,
        fixedRouteTariff: ganeshguriTariff,
      );

      expect(result.level, PriceVerdictLevel.highRisk);
      expect(result.explanation, contains('1.6x the official prepaid fare'));
    });

    test('Demo Scenario: Driver quotes Rs 1200 for Rs 680 fare -> High Risk (1.8x)', () {
      final input = PriceCheckInput(
        serviceType: ServiceType.taxi,
        distanceKm: 28.0,
        quotedPrice: 1200.0,
        timeOfDay: DateTime(2026, 4, 1, 12, 0),
        pickupName: 'LGBI Airport',
        dropName: 'Ganeshguri',
      );

      final result = PricingEngine.evaluate(
        input: input,
        fixedRouteTariff: ganeshguriTariff,
      );

      expect(result.level, PriceVerdictLevel.highRisk);
      expect(result.explanation, 'Quoted price is 1.8x the official prepaid fare');
    });

    test('Below 0.6x official fare (300 vs 680) -> Flagged as possible hidden-charge risk', () {
      final input = PriceCheckInput(
        serviceType: ServiceType.taxi,
        distanceKm: 28.0,
        quotedPrice: 300.0, // Below 0.6 * 680 (408)
        timeOfDay: DateTime(2026, 4, 1, 12, 0),
        pickupName: 'LGBI Airport',
        dropName: 'Ganeshguri',
      );

      final result = PricingEngine.evaluate(
        input: input,
        fixedRouteTariff: ganeshguriTariff,
      );

      expect(result.isUnusuallyLow, isTrue);
      expect(result.explanation, contains('below 0.6x official prepaid fare'));
      expect(result.explanation, contains('hidden charges'));
    });
  });

  group('Phase 3 - PRICING BEHAVIOR: Unlisted & Reverse Direction Fallbacks', () {
    test('Unlisted destination from airport uses derivedEstimate (never official, confidence Low)', () {
      // 10 km route from airport to unlisted spot
      // Derived estimate = 200 base + 24 * 10 = 440
      final input = PriceCheckInput(
        serviceType: ServiceType.taxi,
        distanceKm: 10.0,
        quotedPrice: 500.0,
        timeOfDay: DateTime(2026, 4, 1, 14, 0),
        pickupName: 'LGBI Airport Guwahati',
        dropName: 'Some Unlisted Village',
      );

      final result = PricingEngine.evaluate(
        input: input,
        fixedRouteTariff: null, // Destination not listed!
      );

      // Verify source is labeled 'Estimated from airport prepaid rates'
      expect(result.sources.any((s) => s.type == 'official'), isFalse); // Never official!
      final estimateSrc = result.sources.firstWhere(
        (s) => s.sourceName == 'Estimated from airport prepaid rates',
      );
      expect(estimateSrc.amount, 440.0);
      expect(result.confidence, ConfidenceLevel.low);
      expect(result.fairMin, closeTo(396.0, 1.0));
      expect(result.fairMax, closeTo(484.0, 1.0));
    });

    test('Trip TO the airport uses derivedEstimate with reverse direction label', () {
      // Trip originating from Ganeshguri TO LGBI Airport (28 km)
      // Derived estimate = 200 + 24 * 28 = 200 + 672 = 872
      final input = PriceCheckInput(
        serviceType: ServiceType.taxi,
        distanceKm: 28.0,
        quotedPrice: 900.0,
        timeOfDay: DateTime(2026, 4, 1, 14, 0),
        pickupName: 'Ganeshguri',
        dropName: 'LGBI Airport, Guwahati', // Trip TO the airport
      );

      final result = PricingEngine.evaluate(
        input: input,
        fixedRouteTariff: null,
      );

      // Never official
      expect(result.sources.any((s) => s.type == 'official'), isFalse);
      expect(result.confidence, ConfidenceLevel.low);

      final estimateSrc = result.sources.firstWhere(
        (s) => s.sourceName == 'Estimated from airport prepaid rates',
      );
      expect(estimateSrc.amount, 872.0);

      // Check reverse direction factor tag
      expect(
        result.factors.any((f) => f.label.contains('Reverse Direction')),
        isTrue,
      );
      expect(result.explanation, contains('Trip to airport'));
    });
  });
}
