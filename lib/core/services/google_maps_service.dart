import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/app_models.dart';
import 'route_service.dart';

/// Service interfacing with the serverless proxy for Google Places (New) and Routes APIs
/// with 10-minute caching, session tokens, location biasing, link resolution, and seed fallback.
/// NO Google Maps API key is stored or used in the client app.
class GoogleMapsService {
  final http.Client _client;
  final RouteService _routeService;
  final String proxyBaseUrl;
  final void Function(SearchDebugRecord)? onDebugLog;

  // In-memory 10-minute cache: key = placeId
  final Map<String, GooglePlaceDetails> _placeDetailsCache = {};

  // Current autocomplete session token
  String _sessionToken = _generateSessionToken();

  GoogleMapsService({
    http.Client? client,
    RouteService? routeService,
    String? proxyBaseUrl,
    this.onDebugLog,
  }) : _client = client ?? http.Client(),
       _routeService = routeService ?? RouteService(),
       proxyBaseUrl = proxyBaseUrl ?? ApiConfig.proxyBaseUrl;

  static String _generateSessionToken() {
    final rand = math.Random();
    return List.generate(16, (_) => rand.nextInt(16).toRadixString(16)).join();
  }

  void resetSessionToken() {
    _sessionToken = _generateSessionToken();
  }

