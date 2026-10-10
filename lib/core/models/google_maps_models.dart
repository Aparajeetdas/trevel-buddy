/// Pure Dart Models for Google Places (New) and Routes API (No Maps SDK dependencies)
library;

class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);

  @override
  String toString() => 'LatLng($latitude, $longitude)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LatLng &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;
}

enum SuggestionCategoryType {
  city,
  area,
  landmark,
  food,
  stay,
  transport,
  general;

  static SuggestionCategoryType fromTypes(List<String> types) {
    for (final t in types) {
      final lower = t.toLowerCase();
      if (lower == 'locality' ||
          lower == 'administrative_area_level_1' ||
          lower == 'administrative_area_level_2' ||
          lower == 'country') {
        return SuggestionCategoryType.city;
      }
      if (lower == 'sublocality' ||
          lower == 'neighborhood' ||
          lower == 'sublocality_level_1' ||
          lower == 'postal_code') {
        return SuggestionCategoryType.area;
      }
      if (lower == 'restaurant' ||
          lower == 'cafe' ||
          lower == 'food' ||
          lower == 'bar' ||
          lower == 'bakery' ||
          lower == 'meal_takeaway') {
        return SuggestionCategoryType.food;
      }
      if (lower == 'lodging' ||
          lower == 'hotel' ||
          lower == 'motel' ||
          lower == 'resort') {
        return SuggestionCategoryType.stay;
      }
      if (lower.contains('station') ||
          lower.contains('airport') ||
          lower.contains('transit') ||
          lower.contains('taxi') ||
          lower.contains('bus')) {
        return SuggestionCategoryType.transport;
      }
      if (lower == 'tourist_attraction' ||
          lower == 'point_of_interest' ||
          lower == 'historical_landmark' ||
          lower == 'museum' ||
          lower == 'park' ||
          lower == 'monument') {
        return SuggestionCategoryType.landmark;
      }
    }
    return SuggestionCategoryType.general;
  }
}

class GooglePlaceSuggestion {
  final String placeId;
  final String mainText;
  final String secondaryText;
  final List<String> types;
  final double? distanceMeters;

  const GooglePlaceSuggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    this.types = const [],
    this.distanceMeters,
  });

  String get fullText =>
      secondaryText.isNotEmpty ? '$mainText, $secondaryText' : mainText;

  SuggestionCategoryType get categoryType =>
      SuggestionCategoryType.fromTypes(types);

  String? get formattedDistance {
    if (distanceMeters == null) return null;
    if (distanceMeters! < 1000) return '${distanceMeters!.round()}m';
    return '${(distanceMeters! / 1000).toStringAsFixed(1)}km';
  }
}

typedef GoogleRouteResult = GoogleRouteOption;

class GooglePlaceDetails {
  final String placeId;
  final String name;
  final String formattedAddress;
  final double? rating;
  final int? userRatingCount;
  final String? priceLevel;
  final String? phoneNumber;
  final String? websiteUri;
  final String? editorialSummary;
  final bool? isOpenNow;
  final List<String> weekdayDescriptions;
  final List<String> photoUrls;
  final double latitude;
  final double longitude;
  final DateTime fetchedAt;
  final bool isLiveGoogle;
  final String? attribution;
  final List<String> types;
  final String? primaryType;
  final List<Map<String, dynamic>> addressComponents;
  final Map<String, dynamic>? viewport;

  const GooglePlaceDetails({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    this.rating,
    this.userRatingCount,
    this.priceLevel,
    this.phoneNumber,
    this.websiteUri,
    this.editorialSummary,
    this.isOpenNow,
    this.weekdayDescriptions = const [],
    this.photoUrls = const [],
    required this.latitude,
    required this.longitude,
    required this.fetchedAt,
    this.isLiveGoogle = false,
    this.attribution,
    this.types = const [],
    this.primaryType,
    this.addressComponents = const [],
    this.viewport,
  });

  String get id => placeId;

  bool get isCityOrRegion => types.any((t) {
    final lower = t.toLowerCase();
    return lower == 'locality' ||
        lower == 'administrative_area_level_1' ||
        lower == 'administrative_area_level_2' ||
        lower == 'political';
  });

  SuggestionCategoryType get categoryType =>
      SuggestionCategoryType.fromTypes(types);

