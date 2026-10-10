import 'package:flutter/material.dart';

/// Standard 3 verdict levels used across the entire application
enum PriceVerdictLevel {
  fair(
    'Fair',
    Color(0xFF10B981), // Emerald Green
    Icons.check_circle_rounded,
    'Price is within local fair market rate.',
  ),
  suspicious(
    'Suspicious',
    Color(0xFFF59E0B), // Amber
    Icons.warning_amber_rounded,
    'Price is higher than expected or has warning indicators.',
  ),
  highRisk(
    'High Risk',
    Color(0xFFEF4444), // Crimson Red
    Icons.error_rounded,
    'Significant markup or tourist trap alert detected.',
  );

  final String label;
  final Color color;
  final IconData icon;
  final String defaultSentence;

  const PriceVerdictLevel(
    this.label,
    this.color,
    this.icon,
    this.defaultSentence,
  );

  static PriceVerdictLevel fromScore(int riskScore) {
    if (riskScore < 30) return PriceVerdictLevel.fair;
    if (riskScore < 60) return PriceVerdictLevel.suspicious;
    return PriceVerdictLevel.highRisk;
  }
}

/// Supported service types for price intelligence
enum ServiceType {
  taxi('Taxi / Cab', Icons.local_taxi_rounded),
  auto('Auto-rickshaw', Icons.electric_rickshaw_rounded),
  bikeTaxi('Bike taxi', Icons.two_wheeler_rounded),
  guide('Local guide', Icons.person_pin_circle_rounded),
  meal('Meal / Restaurant', Icons.restaurant_rounded),
  room('Room / Stay', Icons.hotel_rounded),
  entryTicket('Entry ticket / Activity', Icons.confirmation_number_rounded),
  other('Other', Icons.category_rounded);

  final String displayName;
  final IconData icon;

  const ServiceType(this.displayName, this.icon);

  static ServiceType fromString(String val) {
    switch (val.toLowerCase().replaceAll(' ', '').replaceAll('-', '')) {
      case 'taxi':
      case 'cab':
        return ServiceType.taxi;
      case 'auto':
      case 'rickshaw':
      case 'autorickshaw':
        return ServiceType.auto;
      case 'bike':
      case 'biketaxi':
        return ServiceType.bikeTaxi;
      case 'guide':
        return ServiceType.guide;
      case 'meal':
      case 'food':
      case 'restaurant':
        return ServiceType.meal;
      case 'room':
      case 'stay':
      case 'hotel':
        return ServiceType.room;
      case 'entry':
      case 'ticket':
      case 'activity':
      case 'entryticket':
        return ServiceType.entryTicket;
      default:
        return ServiceType.other;
    }
  }
}

/// Confidence level for calculated price intelligence
enum ConfidenceLevel {
  high('High Confidence'),
  medium('Medium Confidence'),
  low('Low Confidence');

  final String label;
  const ConfidenceLevel(this.label);
}

/// Official Government Tariff or notified rate card
class GovTariff {
  final String id;
  final String city;
  final ServiceType serviceType;
  final String vehicleType;
  final double baseFare;
  final double perKm;
  final double perMin;
  final double minFare;
  final double waitingFarePerHour;
  final double nightSurchargePercent; // e.g. 25.0 for 25%
  final double? flatRate;
  final DateTime effectiveDate;
  final String source;
  final String sourceUrl;
  final bool verified; // Sample tariffs have verified: false

  const GovTariff({
    required this.id,
    required this.city,
    required this.serviceType,
    required this.vehicleType,
    required this.baseFare,
    required this.perKm,
    this.perMin = 0.0,
    required this.minFare,
    this.waitingFarePerHour = 0.0,
    this.nightSurchargePercent = 0.0,
    this.flatRate,
    required this.effectiveDate,
    required this.source,
    required this.sourceUrl,
    this.verified = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'city': city,
    'serviceType': serviceType.name,
    'vehicleType': vehicleType,
    'baseFare': baseFare,
    'perKm': perKm,
    'perMin': perMin,
    'minFare': minFare,
    'waitingFarePerHour': waitingFarePerHour,
    'nightSurchargePercent': nightSurchargePercent,
    'flatRate': flatRate,
    'effectiveDate': effectiveDate.toIso8601String(),
    'source': source,
    'sourceUrl': sourceUrl,
    'verified': verified,
  };

  factory GovTariff.fromJson(Map<String, dynamic> json) => GovTariff(
    id: json['id'] as String,
    city: json['city'] as String,
    serviceType: ServiceType.fromString(json['serviceType'] as String),
    vehicleType: json['vehicleType'] as String? ?? 'Standard',
    baseFare: (json['baseFare'] as num).toDouble(),
    perKm: (json['perKm'] as num).toDouble(),
    perMin: (json['perMin'] as num?)?.toDouble() ?? 0.0,
    minFare: (json['minFare'] as num).toDouble(),
    waitingFarePerHour: (json['waitingFarePerHour'] as num?)?.toDouble() ?? 0.0,
    nightSurchargePercent:
        (json['nightSurchargePercent'] as num?)?.toDouble() ?? 0.0,
    flatRate: (json['flatRate'] as num?)?.toDouble(),
    effectiveDate: DateTime.parse(json['effectiveDate'] as String),
    source: json['source'] as String,
    sourceUrl: json['sourceUrl'] as String? ?? '',
    verified: json['verified'] as bool? ?? false,
  );
}

/// Community-submitted Price Report
class PriceReport {
  final String id;
  final ServiceType serviceType;
  final String vehicleType;
  final String routeOrPlace;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropLat;
  final double? dropLng;
  final double pricePaid;
  final DateTime timestamp;
  final bool wasFair;
  final String? photoEvidenceUrl;
  final String? notes;
  final double weight;
  final bool isFlagged;
  final int flagCount;
  final String? userId;