  /// Places API (New) Autocomplete via proxy with session token, location bias, and language
  Future<List<GooglePlaceSuggestion>> autocomplete(
    String query, {
    LatLng? biasCenter,
    String languageCode = 'en',
    bool searchInCountryOnly = false,
    String? countryCode,
  }) async {
    final clean = query.trim();
    if (clean.length < 2) return [];

    try {
      final url = Uri.parse('$proxyBaseUrl/places/autocomplete');

      final body = <String, dynamic>{
        'input': clean,
        'sessionToken': _sessionToken,
        'languageCode': languageCode,
      };

      if (biasCenter != null) {
        body['locationBias'] = {
          'circle': {
            'center': {
              'latitude': biasCenter.latitude,
              'longitude': biasCenter.longitude,
            },
            'radius': 50000.0,
          },
        };
      }

      if (searchInCountryOnly) {
        body['includedRegionCodes'] = [countryCode ?? 'in'];
      }

      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final suggestions = data['suggestions'] as List<dynamic>? ?? [];
        final parsed = suggestions
            .map((s) {
              final placePrediction =
                  s['placePrediction'] as Map<String, dynamic>? ?? {};
              final placeId = placePrediction['placeId'] as String? ?? '';
              final text =
                  placePrediction['text'] as Map<String, dynamic>? ?? {};
              final main =
                  (placePrediction['structuredFormat']?['mainText']?['text']
                      as String?) ??
                  (text['text'] as String? ?? clean);
              final sec =
                  (placePrediction['structuredFormat']?['secondaryText']?['text']
                      as String?) ??
                  '';
              final types =
                  (placePrediction['types'] as List<dynamic>?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  const <String>[];
              final dist = (placePrediction['distanceMeters'] as num?)
                  ?.toDouble();

              return GooglePlaceSuggestion(
                placeId: placeId,
                mainText: main,
                secondaryText: sec,
                types: types,
                distanceMeters: dist,
              );
            })
            .where((s) => s.placeId.isNotEmpty)
            .toList();

        onDebugLog?.call(
          SearchDebugRecord(
            query: clean,
            endpoint: '/places/autocomplete',
            requestBody: body,
            httpStatus: response.statusCode,
            resultsCount: parsed.length,
            timestamp: DateTime.now(),
          ),
        );
        return parsed;
      } else {
        onDebugLog?.call(
          SearchDebugRecord(
            query: clean,
            endpoint: '/places/autocomplete',
            requestBody: body,
            httpStatus: response.statusCode,
            resultsCount: 0,
            errorBody: response.body,
            timestamp: DateTime.now(),
          ),
        );
        throw Exception('Proxy returned status ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Places API (New) Text Search via proxy for free-form queries (e.g. 'cafes in Shillong')
  Future<List<GooglePlaceDetails>> textSearch(
    String query, {
    LatLng? biasCenter,
    String languageCode = 'en',
    bool searchInCountryOnly = false,
    String? countryCode,
    int maxResultCount = 20,
  }) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];

    try {
      final url = Uri.parse('$proxyBaseUrl/places/text-search');
      final body = <String, dynamic>{
        'textQuery': clean,
        'query': clean,
        'sessionToken': _sessionToken,
        'languageCode': languageCode,
        'maxResultCount': maxResultCount,
      };

      if (biasCenter != null) {
        body['locationBias'] = {
          'circle': {
            'center': {
              'latitude': biasCenter.latitude,
              'longitude': biasCenter.longitude,
            },
            'radius': 50000.0,
          },
        };
      }

      if (searchInCountryOnly) {
        body['includedRegionCodes'] = [countryCode ?? 'in'];
      }

      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final places = data['places'] as List<dynamic>? ?? [];
        final parsed = places
            .map((p) => _parseGooglePlaceDetailsJson(p as Map<String, dynamic>))
            .toList();
        onDebugLog?.call(
          SearchDebugRecord(
            query: clean,
            endpoint: '/places/text-search',
            requestBody: body,
            httpStatus: response.statusCode,
            resultsCount: parsed.length,
            timestamp: DateTime.now(),
          ),
        );
        return parsed;
      } else {
        onDebugLog?.call(
          SearchDebugRecord(
            query: clean,
            endpoint: '/places/text-search',
            requestBody: body,
            httpStatus: response.statusCode,
            resultsCount: 0,
            errorBody: response.body,
            timestamp: DateTime.now(),
          ),
        );
        throw Exception(
          'Text search proxy returned status ${response.statusCode}',
        );
      }
    } catch (_) {
      rethrow;
    }
  }

  /// Reverse geocode coordinates via proxy /geocode endpoint
  Future<GooglePlaceDetails?> reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    try {
      final url = Uri.parse('$proxyBaseUrl/geocode');
      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'latitude': latitude,
              'longitude': longitude,
              'lat': latitude,
              'lng': longitude,
              'latlng': '$latitude,$longitude',
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>? ?? [];
        if (results.isNotEmpty) {
          final first = results.first as Map<String, dynamic>;
          final placeId =
              (first['place_id'] as String?) ?? 'geo_${latitude}_$longitude';
          final formattedAddress =
              (first['formatted_address'] as String?) ??
              'Location ($latitude, $longitude)';
          final components =
              (first['address_components'] as List<dynamic>?)
                  ?.map((c) => c as Map<String, dynamic>)
                  .toList() ??
              [];
          final types =
              (first['types'] as List<dynamic>?)
                  ?.map((t) => t.toString())
                  .toList() ??
              [];

          String name = formattedAddress.split(',').first.trim();
          if (name.isEmpty) name = 'Location ($latitude, $longitude)';

          return GooglePlaceDetails(
            placeId: placeId,
            name: name,
            formattedAddress: formattedAddress,
            latitude: latitude,
            longitude: longitude,
            fetchedAt: DateTime.now(),
            isLiveGoogle: true,
            types: types,
            addressComponents: components,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// Places API (New) Place Details via proxy with 10-minute in-memory cache
  Future<GooglePlaceDetails> getPlaceDetails(
    String placeId, {
    String? languageCode,
  }) async {
    // 1. Check in-memory 10-minute cache
    final cached = _placeDetailsCache[placeId];
    if (cached != null) {
      final age = DateTime.now().difference(cached.fetchedAt);
      if (age.inMinutes < 10) {
        return cached;
      }
    }

    // 2. Query proxy endpoint (POST /places/details)
    final url = Uri.parse('$proxyBaseUrl/places/details');
    final body = <String, dynamic>{
      'placeId': placeId,
      'sessionToken': _sessionToken,
    };
    if (languageCode != null) {
      body['languageCode'] = languageCode;
    }

    final response = await _client
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final details = _parseGooglePlaceDetailsJson(data);

      _placeDetailsCache[placeId] = details;
      resetSessionToken(); // End of autocomplete session
      return details;
    }

    throw Exception('Failed to load place details for id: $placeId (Status: ${response.statusCode})');
  }

  GooglePlaceDetails _parseGooglePlaceDetailsJson(Map<String, dynamic> data) {
    final placeId = data['id'] as String? ?? 'place_${DateTime.now().millisecondsSinceEpoch}';
    final loc = data['location'] as Map<String, dynamic>? ?? {};
    final lat = (loc['latitude'] as num?)?.toDouble() ?? 0.0;
    final lng = (loc['longitude'] as num?)?.toDouble() ?? 0.0;
    final name = (data['displayName']?['text'] as String?) ?? 'Discovered Location';

    final weekdayHours =
        (data['regularOpeningHours']?['weekdayDescriptions'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];

    final photos = data['photos'] as List<dynamic>? ?? [];
    final List<String> photoUrls = [];
    for (int i = 0; i < photos.length && i < 3; i++) {
      final photoName = photos[i]['name'] as String?;
      if (photoName != null) {
        photoUrls.add(
          'https://places.googleapis.com/v1/$photoName/media?maxHeightPx=400&maxWidthPx=400',
        );
      }
    }

    final rawTypes =
        (data['types'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        const <String>[];
    final primaryType = data['primaryType'] as String?;
    final addressComponents =
        (data['addressComponents'] as List<dynamic>?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        const <Map<String, dynamic>>[];
    final viewport = data['viewport'] as Map<String, dynamic>?;

    return GooglePlaceDetails(
      placeId: placeId,
      name: name,
      formattedAddress:
          data['formattedAddress'] as String? ?? 'India',
      rating: (data['rating'] as num?)?.toDouble(),
      userRatingCount: data['userRatingCount'] as int?,
      priceLevel: data['priceLevel'] as String?,
      phoneNumber: data['nationalPhoneNumber'] as String?,
      websiteUri: data['websiteUri'] as String?,
      editorialSummary: data['editorialSummary']?['text'] as String?,
      isOpenNow: data['currentOpeningHours']?['openNow'] as bool?,
      weekdayDescriptions: weekdayHours,
      photoUrls: photoUrls,
      latitude: lat,
      longitude: lng,
      fetchedAt: DateTime.now(),
      isLiveGoogle: true,
      attribution: 'Powered by Google Maps',
      types: rawTypes,
      primaryType: primaryType,
      addressComponents: addressComponents,
      viewport: viewport,
    );
  }

  /// Searches places inside the camera viewport or nearby radius via proxy (POST /places/nearby)
  Future<List<GooglePlaceDetails>> searchArea({
    required LatLng center,
    required double radiusMeters,
    String? category,
    List<String>? includedTypes,
  }) async {
    try {
      final url = Uri.parse('$proxyBaseUrl/places/nearby');
      final types =
          includedTypes ??
          (category != null
              ? [_mapCategoryToType(category)]
              : ['tourist_attraction']);

      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'latitude': center.latitude,
              'longitude': center.longitude,
              'radius': radiusMeters.clamp(500.0, 50000.0),
              'includedTypes': types,
              'maxResultCount': 10,
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rawPlaces = data['places'] as List<dynamic>? ?? [];
        final parsed = rawPlaces
            .map((p) {
              final loc = p['location'] as Map<String, dynamic>? ?? {};
              return GooglePlaceDetails(
                placeId: p['id'] as String? ?? '',
                name:
                    (p['displayName']?['text'] as String?) ??
                    'Discovered Location',
                formattedAddress: p['formattedAddress'] as String? ?? 'India',
                rating: (p['rating'] as num?)?.toDouble() ?? 4.0,
                latitude:
                    (loc['latitude'] as num?)?.toDouble() ?? center.latitude,
                longitude:
                    (loc['longitude'] as num?)?.toDouble() ?? center.longitude,
                fetchedAt: DateTime.now(),
                isLiveGoogle: true,
                attribution: 'Powered by Google Maps',
              );
            })
            .where((p) => p.placeId.isNotEmpty)
            .toList();

        if (parsed.isNotEmpty) return parsed;
      }
    } catch (_) {}
    return [];
  }

  /// Resolves short or standard Google Maps URLs via proxy (POST /resolve-link)
  Future<GooglePlaceDetails?> resolveLink(String url) async {
    try {
      final reqUrl = Uri.parse('$proxyBaseUrl/resolve-link');
      final response = await _client
          .post(
            reqUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'url': url.trim()}),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final placeId =
            data['placeId'] as String? ??
            'resolved_${DateTime.now().millisecondsSinceEpoch}';
        final name = data['name'] as String? ?? 'Imported Destination';
        final address = data['formattedAddress'] as String? ?? 'India';
        final lat = (data['latitude'] as num?)?.toDouble() ?? 0.0;
        final lng = (data['longitude'] as num?)?.toDouble() ?? 0.0;
        final rating = (data['rating'] as num?)?.toDouble() ?? 4.3;
        final count = data['userRatingCount'] as int? ?? 85;

        final resolved = GooglePlaceDetails(
          placeId: placeId,
          name: name,
          formattedAddress: address,
          latitude: lat,
          longitude: lng,
          rating: rating,
          userRatingCount: count,
          isOpenNow: true,
          fetchedAt: DateTime.now(),
          isLiveGoogle: data['isLiveGoogle'] == true,
          attribution: 'Imported from Google Maps',
        );

        _placeDetailsCache[placeId] = resolved;
        return resolved;
      }
    } catch (_) {}
    return null;
  }

  static String _mapCategoryToType(String cat) {
    switch (cat.toLowerCase()) {
      case 'restaurants':
        return 'restaurant';
      case 'cafes':
        return 'cafe';
      case 'hotels':
        return 'hotel';
      case 'attractions':
        return 'tourist_attraction';
      case 'taxi stands':
        return 'taxi_stand';
      case 'transport hubs':
        return 'transit_station';
      case 'hospitals':
        return 'hospital';
      case 'atms':
        return 'atm';
      default:
        return 'point_of_interest';
    }
  }

  /// Routes API: compute distance, duration, and traffic awareness
  Future<GoogleRouteOption> computeRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String mode = 'DRIVE',
  }) async {
    final routes = await _routeService.getRoutes(
      origin: LatLng(originLat, originLng),
      destination: LatLng(destLat, destLng),
      mode: mode,
    );
    return routes.first;
  }
}

final googleMapsServiceProvider = Provider<GoogleMapsService>((ref) {
  final routeService = ref.watch(routeServiceProvider);
  return GoogleMapsService(
    routeService: routeService,
    onDebugLog: (record) =>
        ref.read(searchDebugProvider.notifier).record(record),
  );
});

/// Diagnostic record capturing live request/response telemetry for the Search Debug Panel
class SearchDebugRecord {
  final String query;
  final String endpoint;
  final Map<String, dynamic> requestBody;
  final int httpStatus;
  final int resultsCount;
  final String? errorBody;
  final DateTime timestamp;

  const SearchDebugRecord({
    required this.query,
    required this.endpoint,
    required this.requestBody,
    required this.httpStatus,
    required this.resultsCount,
    this.errorBody,
    required this.timestamp,
  });

  String get likelyFix {
    if (httpStatus == 200) {
      return 'Everything working normally. Places API (New) returned $resultsCount results.';
    }
    final err = (errorBody ?? '').toLowerCase();
    if (err.contains('api_key') ||
        err.contains('missing key') ||
        httpStatus == 403) {
      return 'Missing or invalid Google Maps API key. Set GOOGLE_MAPS_SERVER_KEY on the proxy server.';
    }
    if (err.contains('not enabled') || err.contains('service_disabled')) {
      return 'Places API (New) or Geocoding API is not enabled in Google Cloud Console for this project.';
    }
    if (err.contains('billing') || err.contains('billing_not_enabled')) {
      return 'Google Cloud project requires an active billing account linked to use Places API (New).';
    }
    if (err.contains('quota') ||
        err.contains('resource_exhausted') ||
        err.contains('over_query_limit') ||
        httpStatus == 429) {
      return 'Google Maps API quota exceeded or per-IP rate limit triggered. Retry in a moment or increase Google Cloud quotas.';
    }
    if (httpStatus >= 500 ||
        err.contains('econnrefused') ||
        err.contains('failed to connect') ||
        err.contains('connection refused')) {
      return 'Proxy URL unreachable. Ensure proxy is running on port 8080 and GEMINI_PROXY_URL / GOOGLE_MAPS_PROXY_URL is set correctly.';
    }
    return 'Check network connection and proxy server logs for HTTP status $httpStatus.';
  }
}

class SearchDebugNotifier extends Notifier<SearchDebugRecord?> {
  @override
  SearchDebugRecord? build() => null;

  void record(SearchDebugRecord record) {
    state = record;
  }
}

final searchDebugProvider =
    NotifierProvider<SearchDebugNotifier, SearchDebugRecord?>(
      SearchDebugNotifier.new,
    );

/// State notifier managing the currently active city/region across the app
class ActiveCityNotifier extends Notifier<ActiveCity?> {
  static const _key = 'active_city_data';

  @override
  ActiveCity? build() {
    _loadFromPrefs();
    return null;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_key);
      if (str != null) {
        state = ActiveCity.fromJson(jsonDecode(str) as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  Future<void> setActiveCity(ActiveCity city) async {
    state = city;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(city.toJson()));
    } catch (_) {}
  }

  Future<void> clearActiveCity() async {
    state = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}

final activeCityProvider = NotifierProvider<ActiveCityNotifier, ActiveCity?>(
  ActiveCityNotifier.new,
);
