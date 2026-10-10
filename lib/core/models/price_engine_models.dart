import 'ai_price_models.dart';

/// Transparent factor explaining price risk score adjustment
class Factor {
  final String label;
  final int points; // e.g. +55 or -10
  final String evidence;
  final String
  sourceTag; // e.g. [Official Tariff], [Community], [Tourist Trap DB]

  const Factor({
    required this.label,
    required this.points,
    required this.evidence,
    required this.sourceTag,
  });

  Map<String, dynamic> toJson() => {
    'label': label,
    'points': points,
    'evidence': evidence,
    'sourceTag': sourceTag,
  };

  factory Factor.fromJson(Map<String, dynamic> json) => Factor(
    label: json['label'] as String,
    points: json['points'] as int,
    evidence: json['evidence'] as String,
    sourceTag: json['sourceTag'] as String,
  );
}

/// Supporting source displayed on the Result screen sources row
class PriceCheckSource {
  final String type; // 'official', 'community', 'estimate'
  final double? amount;
  final double? minAmount;
  final double? maxAmount;
  final String sourceName;
  final String? effectiveDate;
  final int? reportCount;
  final String details;

  const PriceCheckSource({
    required this.type,
    this.amount,
    this.minAmount,
    this.maxAmount,
    required this.sourceName,
    this.effectiveDate,
    this.reportCount,
    required this.details,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'amount': amount,
    'minAmount': minAmount,
    'maxAmount': maxAmount,
    'sourceName': sourceName,
    'effectiveDate': effectiveDate,
    'reportCount': reportCount,
    'details': details,
  };

  factory PriceCheckSource.fromJson(Map<String, dynamic> json) =>
      PriceCheckSource(
        type: json['type'] as String,
        amount: (json['amount'] as num?)?.toDouble(),
        minAmount: (json['minAmount'] as num?)?.toDouble(),
        maxAmount: (json['maxAmount'] as num?)?.toDouble(),
        sourceName: json['sourceName'] as String,
        effectiveDate: json['effectiveDate'] as String?,
        reportCount: json['reportCount'] as int?,
        details: json['details'] as String,
      );
}

/// Input data fed into the pricing engine
class PriceCheckInput {
  final ServiceType serviceType;
  final String? vehicleType;
  final String? pickupName;
  final String? dropName;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropLat;
  final double? dropLng;
  final double? distanceKm;
  final double? durationMinutes;
  final double quotedPrice;
  final DateTime timeOfDay;
  final int passengers;
  // Guides
  final double? hours;
  final int? groupSize;
  // Meals
  final int? mealPeople;
  final String? mealItems;
  // Rooms
  final int? roomNights;
  final String? roomType;
  // Rides & Driver
  final bool meterUsed;
  final String? driverOrBusinessName;
  final String? vehicleNumber;

  PriceCheckInput({
    required this.serviceType,
    this.vehicleType,
    this.pickupName,
    this.dropName,
    this.pickupLat,
    this.pickupLng,
    this.dropLat,
    this.dropLng,
    this.distanceKm,
    this.durationMinutes,
    required this.quotedPrice,
    DateTime? timeOfDay,
    this.passengers = 1,
    this.hours,
    this.groupSize,
    this.mealPeople,
    this.mealItems,
    this.roomNights,
    this.roomType,
    this.meterUsed = false,
    this.driverOrBusinessName,
    this.vehicleNumber,
  }) : timeOfDay = timeOfDay ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'serviceType': serviceType.name,
    'vehicleType': vehicleType,
    'pickupName': pickupName,
    'dropName': dropName,
    'pickupLat': pickupLat,
    'pickupLng': pickupLng,
    'dropLat': dropLat,
    'dropLng': dropLng,
    'distanceKm': distanceKm,
    'durationMinutes': durationMinutes,
    'quotedPrice': quotedPrice,
    'timeOfDay': timeOfDay.toIso8601String(),
    'passengers': passengers,
    'hours': hours,
    'groupSize': groupSize,
    'mealPeople': mealPeople,
    'mealItems': mealItems,
    'roomNights': roomNights,
    'roomType': roomType,
    'meterUsed': meterUsed,
    'driverOrBusinessName': driverOrBusinessName,
    'vehicleNumber': vehicleNumber,
  };