  String get updatedTimeString {
    final diff = DateTime.now().difference(fetchedAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

/// Active City state model tracking user's active geographic context
class ActiveCity {
  final String name;
  final String placeId;
  final double centerLat;
  final double centerLng;
  final String? countryCode;
  final Map<String, dynamic>? viewport;

  const ActiveCity({
    required this.name,
    required this.placeId,
    required this.centerLat,
    required this.centerLng,
    this.countryCode,
    this.viewport,
  });

  LatLng get center => LatLng(centerLat, centerLng);

  Map<String, dynamic> toJson() => {
    'name': name,
    'placeId': placeId,
    'centerLat': centerLat,
    'centerLng': centerLng,
    'countryCode': countryCode,
    'viewport': viewport,
  };

  factory ActiveCity.fromJson(Map<String, dynamic> json) => ActiveCity(
    name: json['name'] as String? ?? 'Active Location',
    placeId: json['placeId'] as String? ?? '',
    centerLat: (json['centerLat'] as num?)?.toDouble() ?? 0.0,
    centerLng: (json['centerLng'] as num?)?.toDouble() ?? 0.0,
    countryCode: json['countryCode'] as String?,
    viewport: json['viewport'] as Map<String, dynamic>?,
  );
}

/// Soft re-ranking filter options (promotes matches without hiding non-matches)
enum SearchRankFilter {
  all('All', null),
  cities('Cities', SuggestionCategoryType.city),
  food('Food', SuggestionCategoryType.food),
  stay('Stay', SuggestionCategoryType.stay),
  attractions('Attractions', SuggestionCategoryType.landmark),
  transport('Transport', SuggestionCategoryType.transport);

  final String label;
  final SuggestionCategoryType? category;
  const SearchRankFilter(this.label, this.category);
}

enum RouteTrafficSpeed {
  normal,
  slow,
  trafficJam;

  static RouteTrafficSpeed fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'TRAFFIC_JAM':
      case 'CONGESTION_HEAVY':
        return RouteTrafficSpeed.trafficJam;
      case 'SLOW':
      case 'CONGESTION_MEDIUM':
        return RouteTrafficSpeed.slow;
      case 'NORMAL':
      default:
        return RouteTrafficSpeed.normal;
    }
  }
}

class RouteTrafficSegment {
  final List<LatLng> points;
  final RouteTrafficSpeed speed;

  const RouteTrafficSegment({required this.points, required this.speed});
}

class RouteStepItem {
  final String instruction;
  final double distanceMeters;
  final double durationSeconds;
  final List<LatLng> points;

  const RouteStepItem({
    required this.instruction,
    required this.distanceMeters,
    required this.durationSeconds,
    this.points = const [],
  });

  String get distanceText {
    if (distanceMeters < 1000) return '${distanceMeters.toStringAsFixed(0)} m';
    return '${(distanceMeters / 1000.0).toStringAsFixed(1)} km';
  }
}

class GoogleRouteOption {
  final String routeId;
  final bool isMain;
  final double distanceMeters;
  final double durationSeconds;
  final double? staticDurationSeconds;
  final String encodedPoints;
  final List<LatLng> points;
  final List<RouteStepItem> steps;
  final List<RouteTrafficSegment> trafficSegments;
  final bool isEstimatedRoute;
  final String mode; // DRIVE, TWO_WHEELER, WALK, TRANSIT

  const GoogleRouteOption({
    required this.routeId,
    this.isMain = true,
    required this.distanceMeters,
    required this.durationSeconds,
    this.staticDurationSeconds,
    required this.encodedPoints,
    required this.points,
    this.steps = const [],
    this.trafficSegments = const [],
    this.isEstimatedRoute = false,
    this.mode = 'DRIVE',
  });

  double get distanceKm => distanceMeters / 1000.0;
  double get durationMinutes => durationSeconds / 60.0;

  String get distanceText => '${distanceKm.toStringAsFixed(1)} km';

  String get durationText {
    final mins = durationMinutes.round();
    if (mins < 60) return '$mins min';
    final hrs = mins ~/ 60;
    final rem = mins % 60;
    return rem == 0 ? '$hrs hr' : '$hrs hr $rem min';
  }

  String get summaryChipText {
    if (isEstimatedRoute) {
      return '$distanceText, $durationText (Estimated route)';
    }
    final delay =
        (durationSeconds - (staticDurationSeconds ?? durationSeconds)) / 60.0;
    if (delay > 2.0) {
      return '$distanceText, $durationText with traffic';
    }
    return '$distanceText, $durationText';
  }
}
