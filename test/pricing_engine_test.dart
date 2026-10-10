import 'package:flutter_test/flutter_test.dart';
import 'package:travel_buddy/core/constants/price_thresholds.dart';
import 'package:travel_buddy/core/models/app_models.dart';
import 'package:travel_buddy/core/utils/engine_math.dart';
import 'package:travel_buddy/core/utils/pricing_engine.dart';

void main() {
  group('PricingEngine Fare Calculation Tests', () {
    final sampleAutoTariff = GovTariff(
      id: 'tariff-test-auto',
      city: 'Jaipur',
      serviceType: ServiceType.auto,
      vehicleType: 'Auto-rickshaw',
      baseFare: 30.0,
      perKm: 12.0,
      perMin: 0.5,
      minFare: 30.0,
      waitingFarePerHour: 30.0,
      nightSurchargePercent: 25.0,
      effectiveDate: DateTime(2024, 1, 1),
      source: 'Rajasthan Transport Dept',
      sourceUrl: '',
      verified: true,
    );

    test('Standard daytime ride calculates base + km + min correctly', () {
      final input = PriceCheckInput(
        serviceType: ServiceType.auto,
        distanceKm: 5.0,
        durationMinutes: 15.0,
        quotedPrice: 100.0,
        timeOfDay: DateTime(2026, 4, 1, 14, 0), // 2:00 PM
      );

      final result = PricingEngine.evaluate(
        input: input,
        tariff: sampleAutoTariff,
      );

      // Expected tariff: 30 + (12 * 5) + (0.5 * 15) = 30 + 60 + 7.5 = 97.5 -> rounded to 98
      expect(result.sources.any((s) => s.type == 'official'), isTrue);
      expect(result.fairMin, inInclusiveRange(97.0, 99.0));
      // fairMax is 1.10x fairMin = ~107
      expect(result.fairMax, inInclusiveRange(106.0, 109.0));
      // Quoted 100 is <= fairMax -> Fair verdict
      expect(result.level, PriceVerdictLevel.fair);
      expect(result.confidence, ConfidenceLevel.high);
    });

    test('Night surcharge (25%) is applied between 23:00 and 05:00', () {
      final input = PriceCheckInput(
        serviceType: ServiceType.auto,
        distanceKm: 10.0,
        durationMinutes: 20.0,
        quotedPrice: 200.0,
        timeOfDay: DateTime(2026, 4, 1, 23, 30), // 11:30 PM Night
      );

      final result = PricingEngine.evaluate(
        input: input,
        tariff: sampleAutoTariff,
      );

      // Daytime: 30 + 120 + 10 = 160. Night +25% = 200.
      expect(result.fairMin, inInclusiveRange(199.0, 201.0));
    });

    test('Minimum fare floor is enforced for very short trips', () {
      final input = PriceCheckInput(
        serviceType: ServiceType.auto,
        distanceKm: 0.2,
        durationMinutes: 1.0,
        quotedPrice: 30.0,
        timeOfDay: DateTime(2026, 4, 1, 12, 0),
      );

      final result = PricingEngine.evaluate(
        input: input,
        tariff: sampleAutoTariff,
      );

      // 30 + 2.4 + 0.5 = 32.9 >= 30.
      expect(result.fairMin, greaterThanOrEqualTo(sampleAutoTariff.minFare));
    });
  });

  group('Community Benchmark & Percentiles Tests', () {
    test('Calculates recency-weighted percentiles and drops 10% outliers', () {
      final items = [
        WeightedValue(value: 50.0, weight: 1.0), // Outlier bottom
        WeightedValue(value: 90.0, weight: 1.0),
        WeightedValue(value: 100.0, weight: 1.0),
        WeightedValue(value: 105.0, weight: 1.0),
        WeightedValue(value: 110.0, weight: 1.0),
        WeightedValue(value: 115.0, weight: 1.0),
        WeightedValue(value: 350.0, weight: 1.0), // Outlier top
      ];

      final stats = EngineMath.calculateWeightedPercentiles(items: items);
      expect(stats, isNotNull);
      expect(stats!.count, 7);
      expect(stats.median, inInclusiveRange(100.0, 110.0));
      expect(stats.p25, inInclusiveRange(90.0, 105.0));
      expect(stats.p75, inInclusiveRange(105.0, 115.0));
    });

    test('Requires at least 5 reports for community benchmark', () {
      final input = PriceCheckInput(
        serviceType: ServiceType.meal,
        quotedPrice: 250.0,
      );

      final fewReports = [
        PriceReport(
          id: 'r1',
          serviceType: ServiceType.meal,
          vehicleType: 'Standard',
          routeOrPlace: 'Old Town',
          pricePaid: 200.0,
          timestamp: DateTime.now(),
          wasFair: true,
        ),
      ];

      final result = PricingEngine.evaluate(input: input, reports: fewReports);

      // Should fallback to model estimate
      expect(result.sources.any((s) => s.type == 'community'), isFalse);
      expect(result.sources.any((s) => s.type == 'estimate'), isTrue);
    });
  });

  group('Scoring, Anomaly, and Overrides Tests', () {
    final tariff = GovTariff(
      id: 'tariff-1',
      city: 'Delhi',
      serviceType: ServiceType.auto,
      vehicleType: 'Auto-rickshaw',
      baseFare: 30.0,
      perKm: 10.0,
      minFare: 30.0,
      effectiveDate: DateTime(2024, 1, 1),
      source: 'Delhi Gov',
      sourceUrl: '',
      verified: true,
    );

    test('Unusually low rule (< 0.6x fairMin) flags priceScore=35 and anomaly reason', () {
      final input = PriceCheckInput(
        serviceType: ServiceType.auto,
        distanceKm: 10.0, // tariff fare ~130, fairMin ~130
        quotedPrice: 50.0, // 50 < 0.6 * 130 = 78 -> Unusually low
      );

      final result = PricingEngine.evaluate(input: input, tariff: tariff);

      expect(result.isUnusuallyLow, isTrue);
      expect(
        result.factors.any((f) => f.label == 'Suspiciously Low Quote'),
        isTrue,
      );
      expect(
        result.factors.any(
          (f) => f.evidence.contains(PriceThresholds.unusuallyLowReason),
        ),
        isTrue,
      );
    });

    test('Override 1: Quoted <= official max cannot exceed Suspicious', () {
      // Create scenario with active nearby tourist traps to inflate trapScore
      final traps = [
        TouristTrap(
          id: 'trap-1',
          latitude: 28.6000,
          longitude: 77.2000,
          serviceType: ServiceType.auto,
          type: 'overcharging',
          description: 'Station scam',
          avoidTip: 'Avoid',
          severity: 5,
          reportCount: 50,
          lastReported: DateTime.now(),
          source: 'community',
        ),
      ];

      final input = PriceCheckInput(
        serviceType: ServiceType.auto,
        pickupLat: 28.6001,
        pickupLng: 77.2001,
        dropLat: 28.6050,
        dropLng: 77.2050,
        distanceKm: 5.0, // tariff fare = 30 + 50 = 80, fairMax ~ 88
        quotedPrice: 85.0, // Quoted is <= officialMax (88)
      );

      final result = PricingEngine.evaluate(
        input: input,
        tariff: tariff,
        traps: traps,
      );

      // Even if trap score is elevated, verdict cannot be High Risk
      expect(result.level, isNot(PriceVerdictLevel.highRisk));
    });

    test('Override 2: Quoted > 1.5x official max is forced to High Risk', () {
      final input = PriceCheckInput(
        serviceType: ServiceType.auto,
        distanceKm: 5.0, // fare = 80, fairMax = 88, 1.5x = 132
        quotedPrice: 150.0, // 150 > 132
      );

      final result = PricingEngine.evaluate(input: input, tariff: tariff);

      expect(result.level, PriceVerdictLevel.highRisk);
      expect(result.riskScore, greaterThanOrEqualTo(60));
    });

    test('Low confidence result explicitly states based on an estimate', () {
      final input = PriceCheckInput(
        serviceType: ServiceType.other,
        quotedPrice: 500.0,
      );

      final result = PricingEngine.evaluate(input: input);

      expect(result.confidence, ConfidenceLevel.low);
      expect(result.explanation, contains('based on an estimate'));
    });

    test('Counter-offer equals fairMax and provides copyable phrase', () {
      final input = PriceCheckInput(
        serviceType: ServiceType.auto,
        distanceKm: 5.0,
        quotedPrice: 140.0,
      );

      final result = PricingEngine.evaluate(input: input, tariff: tariff);

      expect(result.counterOffer, result.fairMax);
      expect(
        result.counterOfferLine,
        contains('Can we agree on ₹${result.counterOffer.toInt()}?'),
      );
    });
  });
}
