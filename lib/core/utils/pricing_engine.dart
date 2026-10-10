import 'dart:math';

import '../constants/price_thresholds.dart';
import '../models/app_models.dart';
import '../services/airport_prepaid_matcher.dart';
import 'engine_math.dart';

/// Deterministic, testable AI Price Intelligence Engine
class PricingEngine {
  PricingEngine._();

  static PriceCheckResult evaluate({
    required PriceCheckInput input,
    GovTariff? tariff,
    FixedRouteTariff? fixedRouteTariff,
    FixedRouteTariff? fixedTariff,
    bool isAirportTrip = false,
    bool isToAirport = false,
    double airportBaseFare = 200.0,
    double airportPerKmRate = 24.0,
    List<PriceReport> reports = const [],
    List<TouristTrap> traps = const [],
    List<String> knownReportedEntities = const [],
  }) {
    final activeFixedTariff = fixedRouteTariff ?? fixedTariff;
    // 1. Calculate effective distance and travel duration
    final double distanceKm = _resolveDistance(input);
    final double durationMinutes = _resolveDuration(input, distanceKm);

    // Detect airport trips and direction
    final bool detectedPickupAirport = AirportPrepaidMatcher.isAirportPickup(
      lat: input.pickupLat,
      lng: input.pickupLng,
      name: input.pickupName,
    );
    final bool detectedDropAirport = AirportPrepaidMatcher.isAirportDropoff(
      lat: input.dropLat,
      lng: input.dropLng,
      name: input.dropName,
    );

    final bool tripIsToAirport = isToAirport || detectedDropAirport;
    final bool tripIsFromAirport = (isAirportTrip && !isToAirport) ||
        detectedPickupAirport ||
        (activeFixedTariff != null && !tripIsToAirport);

    final bool useAirportDerivedEstimate =
        (tripIsToAirport || (tripIsFromAirport && activeFixedTariff == null)) &&
        (input.serviceType == ServiceType.taxi ||
            input.serviceType == ServiceType.auto ||
            input.serviceType == ServiceType.other);

    // 2. Compute Official Tariff Fare (if present)
    double? officialFare;
    double? officialMin;
    double? officialMax;
    PriceCheckSource? officialSource;

    if (activeFixedTariff != null && !tripIsToAirport) {
      officialFare = activeFixedTariff.fare;
      officialMin = activeFixedTariff.fare;
      officialMax = activeFixedTariff.fare;

      final String dateStr = activeFixedTariff.effectiveDate != null
          ? activeFixedTariff.effectiveDate!.toIso8601String().split('T').first
          : 'effective date not stated';
      final String dateNote = activeFixedTariff.effectiveDate == null
          ? ' • effective date not stated'
          : '';

      officialSource = PriceCheckSource(
        type: 'official',
        amount: activeFixedTariff.fare,
        minAmount: activeFixedTariff.fare,
        maxAmount: activeFixedTariff.fare,
        sourceName: activeFixedTariff.source,
        effectiveDate: dateStr,
        details:
            'Official prepaid fare Rs ${activeFixedTariff.fare.round()} (about ${activeFixedTariff.km.round()} km)$dateNote',
      );
    } else if (!useAirportDerivedEstimate && tariff != null) {
      officialFare = _calculateTariffFare(
        tariff,
        input,
        distanceKm,
        durationMinutes,
      );
      officialMin = officialFare;
      officialMax = (officialFare * 1.10).roundToDouble();

      final String dateStr = tariff.effectiveDate
          .toIso8601String()
          .split('T')
          .first;
      officialSource = PriceCheckSource(
        type: 'official',
        amount: officialFare,
        minAmount: officialMin,
        maxAmount: officialMax,
        sourceName: tariff.source,
        effectiveDate: dateStr,
        details: tariff.verified
            ? 'Official notified government tariff'
            : 'Sample tariff (Pending official Gazette verification)',
      );
    }

    // 3. Compute Community Benchmark (if available)
    BenchmarkStats? benchmarkStats;
    PriceCheckSource? communitySource;
    final matchingReports = _filterMatchingReports(input, reports);

    if (matchingReports.length >= PriceThresholds.minReportsForBenchmark) {
      benchmarkStats = _calculateCommunityBenchmark(matchingReports);
      if (benchmarkStats != null) {
        communitySource = PriceCheckSource(
          type: 'community',
          amount: benchmarkStats.median,
          minAmount: benchmarkStats.p25,
          maxAmount: benchmarkStats.p75,
          sourceName: 'Traveller Community Reports',
          reportCount: benchmarkStats.count,
          details:
              'Median ₹${benchmarkStats.median.round()} from ${benchmarkStats.count} reports (last 90 days)',
        );
      }
    }

    // 4. Model Estimate or Airport Derived Estimate
    final PriceCheckSource estimateSource;
    final double estimateMin;
    final double estimateMax;

    if (useAirportDerivedEstimate) {
      // derivedEstimate = base + perKm x route distance from Routes API
      final double derivedFare =
          (airportBaseFare + (airportPerKmRate * distanceKm)).roundToDouble();
      estimateMin = (derivedFare * 0.90).roundToDouble();
      estimateMax = (derivedFare * 1.10).roundToDouble();

      estimateSource = PriceCheckSource(
        type: 'estimate', // Never official!
        amount: derivedFare,
        minAmount: estimateMin,
        maxAmount: estimateMax,
        sourceName: 'Estimated from airport prepaid rates',
        details: tripIsToAirport
            ? 'Trip to airport: Estimated from airport prepaid rates (₹${airportBaseFare.round()} base + ₹${airportPerKmRate.round()}/km)'
            : 'Destination not listed: Estimated from airport prepaid rates (₹${airportBaseFare.round()} base + ₹${airportPerKmRate.round()}/km)',
      );
    } else {
      final double modelEstimate = _calculateModelEstimate(input, distanceKm);
      estimateMin = (modelEstimate * PriceThresholds.estimateFairMinMultiplier)
          .roundToDouble();
      estimateMax = (modelEstimate * PriceThresholds.estimateFairMaxMultiplier)
          .roundToDouble();
      estimateSource = PriceCheckSource(
        type: 'estimate',
        amount: modelEstimate,
        minAmount: estimateMin,
        maxAmount: estimateMax,
        sourceName: 'Travel Buddy Pricing Model',
        details: 'Statistical baseline calculated from local mobility indices',
      );
    }

    // 5. Determine Fair Range (Priority: Fixed-Route Tariff -> Airport Derived Estimate -> Gov Tariff -> Community -> Model Estimate)
    final double fairMin;
    final double fairMax;
    if (activeFixedTariff != null && !tripIsToAirport) {
      fairMin = activeFixedTariff.fare;
      fairMax = activeFixedTariff.fare;
    } else if (useAirportDerivedEstimate) {
      fairMin = estimateMin;
      fairMax = estimateMax;
    } else if (officialMin != null && officialMax != null) {
      fairMin = officialMin;
      fairMax = officialMax;
    } else if (benchmarkStats != null) {
      fairMin = benchmarkStats.p25.roundToDouble();
      fairMax = benchmarkStats.p75.roundToDouble();
    } else {
      fairMin = estimateMin;
      fairMax = estimateMax;
    }

    // 6. Calculate Price Score
    final double ratio = fairMax > 0 ? (input.quotedPrice / fairMax) : 1.0;
    final bool isUnusuallyLow = (activeFixedTariff != null && !tripIsToAirport)
        ? input.quotedPrice < (0.6 * fairMin)
        : input.quotedPrice < (PriceThresholds.unusuallyLowMultiplier * fairMin);

    double priceScore;
    if (isUnusuallyLow) {
      priceScore = PriceThresholds.unusuallyLowDefaultScore.toDouble();
    } else if (activeFixedTariff != null && !tripIsToAirport) {
      final double toleranceLimit = (fairMax * 1.05).roundToDouble();
      if (input.quotedPrice <= toleranceLimit) {
        priceScore = 0.0;
      } else if (ratio > 1.50) {
        priceScore = 80.0;
      } else if (ratio <= PriceThresholds.ratioSuspiciousFloor) {
        priceScore = ((ratio - 1.05) / 0.20) * PriceThresholds.priceScoreAt1_25;
      } else {
        priceScore = PriceThresholds.priceScoreAt1_25 +
            ((ratio - 1.25) / 0.25) *
                (PriceThresholds.priceScoreAt1_60 - PriceThresholds.priceScoreAt1_25);
      }
    } else if (ratio <= PriceThresholds.ratioFairFloor) {
      priceScore = 0.0;
    } else if (ratio <= PriceThresholds.ratioSuspiciousFloor) {
      priceScore = ((ratio - 1.00) / 0.25) * PriceThresholds.priceScoreAt1_25;
    } else if (ratio <= PriceThresholds.ratioHighRiskFloor) {
      priceScore =
          PriceThresholds.priceScoreAt1_25 +
          ((ratio - 1.25) / 0.35) *
              (PriceThresholds.priceScoreAt1_60 -
                  PriceThresholds.priceScoreAt1_25);
    } else {
      final double progress =
          ((ratio - 1.60) / (PriceThresholds.ratioCap - 1.60)).clamp(0.0, 1.0);
      priceScore = PriceThresholds.priceScoreAt1_60 + progress * 25.0;
    }
    priceScore = priceScore.clamp(0.0, 100.0);

    // 7. Calculate Tourist Trap Score & Nearby Traps
    final nearbyTraps = _findNearbyTraps(input, traps);
    double trapScore = 0.0;
    final now = DateTime.now();

    for (final trap in nearbyTraps) {
      final daysAgo = max(0, now.difference(trap.lastReported).inDays);
      final recencyWeight = pow(
        0.5,
        daysAgo / PriceThresholds.trapRecencyHalfLifeDays,
      );
      trapScore += trap.severity * 8.0 * recencyWeight;
    }

    if (input.driverOrBusinessName != null &&
        input.driverOrBusinessName!.isNotEmpty) {
      final query = input.driverOrBusinessName!.toLowerCase();
      final hasComplaints = knownReportedEntities.any(
        (e) => e.toLowerCase().contains(query),
      );
      if (hasComplaints) trapScore += 25.0;
    }
    trapScore = trapScore.clamp(0.0, 100.0);

    // 8. Composite Risk Score & Level
    int riskScore =
        (PriceThresholds.priceScoreWeight * priceScore +
                PriceThresholds.trapScoreWeight * trapScore)
            .round()
            .clamp(0, 100);

    PriceVerdictLevel level = PriceVerdictLevel.fromScore(riskScore);

    // 9. Apply Overrides
    if (activeFixedTariff != null && !tripIsToAirport) {
      if (input.quotedPrice <= (fairMax * 1.05).roundToDouble()) {
        level = PriceVerdictLevel.fair;
      } else if (ratio > 1.5) {
        level = PriceVerdictLevel.highRisk;
        if (riskScore < 60) riskScore = 65;
      }
    } else if (officialMax != null) {
      if (input.quotedPrice <= officialMax) {
        if (level == PriceVerdictLevel.highRisk) {
          level = PriceVerdictLevel.suspicious;
        }
      } else if (input.quotedPrice >
          PriceThresholds.officialMaxHighRiskMultiplier * officialMax) {
        level = PriceVerdictLevel.highRisk;
        if (riskScore < 60) riskScore = 65;
      }
    }

    // 10. Confidence Level
    final ConfidenceLevel confidence;
    if (useAirportDerivedEstimate) {
      confidence = ConfidenceLevel.low; // Always Low, never official
    } else if (activeFixedTariff != null && !tripIsToAirport) {
      confidence = activeFixedTariff.hasFlagCheckPrintedList
          ? ConfidenceLevel.medium
          : ConfidenceLevel.high;
    } else if (officialFare != null ||
        matchingReports.length >= PriceThresholds.highConfidenceReportCount) {
      confidence = ConfidenceLevel.high;
    } else if (matchingReports.length >=
            PriceThresholds.minReportsForBenchmark ||
        nearbyTraps.isNotEmpty) {
      confidence = ConfidenceLevel.medium;
    } else {
      confidence = ConfidenceLevel.low;
    }

    // 11. Generate Factor List
    final factors = _generateFactors(
      ratio: ratio,
      isUnusuallyLow: isUnusuallyLow,
      priceScore: priceScore,
      trapScore: trapScore,
      nearbyTraps: nearbyTraps,
      officialMax: officialMax,
      input: input,
    );

    if (activeFixedTariff != null && !tripIsToAirport) {
      factors.add(
        const Factor(
          label: 'Prepaid Fare Note',
          points: 0,
          evidence: 'Ask the counter whether tolls are included',
          sourceTag: '[Official Tariff]',
        ),
      );
      if (activeFixedTariff.hasFlagCheckPrintedList) {
        factors.add(
          const Factor(
            label: 'Counter Check',
            points: 0,
            evidence: 'Confirm at the counter',
            sourceTag: '[Official Tariff]',
          ),
        );
      }
    } else if (useAirportDerivedEstimate) {
      if (tripIsToAirport) {
        factors.add(
          const Factor(
            label: 'Trip to Airport (Reverse Direction)',
            points: 0,
            evidence:
                'Trip is TO the airport. Prepaid counter rates officially apply FROM the airport; rate is estimated from airport prepaid baseline.',
            sourceTag: '[Estimated from airport prepaid rates]',
          ),
        );
      } else {
        factors.add(
          const Factor(
            label: 'Unlisted Airport Route',
            points: 0,
            evidence:
                'Destination not in printed prepaid list. Estimated from airport prepaid rates.',
            sourceTag: '[Estimated from airport prepaid rates]',
          ),
        );
      }
    }

    // 12. Counter-offer line
    final double counterOffer = fairMax.roundToDouble();
    final String counterOfferLine =
        'Local fair rate is ₹${counterOffer.toInt()}. Can we agree on ₹${counterOffer.toInt()}?';

    // 13. Sources list
    final List<PriceCheckSource> sources = [];
    if (officialSource != null) sources.add(officialSource);
    if (communitySource != null) sources.add(communitySource);
    sources.add(estimateSource);

    final double diffRupees = max(0.0, input.quotedPrice - fairMax);
    final double diffPercent = fairMax > 0
        ? (diffRupees / fairMax) * 100.0
        : 0.0;

    final String explanation;
    if (activeFixedTariff != null && !tripIsToAirport && ratio > 1.5) {
      explanation =
          'Quoted price is ${(input.quotedPrice / fairMax).toStringAsFixed(1)}x the official prepaid fare';
    } else if (activeFixedTariff != null && !tripIsToAirport && isUnusuallyLow) {
      explanation =
          'Quoted price is below 0.6x official prepaid fare. Possible hidden charges or bait-and-switch risk.';
    } else if (activeFixedTariff != null &&
        !tripIsToAirport &&
        input.quotedPrice <= (fairMax * 1.05).roundToDouble()) {
      explanation =
          'Price matches official prepaid taxi fare of ₹${fairMax.round()} (within 5% tolerance).';
    } else if (useAirportDerivedEstimate) {
      if (tripIsToAirport) {
        explanation =
            'Trip to airport: Estimated from airport prepaid rates of ₹${fairMin.round()}–₹${fairMax.round()} (Low confidence). Official counter fixed rates apply only departing from the airport.';
      } else {
        explanation =
            'Destination not in official prepaid tariff list. Estimated from airport prepaid rates of ₹${fairMin.round()}–₹${fairMax.round()} (Low confidence).';
      }
    } else {
      explanation = _buildDefaultExplanation(
        level,
        input.quotedPrice,
        fairMin,
        fairMax,
        confidence,
      );
    }

    return PriceCheckResult(
      level: level,
      riskScore: riskScore,
      confidence: confidence,
      fairMin: fairMin,
      fairMax: fairMax,
      quotedPrice: input.quotedPrice,
      differenceRupees: diffRupees,
      differencePercent: diffPercent,
      counterOffer: counterOffer,
      counterOfferLine: counterOfferLine,
      sources: sources,
      factors: factors,
      explanation: explanation,
      nearbyTraps: nearbyTraps,
      isUnusuallyLow: isUnusuallyLow,
    );
  }