  factory PriceCheckInput.fromJson(Map<String, dynamic> json) =>
      PriceCheckInput(
        serviceType: ServiceType.fromString(json['serviceType'] as String),
        vehicleType: json['vehicleType'] as String?,
        pickupName: json['pickupName'] as String?,
        dropName: json['dropName'] as String?,
        pickupLat: (json['pickupLat'] as num?)?.toDouble(),
        pickupLng: (json['pickupLng'] as num?)?.toDouble(),
        dropLat: (json['dropLat'] as num?)?.toDouble(),
        dropLng: (json['dropLng'] as num?)?.toDouble(),
        distanceKm: (json['distanceKm'] as num?)?.toDouble(),
        durationMinutes: (json['durationMinutes'] as num?)?.toDouble(),
        quotedPrice: (json['quotedPrice'] as num).toDouble(),
        timeOfDay: json['timeOfDay'] != null
            ? DateTime.parse(json['timeOfDay'] as String)
            : null,
        passengers: json['passengers'] as int? ?? 1,
        hours: (json['hours'] as num?)?.toDouble(),
        groupSize: json['groupSize'] as int?,
        mealPeople: json['mealPeople'] as int?,
        mealItems: json['mealItems'] as String?,
        roomNights: json['roomNights'] as int?,
        roomType: json['roomType'] as String?,
        meterUsed: json['meterUsed'] as bool? ?? false,
        driverOrBusinessName: json['driverOrBusinessName'] as String?,
        vehicleNumber: json['vehicleNumber'] as String?,
      );
}

/// Output result generated by the deterministic pricing engine
class PriceCheckResult {
  final PriceVerdictLevel level;
  final int riskScore; // 0 - 100
  final ConfidenceLevel confidence;
  final double fairMin;
  final double fairMax;
  final double quotedPrice;
  final double differenceRupees;
  final double differencePercent;
  final double counterOffer;
  final String counterOfferLine;
  final List<PriceCheckSource> sources;
  final List<Factor> factors;
  final String explanation;
  final List<TouristTrap> nearbyTraps;
  final bool isUnusuallyLow;

  const PriceCheckResult({
    required this.level,
    required this.riskScore,
    required this.confidence,
    required this.fairMin,
    required this.fairMax,
    required this.quotedPrice,
    required this.differenceRupees,
    required this.differencePercent,
    required this.counterOffer,
    required this.counterOfferLine,
    required this.sources,
    required this.factors,
    required this.explanation,
    this.nearbyTraps = const [],
    this.isUnusuallyLow = false,
  });

  Map<String, dynamic> toJson() => {
    'level': level.name,
    'riskScore': riskScore,
    'confidence': confidence.name,
    'fairMin': fairMin,
    'fairMax': fairMax,
    'quotedPrice': quotedPrice,
    'differenceRupees': differenceRupees,
    'differencePercent': differencePercent,
    'counterOffer': counterOffer,
    'counterOfferLine': counterOfferLine,
    'sources': sources.map((s) => s.toJson()).toList(),
    'factors': factors.map((f) => f.toJson()).toList(),
    'explanation': explanation,
    'nearbyTraps': nearbyTraps.map((t) => t.toJson()).toList(),
    'isUnusuallyLow': isUnusuallyLow,
  };
}

/// Action proposed by the Ask Buddy Agent
class AgentAction {
  final String type; // 'check_price', 'show_map', 'start_ride', 'call_112'
  final String label;
  final Map<String, dynamic> params;

  const AgentAction({
    required this.type,
    required this.label,
    this.params = const {},
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'label': label,
    'params': params,
  };

  factory AgentAction.fromJson(Map<String, dynamic> json) => AgentAction(
    type: json['type'] as String,
    label: json['label'] as String,
    params: json['params'] as Map<String, dynamic>? ?? {},
  );
}

/// Chat message exchange with the AI Travel Buddy
class AgentMessage {
  final String id;
  final String sender; // 'user' or 'buddy'
  final String text;
  final DateTime timestamp;
  final List<AgentAction> actions;
  final List<String> sources;

  const AgentMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.actions = const [],
    this.sources = const [],
  });

  AgentMessage copyWith({
    String? id,
    String? sender,
    String? text,
    DateTime? timestamp,
    List<AgentAction>? actions,
    List<String>? sources,
  }) {
    return AgentMessage(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      actions: actions ?? this.actions,
      sources: sources ?? this.sources,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sender': sender,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
    'actions': actions.map((a) => a.toJson()).toList(),
    'sources': sources,
  };

  factory AgentMessage.fromJson(Map<String, dynamic> json) => AgentMessage(
    id: json['id'] as String? ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
    sender: json['sender'] as String? ?? 'buddy',
    text: (json['text'] ?? json['reply']) as String? ?? '',
    timestamp: json['timestamp'] != null
        ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
        : DateTime.now(),
    actions: (json['actions'] as List<dynamic>?)
            ?.map((a) => AgentAction.fromJson(a as Map<String, dynamic>))
            .toList() ??
        [],
    sources: (json['sources'] as List<dynamic>?)
            ?.map((s) => s.toString())
            .toList() ??
        [],
  );
}

/// Simple price range output for tariff calculations
class FareRange {
  final double fareMin;
  final double fareMax;

  const FareRange({required this.fareMin, required this.fareMax});
}
