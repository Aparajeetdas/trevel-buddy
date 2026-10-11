import 'ai_price_models.dart';
import 'price_engine_models.dart';

/// Location coordinates and title for roadmap origin/destination
class RoadmapLocation {
  final String? placeId;
  final String name;
  final double lat;
  final double lng;
  final String? formattedAddress;
  final bool isMyLocation;

  const RoadmapLocation({
    this.placeId,
    required this.name,
    required this.lat,
    required this.lng,
    this.formattedAddress,
    this.isMyLocation = false,
  });

  Map<String, dynamic> toJson() => {
    'placeId': placeId,
    'name': name,
    'lat': lat,
    'lng': lng,
    'formattedAddress': formattedAddress,
    'isMyLocation': isMyLocation,
  };

  factory RoadmapLocation.fromJson(Map<String, dynamic> json) =>
      RoadmapLocation(
        placeId: json['placeId'] as String?,
        name: json['name'] as String? ?? 'Location',
        lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
        lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
        formattedAddress: json['formattedAddress'] as String?,
        isMyLocation: json['isMyLocation'] as bool? ?? false,
      );
}

/// A discrete step/leg along a transit or ride route
class RoadmapStep {
  final int index;
  final String mode; // 'walk', 'bike_taxi', 'auto', 'cab', 'bus', 'train', 'metro', 'shared_taxi'
  final String title;
  final String instruction;
  final String fromName;
  final String toName;
  final double startLat;
  final double startLng;
  final double endLat;
  final double endLng;
  final double distanceM;
  final double durationMin;
  final String? polyline;
  final double fairMin;
  final double fairMax;
  final double dontPayMoreThan;
  final String
  priceSource; // '[Official tariff]', '[Community]', '[Estimate]', '[Google]'
  final ConfidenceLevel confidence;
  final String boardingPoint;
  final List<String> warnings;
  final List<String> tips;
  final List<String> trapIds;
  final List<TouristTrap> traps;
  final PriceCheckInput? priceCheckInput;

  const RoadmapStep({
    required this.index,
    required this.mode,
    required this.title,
    required this.instruction,
    required this.fromName,
    required this.toName,
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
    required this.distanceM,
    required this.durationMin,
    this.polyline,
    required this.fairMin,
    required this.fairMax,
    required this.dontPayMoreThan,
    required this.priceSource,
    this.confidence = ConfidenceLevel.high,
    required this.boardingPoint,
    this.warnings = const [],
    this.tips = const [],
    this.trapIds = const [],
    this.traps = const [],
    this.priceCheckInput,
  });

  Map<String, dynamic> toJson() => {
    'index': index,
    'mode': mode,
    'title': title,
    'instruction': instruction,
    'fromName': fromName,
    'toName': toName,
    'startLat': startLat,
    'startLng': startLng,
    'endLat': endLat,
    'endLng': endLng,
    'distanceM': distanceM,
    'durationMin': durationMin,
    'polyline': polyline,
    'fairMin': fairMin,
    'fairMax': fairMax,
    'dontPayMoreThan': dontPayMoreThan,
    'priceSource': priceSource,
    'confidence': confidence.name,
    'boardingPoint': boardingPoint,
    'warnings': warnings,
    'tips': tips,
    'trapIds': trapIds,
    'traps': traps.map((t) => t.toJson()).toList(),
    'priceCheckInput': priceCheckInput?.toJson(),
  };