  static double _resolveDistance(PriceCheckInput input) {
    if (input.distanceKm != null && input.distanceKm! > 0) {
      return input.distanceKm!;
    }
    if (input.pickupLat != null &&
        input.pickupLng != null &&
        input.dropLat != null &&
        input.dropLng != null) {
      final straight = EngineMath.haversineDistanceKm(
        input.pickupLat!,
        input.pickupLng!,
        input.dropLat!,
        input.dropLng!,
      );
      return (straight * PriceThresholds.straightLineDistanceFactor).clamp(
        1.0,
        500.0,
      );
    }
    return 5.0; // Default urban transit hop
  }

  static double _resolveDuration(PriceCheckInput input, double distanceKm) {
    if (input.durationMinutes != null && input.durationMinutes! > 0) {
      return input.durationMinutes!;
    }
    return ((distanceKm / 25.0) * 60.0).clamp(5.0, 600.0);
  }

  static FareRange calculateFare({
    required GovTariff tariff,
    required double distanceKm,
    required double durationMinutes,
    required DateTime timeOfDay,
  }) {
    final input = PriceCheckInput(
      serviceType: tariff.serviceType,
      quotedPrice: 100,
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
      timeOfDay: timeOfDay,
    );
    final fare = _calculateTariffFare(
      tariff,
      input,
      distanceKm,
      durationMinutes,
    );
    return FareRange(fareMin: fare, fareMax: (fare * 1.15).roundToDouble());
  }

