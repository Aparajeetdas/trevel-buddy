import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/google_maps_models.dart';
import '../utils/engine_math.dart';
import '../utils/route_points_decoder.dart';

class RouteCacheEntry {
  final List<GoogleRouteOption> routes;
  final DateTime timestamp;

  const RouteCacheEntry(this.routes, this.timestamp);

  bool get isExpired => DateTime.now().difference(timestamp).inMinutes >= 10;
}

/// Service providing computeRoutes via Google Routes API with traffic awareness,
/// alternative route selection, 10-minute caching, web proxy fallback, and 1.3x straight-line estimation.
class RouteService {
  final http.Client _client;
  final String proxyBaseUrl;

  // 10-minute in-memory cache
  final Map<String, RouteCacheEntry> _cache = {};

  RouteService({http.Client? client, String? proxyBaseUrl})
    : _client = client ?? http.Client(),
      proxyBaseUrl = proxyBaseUrl ?? ApiConfig.proxyBaseUrl;

  String _cacheKey(LatLng origin, LatLng dest, String mode) {
    return '${origin.latitude.toStringAsFixed(4)},${origin.longitude.toStringAsFixed(4)}->${dest.latitude.toStringAsFixed(4)},${dest.longitude.toStringAsFixed(4)}_$mode';
  }

  String _sanitizeMode(String mode) {
    final m = mode.toUpperCase();
    if (m == 'TWO_WHEELER' ||
        m == 'BIKE' ||
        m == 'MOTORCYCLE' ||
        m == 'BIKE_TAXI') {
      return 'TWO_WHEELER';
    }
    if (m == 'WALK' || m == 'WALKING') {
      return 'WALK';
    }
    if (m == 'TRANSIT' || m == 'BUS' || m == 'METRO' || m == 'TRAIN') {
      return 'TRANSIT';
    }
    return 'DRIVE';
  }

  Future<List<GoogleRouteOption>> getRoutes({
    required LatLng origin,
    required LatLng destination,
    String mode = 'DRIVE',
    DateTime? departTime,
  }) async {
    final key = _cacheKey(origin, destination, mode);
    final cached = _cache[key];
    if (cached != null && !cached.isExpired) {
      return cached.routes;
    }

    final sanitizedMode = _sanitizeMode(mode);

    // Route computation via serverless proxy (POST /route)
    try {
      final routes = await _fetchViaProxy(
        origin,
        destination,
        sanitizedMode,
        departTime,
      );
      if (routes.isNotEmpty) {
        _cache[key] = RouteCacheEntry(routes, DateTime.now());
        return routes;
      }
    } catch (_) {
      // Graceful fallback to 1.3x straight line estimate
    }

    // Straight-line distance * 1.30 GPS fallback labeled 'Estimated route'
    final fallbackRoute = _computeStraightLineFallback(
      origin,
      destination,
      sanitizedMode,
    );
    final fallbackList = [fallbackRoute];
    _cache[key] = RouteCacheEntry(fallbackList, DateTime.now());
    return fallbackList;
  }

