import 'package:flutter_test/flutter_test.dart';
import 'package:travel_buddy/core/models/app_models.dart';
import 'package:travel_buddy/core/utils/fair_price_calculator.dart';

void main() {
  group('FairPriceCalculator Logic Tests', () {
    const double fairMin = 200.0;
    const double fairMax = 300.0;

    test('quoted below fairMin (150.0) -> Verdict is Fair with 0 diff', () {
      final result = FairPriceCalculator.evaluate(
        quotedPrice: 150.0,
        fairMin: fairMin,
        fairMax: fairMax,
      );
      expect(result.verdict, PriceVerdictType.fair);
      expect(result.differenceRupees, 0.0);
      expect(result.isOvercharged, isFalse);
    });

    test('quoted between fairMin and fairMax (250.0) -> Verdict is Fair with 0 diff', () {
      final result = FairPriceCalculator.evaluate(
        quotedPrice: 250.0,
        fairMin: fairMin,
        fairMax: fairMax,
      );
      expect(result.verdict, PriceVerdictType.fair);
      expect(result.differenceRupees, 0.0);
      expect(result.isOvercharged, isFalse);
    });

    test(
      'quoted exactly at fairMax (300.0) -> Verdict is Fair with 0 diff',
      () {
        final result = FairPriceCalculator.evaluate(
          quotedPrice: 300.0,
          fairMin: fairMin,
          fairMax: fairMax,
        );
        expect(result.verdict, PriceVerdictType.fair);
        expect(result.differenceRupees, 0.0);
      },
    );

    test('quoted within 10% tolerance (320.0 <= 330.0) -> Verdict is Fair with diff', () {
      final result = FairPriceCalculator.evaluate(
        quotedPrice: 320.0,
        fairMin: fairMin,
        fairMax: fairMax,
      );
      expect(result.verdict, PriceVerdictType.fair);
      expect(result.differenceRupees, 20.0);
      expect(result.isOvercharged, isFalse);
    });

    test(
      'quoted exactly at 1.10x fairMax boundary (330.0) -> Verdict is Fair',
      () {
        final result = FairPriceCalculator.evaluate(
          quotedPrice: 330.0,
          fairMin: fairMin,
          fairMax: fairMax,
        );
        expect(result.verdict, PriceVerdictType.fair);
        expect(result.differenceRupees, 30.0);
      },
    );

    test('quoted slightly above 1.10x boundary (335.0) -> Verdict is Slightly High', () {
      final result = FairPriceCalculator.evaluate(
        quotedPrice: 335.0,
        fairMin: fairMin,
        fairMax: fairMax,
      );
      expect(result.verdict, PriceVerdictType.slightlyHigh);
      expect(result.differenceRupees, 35.0);
      expect(result.isOvercharged, isFalse);
    });

    test(
      'quoted midway in slightly high band (360.0) -> Verdict is Slightly High',
      () {
        final result = FairPriceCalculator.evaluate(
          quotedPrice: 360.0,
          fairMin: fairMin,
          fairMax: fairMax,
        );
        expect(result.verdict, PriceVerdictType.slightlyHigh);
        expect(result.differenceRupees, 60.0);
      },
    );

    test('quoted exactly at 1.30x fairMax boundary (390.0) -> Verdict is Slightly High', () {
      final result = FairPriceCalculator.evaluate(
        quotedPrice: 390.0,
        fairMin: fairMin,
        fairMax: fairMax,
      );
      expect(result.verdict, PriceVerdictType.slightlyHigh);
      expect(result.differenceRupees, 90.0);
      expect(result.isOvercharged, isFalse);
    });

    test('quoted above 1.30x fairMax (391.0) -> Verdict is Overcharged', () {
      final result = FairPriceCalculator.evaluate(
        quotedPrice: 391.0,
        fairMin: fairMin,
        fairMax: fairMax,
      );
      expect(result.verdict, PriceVerdictType.overcharged);
      expect(result.differenceRupees, 91.0);
      expect(result.isOvercharged, isTrue);
    });

    test('quoted heavily inflated (1000.0 vs fairMax 300.0) -> Verdict is Overcharged', () {
      final result = FairPriceCalculator.evaluate(
        quotedPrice: 1000.0,
        fairMin: fairMin,
        fairMax: fairMax,
      );
      expect(result.verdict, PriceVerdictType.overcharged);
      expect(result.differenceRupees, 700.0);
      expect(result.isOvercharged, isTrue);
    });
  });

  group('FareRule Calculation Tests', () {
    const bikeRule = FareRule(
      vehicleType: 'bike',
      displayName: 'Bike Taxi',
      baseFare: 20.0,
      perKmRate: 8.0,
      perMinuteRate: 1.0,
      minimumFare: 30.0,
      badRoadMultiplier: 1.2,
    );

    const autoRule = FareRule(
      vehicleType: 'auto',
      displayName: 'Auto Rickshaw',
      baseFare: 30.0,
      perKmRate: 12.0,
      perMinuteRate: 1.5,
      minimumFare: 50.0,
      badRoadMultiplier: 1.25,
    );

    test('Bike Taxi normal fare calculation (5 km, 15 min)', () {
      final fare = bikeRule.calculateFare(distanceKm: 5.0, timeMinutes: 15.0);
      // 20 + (8*5) + (1*15) = 75.0
      expect(fare, 75.0);
    });

    test(
      'Bike Taxi with bad road multiplier (5 km, 15 min, isBadRoad: true)',
      () {
        final fare = bikeRule.calculateFare(
          distanceKm: 5.0,
          timeMinutes: 15.0,
          isBadRoad: true,
        );
        // 75.0 * 1.2 = 90.0
        expect(fare, 90.0);
      },
    );

    test(
      'Bike Taxi minimum fare floor applied when calculated below minimum',
      () {
        final fare = bikeRule.calculateFare(distanceKm: 0.5, timeMinutes: 2.0);
        // 20 + 4 + 2 = 26 < minimumFare 30 -> 30.0
        expect(fare, 30.0);
      },
    );

    test('Auto Rickshaw normal fare calculation (10 km, 20 min)', () {
      final fare = autoRule.calculateFare(distanceKm: 10.0, timeMinutes: 20.0);
      // 30 + 120 + 30 = 180.0
      expect(fare, 180.0);
    });

    test(
      'Auto Rickshaw bad road multiplier (10 km, 20 min, isBadRoad: true)',
      () {
        final fare = autoRule.calculateFare(
          distanceKm: 10.0,
          timeMinutes: 20.0,
          isBadRoad: true,
        );
        // 180.0 * 1.25 = 225.0
        expect(fare, 225.0);
      },
    );

    test('Auto Rickshaw minimum fare floor applied (0.5 km, 1 min)', () {
      final fare = autoRule.calculateFare(distanceKm: 0.5, timeMinutes: 1.0);
      // 30 + 6 + 1.5 = 37.5 < minimumFare 50 -> 50.0
      expect(fare, 50.0);
    });
  });
}