  static double _calculateTariffFare(
    GovTariff tariff,
    PriceCheckInput input,
    double distanceKm,
    double durationMin,
  ) {
    if (tariff.flatRate != null && tariff.flatRate! > 0) {
      return tariff.flatRate!;
    }
    double fare =
        tariff.baseFare +
        (tariff.perKm * distanceKm) +
        (tariff.perMin * durationMin);
    final hour = input.timeOfDay.hour;
    if ((hour >= 23 || hour < 5) && tariff.nightSurchargePercent > 0) {
      fare += (fare * tariff.nightSurchargePercent / 100.0);
    }
    return max(fare, tariff.minFare).roundToDouble();
  }

  static List<PriceReport> _filterMatchingReports(
    PriceCheckInput input,
    List<PriceReport> reports,
  ) {
    final now = DateTime.now();
    return reports.where((r) {
      if (r.serviceType != input.serviceType) return false;
      // Exclude flagged/reported submissions pending review
      if (r.isFlagged) return false;
      if (now.difference(r.timestamp).inDays >
          PriceThresholds.trapRecencyCutoffDays) {
        return false;
      }
      return true;
    }).toList();
  }

  static BenchmarkStats? _calculateCommunityBenchmark(
    List<PriceReport> reports,
  ) {
    final now = DateTime.now();
    final items = reports.map((r) {
      final daysAgo = max(0, now.difference(r.timestamp).inDays);
      final recencyWeight = pow(
        0.5,
        daysAgo / PriceThresholds.benchmarkRecencyHalfLifeDays,
      ).toDouble();
      // Incorporate account trust weight (0.5 for new accounts, 1.0 for established accounts)
      final effectiveWeight = recencyWeight * (r.weight > 0 ? r.weight : 0.5);
      return WeightedValue(value: r.pricePaid, weight: effectiveWeight);
    }).toList();

    return EngineMath.calculateWeightedPercentiles(
      items: items,
      lowerOutlierCut: PriceThresholds.benchmarkOutlierLowerPercentile,
      upperOutlierCut: PriceThresholds.benchmarkOutlierUpperPercentile,
    );
  }

