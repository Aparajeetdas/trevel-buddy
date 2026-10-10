import 'dart:math';

/// Mathematical utilities for pricing engine distance & percentiles
class EngineMath {
  EngineMath._();

  /// Haversine straight-line distance in kilometers
  static double haversineDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371.0;
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180.0;
  }

  /// Calculates recency-weighted percentiles after discarding outliers (top & bottom 10%)
  static BenchmarkStats? calculateWeightedPercentiles({
    required List<WeightedValue> items,
    double lowerOutlierCut = 0.10,
    double upperOutlierCut = 0.90,
  }) {
    if (items.length < 5) return null;

    // Sort by value ascending
    final sorted = List<WeightedValue>.from(items)
      ..sort((a, b) => a.value.compareTo(b.value));

    // Remove top and bottom 10%
    final int lowerIndex = (sorted.length * lowerOutlierCut).floor();
    final int upperIndex = (sorted.length * upperOutlierCut).ceil();
    final trimmed = sorted.sublist(
      lowerIndex.clamp(0, sorted.length - 1),
      upperIndex.clamp(1, sorted.length),
    );

    if (trimmed.isEmpty) return null;

    double totalWeight = trimmed.fold(0.0, (sum, item) => sum + item.weight);
    if (totalWeight <= 0) return null;

    double p25 = _findWeightedQuantile(trimmed, totalWeight, 0.25);
    double p50 = _findWeightedQuantile(trimmed, totalWeight, 0.50);
    double p75 = _findWeightedQuantile(trimmed, totalWeight, 0.75);

    return BenchmarkStats(count: items.length, median: p50, p25: p25, p75: p75);
  }

  static double _findWeightedQuantile(
    List<WeightedValue> sortedTrimmed,
    double totalWeight,
    double targetFraction,
  ) {
    final double targetWeight = totalWeight * targetFraction;
    double cumulative = 0.0;

    for (final item in sortedTrimmed) {
      cumulative += item.weight;
      if (cumulative >= targetWeight) {
        return item.value;
      }
    }
    return sortedTrimmed.last.value;
  }
}

class WeightedValue {
  final double value;
  final double weight;

  const WeightedValue({required this.value, required this.weight});
}

class BenchmarkStats {
  final int count;
  final double median;
  final double p25;
  final double p75;

  const BenchmarkStats({
    required this.count,
    required this.median,
    required this.p25,
    required this.p75,
  });
}