  const PriceReport({
    required this.id,
    required this.serviceType,
    required this.vehicleType,
    required this.routeOrPlace,
    this.pickupLat,
    this.pickupLng,
    this.dropLat,
    this.dropLng,
    required this.pricePaid,
    required this.timestamp,
    required this.wasFair,
    this.photoEvidenceUrl,
    this.notes,
    this.weight = 1.0,
    this.isFlagged = false,
    this.flagCount = 0,
    this.userId,
  });

  PriceReport copyWith({
    String? id,
    ServiceType? serviceType,
    String? vehicleType,
    String? routeOrPlace,
    double? pickupLat,
    double? pickupLng,
    double? dropLat,
    double? dropLng,
    double? pricePaid,
    DateTime? timestamp,
    bool? wasFair,
    String? photoEvidenceUrl,
    String? notes,
    double? weight,
    bool? isFlagged,
    int? flagCount,
    String? userId,
  }) => PriceReport(
    id: id ?? this.id,
    serviceType: serviceType ?? this.serviceType,
    vehicleType: vehicleType ?? this.vehicleType,
    routeOrPlace: routeOrPlace ?? this.routeOrPlace,
    pickupLat: pickupLat ?? this.pickupLat,
    pickupLng: pickupLng ?? this.pickupLng,
    dropLat: dropLat ?? this.dropLat,
    dropLng: dropLng ?? this.dropLng,
    pricePaid: pricePaid ?? this.pricePaid,
    timestamp: timestamp ?? this.timestamp,
    wasFair: wasFair ?? this.wasFair,
    photoEvidenceUrl: photoEvidenceUrl ?? this.photoEvidenceUrl,
    notes: notes ?? this.notes,
    weight: weight ?? this.weight,
    isFlagged: isFlagged ?? this.isFlagged,
    flagCount: flagCount ?? this.flagCount,
    userId: userId ?? this.userId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'serviceType': serviceType.name,
    'vehicleType': vehicleType,
    'routeOrPlace': routeOrPlace,
    'pickupLat': pickupLat,
    'pickupLng': pickupLng,
    'dropLat': dropLat,
    'dropLng': dropLng,
    'pricePaid': pricePaid,
    'timestamp': timestamp.toIso8601String(),
    'wasFair': wasFair,
    'photoEvidenceUrl': photoEvidenceUrl,
    'notes': notes,
    'weight': weight,
    'isFlagged': isFlagged,
    'flagCount': flagCount,
    'userId': userId,
  };

  factory PriceReport.fromJson(Map<String, dynamic> json) => PriceReport(
    id: json['id'] as String,
    serviceType: ServiceType.fromString(json['serviceType'] as String),
    vehicleType: json['vehicleType'] as String? ?? 'standard',
    routeOrPlace: json['routeOrPlace'] as String,
    pickupLat: (json['pickupLat'] as num?)?.toDouble(),
    pickupLng: (json['pickupLng'] as num?)?.toDouble(),
    dropLat: (json['dropLat'] as num?)?.toDouble(),
    dropLng: (json['dropLng'] as num?)?.toDouble(),
    pricePaid: (json['pricePaid'] as num).toDouble(),
    timestamp: DateTime.parse(json['timestamp'] as String),
    wasFair: json['wasFair'] as bool? ?? true,
    photoEvidenceUrl: json['photoEvidenceUrl'] as String?,
    notes: json['notes'] as String?,
    weight: (json['weight'] as num?)?.toDouble() ?? 1.0,
    isFlagged: json['isFlagged'] as bool? ?? false,
    flagCount: json['flagCount'] as int? ?? 0,
    userId: json['userId'] as String?,
  );
}

/// Tourist Trap entry in the intelligence database
class TouristTrap {
  final String id;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final ServiceType serviceType;
  final String type; // overcharging, hidden charge, meter tampering, fake guide, commission shop, fake closure, fake booking, other
  final String description;
  final String avoidTip;
  final int severity; // 1 - 5
  final int reportCount;
  final DateTime lastReported;
  final String source; // community / official / news

