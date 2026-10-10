import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/community_repository.dart';
import '../data/tariff_repository.dart';
import '../models/ai_price_models.dart';
import '../models/price_engine_models.dart';
import '../models/roadmap_models.dart';
import '../utils/pricing_engine.dart';
import 'airport_prepaid_matcher.dart';
import 'google_maps_service.dart';

final roadmapServiceProvider = Provider<RoadmapService>((ref) {
  return RoadmapService(
    tariffRepo: ref.read(govTariffRepositoryProvider),
    communityRepo: ref.read(communityRepositoryProvider),
    googleMapsService: ref.read(googleMapsServiceProvider),
  );
});

/// Intelligent multi-modal Journey Roadmap Engine
class RoadmapService {
  final GovTariffRepository tariffRepo;
  final CommunityRepository communityRepo;
  final GoogleMapsService googleMapsService;

  List<Roadmap>? _curatedCache;

  RoadmapService({
    required this.tariffRepo,
    required this.communityRepo,
    required this.googleMapsService,
  });

  /// Loads curated hand-written roadmaps from assets
  Future<List<Roadmap>> getCuratedRoadmaps() async {
    if (_curatedCache != null) return _curatedCache!;
    try {
      final jsonStr = await rootBundle.loadString(
        'assets/data/curated_roadmaps.json',
      );
      final list = jsonDecode(jsonStr) as List<dynamic>;
      _curatedCache = list
          .map((e) => Roadmap.fromJson(e as Map<String, dynamic>))
          .toList();
      return _curatedCache!;
    } catch (_) {
      return [];
    }
  }

  /// Primary builder: produces a complete multi-option Journey Roadmap
  Future<Roadmap> planRoadmap({
    required RoadmapLocation origin,
    required RoadmapLocation destination,
    DateTime? departTime,
    int travelers = 1,
    String preference = 'Fastest', // 'Cheapest', 'Fastest', 'Comfortable'
  }) async {
    final effectiveTime = departTime ?? DateTime.now();
    final tariffs = await tariffRepo.getTariffs();
    final traps = await communityRepo.getTouristTraps();
    final curatedList = await getCuratedRoadmaps();

    // 1. Check curated roadmaps first
    final curatedMatch = _findCuratedMatch(curatedList, origin, destination);

    final List<RoadmapOption> options = [];

    if (curatedMatch != null) {
      for (final opt in curatedMatch.options) {
        // Attach nearby traps & enrich step pricing
        final enrichedSteps = _enrichSteps(
          opt.steps,
          traps,
          tariffs,
          effectiveTime,
        );
        options.add(
          RoadmapOption(
            id: opt.id,
            label: opt.label == 'Local guide' ? 'Local guide' : opt.label,
            totalMin: opt.totalMin,
            totalFairMin: _sumFairMin(enrichedSteps),
            totalFairMax: _sumFairMax(enrichedSteps),
            riskLevel: _computeOptionRisk(enrichedSteps),
            steps: enrichedSteps,
            isCurated: true,
            summaryOneLiner: opt.summaryOneLiner,
          ),
        );
      }
    }

    // 2. Generate multi-modal options via Google Routes API or fallback
    final generatedOptions = await _generateOptions(
      origin: origin,
      destination: destination,
      departTime: effectiveTime,
      tariffs: tariffs,
      traps: traps,
    );

    // Merge options avoiding duplicate labels
    for (final gen in generatedOptions) {
      if (!options.any(
        (o) => o.label.toLowerCase() == gen.label.toLowerCase(),
      )) {
        options.add(gen);
      }
    }

    // Sort options so curated or selected preference is first
    options.sort((a, b) {
      if (a.isCurated) return -1;
      if (b.isCurated) return 1;
      if (a.label.toLowerCase() == preference.toLowerCase()) return -1;
      return 0;
    });

    final checklist = _generateChecklist(
      origin: origin,
      destination: destination,
      departTime: effectiveTime,
      options: options,
    );

    return Roadmap(
      id: 'roadmap_${DateTime.now().millisecondsSinceEpoch}',
      origin: origin,
      destination: destination,
      departTime: effectiveTime,
      travelers: travelers,
      options: options,
      checklist: checklist,
      aiSummary: options.isNotEmpty
          ? options.first.summaryOneLiner
          : 'Journey roadmap ready.',
    );
  }

