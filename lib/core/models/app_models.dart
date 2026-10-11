export 'ai_price_models.dart';
export 'price_engine_models.dart';
export 'google_maps_models.dart';
export 'scam_playbook_models.dart';
export '../config/city_config.dart';

/// Category for fair price inquiries
enum PriceCategory {
  ride,
  meal,
  room;

  String get displayName {
    switch (this) {
      case PriceCategory.ride:
        return 'Ride';
      case PriceCategory.meal:
        return 'Meal';
      case PriceCategory.room:
        return 'Room';
    }
  }

  static PriceCategory fromString(String val) {
    switch (val.toLowerCase()) {
      case 'ride':
      case 'transport':
        return PriceCategory.ride;
      case 'meal':
      case 'food':
        return PriceCategory.meal;
      case 'room':
      case 'stay':
      case 'hotel':
        return PriceCategory.room;
      default:
        return PriceCategory.ride;
    }
  }
}

/// Fair Price Model
class FairPrice {
  final String id;
  final String title;
  final PriceCategory category;
  final String routeOrItem;
  final double fairMin;
  final double fairMax;
  final String unit;
  final String tip;
  final double? priceCap; // Nullable priceCap for future government caps

  const FairPrice({
    required this.id,
    required this.title,
    required this.category,
    required this.routeOrItem,
    required this.fairMin,
    required this.fairMax,
    required this.unit,
    required this.tip,
    this.priceCap,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category.name,
    'routeOrItem': routeOrItem,
    'fairMin': fairMin,
    'fairMax': fairMax,
    'unit': unit,
    'tip': tip,
    'priceCap': priceCap,
  };

  factory FairPrice.fromJson(Map<String, dynamic> json) => FairPrice(
    id: json['id'] as String,
    title: json['title'] as String,
    category: PriceCategory.fromString(json['category'] as String),
    routeOrItem: json['routeOrItem'] as String,
    fairMin: (json['fairMin'] as num).toDouble(),
    fairMax: (json['fairMax'] as num).toDouble(),
    unit: json['unit'] as String? ?? '₹',
    tip: json['tip'] as String? ?? '',
    priceCap: (json['priceCap'] as num?)?.toDouble(),
  );
}

/// Transport Option
class TransportOption {
  final String id;
  final String mode; // 'bus', 'shared_taxi', 'private_car', 'bike'
  final String title;
  final double fairMin;
  final double fairMax;
  final double dontPayMoreThan;
  final String pickupPoint;
  final String travelTime;
  final String roadCondition;
  final String tip;

  const TransportOption({
    required this.id,
    required this.mode,
    required this.title,
    required this.fairMin,
    required this.fairMax,
    required this.dontPayMoreThan,
    required this.pickupPoint,
    required this.travelTime,
    required this.roadCondition,
    required this.tip,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'mode': mode,
    'title': title,
    'fairMin': fairMin,
    'fairMax': fairMax,
    'dontPayMoreThan': dontPayMoreThan,
    'pickupPoint': pickupPoint,
    'travelTime': travelTime,
    'roadCondition': roadCondition,
    'tip': tip,
  };

  factory TransportOption.fromJson(Map<String, dynamic> json) =>
      TransportOption(
        id: json['id'] as String,
        mode: json['mode'] as String,
        title: json['title'] as String,
        fairMin: (json['fairMin'] as num).toDouble(),
        fairMax: (json['fairMax'] as num).toDouble(),
        dontPayMoreThan: (json['dontPayMoreThan'] as num).toDouble(),
        pickupPoint: json['pickupPoint'] as String,
        travelTime: json['travelTime'] as String,
        roadCondition: json['roadCondition'] as String,
        tip: json['tip'] as String? ?? '',
      );
}

/// Route Warning
class RouteWarning {
  final String id;
  final String title;
  final String severity; // 'warning', 'danger', 'info'
  final String description;
  final String affectedRoute;

  const RouteWarning({
    required this.id,
    required this.title,
    required this.severity,
    required this.description,
    required this.affectedRoute,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'severity': severity,
    'description': description,
    'affectedRoute': affectedRoute,
  };

  factory RouteWarning.fromJson(Map<String, dynamic> json) => RouteWarning(
    id: json['id'] as String,
    title: json['title'] as String,
    severity: json['severity'] as String? ?? 'warning',
    description: json['description'] as String,
    affectedRoute: json['affectedRoute'] as String,
  );
}

/// Food Venue
class FoodVenue {
  final String id;
  final String name;
  final String type;
  final double fairRangeMin;
  final double fairRangeMax;
  final List<String> popularItems;
  final double hygieneRating;
  final double? priceCap;