  static double _calculateModelEstimate(
    PriceCheckInput input,
    double distanceKm,
  ) {
    switch (input.serviceType) {
      case ServiceType.auto:
        return (30.0 + 13.0 * distanceKm).roundToDouble();
      case ServiceType.taxi:
        return (50.0 + 17.0 * distanceKm).roundToDouble();
      case ServiceType.bikeTaxi:
        return (20.0 + 8.0 * distanceKm).roundToDouble();
      case ServiceType.guide:
        return ((input.hours ?? 2.0) * 400.0).clamp(600.0, 3000.0);
      case ServiceType.meal:
        return ((input.mealPeople ?? 1) * 250.0).clamp(150.0, 2000.0);
      case ServiceType.room:
        return ((input.roomNights ?? 1) * 1800.0).clamp(800.0, 10000.0);
      case ServiceType.entryTicket:
        return (input.passengers * 100.0).clamp(50.0, 2000.0);
      case ServiceType.other:
        return 200.0;
    }
  }

  static List<TouristTrap> _findNearbyTraps(
    PriceCheckInput input,
    List<TouristTrap> traps,
  ) {
    final now = DateTime.now();
    return traps.where((t) {
      if (t.serviceType != input.serviceType) return false;
      if (now.difference(t.lastReported).inDays >
          PriceThresholds.trapRecencyCutoffDays) {
        return false;
      }

      bool closeToPickup = false;
      if (input.pickupLat != null && input.pickupLng != null) {
        final d =
            EngineMath.haversineDistanceKm(
              input.pickupLat!,
              input.pickupLng!,
              t.latitude,
              t.longitude,
            ) *
            1000.0;
        if (d <= PriceThresholds.trapSearchRadiusMeters) closeToPickup = true;
      }

      bool closeToDrop = false;
      if (input.dropLat != null && input.dropLng != null) {
        final d =
            EngineMath.haversineDistanceKm(
              input.dropLat!,
              input.dropLng!,
              t.latitude,
              t.longitude,
            ) *
            1000.0;
        if (d <= PriceThresholds.trapSearchRadiusMeters) closeToDrop = true;
      }

      return closeToPickup || closeToDrop;
    }).toList();
  }