  Roadmap? _findCuratedMatch(
    List<Roadmap> curatedList,
    RoadmapLocation origin,
    RoadmapLocation destination,
  ) {
    for (final c in curatedList) {
      final originDist = _haversineMeters(
        origin.lat,
        origin.lng,
        c.origin.lat,
        c.origin.lng,
      );
      final destDist = _haversineMeters(
        destination.lat,
        destination.lng,
        c.destination.lat,
        c.destination.lng,
      );

      final originNameMatch = _nameMatches(origin.name, c.origin.name);
      final destNameMatch = _nameMatches(destination.name, c.destination.name);

      if ((originDist < 2500 || originNameMatch) &&
          (destDist < 2500 || destNameMatch)) {
        return c;
      }
    }
    return null;
  }

  bool _nameMatches(String a, String b) {
    final cleanA = a.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final cleanB = b.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return cleanA.contains(cleanB) || cleanB.contains(cleanA);
  }

  Future<List<RoadmapOption>> _generateOptions({
    required RoadmapLocation origin,
    required RoadmapLocation destination,
    required DateTime departTime,
    required List<GovTariff> tariffs,
    required List<TouristTrap> traps,
  }) async {
    // Attempt Route computation
    final route = await googleMapsService.computeRoute(
      originLat: origin.lat,
      originLng: origin.lng,
      destLat: destination.lat,
      destLng: destination.lng,
    );

    final distanceM =
        (route.distanceKm > 0
            ? route.distanceKm
            : _straightLineKm(origin, destination) * 1.3) *
        1000.0;
    final durationMin = route.durationMinutes > 0
        ? route.durationMinutes
        : (distanceM / 1000.0 * 2.8); // ~22 km/h city avg

    // Find city tariff
    final cityTariffAuto = tariffs.firstWhere(
      (t) => t.serviceType == ServiceType.auto,
      orElse: () => _defaultAutoTariff(),
    );
    final cityTariffCab = tariffs.firstWhere(
      (t) => t.serviceType == ServiceType.taxi,
      orElse: () => _defaultCabTariff(),
    );

    // Option 1: Cheapest (Auto / Transit hybrid)
    final cheapestSteps = _buildCheapestSteps(
      origin: origin,
      destination: destination,
      distanceM: distanceM,
      durationMin: durationMin,
      tariff: cityTariffAuto,
      traps: traps,
      departTime: departTime,
    );

    // Option 2: Fastest (Direct Auto or Cab)
    final fastestSteps = _buildFastestSteps(
      origin: origin,
      destination: destination,
      distanceM: distanceM,
      durationMin: durationMin * 0.85,
      tariff: cityTariffAuto,
      traps: traps,
      departTime: departTime,
    );

    // Option 3: Comfortable (AC Cab / Sedan)
    final comfortableSteps = _buildComfortableSteps(
      origin: origin,
      destination: destination,
      distanceM: distanceM,
      durationMin: durationMin * 0.9,
      tariff: cityTariffCab,
      traps: traps,
      departTime: departTime,
    );

    // If trip originates at LGBI Airport, step 1 uses the fixed fare with the counter tip
    final isLgbiPickup = AirportPrepaidMatcher.isAirportPickup(
          name: origin.name,
          lat: origin.lat,
          lng: origin.lng,
        ) ||
        AirportPrepaidMatcher.isAirportPickup(
          address: origin.formattedAddress ?? '',
          lat: origin.lat,
          lng: origin.lng,
        );

    if (isLgbiPickup) {
      final dataset = await tariffRepo.getAirportDataset();
      final match = AirportPrepaidMatcher.matchDestination(
        destination: destination.name,
        tariffs: dataset.routes,
      );

      final FixedRouteTariff? matchedRoute =
          match.status == AirportMatchStatus.confident ? match.matchedTariff : null;
      final distKm = matchedRoute != null ? matchedRoute.km : (distanceM / 1000.0);
      final fare = matchedRoute != null
          ? matchedRoute.fare
          : PricingEngine.calculateAirportDerivedEstimate(distKm);
      final priceSource = matchedRoute != null
          ? '[Official tariff]'
          : '[Estimated from airport prepaid rates]';
      final confidence = (matchedRoute != null &&
              !matchedRoute.flags.contains('check_against_printed_list'))
          ? ConfidenceLevel.high
          : (matchedRoute != null ? ConfidenceLevel.medium : ConfidenceLevel.low);

      final warnings = <String>[];
      if (matchedRoute != null &&
          matchedRoute.flags.contains('check_against_printed_list')) {
        warnings.add('Confirm fare at the counter against current printed list');
      }

      RoadmapStep airportStep(double stepDur, String mode) => RoadmapStep(
            index: 1,
            mode: mode,
            title: 'Pre-paid Taxi to ${destination.name}',
            instruction:
                'Book an official pre-paid taxi at the LGBI Airport counter to ${destination.name}.',
            fromName: origin.name,
            toName: destination.name,
            startLat: origin.lat,
            startLng: origin.lng,
            endLat: destination.lat,
            endLng: destination.lng,
            distanceM: distKm * 1000.0,
            durationMin: stepDur,
            fairMin: fare,
            fairMax: fare,
            dontPayMoreThan: (fare * 1.05).roundToDouble(),
            priceSource: priceSource,
            confidence: confidence,
            boardingPoint:
                'LGBI Airport Pre-paid Taxi Counter (inside arrival hall)',
            warnings: warnings,
            tips: [
              'The pre-paid taxi counter has fixed fares. Compare before you agree with a driver. Ask the counter whether tolls are included.',
            ],
            priceCheckInput: PriceCheckInput(
              serviceType: ServiceType.taxi,
              pickupName: origin.name,
              dropName: destination.name,
              distanceKm: distKm,
              durationMinutes: stepDur,
              quotedPrice: fare,
              timeOfDay: departTime,
            ),
          );

      if (cheapestSteps.isNotEmpty) cheapestSteps[0] = airportStep(durationMin, 'cab');
      if (fastestSteps.isNotEmpty) fastestSteps[0] = airportStep(durationMin * 0.85, 'cab');
      if (comfortableSteps.isNotEmpty) comfortableSteps[0] = airportStep(durationMin * 0.9, 'cab');
    }

    final isEstimated = route.isEstimatedRoute;

    return [
      RoadmapOption(
        id: 'opt_gen_fastest',
        label: 'Fastest',
        totalMin: fastestSteps.fold(0.0, (acc, s) => acc + s.durationMin),
        totalFairMin: _sumFairMin(fastestSteps),
        totalFairMax: _sumFairMax(fastestSteps),
        riskLevel: _computeOptionRisk(fastestSteps),
        steps: fastestSteps,
        isEstimatedRoute: isEstimated,
        summaryOneLiner: isEstimated
            ? 'Estimated route • Direct ride with estimated fare range.'
            : 'Direct point-to-point ride with verified fare range.',
      ),
      RoadmapOption(
        id: 'opt_gen_cheapest',
        label: 'Cheapest',
        totalMin: cheapestSteps.fold(0.0, (acc, s) => acc + s.durationMin),
        totalFairMin: _sumFairMin(cheapestSteps),
        totalFairMax: _sumFairMax(cheapestSteps),
        riskLevel: _computeOptionRisk(cheapestSteps),
        steps: cheapestSteps,
        isEstimatedRoute: isEstimated,
        summaryOneLiner: isEstimated
            ? 'Estimated route • Cost-optimized combination.'
            : 'Cost-optimized combination using short walks and auto meter.',
      ),
      RoadmapOption(
        id: 'opt_gen_comfortable',
        label: 'Comfortable',
        totalMin: comfortableSteps.fold(0.0, (acc, s) => acc + s.durationMin),
        totalFairMin: _sumFairMin(comfortableSteps),
        totalFairMax: _sumFairMax(comfortableSteps),
        riskLevel: _computeOptionRisk(comfortableSteps),
        steps: comfortableSteps,
        isEstimatedRoute: isEstimated,
        summaryOneLiner: isEstimated
            ? 'Estimated route • AC Cab with prepaid pricing guidance.'
            : 'AC Cab ride with prepaid pricing guidance.',
      ),
    ];
  }

