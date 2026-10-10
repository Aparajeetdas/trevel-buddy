import 'dart:math';

import '../models/app_models.dart';
import '../utils/engine_math.dart';

/// Status of an airport tariff match
enum AirportMatchStatus {
  /// Confident, unambiguous match found above threshold
  confident,

  /// Multiple candidate tariffs matched with similar high scores (e.g. 3 Shillong variants)
  ambiguous,

  /// Low confidence match, candidate areas suggested
  unconfident,

  /// No listed area matched
  notListed,
}

/// Result of matching a destination against the official airport prepaid tariffs
class AirportTariffMatchResult {
  final AirportMatchStatus status;
  final FixedRouteTariff? matchedTariff;
  final List<FixedRouteTariff> candidates;
  final double confidenceScore;
  final String query;

  const AirportTariffMatchResult({
    required this.status,
    this.matchedTariff,
    this.candidates = const [],
    this.confidenceScore = 0.0,
    required this.query,
  });

  bool get isConfident => status == AirportMatchStatus.confident && matchedTariff != null;
  bool get isAmbiguous => status == AirportMatchStatus.ambiguous;
  bool get requiresPicker =>
      status == AirportMatchStatus.ambiguous || status == AirportMatchStatus.unconfident;
}

/// Intelligent matching service for LGBI Airport prepaid taxi fares
class AirportPrepaidMatcher {
  AirportPrepaidMatcher._();

  /// Official LGBI Airport coordinates (Terminal building / Prepaid counter)
  static const double airportOriginLat = 26.1061;
  static const double airportOriginLng = 91.5859;

  /// Radius for airport pickup in kilometers
  static const double airportRadiusKm = 1.5;

  /// Confidence score threshold for single confident match
  static const double confidentThreshold = 0.80;

  /// Ambiguity threshold: if multiple candidates are within this delta of the top score
  static const double ambiguityDelta = 0.12;

  /// Check whether the pickup location represents LGBI Airport
  static bool isAirportPickup({
    double? lat,
    double? lng,
    String? name,
    String? address,
  }) {
    // 1. Distance check within 1.5 km of origin coordinates
    if (lat != null && lng != null) {
      final distanceKm = EngineMath.haversineDistanceKm(
        lat,
        lng,
        airportOriginLat,
        airportOriginLng,
      );
      if (distanceKm <= airportRadiusKm) return true;
    }

    // 2. Name or address contains 'LGBI' or 'Guwahati airport'
    final normalizedName = normalize(name ?? '');
    final normalizedAddr = normalize(address ?? '');

    return _containsAirportKeyword(normalizedName) ||
        _containsAirportKeyword(normalizedAddr);
  }

  /// Check whether the destination represents LGBI Airport (trip TO airport)
  static bool isAirportDropoff({
    double? lat,
    double? lng,
    String? name,
    String? address,
  }) {
    if (lat != null && lng != null) {
      final distanceKm = EngineMath.haversineDistanceKm(
        lat,
        lng,
        airportOriginLat,
        airportOriginLng,
      );
      if (distanceKm <= airportRadiusKm) return true;
    }

    final normalizedName = normalize(name ?? '');
    final normalizedAddr = normalize(address ?? '');

    return _containsAirportKeyword(normalizedName) ||
        _containsAirportKeyword(normalizedAddr);
  }

  static bool _containsAirportKeyword(String normalizedText) {
    if (normalizedText.isEmpty) return false;
    return normalizedText.contains('lgbi') ||
        normalizedText.contains('guwahati airport') ||
        normalizedText.contains('borjhar airport') ||
        normalizedText.contains('lokpriya gopinath bordoloi');
  }

