import 'package:flutter_test/flutter_test.dart';
import 'package:travel_buddy/core/data/tariff_repository.dart';
import 'package:travel_buddy/core/models/app_models.dart';
import 'package:travel_buddy/core/utils/pricing_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 1 - DATA: Airport Prepaid Fare Integration Tests', () {
    test('FixedRouteTariff model correctly serializes and deserializes', () {
      final tariff = FixedRouteTariff(
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

      final json = tariff.toJson();
      expect(json['origin'], 'LGBI Airport, Guwahati');
      expect(json['destinationName'], 'Ganeshguri');
      expect(json['destinationNameHi'], 'गणेशगुरी');
      expect(json['aliases'], contains('Ganesh Guri'));
      expect(json['km'], 28.0);
      expect(json['fare'], 680.0);
      expect(json['category'], 'Local');
      expect(json['flags'], isEmpty);
      expect(json['source'], 'LGBI Airport Pre-paid Taxi Counter, Guwahati');
      expect(json['effectiveDate'], isNull);
      expect(json['verified'], isTrue);

      final parsed = FixedRouteTariff.fromJson(json);
      expect(parsed.destinationName, 'Ganeshguri');
      expect(parsed.fare, 680.0);
      expect(parsed.km, 28.0);
      expect(parsed.ratePerKm, closeTo(24.28, 0.05));
      expect(parsed.hasFlagCheckPrintedList, isFalse);
    });

    test('FixedRouteTariff handles flags like check_against_printed_list', () {
      final tariff = FixedRouteTariff(
        origin: 'LGBI Airport, Guwahati',
        destinationName: 'Shillong (Police Bazar)',
        destinationNameHi: 'शिलांग (पुलिस बाज़ार)',
        aliases: const ['Police Bazar', 'PB Shillong'],
        km: 120.0,
        fare: 2800.0,
        category: 'Out of state',
        flags: const ['check_against_printed_list'],
        source: 'LGBI Airport Pre-paid Taxi Counter, Guwahati',
        effectiveDate: null,
        verified: true,
      );

      expect(tariff.hasFlagCheckPrintedList, isTrue);
      expect(tariff.category, 'Out of state');
      expect(tariff.fare, 2800.0);
    });

    test('LocalGovTariffRepository lazily loads and caches airport prepaid dataset', () async {
      final repo = LocalGovTariffRepository();

      final dataset1 = await repo.getAirportDataset();
      expect(dataset1.source, contains('LGBI Airport Pre-paid Taxi Counter'));
      expect(dataset1.effectiveDate, isNull);
      expect(dataset1.verified, isTrue);
      expect(dataset1.routes.isNotEmpty, isTrue);

      final ganeshguri = dataset1.routes.firstWhere(
        (r) => r.destinationName == 'Ganeshguri',
      );
      expect(ganeshguri.fare, 680.0);
      expect(ganeshguri.km, 28.0);

      final shillongPB = dataset1.routes.firstWhere(
        (r) => r.destinationName == 'Shillong (Police Bazar)',
      );
      expect(shillongPB.hasFlagCheckPrintedList, isTrue);
      expect(shillongPB.fare, 2800.0);

      // Verify caching: second call returns the cached instance
      final dataset2 = await repo.getAirportDataset();
      expect(identical(dataset1, dataset2), isTrue);

      final tariffs = await repo.getAirportPrepaidTariffs();
      expect(tariffs.length, dataset1.routes.length);
    });

    test('PricingEngine: Matching FixedRouteTariff is the TOP priority fair-price source', () {
      final fixedTariff = FixedRouteTariff(
        origin: 'LGBI Airport, Guwahati',
        destinationName: 'Ganeshguri',
        destinationNameHi: 'गणेशगुरी',
        aliases: const ['Ganesh Guri'],
        km: 28.0,
        fare: 680.0,
        category: 'Local',
        source: 'LGBI Airport Pre-paid Taxi Counter, Guwahati',
        effectiveDate: null,
        verified: true,
      );

      final conflictingGovTariff = GovTariff(
        id: 'conflicting-tariff',
        city: 'Guwahati',
        serviceType: ServiceType.taxi,
        vehicleType: 'Sedan',
        baseFare: 100.0,
        perKm: 30.0,
        minFare: 100.0,
        effectiveDate: DateTime(2024, 1, 1),
        source: 'Generic RTO Rate',
        sourceUrl: '',
        verified: false,
      );

      final input = PriceCheckInput(
        serviceType: ServiceType.taxi,
        distanceKm: 28.0,
        durationMinutes: 45.0,
        quotedPrice: 680.0, // Exactly official fare
        timeOfDay: DateTime(2026, 4, 1, 12, 0),
      );

      final result = PricingEngine.evaluate(
        input: input,
        tariff: conflictingGovTariff, // Pass standard GovTariff as well
        fixedRouteTariff: fixedTariff, // FixedRouteTariff must take top priority!
      );

      // Fair price = official fare (range min = max = fare)
      expect(result.fairMin, 680.0);
      expect(result.fairMax, 680.0);
      expect(result.level, PriceVerdictLevel.fair);
      expect(result.confidence, ConfidenceLevel.high);

      // Source check
      final officialSrc = result.sources.firstWhere((s) => s.type == 'official');
      expect(officialSrc.sourceName, 'LGBI Airport Pre-paid Taxi Counter, Guwahati');
      expect(officialSrc.amount, 680.0);
      expect(officialSrc.details, contains('Official prepaid fare Rs 680'));
      expect(officialSrc.details, contains('effective date not stated'));

      // Counter note factor
      expect(
        result.factors.any((f) => f.evidence.contains('Ask the counter whether tolls are included')),
        isTrue,
      );
    });

    test('PricingEngine: Demo Scenario Airport -> Ganeshguri quotes Rs 1200 -> High Risk 1.8x', () {
      final fixedTariff = FixedRouteTariff(
        origin: 'LGBI Airport, Guwahati',
        destinationName: 'Ganeshguri',
        km: 28.0,
        fare: 680.0,
        category: 'Local',
        source: 'LGBI Airport Pre-paid Taxi Counter, Guwahati',
        effectiveDate: null,
        verified: true,
      );

      final input = PriceCheckInput(
        serviceType: ServiceType.taxi,
        distanceKm: 28.0,
        durationMinutes: 45.0,
        quotedPrice: 1200.0,
        timeOfDay: DateTime(2026, 4, 1, 12, 0),
      );

      final result = PricingEngine.evaluate(
        input: input,
        fixedRouteTariff: fixedTariff,
      );

      expect(result.level, PriceVerdictLevel.highRisk);
      expect(result.explanation, 'Quoted price is 1.8x the official prepaid fare');
    });

    test('PricingEngine: Flagged row check_against_printed_list gives Medium confidence', () {
      final shillongTariff = FixedRouteTariff(
        origin: 'LGBI Airport, Guwahati',
        destinationName: 'Shillong (Police Bazar)',
        km: 120.0,
        fare: 2800.0,
        category: 'Out of state',
        flags: const ['check_against_printed_list'],
        source: 'LGBI Airport Pre-paid Taxi Counter, Guwahati',
        effectiveDate: null,
        verified: true,
      );

      final input = PriceCheckInput(
        serviceType: ServiceType.taxi,
        distanceKm: 120.0,
        durationMinutes: 180.0,
        quotedPrice: 2800.0,
        timeOfDay: DateTime(2026, 4, 1, 10, 0),
      );

      final result = PricingEngine.evaluate(
        input: input,
        fixedRouteTariff: shillongTariff,
      );

      expect(result.fairMin, 2800.0);
      expect(result.fairMax, 2800.0);
      expect(result.confidence, ConfidenceLevel.medium);
      expect(
        result.factors.any((f) => f.evidence.contains('Confirm at the counter')),
        isTrue,
      );
    });
  });
}