  List<RoadmapStep> _buildFastestSteps({
    required RoadmapLocation origin,
    required RoadmapLocation destination,
    required double distanceM,
    required double durationMin,
    required GovTariff tariff,
    required List<TouristTrap> traps,
    required DateTime departTime,
  }) {
    final distKm = distanceM / 1000.0;
    final calc = PricingEngine.calculateFare(
      tariff: tariff,
      distanceKm: distKm,
      durationMinutes: durationMin,
      timeOfDay: departTime,
    );

    final nearbyTraps = _findTrapsNear(
      origin.lat,
      origin.lng,
      traps,
      ServiceType.auto,
    );
    final warnings = <String>[];
    if (departTime.hour >= 23 || departTime.hour < 5) {
      warnings.add(
        'Night travel: 25% official surcharge applies between 11 PM and 5 AM',
      );
    }
    if (nearbyTraps.isNotEmpty) {
      warnings.add(
        'Active touting reported near pickup point (${nearbyTraps.first.type})',
      );
    }

    return [
      RoadmapStep(
        index: 1,
        mode: 'auto',
        title: 'Direct Auto-rickshaw to ${destination.name}',
        instruction:
            'Hire an auto directly from ${origin.name} to ${destination.name}.',
        fromName: origin.name,
        toName: destination.name,
        startLat: origin.lat,
        startLng: origin.lng,
        endLat: destination.lat,
        endLng: destination.lng,
        distanceM: distanceM,
        durationMin: durationMin,
        fairMin: calc.fareMin,
        fairMax: calc.fareMax,
        dontPayMoreThan: calc.fareMax * 1.25,
        priceSource: '[Official tariff]',
        confidence: ConfidenceLevel.high,
        boardingPoint:
            'Main street auto stand or prepaid booth outside ${origin.name}',
        warnings: warnings,
        tips: [
          'Demand digital meter or agree on ₹${calc.fareMax.round()} before boarding.',
        ],
        trapIds: nearbyTraps.map((t) => t.id).toList(),
        traps: nearbyTraps,
        priceCheckInput: PriceCheckInput(
          serviceType: ServiceType.auto,
          pickupName: origin.name,
          dropName: destination.name,
          distanceKm: distKm,
          durationMinutes: durationMin,
          quotedPrice: calc.fareMax,
          timeOfDay: departTime,
        ),
      ),
    ];
  }