  static List<Factor> _generateFactors({
    required double ratio,
    required bool isUnusuallyLow,
    required double priceScore,
    required double trapScore,
    required List<TouristTrap> nearbyTraps,
    required double? officialMax,
    required PriceCheckInput input,
  }) {
    final factors = <Factor>[];

    if (isUnusuallyLow) {
      factors.add(
        const Factor(
          label: 'Suspiciously Low Quote',
          points: 35,
          evidence: PriceThresholds.unusuallyLowReason,
          sourceTag: '[Anomaly Rule]',
        ),
      );
    } else if (ratio > 1.0) {
      final pts = priceScore.round();
      final tag = officialMax != null
          ? '[Official Tariff]'
          : '[Market Baseline]';
      factors.add(
        Factor(
          label: 'Price Markup Detected',
          points: pts,
          evidence:
              'Quoted price is ${ratio.toStringAsFixed(1)}x above fair benchmark rate (+$pts)',
          sourceTag: tag,
        ),
      );
    } else {
      factors.add(
        const Factor(
          label: 'Competitive Fair Pricing',
          points: 0,
          evidence: 'Quoted price is within local standard rates',
          sourceTag: '[Price Check]',
        ),
      );
    }

    if (nearbyTraps.isNotEmpty) {
      factors.add(
        Factor(
          label: 'Tourist Trap Hotspot',
          points: (trapScore * 0.3).round(),
          evidence:
              '${nearbyTraps.length} active trap report(s) flagged within 1 km in the last 90 days',
          sourceTag: '[Tourist Trap DB]',
        ),
      );
    }

    if (input.serviceType == ServiceType.auto && !input.meterUsed) {
      factors.add(
        const Factor(
          label: 'No Meter Applied',
          points: 5,
          evidence: 'Trip agreed on fixed flat negotiation instead of calibrated meter',
          sourceTag: '[Ride Protocol]',
        ),
      );
    }

    return factors;
  }