  factory RoadmapStep.fromJson(Map<String, dynamic> json) => RoadmapStep(
    index: json['index'] as int? ?? 0,
    mode: json['mode'] as String? ?? 'walk',
    title: json['title'] as String? ?? '',
    instruction: json['instruction'] as String? ?? '',
    fromName: json['fromName'] as String? ?? '',
    toName: json['toName'] as String? ?? '',
    startLat: (json['startLat'] as num?)?.toDouble() ?? 0.0,
    startLng: (json['startLng'] as num?)?.toDouble() ?? 0.0,
    endLat: (json['endLat'] as num?)?.toDouble() ?? 0.0,
    endLng: (json['endLng'] as num?)?.toDouble() ?? 0.0,
    distanceM: (json['distanceM'] as num?)?.toDouble() ?? 0.0,
    durationMin: (json['durationMin'] as num?)?.toDouble() ?? 0.0,
    polyline: json['polyline'] as String?,
    fairMin: (json['fairMin'] as num?)?.toDouble() ?? 0.0,
    fairMax: (json['fairMax'] as num?)?.toDouble() ?? 0.0,
    dontPayMoreThan: (json['dontPayMoreThan'] as num?)?.toDouble() ?? 0.0,
    priceSource: json['priceSource'] as String? ?? '[Estimate]',
    confidence: ConfidenceLevel.values.firstWhere(
      (c) => c.name == json['confidence'],
      orElse: () => ConfidenceLevel.medium,
    ),
    boardingPoint: json['boardingPoint'] as String? ?? '',
    warnings: List<String>.from(json['warnings'] ?? []),
    tips: List<String>.from(json['tips'] ?? []),
    trapIds: List<String>.from(json['trapIds'] ?? []),
    traps:
        (json['traps'] as List<dynamic>?)
            ?.map((t) => TouristTrap.fromJson(t as Map<String, dynamic>))
            .toList() ??
        const [],
    priceCheckInput: json['priceCheckInput'] != null
        ? PriceCheckInput.fromJson(
            json['priceCheckInput'] as Map<String, dynamic>,
          )
        : null,
  );
}

/// A complete route choice (e.g. Cheapest, Fastest, Comfortable, Local guide)
class RoadmapOption {
  final String id;
  final String label; // 'Cheapest', 'Fastest', 'Comfortable', 'Local guide'
  final double totalMin;
  final double totalFairMin;
  final double totalFairMax;
  final PriceVerdictLevel riskLevel;
  final List<RoadmapStep> steps;
  final bool isCurated;
  final bool isEstimatedRoute;
  final String summaryOneLiner;

  const RoadmapOption({
    required this.id,
    required this.label,
    required this.totalMin,
    required this.totalFairMin,
    required this.totalFairMax,
    required this.riskLevel,
    required this.steps,
    this.isCurated = false,
    this.isEstimatedRoute = false,
    required this.summaryOneLiner,
  });

  String get primaryMode => steps.isNotEmpty ? steps.first.mode : 'driving';

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'totalMin': totalMin,
    'totalFairMin': totalFairMin,
    'totalFairMax': totalFairMax,
    'riskLevel': riskLevel.name,
    'steps': steps.map((s) => s.toJson()).toList(),
    'isCurated': isCurated,
    'summaryOneLiner': summaryOneLiner,
  };

  factory RoadmapOption.fromJson(Map<String, dynamic> json) => RoadmapOption(
    id: json['id'] as String? ?? '',
    label: json['label'] as String? ?? 'Option',
    totalMin: (json['totalMin'] as num?)?.toDouble() ?? 0.0,
    totalFairMin: (json['totalFairMin'] as num?)?.toDouble() ?? 0.0,
    totalFairMax: (json['totalFairMax'] as num?)?.toDouble() ?? 0.0,
    riskLevel: PriceVerdictLevel.values.firstWhere(
      (v) => v.name == json['riskLevel'],
      orElse: () => PriceVerdictLevel.fair,
    ),
    steps:
        (json['steps'] as List<dynamic>?)
            ?.map((s) => RoadmapStep.fromJson(s as Map<String, dynamic>))
            .toList() ??
        const [],
    isCurated: json['isCurated'] as bool? ?? false,
    summaryOneLiner: json['summaryOneLiner'] as String? ?? '',
  );
}

/// Pre-trip safety and logistical checklist item
class ChecklistItem {
  final String id;
  final String title;
  final String subtitle;
  final String category; // 'essential', 'conditional'
  final bool isChecked;

  const ChecklistItem({
    required this.id,
    required this.title,
    required this.subtitle,
    this.category = 'essential',
    this.isChecked = false,
  });