  List<RoadmapStep> _buildCheapestSteps({
    required RoadmapLocation origin,
    required RoadmapLocation destination,
    required double distanceM,
    required double durationMin,
    required GovTariff tariff,
    required List<TouristTrap> traps,
    required DateTime departTime,
  }) {
    if (distanceM < 1200) {
      // Walkable
      return [
        RoadmapStep(
          index: 1,
          mode: 'walk',
          title: 'Walk to ${destination.name}',
          instruction:
              'Walk along the pedestrian sidewalk from ${origin.name} to ${destination.name}.',
          fromName: origin.name,
          toName: destination.name,
          startLat: origin.lat,
          startLng: origin.lng,
          endLat: destination.lat,
          endLng: destination.lng,
          distanceM: distanceM,
          durationMin: distanceM / 75.0, // ~4.5 km/h
          fairMin: 0.0,
          fairMax: 0.0,
          dontPayMoreThan: 0.0,
          priceSource: '[Estimate]',
          boardingPoint: 'Pedestrian sidewalk',
          tips: ['Easy walk; follow pedestrian footpath.'],
        ),
      ];
    }

    final walkDist = 250.0;
    final rideDist = distanceM - walkDist;
    final distKm = rideDist / 1000.0;
    final calc = PricingEngine.calculateFare(
      tariff: tariff,
      distanceKm: distKm,
      durationMinutes: durationMin,
      timeOfDay: departTime,
    );

    final nearbyTraps = _findTrapsNear(
      origin.lat,
      origin.lng,
      traps,
      ServiceType.auto,
    );

    return [
      RoadmapStep(
        index: 1,
        mode: 'walk',
        title: 'Walk to Transit / Stand',
        instruction:
            'Walk 200m away from immediate gate touts to the main road.',
        fromName: origin.name,
        toName: 'Main Road Junction',
        startLat: origin.lat,
        startLng: origin.lng,
        endLat: origin.lat + 0.0015,
        endLng: origin.lng + 0.0015,
        distanceM: walkDist,
        durationMin: 3.5,
        fairMin: 0.0,
        fairMax: 0.0,
        dontPayMoreThan: 0.0,
        priceSource: '[Estimate]',
        boardingPoint: 'Main road crossing',
        tips: [
          'Walking 100m away from the station gate reduces quotes by 40%.',
        ],
      ),
      RoadmapStep(
        index: 2,
        mode: 'auto',
        title: 'Metered Auto to ${destination.name}',
        instruction:
            'Board a passing auto from the main road to ${destination.name}.',
        fromName: 'Main Road Junction',
        toName: destination.name,
        startLat: origin.lat + 0.0015,
        startLng: origin.lng + 0.0015,
        endLat: destination.lat,
        endLng: destination.lng,
        distanceM: rideDist,
        durationMin: durationMin,
        fairMin: calc.fareMin * 0.9,
        fairMax: calc.fareMax,
        dontPayMoreThan: calc.fareMax * 1.2,
        priceSource: '[Official tariff]',
        confidence: ConfidenceLevel.high,
        boardingPoint: 'Main road auto pickup point',
        warnings: nearbyTraps.isNotEmpty
            ? ['High touting density near origin']
            : [],
        tips: ['Confirm ₹${calc.fareMax.round()} or insist on digital meter.'],
        trapIds: nearbyTraps.map((t) => t.id).toList(),
        traps: nearbyTraps,
      ),
    ];
  }