  static String _buildDefaultExplanation(
    PriceVerdictLevel level,
    double quoted,
    double fairMin,
    double fairMax,
    ConfidenceLevel confidence,
  ) {
    final confNote = confidence == ConfidenceLevel.low
        ? ' (based on an estimate)'
        : '';
    switch (level) {
      case PriceVerdictLevel.fair:
        return 'The quoted ₹${quoted.round()} is consistent with local standard pricing between ₹${fairMin.round()} and ₹${fairMax.round()}$confNote. Safe to proceed.';
      case PriceVerdictLevel.suspicious:
        return 'Quoted ₹${quoted.round()} is somewhat inflated above the standard range of ₹${fairMin.round()}–₹${fairMax.round()}$confNote. Consider negotiating down or verifying with meter.';
      case PriceVerdictLevel.highRisk:
        return 'Quoted ₹${quoted.round()} significantly exceeds standard local rates of ₹${fairMin.round()}–₹${fairMax.round()}$confNote. High risk of overcharging or tourist commission.';
    }
  }

  /// Helper to calculate derived estimate from airport prepaid rates
  static double calculateAirportDerivedEstimate(
    double distanceKm, {
    double baseFare = 200.0,
    double perKmRate = 24.0,
  }) {
    return (baseFare + (perKmRate * distanceKm)).roundToDouble();
  }
}