  ChecklistItem copyWith({bool? isChecked}) => ChecklistItem(
    id: id,
    title: title,
    subtitle: subtitle,
    category: category,
    isChecked: isChecked ?? this.isChecked,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'category': category,
    'isChecked': isChecked,
  };

  factory ChecklistItem.fromJson(Map<String, dynamic> json) => ChecklistItem(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    subtitle: json['subtitle'] as String? ?? '',
    category: json['category'] as String? ?? 'essential',
    isChecked: json['isChecked'] as bool? ?? false,
  );
}

/// Saved journey roadmap for offline review
class SavedTrip {
  final String id;
  final String originName;
  final double originLat;
  final double originLng;
  final String destName;
  final double destLat;
  final double destLng;
  final String selectedOptionLabel;
  final double totalFairMin;
  final double totalFairMax;
  final DateTime createdAt;

  const SavedTrip({
    required this.id,
    required this.originName,
    required this.originLat,
    required this.originLng,
    required this.destName,
    required this.destLat,
    required this.destLng,
    required this.selectedOptionLabel,
    required this.totalFairMin,
    required this.totalFairMax,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'originName': originName,
    'originLat': originLat,
    'originLng': originLng,
    'destName': destName,
    'destLat': destLat,
    'destLng': destLng,
    'selectedOptionLabel': selectedOptionLabel,
    'totalFairMin': totalFairMin,
    'totalFairMax': totalFairMax,
    'createdAt': createdAt.toIso8601String(),
  };

  factory SavedTrip.fromJson(Map<String, dynamic> json) => SavedTrip(
    id: json['id'] as String? ?? '',
    originName: json['originName'] as String? ?? '',
    originLat: (json['originLat'] as num?)?.toDouble() ?? 0.0,
    originLng: (json['originLng'] as num?)?.toDouble() ?? 0.0,
    destName: json['destName'] as String? ?? '',
    destLat: (json['destLat'] as num?)?.toDouble() ?? 0.0,
    destLng: (json['destLng'] as num?)?.toDouble() ?? 0.0,
    selectedOptionLabel: json['selectedOptionLabel'] as String? ?? '',
    totalFairMin: (json['totalFairMin'] as num?)?.toDouble() ?? 0.0,
    totalFairMax: (json['totalFairMax'] as num?)?.toDouble() ?? 0.0,
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : DateTime.now(),
  );
}

/// Full journey roadmap with multi-modal options and pre-trip checklist
class Roadmap {
  final String id;
  final RoadmapLocation origin;
  final RoadmapLocation destination;
  final DateTime departTime;
  final int travelers;
  final List<RoadmapOption> options;
  final List<ChecklistItem> checklist;
  final String? aiSummary;

  const Roadmap({
    required this.id,
    required this.origin,
    required this.destination,
    required this.departTime,
    this.travelers = 1,
    required this.options,
    this.checklist = const [],
    this.aiSummary,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'origin': origin.toJson(),
    'destination': destination.toJson(),
    'departTime': departTime.toIso8601String(),
    'travelers': travelers,
    'options': options.map((o) => o.toJson()).toList(),
    'checklist': checklist.map((c) => c.toJson()).toList(),
    'aiSummary': aiSummary,
  };

  factory Roadmap.fromJson(Map<String, dynamic> json) => Roadmap(
    id: json['id'] as String? ?? '',
    origin: RoadmapLocation.fromJson(json['origin'] as Map<String, dynamic>),
    destination: RoadmapLocation.fromJson(
      json['destination'] as Map<String, dynamic>,
    ),
    departTime: json['departTime'] != null
        ? DateTime.parse(json['departTime'] as String)
        : DateTime.now(),
    travelers: json['travelers'] as int? ?? 1,
    options:
        (json['options'] as List<dynamic>?)
            ?.map((o) => RoadmapOption.fromJson(o as Map<String, dynamic>))
            .toList() ??
        const [],
    checklist:
        (json['checklist'] as List<dynamic>?)
            ?.map((c) => ChecklistItem.fromJson(c as Map<String, dynamic>))
            .toList() ??
        const [],
    aiSummary: json['aiSummary'] as String?,
  );
}