  List<RoadmapStep> _buildComfortableSteps({
    required RoadmapLocation origin,
    required RoadmapLocation destination,
    required double distanceM,
    required double durationMin,
    required GovTariff tariff,
    required List<TouristTrap> traps,
    required DateTime departTime,
  }) {
    final distKm = distanceM / 1000.0;
    final calc = PricingEngine.calculateFare(
      tariff: tariff,
      distanceKm: distKm,
      durationMinutes: durationMin,
      timeOfDay: departTime,
    );

    final nearbyTraps = _findTrapsNear(
      origin.lat,
      origin.lng,
      traps,
      ServiceType.taxi,
    );

    return [
      RoadmapStep(
        index: 1,
        mode: 'cab',
        title: 'AC Cab / App Taxi to ${destination.name}',
        instruction:
            'Book an app cab or take a prepaid sedan cab to ${destination.name}.',
        fromName: origin.name,
        toName: destination.name,
        startLat: origin.lat,
        startLng: origin.lng,
        endLat: destination.lat,
        endLng: destination.lng,
        distanceM: distanceM,
        durationMin: durationMin,
        fairMin: calc.fareMin,
        fairMax: calc.fareMax,
        dontPayMoreThan: calc.fareMax * 1.3,
        priceSource: '[Official tariff]',
        confidence: ConfidenceLevel.high,
        boardingPoint: 'Designated app cab pickup zone or prepaid counter',
        warnings: nearbyTraps.isNotEmpty
            ? ['Decline private drivers soliciting inside arrivals']
            : [],
        tips: ['Confirm vehicle plate number in app before boarding.'],
        trapIds: nearbyTraps.map((t) => t.id).toList(),
        traps: nearbyTraps,
      ),
    ];
  }

  List<RoadmapStep> _enrichSteps(
    List<RoadmapStep> steps,
    List<TouristTrap> traps,
    List<GovTariff> tariffs,
    DateTime departTime,
  ) {
    return steps.map((s) {
      final nearby = _findTrapsNear(
        s.startLat,
        s.startLng,
        traps,
        ServiceType.fromString(s.mode),
      );
      return RoadmapStep(
        index: s.index,
        mode: s.mode,
        title: s.title,
        instruction: s.instruction,
        fromName: s.fromName,
        toName: s.toName,
        startLat: s.startLat,
        startLng: s.startLng,
        endLat: s.endLat,
        endLng: s.endLng,
        distanceM: s.distanceM,
        durationMin: s.durationMin,
        polyline: s.polyline,
        fairMin: s.fairMin,
        fairMax: s.fairMax,
        dontPayMoreThan: s.dontPayMoreThan,
        priceSource: s.priceSource,
        confidence: s.confidence,
        boardingPoint: s.boardingPoint,
        warnings: [
          ...s.warnings,
          if (nearby.isNotEmpty)
            'Warning: Trap reported nearby (${nearby.first.type})',
        ],
        tips: s.tips,
        trapIds: nearby.map((t) => t.id).toList(),
        traps: nearby,
      );
    }).toList();
  }