  const TouristTrap({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 500.0,
    required this.serviceType,
    required this.type,
    required this.description,
    required this.avoidTip,
    required this.severity,
    required this.reportCount,
    required this.lastReported,
    required this.source,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'latitude': latitude,
    'longitude': longitude,
    'radiusMeters': radiusMeters,
    'serviceType': serviceType.name,
    'type': type,
    'description': description,
    'avoidTip': avoidTip,
    'severity': severity,
    'reportCount': reportCount,
    'lastReported': lastReported.toIso8601String(),
    'source': source,
  };

  factory TouristTrap.fromJson(Map<String, dynamic> json) => TouristTrap(
    id: json['id'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    radiusMeters: (json['radiusMeters'] as num?)?.toDouble() ?? 500.0,
    serviceType: ServiceType.fromString(json['serviceType'] as String),
    type: json['type'] as String,
    description: json['description'] as String,
    avoidTip: json['avoidTip'] as String,
    severity: json['severity'] as int,
    reportCount: json['reportCount'] as int,
    lastReported: DateTime.parse(json['lastReported'] as String),
    source: json['source'] as String? ?? 'community',
  );
}

/// Community-submitted Trap Report
class TrapReport {
  final String id;
  final ServiceType serviceType;
  final String scamType;
  final String locationName;
  final double latitude;
  final double longitude;
  final String description;
  final int severity; // 1 to 5
  final DateTime timestamp;
  final String? driverOrBusinessName;
  final double? extraCostExtorted;
  final String? evidencePhotoUrl;

  const TrapReport({
    required this.id,
    required this.serviceType,
    required this.scamType,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.description,
    required this.severity,
    required this.timestamp,
    this.driverOrBusinessName,
    this.extraCostExtorted,
    this.evidencePhotoUrl,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'serviceType': serviceType.name,
    'scamType': scamType,
    'locationName': locationName,
    'latitude': latitude,
    'longitude': longitude,
    'description': description,
    'severity': severity,
    'timestamp': timestamp.toIso8601String(),
    'driverOrBusinessName': driverOrBusinessName,
    'extraCostExtorted': extraCostExtorted,
    'evidencePhotoUrl': evidencePhotoUrl,
  };

  factory TrapReport.fromJson(Map<String, dynamic> json) => TrapReport(
    id: json['id'] as String,
    serviceType: ServiceType.fromString(json['serviceType'] as String),
    scamType: json['scamType'] as String,
    locationName: json['locationName'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    description: json['description'] as String,
    severity: json['severity'] as int? ?? 3,
    timestamp: DateTime.parse(json['timestamp'] as String),
    driverOrBusinessName: json['driverOrBusinessName'] as String?,
    extraCostExtorted: (json['extraCostExtorted'] as num?)?.toDouble(),
    evidencePhotoUrl: json['evidencePhotoUrl'] as String?,
  );
}

/// Area Insight for Location Intelligence
class AreaInsight {
  final String id;
  final String areaName;
  final double centerLat;
  final double centerLng;
  final double priceIndex; // average quoted / fair price ratio (e.g. 1.35)
  final int complaintCount90d;
  final List<String> topTrapTypes;
  final List<String> saferAlternatives; // e.g. "Prepaid Taxi Booth #3"
  final DateTime lastUpdated;

  const AreaInsight({
    required this.id,
    required this.areaName,
    required this.centerLat,
    required this.centerLng,
    required this.priceIndex,
    required this.complaintCount90d,
    required this.topTrapTypes,
    required this.saferAlternatives,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'areaName': areaName,
    'centerLat': centerLat,
    'centerLng': centerLng,
    'priceIndex': priceIndex,
    'complaintCount90d': complaintCount90d,
    'topTrapTypes': topTrapTypes,
    'saferAlternatives': saferAlternatives,
    'lastUpdated': lastUpdated.toIso8601String(),
  };

  factory AreaInsight.fromJson(Map<String, dynamic> json) => AreaInsight(
    id: json['id'] as String,
    areaName: json['areaName'] as String,
    centerLat: (json['centerLat'] as num).toDouble(),
    centerLng: (json['centerLng'] as num).toDouble(),
    priceIndex: (json['priceIndex'] as num).toDouble(),
    complaintCount90d: json['complaintCount90d'] as int,
    topTrapTypes: List<String>.from(json['topTrapTypes'] as List),
    saferAlternatives: List<String>.from(json['saferAlternatives'] as List),
    lastUpdated: DateTime.parse(json['lastUpdated'] as String),
  );
}