  Future<List<GoogleRouteOption>> _fetchViaProxy(
    LatLng origin,
    LatLng destination,
    String mode,
    DateTime? departTime,
  ) async {
    final url = Uri.parse('$proxyBaseUrl/route');
    final response = await _client
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'origin': {
              'latitude': origin.latitude,
              'longitude': origin.longitude,
            },
            'destination': {
              'latitude': destination.latitude,
              'longitude': destination.longitude,
            },
            'travelMode': mode,
            'departureTime': departTime?.toUtc().toIso8601String(),
          }),
        )
        .timeout(const Duration(seconds: 4));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return parseRoutesJson(json, mode: mode);
    }

    throw Exception('Proxy /route returned ${response.statusCode}');
  }

  /// Parses raw Google computeRoutes JSON into a list of [GoogleRouteOption]
  static List<GoogleRouteOption> parseRoutesJson(
    Map<String, dynamic> json, {
    String mode = 'DRIVE',
  }) {
    final rawRoutes = json['routes'] as List<dynamic>? ?? [];
    final List<GoogleRouteOption> results = [];

    for (int i = 0; i < rawRoutes.length; i++) {
      final r = rawRoutes[i] as Map<String, dynamic>;
      final distanceMeters = (r['distanceMeters'] as num?)?.toDouble() ?? 0.0;
      final durationStr = r['duration'] as String? ?? '0s';
      final durationSeconds =
          double.tryParse(durationStr.replaceAll('s', '')) ?? 0.0;

      final staticDurationStr = r['staticDuration'] as String?;
      final staticDurationSeconds = staticDurationStr != null
          ? double.tryParse(staticDurationStr.replaceAll('s', ''))
          : null;

      final encoded = r['polyline']?['encodedPolyline'] as String? ?? '';
      final points = RoutePointsDecoder.decode(encoded);

      // Parse Steps
      final List<RouteStepItem> steps = [];
      final legs = r['legs'] as List<dynamic>? ?? [];
      for (final leg in legs) {
        final rawSteps = leg['steps'] as List<dynamic>? ?? [];
        for (final s in rawSteps) {
          final instruction =
              s['navigationInstruction']?['instructions'] as String? ??
              'Proceed on route';
          final sDist = (s['distanceMeters'] as num?)?.toDouble() ?? 0.0;
          final sDurStr = s['staticDuration'] as String? ?? '0s';
          final sDur = double.tryParse(sDurStr.replaceAll('s', '')) ?? 0.0;
          final sEncoded = s['polyline']?['encodedPolyline'] as String? ?? '';
          final sPoints = RoutePointsDecoder.decode(sEncoded);

          steps.add(
            RouteStepItem(
              instruction: instruction,
              distanceMeters: sDist,
              durationSeconds: sDur,
              points: sPoints,
            ),
          );
        }
      }

      // Parse Travel Advisory Traffic speed intervals
      final List<RouteTrafficSegment> trafficSegments = [];
      final intervals =
          r['travelAdvisory']?['speedReadingIntervals'] as List<dynamic>? ?? [];
      for (final interval in intervals) {
        final startIdx =
            (interval['startPolylinePointIndex'] as num?)?.toInt() ?? 0;
        final endIdx =
            (interval['endPolylinePointIndex'] as num?)?.toInt() ??
            points.length - 1;
        final speedType = interval['speed'] as String? ?? 'NORMAL';

        if (startIdx >= 0 && endIdx < points.length && startIdx < endIdx) {
          final segPoints = points.sublist(startIdx, endIdx + 1);
          trafficSegments.add(
            RouteTrafficSegment(
              points: segPoints,
              speed: RouteTrafficSpeed.fromString(speedType),
            ),
          );
        }
      }

      results.add(
        GoogleRouteOption(
          routeId: 'route_$i',
          isMain: i == 0,
          distanceMeters: distanceMeters,
          durationSeconds: durationSeconds,
          staticDurationSeconds: staticDurationSeconds,
          encodedPoints: encoded,
          points: points,
          steps: steps,
          trafficSegments: trafficSegments,
          isEstimatedRoute: false,
          mode: mode,
        ),
      );
    }

    return results;
  }

  /// Calculates straight-line distance * 1.30 fallback labeled 'Estimated route'
  GoogleRouteOption _computeStraightLineFallback(
    LatLng origin,
    LatLng destination,
    String mode,
  ) {
    final straightKm = EngineMath.haversineDistanceKm(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );
    final distanceKm = (straightKm * 1.30).clamp(0.5, 600.0);
    final distanceMeters = distanceKm * 1000.0;

    // Speeds in km/h: DRIVE: 28, TWO_WHEELER: 25, WALK: 4.5, TRANSIT: 22
    double speedKmh = 28.0;
    if (mode == 'TWO_WHEELER') speedKmh = 25.0;
    if (mode == 'WALK') speedKmh = 4.5;
    if (mode == 'TRANSIT') speedKmh = 22.0;

    final durationHours = distanceKm / speedKmh;
    final durationSeconds = durationHours * 3600.0;

    final points = [
      origin,
      // Intermediate arc point to give curve feeling
      LatLng(
        (origin.latitude + destination.latitude) / 2.0 + 0.002,
        (origin.longitude + destination.longitude) / 2.0 + 0.002,
      ),
      destination,
    ];

    final steps = [
      RouteStepItem(
        instruction: 'Head towards destination via main road',
        distanceMeters: distanceMeters * 0.4,
        durationSeconds: durationSeconds * 0.4,
        points: [origin, points[1]],
      ),
      RouteStepItem(
        instruction: 'Arrive at destination',
        distanceMeters: distanceMeters * 0.6,
        durationSeconds: durationSeconds * 0.6,
        points: [points[1], destination],
      ),
    ];

    return GoogleRouteOption(
      routeId: 'fallback_route',
      isMain: true,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      encodedPoints: '',
      points: points,
      steps: steps,
      trafficSegments: const [],
      isEstimatedRoute: true,
      mode: mode,
    );
  }
}

final routeServiceProvider = Provider<RouteService>((ref) {
  return RouteService();
});