  const FoodVenue({
    required this.id,
    required this.name,
    required this.type,
    required this.fairRangeMin,
    required this.fairRangeMax,
    required this.popularItems,
    required this.hygieneRating,
    this.priceCap,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'fairRangeMin': fairRangeMin,
    'fairRangeMax': fairRangeMax,
    'popularItems': popularItems,
    'hygieneRating': hygieneRating,
    'priceCap': priceCap,
  };

  factory FoodVenue.fromJson(Map<String, dynamic> json) => FoodVenue(
    id: json['id'] as String,
    name: json['name'] as String,
    type: json['type'] as String,
    fairRangeMin: (json['fairRangeMin'] as num).toDouble(),
    fairRangeMax: (json['fairRangeMax'] as num).toDouble(),
    popularItems:
        (json['popularItems'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [],
    hygieneRating: (json['hygieneRating'] as num?)?.toDouble() ?? 4.0,
    priceCap: (json['priceCap'] as num?)?.toDouble(),
  );
}

/// Stay
class Stay {
  final String id;
  final String name;
  final String category;
  final double fairPriceMin;
  final double fairPriceMax;
  final List<String> amenities;
  final double? priceCap;

  const Stay({
    required this.id,
    required this.name,
    required this.category,
    required this.fairPriceMin,
    required this.fairPriceMax,
    required this.amenities,
    this.priceCap,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'fairPriceMin': fairPriceMin,
    'fairPriceMax': fairPriceMax,
    'amenities': amenities,
    'priceCap': priceCap,
  };

  factory Stay.fromJson(Map<String, dynamic> json) => Stay(
    id: json['id'] as String,
    name: json['name'] as String,
    category: json['category'] as String,
    fairPriceMin: (json['fairPriceMin'] as num).toDouble(),
    fairPriceMax: (json['fairPriceMax'] as num).toDouble(),
    amenities:
        (json['amenities'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [],
    priceCap: (json['priceCap'] as num?)?.toDouble(),
  );
}

/// Scam Alert
class ScamAlert {
  final String id;
  final String title;
  final String category;
  final String scamRisk; // 'Low', 'Medium', 'High'
  final String howToAvoid;
  final int reportCount;
  final String location;

  const ScamAlert({
    required this.id,
    required this.title,
    required this.category,
    required this.scamRisk,
    required this.howToAvoid,
    required this.reportCount,
    required this.location,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'scamRisk': scamRisk,
    'howToAvoid': howToAvoid,
    'reportCount': reportCount,
    'location': location,
  };

  factory ScamAlert.fromJson(Map<String, dynamic> json) => ScamAlert(
    id: json['id'] as String,
    title: json['title'] as String,
    category: json['category'] as String,
    scamRisk: json['scamRisk'] as String? ?? 'Medium',
    howToAvoid: json['howToAvoid'] as String,
    reportCount: json['reportCount'] as int? ?? 1,
    location: json['location'] as String? ?? '',
  );
}

/// Scam Report submitted by user
class ScamReport {
  final String id;
  final String incidentType;
  final String placeName;
  final double amountLost;
  final String description;
  final String? photoUrl;
  final DateTime timestamp;
  final String status;

  const ScamReport({
    required this.id,
    required this.incidentType,
    required this.placeName,
    required this.amountLost,
    required this.description,
    this.photoUrl,
    required this.timestamp,
    this.status = 'Submitted',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'incidentType': incidentType,
    'placeName': placeName,
    'amountLost': amountLost,
    'description': description,
    'photoUrl': photoUrl,
    'timestamp': timestamp.toIso8601String(),
    'status': status,
  };

  factory ScamReport.fromJson(Map<String, dynamic> json) => ScamReport(
    id: json['id'] as String,
    incidentType: json['incidentType'] as String,
    placeName: json['placeName'] as String,
    amountLost: (json['amountLost'] as num).toDouble(),
    description: json['description'] as String,
    photoUrl: json['photoUrl'] as String?,
    timestamp:
        DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    status: json['status'] as String? ?? 'Submitted',
  );
}

/// Review
class Review {
  final String id;
  final String authorName;
  final double rating;
  final String comment;
  final String date;
  final bool isVerifiedBuyer;

  const Review({
    required this.id,
    required this.authorName,
    required this.rating,
    required this.comment,
    required this.date,
    this.isVerifiedBuyer = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'authorName': authorName,
    'rating': rating,
    'comment': comment,
    'date': date,
    'isVerifiedBuyer': isVerifiedBuyer,
  };

  factory Review.fromJson(Map<String, dynamic> json) => Review(
    id: json['id'] as String,
    authorName: json['authorName'] as String,
    rating: (json['rating'] as num).toDouble(),
    comment: json['comment'] as String,
    date: json['date'] as String,
    isVerifiedBuyer: json['isVerifiedBuyer'] as bool? ?? true,
  );
}

/// Driver
class Driver {
  final String id;
  final String name;
  final String vehicleNumber;
  final String vehicleType;
  final String photoUrl;
  final bool isVerified;
  final double rating;
  final int complaints;
  final String route;
  final double fairPriceForRoute;
  final String phone;

  const Driver({
    required this.id,
    required this.name,
    required this.vehicleNumber,
    required this.vehicleType,
    required this.photoUrl,
    required this.isVerified,
    required this.rating,
    required this.complaints,
    required this.route,
    required this.fairPriceForRoute,
    required this.phone,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'vehicleNumber': vehicleNumber,
    'vehicleType': vehicleType,
    'photoUrl': photoUrl,
    'isVerified': isVerified,
    'rating': rating,
    'complaints': complaints,
    'route': route,
    'fairPriceForRoute': fairPriceForRoute,
    'phone': phone,
  };

  factory Driver.fromJson(Map<String, dynamic> json) => Driver(
    id: json['id'] as String,
    name: json['name'] as String,
    vehicleNumber: json['vehicleNumber'] as String,
    vehicleType: json['vehicleType'] as String,
    photoUrl: json['photoUrl'] as String,
    isVerified: json['isVerified'] as bool,
    rating: (json['rating'] as num).toDouble(),
    complaints: json['complaints'] as int,
    route: json['route'] as String,
    fairPriceForRoute: (json['fairPriceForRoute'] as num).toDouble(),
    phone: json['phone'] as String,
  );
}



/// Scam Report Zone for Map Heatmap
class ScamReportZone {
  final String id;
  final String title;
  final String location;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final String riskLevel; // 'High', 'Medium', 'Low'
  final int reportsCount;
  final String description;

  const ScamReportZone({
    required this.id,
    required this.title,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.riskLevel,
    required this.reportsCount,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'location': location,
    'latitude': latitude,
    'longitude': longitude,
    'radiusMeters': radiusMeters,
    'riskLevel': riskLevel,
    'reportsCount': reportsCount,
    'description': description,
  };

  factory ScamReportZone.fromJson(Map<String, dynamic> json) => ScamReportZone(
    id: json['id'] as String,
    title: json['title'] as String,
    location: json['location'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    radiusMeters: (json['radiusMeters'] as num).toDouble(),
    riskLevel: json['riskLevel'] as String,
    reportsCount: json['reportsCount'] as int,
    description: json['description'] as String,
  );
}

/// Place Model
class Place {
  final String id;
  final String name;
  final String state;
  final String category; // 'Best places', 'Viewpoints', 'Nearby', 'Budget'
  final String coverPhoto;
  final List<String> gallery;
  final double rating;
  final int reviewsCount;
  final String scamRisk; // 'Low', 'Medium', 'High'
  final String bestTimeToVisit;
  final double latitude;
  final double longitude;
  final String description;
  final List<TransportOption> transportOptions;
  final List<RouteWarning> routeWarnings;
  final List<FoodVenue> foodVenues;
  final List<Stay> stays;
  final List<ScamAlert> scamAlerts;
  final List<Review> reviews;

  const Place({
    required this.id,
    required this.name,
    required this.state,
    required this.category,
    required this.coverPhoto,
    required this.gallery,
    required this.rating,
    required this.reviewsCount,
    required this.scamRisk,
    required this.bestTimeToVisit,
    required this.latitude,
    required this.longitude,
    required this.description,
    required this.transportOptions,
    required this.routeWarnings,
    required this.foodVenues,
    required this.stays,
    required this.scamAlerts,
    required this.reviews,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'state': state,
    'category': category,
    'coverPhoto': coverPhoto,
    'gallery': gallery,
    'rating': rating,
    'reviewsCount': reviewsCount,
    'scamRisk': scamRisk,
    'bestTimeToVisit': bestTimeToVisit,
    'latitude': latitude,
    'longitude': longitude,
    'description': description,
    'transportOptions': transportOptions.map((e) => e.toJson()).toList(),
    'routeWarnings': routeWarnings.map((e) => e.toJson()).toList(),
    'foodVenues': foodVenues.map((e) => e.toJson()).toList(),
    'stays': stays.map((e) => e.toJson()).toList(),
    'scamAlerts': scamAlerts.map((e) => e.toJson()).toList(),
    'reviews': reviews.map((e) => e.toJson()).toList(),
  };

  factory Place.fromJson(Map<String, dynamic> json) => Place(
    id: json['id'] as String,
    name: json['name'] as String,
    state: json['state'] as String,
    category: json['category'] as String? ?? 'Best places',
    coverPhoto: json['coverPhoto'] as String,
    gallery:
        (json['gallery'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [],
    rating: (json['rating'] as num).toDouble(),
    reviewsCount: json['reviewsCount'] as int? ?? 0,
    scamRisk: json['scamRisk'] as String? ?? 'Medium',
    bestTimeToVisit: json['bestTimeToVisit'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    description: json['description'] as String,
    transportOptions:
        (json['transportOptions'] as List<dynamic>?)
            ?.map((e) => TransportOption.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    routeWarnings:
        (json['routeWarnings'] as List<dynamic>?)
            ?.map((e) => RouteWarning.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    foodVenues:
        (json['foodVenues'] as List<dynamic>?)
            ?.map((e) => FoodVenue.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    stays:
        (json['stays'] as List<dynamic>?)
            ?.map((e) => Stay.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    scamAlerts:
        (json['scamAlerts'] as List<dynamic>?)
            ?.map((e) => ScamAlert.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    reviews:
        (json['reviews'] as List<dynamic>?)
            ?.map((e) => Review.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
  );
}

/// Vehicle Fare Calculation Rule
class FareRule {
  final String vehicleType; // 'bike', 'auto', 'cab'
  final String displayName;
  final double baseFare;
  final double perKmRate;
  final double perMinuteRate;
  final double minimumFare;
  final double badRoadMultiplier;

  const FareRule({
    required this.vehicleType,
    required this.displayName,
    required this.baseFare,
    required this.perKmRate,
    required this.perMinuteRate,
    required this.minimumFare,
    this.badRoadMultiplier = 1.2,
  });

  double calculateFare({
    required double distanceKm,
    required double timeMinutes,
    bool isBadRoad = false,
  }) {
    final mult = isBadRoad ? badRoadMultiplier : 1.0;
    final calculated =
        (baseFare + (perKmRate * distanceKm) + (perMinuteRate * timeMinutes)) *
        mult;
    return calculated < minimumFare ? minimumFare : calculated;
  }

  Map<String, dynamic> toJson() => {
    'vehicleType': vehicleType,
    'displayName': displayName,
    'baseFare': baseFare,
    'perKmRate': perKmRate,
    'perMinuteRate': perMinuteRate,
    'minimumFare': minimumFare,
    'badRoadMultiplier': badRoadMultiplier,
  };

  factory FareRule.fromJson(Map<String, dynamic> json) => FareRule(
    vehicleType: json['vehicleType'] as String,
    displayName:
        json['displayName'] as String? ?? json['vehicleType'] as String,
    baseFare: (json['baseFare'] as num).toDouble(),
    perKmRate: (json['perKmRate'] as num).toDouble(),
    perMinuteRate: (json['perMinuteRate'] as num).toDouble(),
    minimumFare: (json['minimumFare'] as num).toDouble(),
    badRoadMultiplier: (json['badRoadMultiplier'] as num?)?.toDouble() ?? 1.2,
  );
}

/// Real-time / Simulated Ride Session
class RideSession {
  final String id;
  final String originName;
  final String destinationName;
  final double originLat;
  final double originLng;
  final double destinationLat;
  final double destinationLng;
  final String vehicleType;
  final double distanceKm;
  final double estimatedMinutes;
  final double fairFareEstimate;
  final double? driverQuotedPrice;
  final int currentElapsedSeconds;
  final double currentDistanceTraveledKm;
  final double currentRunningFare;
  final String status; // 'planning', 'ongoing', 'completed'

  const RideSession({
    required this.id,
    required this.originName,
    required this.destinationName,
    required this.originLat,
    required this.originLng,
    required this.destinationLat,
    required this.destinationLng,
    required this.vehicleType,
    required this.distanceKm,
    required this.estimatedMinutes,
    required this.fairFareEstimate,
    this.driverQuotedPrice,
    this.currentElapsedSeconds = 0,
    this.currentDistanceTraveledKm = 0.0,
    this.currentRunningFare = 0.0,
    this.status = 'planning',
  });

  RideSession copyWith({
    String? id,
    String? originName,
    String? destinationName,
    double? originLat,
    double? originLng,
    double? destinationLat,
    double? destinationLng,
    String? vehicleType,
    double? distanceKm,
    double? estimatedMinutes,
    double? fairFareEstimate,
    double? driverQuotedPrice,
    int? currentElapsedSeconds,
    double? currentDistanceTraveledKm,
    double? currentRunningFare,
    String? status,
  }) {
    return RideSession(
      id: id ?? this.id,
      originName: originName ?? this.originName,
      destinationName: destinationName ?? this.destinationName,
      originLat: originLat ?? this.originLat,
      originLng: originLng ?? this.originLng,
      destinationLat: destinationLat ?? this.destinationLat,
      destinationLng: destinationLng ?? this.destinationLng,
      vehicleType: vehicleType ?? this.vehicleType,
      distanceKm: distanceKm ?? this.distanceKm,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      fairFareEstimate: fairFareEstimate ?? this.fairFareEstimate,
      driverQuotedPrice: driverQuotedPrice ?? this.driverQuotedPrice,
      currentElapsedSeconds:
          currentElapsedSeconds ?? this.currentElapsedSeconds,
      currentDistanceTraveledKm:
          currentDistanceTraveledKm ?? this.currentDistanceTraveledKm,
      currentRunningFare: currentRunningFare ?? this.currentRunningFare,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'originName': originName,
    'destinationName': destinationName,
    'originLat': originLat,
    'originLng': originLng,
    'destinationLat': destinationLat,
    'destinationLng': destinationLng,
    'vehicleType': vehicleType,
    'distanceKm': distanceKm,
    'estimatedMinutes': estimatedMinutes,
    'fairFareEstimate': fairFareEstimate,
    'driverQuotedPrice': driverQuotedPrice,
    'currentElapsedSeconds': currentElapsedSeconds,
    'currentDistanceTraveledKm': currentDistanceTraveledKm,
    'currentRunningFare': currentRunningFare,
    'status': status,
  };

  factory RideSession.fromJson(Map<String, dynamic> json) => RideSession(
    id: json['id'] as String,
    originName: json['originName'] as String,
    destinationName: json['destinationName'] as String,
    originLat: (json['originLat'] as num).toDouble(),
    originLng: (json['originLng'] as num).toDouble(),
    destinationLat: (json['destinationLat'] as num).toDouble(),
    destinationLng: (json['destinationLng'] as num).toDouble(),
    vehicleType: json['vehicleType'] as String,
    distanceKm: (json['distanceKm'] as num).toDouble(),
    estimatedMinutes: (json['estimatedMinutes'] as num).toDouble(),
    fairFareEstimate: (json['fairFareEstimate'] as num).toDouble(),
    driverQuotedPrice: (json['driverQuotedPrice'] as num?)?.toDouble(),
    currentElapsedSeconds: json['currentElapsedSeconds'] as int? ?? 0,
    currentDistanceTraveledKm:
        (json['currentDistanceTraveledKm'] as num?)?.toDouble() ?? 0.0,
    currentRunningFare: (json['currentRunningFare'] as num?)?.toDouble() ?? 0.0,
    status: json['status'] as String? ?? 'planning',
  );
}