  List<TouristTrap> _findTrapsNear(
    double lat,
    double lng,
    List<TouristTrap> traps,
    ServiceType serviceType,
  ) {
    return traps.where((t) {
      final d = _haversineMeters(lat, lng, t.latitude, t.longitude);
      return d <= 300.0;
    }).toList();
  }

  double _sumFairMin(List<RoadmapStep> steps) =>
      steps.fold(0.0, (acc, s) => acc + s.fairMin);
  double _sumFairMax(List<RoadmapStep> steps) =>
      steps.fold(0.0, (acc, s) => acc + s.fairMax);

  PriceVerdictLevel _computeOptionRisk(List<RoadmapStep> steps) {
    final totalTraps = steps.fold(0, (acc, s) => acc + s.traps.length);
    if (totalTraps >= 2) return PriceVerdictLevel.highRisk;
    if (totalTraps == 1) return PriceVerdictLevel.suspicious;
    return PriceVerdictLevel.fair;
  }

  List<ChecklistItem> _generateChecklist({
    required RoadmapLocation origin,
    required RoadmapLocation destination,
    required DateTime departTime,
    required List<RoadmapOption> options,
  }) {
    final items = <ChecklistItem>[
      const ChecklistItem(
        id: 'chk_cash_upi',
        title: 'Carry ₹200 Cash & UPI',
        subtitle: 'Auto drivers and transit booths frequently lack change.',
        category: 'essential',
      ),
      const ChecklistItem(
        id: 'chk_charge',
        title: 'Ensure Phone Battery > 40%',
        subtitle: 'Needed for GPS navigation and digital payment.',
        category: 'essential',
      ),
      const ChecklistItem(
        id: 'chk_emergency',
        title: 'Emergency Contact & 112',
        subtitle: 'Tourist Police national assistance is 112.',
        category: 'essential',
      ),
    ];

    if (departTime.hour >= 21 || departTime.hour < 5) {
      items.add(
        const ChecklistItem(
          id: 'chk_night',
          title: 'Prebook Arrival Stay',
          subtitle: 'Night arrivals face higher hotel commission touting.',
          category: 'conditional',
        ),
      );
    }

    final totalDistKm = options.isNotEmpty
        ? options.first.steps.fold(0.0, (acc, s) => acc + s.distanceM) / 1000.0
        : 0.0;
    if (totalDistKm > 10.0) {
      items.add(
        const ChecklistItem(
          id: 'chk_offline_map',
          title: 'Offline Map Area Ready',
          subtitle: 'Download the route area for low-connectivity stretches.',
          category: 'conditional',
        ),
      );
    }

    return items;
  }

  double _straightLineKm(RoadmapLocation a, RoadmapLocation b) {
    return _haversineMeters(a.lat, a.lng, b.lat, b.lng) / 1000.0;
  }

  double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  GovTariff _defaultAutoTariff() => GovTariff(
    id: 'default_auto',
    city: 'Jaipur',
    serviceType: ServiceType.auto,
    vehicleType: 'Auto Rickshaw',
    baseFare: 30.0,
    perKm: 12.0,
    minFare: 30.0,
    nightSurchargePercent: 25.0,
    effectiveDate: DateTime.now(),
    source: 'State Transport Authority',
    sourceUrl: '',
    verified: false,
  );

  GovTariff _defaultCabTariff() => GovTariff(
    id: 'default_cab',
    city: 'Jaipur',
    serviceType: ServiceType.taxi,
    vehicleType: 'Sedan Cab',
    baseFare: 50.0,
    perKm: 18.0,
    minFare: 100.0,
    nightSurchargePercent: 25.0,
    effectiveDate: DateTime.now(),
    source: 'State Transport Authority',
    sourceUrl: '',
    verified: false,
  );
}