  /// Normalize string: lowercase, remove punctuation, strip diacritics, keep alphanumeric and Hindi characters
  static String normalize(String text) {
    if (text.isEmpty) return '';

    // 1. Convert to lowercase
    String str = text.toLowerCase();

    // 2. Strip diacritics
    str = _removeDiacritics(str);

    // 3. Remove punctuation and special symbols, preserving Hindi (Devanagari: \u0900-\u097F)
    // and standard alphanumeric characters
    str = str.replaceAll(RegExp(r'[^\w\s\u0900-\u097F]', unicode: true), ' ');

    // 4. Collapse whitespace
    return str.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Match destination query against list of fixed route tariffs
  static AirportTariffMatchResult matchDestination({
    required String destination,
    GooglePlaceDetails? placeDetails,
    required List<FixedRouteTariff> tariffs,
    double confidentMinScore = confidentThreshold,
    double ambiguityMargin = ambiguityDelta,
  }) {
    final normalizedQuery = normalize(destination);
    if (normalizedQuery.isEmpty || tariffs.isEmpty) {
      return AirportTariffMatchResult(
        status: AirportMatchStatus.notListed,
        query: destination,
      );
    }

    // Extract additional locality & neighborhood strings from place details if available
    final List<String> neighborhoodAndLocalityNames = [];
    if (placeDetails != null) {
      if (placeDetails.name.isNotEmpty) {
        final normPlaceName = normalize(placeDetails.name);
        if (normPlaceName != 'guwahati') {
          neighborhoodAndLocalityNames.add(normPlaceName);
        }
      }
      for (final comp in placeDetails.addressComponents) {
        final types = (comp['types'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        if (types.contains('sublocality') ||
            types.contains('neighborhood') ||
            types.contains('sublocality_level_1') ||
            types.contains('locality')) {
          final longName = comp['long_name'] as String? ?? '';
          final normComp = normalize(longName);
          if (normComp.isNotEmpty && normComp != 'guwahati') {
            neighborhoodAndLocalityNames.add(normComp);
          }
        }
      }
    }

    // Score all tariffs
    final List<_ScoredTariff> scored = [];

    for (final tariff in tariffs) {
      double bestScore = _scoreTariffMatch(
        query: normalizedQuery,
        tariff: tariff,
        neighborhoodAndLocalityNames: neighborhoodAndLocalityNames,
      );

      if (bestScore > 0.35) {
        scored.add(_ScoredTariff(tariff: tariff, score: bestScore));
      }
    }

    if (scored.isEmpty) {
      return AirportTariffMatchResult(
        status: AirportMatchStatus.notListed,
        query: destination,
      );
    }

    // Sort descending by score
    scored.sort((a, b) => b.score.compareTo(a.score));

    final topScore = scored.first.score;

    // 1. Check for Exact or 1.0 Match
    if (topScore >= 0.98) {
      // If there are multiple tariffs with score >= 0.95 (e.g. searching "Shillong" matching 3 Shillongs equally)
      final topGroup = scored.where((s) => s.score >= 0.95).toList();
      if (topGroup.length > 1) {
        return AirportTariffMatchResult(
          status: AirportMatchStatus.ambiguous,
          candidates: topGroup.map((e) => e.tariff).toList(),
          confidenceScore: topScore,
          query: destination,
        );
      }

      return AirportTariffMatchResult(
        status: AirportMatchStatus.confident,
        matchedTariff: scored.first.tariff,
        confidenceScore: topScore,
        query: destination,
      );
    }

    // 2. Check for Ambiguity among top candidates
    final closeCandidates = scored
        .where((s) => s.score >= 0.65 && (topScore - s.score) <= ambiguityMargin)
        .toList();

    if (closeCandidates.length > 1) {
      // E.g. "Shillong" matches Shillong (Police Bazar), Shillong (Barabazar), Shillong (Happy Valley)
      return AirportTariffMatchResult(
        status: AirportMatchStatus.ambiguous,
        candidates: closeCandidates.map((e) => e.tariff).toList(),
        confidenceScore: topScore,
        query: destination,
      );
    }

    // 3. Single candidate above confident threshold
    if (topScore >= confidentMinScore) {
      return AirportTariffMatchResult(
        status: AirportMatchStatus.confident,
        matchedTariff: scored.first.tariff,
        confidenceScore: topScore,
        query: destination,
      );
    }

    // 4. Below confident threshold -> Unconfident, return top candidates for picker
    if (topScore >= 0.50) {
      final potentialCandidates = scored.take(4).map((e) => e.tariff).toList();
      return AirportTariffMatchResult(
        status: AirportMatchStatus.unconfident,
        candidates: potentialCandidates,
        confidenceScore: topScore,
        query: destination,
      );
    }

    // 5. Not listed
    return AirportTariffMatchResult(
      status: AirportMatchStatus.notListed,
      query: destination,
      confidenceScore: topScore,
    );
  }

  static double _scoreTariffMatch({
    required String query,
    required FixedRouteTariff tariff,
    required List<String> neighborhoodAndLocalityNames,
  }) {
    double maxScore = 0.0;

    // Check primary destination name
    final normDest = normalize(tariff.destinationName);
    maxScore = max(maxScore, _stringSimilarity(query, normDest));

    // Check Hindi name
    if (tariff.destinationNameHi != null && tariff.destinationNameHi!.isNotEmpty) {
      final normHi = normalize(tariff.destinationNameHi!);
      maxScore = max(maxScore, _stringSimilarity(query, normHi));
    }

    // Check all aliases
    for (final alias in tariff.aliases) {
      final normAlias = normalize(alias);
      maxScore = max(maxScore, _stringSimilarity(query, normAlias));
    }

    // Check against Google place details locality and neighborhood names
    for (final area in neighborhoodAndLocalityNames) {
      if (area.isEmpty) continue;
      maxScore = max(maxScore, _stringSimilarity(area, normDest));
      for (final alias in tariff.aliases) {
        final normAlias = normalize(alias);
        maxScore = max(maxScore, _stringSimilarity(area, normAlias));
      }
    }

    return maxScore;
  }

  /// Multi-metric string similarity (exact, containment, Levenshtein, and bigrams)
  static double _stringSimilarity(String s1, String s2) {
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    if (s1 == s2) return 1.0;

    // Check exact word token containment
    final tokens1 = s1.split(' ').where((t) => t.isNotEmpty).toList();
    final tokens2 = s2.split(' ').where((t) => t.isNotEmpty).toList();

    // If query is an exact match for one of the main tokens (e.g. "shillong" in "shillong police bazar")
    bool hasSharedMainToken = false;
    for (final t1 in tokens1) {
      if (t1.length >= 4 && tokens2.contains(t1)) {
        hasSharedMainToken = true;
        break;
      }
    }

    // Substring containment
    if (s1.contains(s2) || s2.contains(s1)) {
      final shorter = s1.length < s2.length ? s1 : s2;
      final longer = s1.length >= s2.length ? s1 : s2;
      final ratio = shorter.length / longer.length;

      // If query is a substantial part of destination (e.g. "ganeshguri" in "ganeshguri flyover")
      if (ratio >= 0.70) return 0.95;
      if (hasSharedMainToken) {
        // e.g. "shillong" in "shillong police bazar" -> high match but triggers ambiguity check
        return 0.88;
      }
      return 0.75 + (ratio * 0.15);
    }

    // Token set overlap (Jaccard on words)
    int matchingTokens = 0;
    for (final t1 in tokens1) {
      if (tokens2.any((t2) => t1 == t2 || _levenshteinSimilarity(t1, t2) >= 0.80)) {
        matchingTokens++;
      }
    }
    final tokenScore = matchingTokens > 0
        ? (2.0 * matchingTokens) / (tokens1.length + tokens2.length)
        : 0.0;

    // Levenshtein similarity on full string
    final levScore = _levenshteinSimilarity(s1, s2);

    // Dice bigram similarity
    final bigramScore = _bigramSimilarity(s1, s2);

    return max(tokenScore, max(levScore, bigramScore));
  }

  static double _levenshteinSimilarity(String s1, String s2) {
    final maxLen = max(s1.length, s2.length);
    if (maxLen == 0) return 1.0;
    final dist = _levenshteinDistance(s1, s2);
    return (1.0 - (dist / maxLen)).clamp(0.0, 1.0);
  }

  static int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> v0 = List<int>.generate(s2.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < s2.length; j++) {
        int cost = (s1.codeUnitAt(i) == s2.codeUnitAt(j)) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j <= s2.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[s2.length];
  }

  static double _bigramSimilarity(String s1, String s2) {
    if (s1.length < 2 || s2.length < 2) return 0.0;
    final Set<String> bigrams1 = {};
    for (int i = 0; i < s1.length - 1; i++) {
      bigrams1.add(s1.substring(i, i + 2));
    }
    int intersection = 0;
    for (int i = 0; i < s2.length - 1; i++) {
      if (bigrams1.contains(s2.substring(i, i + 2))) {
        intersection++;
      }
    }
    return (2.0 * intersection) / (s1.length + s2.length - 2);
  }

  static String _removeDiacritics(String str) {
    const withDia = 'ÀÁÂÃÄÅàáâãäåÈÉÊËèéêëÌÍÎÏìíîïÒÓÔÕÖØòóôõöøÙÚÛÜùúûüÝýÿÑñÇç';
    const withoutDia = 'AAAAAAaaaaaaEEEEeeeeIIIIiiiiOOOOOOooooooUUUUuuuuYyyNnCc';

    String result = str;
    for (int i = 0; i < withDia.length; i++) {
      result = result.replaceAll(withDia[i], withoutDia[i]);
    }
    return result;
  }
}

class _ScoredTariff {
  final FixedRouteTariff tariff;
  final double score;

  const _ScoredTariff({required this.tariff, required this.score});
}
