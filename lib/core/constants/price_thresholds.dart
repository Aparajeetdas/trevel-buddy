/// Single configuration file for all Fair Price & Risk Intelligence thresholds
class PriceThresholds {
  PriceThresholds._();

  // -------------------------------------------------------------
  // Verdict Boundaries (Risk Score 0 - 100)
  // -------------------------------------------------------------
  static const int fairMaxScore = 29; // 0 - 29: Fair (Green)
  static const int suspiciousMaxScore = 59; // 30 - 59: Suspicious (Amber)
  // 60 - 100: High Risk (Red)

  // -------------------------------------------------------------
  // Price Ratio Scoring Breakpoints
  // ratio = quotedPrice / fairMax
  // -------------------------------------------------------------
  static const double ratioFairFloor = 1.00;
  static const double ratioSuspiciousFloor = 1.25;
  static const double ratioHighRiskFloor = 1.60;
  static const double ratioCap = 2.50;

  static const double priceScoreAt1_00 = 0.0;
  static const double priceScoreAt1_25 = 40.0;
  static const double priceScoreAt1_60 = 75.0;
  static const double priceScoreAtCap = 100.0;

  // Multipliers for backwards compatibility and quick checks
  static const double fairMultiplier = 1.10;
  static const double slightlyHighMultiplier = 1.30;
  static const double suspiciousMultiplier = 1.25;

  // -------------------------------------------------------------
  // Unusually Low Anomaly Threshold
  // If quoted < unusuallyLowMultiplier * fairMin -> suspicious / hidden charge
  // -------------------------------------------------------------
  static const double unusuallyLowMultiplier = 0.60;
  static const int unusuallyLowDefaultScore = 35;
  static const String unusuallyLowReason =
      'Unusually low quote; watch for hidden charges or a price change later';

  // -------------------------------------------------------------
  // Overrides
  // -------------------------------------------------------------
  /// If quoted <= officialMax, level cannot exceed Suspicious
  /// If quoted > 1.5 * officialMax, level is High Risk
  static const double officialMaxHighRiskMultiplier = 1.50;

  // -------------------------------------------------------------
  // Risk Score Weights
  // riskScore = round(0.7 * priceScore + 0.3 * trapScore)
  // -------------------------------------------------------------
  static const double priceScoreWeight = 0.70;
  static const double trapScoreWeight = 0.30;

  // -------------------------------------------------------------
  // Tourist Trap Scoring Constants
  // -------------------------------------------------------------
  static const double trapSearchRadiusMeters = 1000.0; // 1 km radius
  static const int trapRecencyCutoffDays = 90;
  static const double trapRecencyHalfLifeDays = 45.0;

  // -------------------------------------------------------------
  // Community Benchmark Constants
  // -------------------------------------------------------------
  static const double benchmarkRecencyHalfLifeDays = 60.0;
  static const int minReportsForBenchmark = 5;
  static const int highConfidenceReportCount = 10;
  static const double benchmarkOutlierLowerPercentile = 0.10;
  static const double benchmarkOutlierUpperPercentile = 0.90;

  // -------------------------------------------------------------
  // Fallback Fair Range Multipliers (when only estimate is available)
  // -------------------------------------------------------------
  static const double estimateFairMinMultiplier = 0.90;
  static const double estimateFairMaxMultiplier = 1.15;
  static const double straightLineDistanceFactor = 1.30;
}
