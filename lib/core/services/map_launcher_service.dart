import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/roadmap_models.dart';

enum PreferredMapApp {
  googleMaps('Google Maps'),
  waze('Waze'),
  appleMaps('Apple Maps'),
  askEachTime('Ask each time');

  final String displayName;
  const PreferredMapApp(this.displayName);

  static PreferredMapApp fromString(String? val) {
    switch (val) {
      case 'waze':
        return PreferredMapApp.waze;
      case 'appleMaps':
        return PreferredMapApp.appleMaps;
      case 'askEachTime':
        return PreferredMapApp.askEachTime;
      case 'googleMaps':
      default:
        return PreferredMapApp.googleMaps;
    }
  }
}

class MapLauncherService {
  static const String _prefKey = 'preferred_map_app';
  PreferredMapApp _cachedApp = PreferredMapApp.googleMaps;

  MapLauncherService() {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getString(_prefKey);
      _cachedApp = PreferredMapApp.fromString(val);
    } catch (_) {}
  }

  Future<PreferredMapApp> getPreferredApp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getString(_prefKey);
      _cachedApp = PreferredMapApp.fromString(val);
    } catch (_) {}
    return _cachedApp;
  }

  Future<void> setPreferredApp(PreferredMapApp app) async {
    _cachedApp = app;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, app.name);
    } catch (_) {}
  }

  // --- URL Builders (Pure & Unit-Testable) ---

  /// Builds Google Maps place search URL
  /// `https://www.google.com/maps/search/?api=1&query=<name or lat,lng>&query_place_id=<placeId>`
  static String buildGoogleMapsPlaceUrl({
    String? placeId,
    String? name,
    double? lat,
    double? lng,
  }) {
    String queryParam = '';
    if (name != null && name.trim().isNotEmpty) {
      queryParam = name.trim();
    } else if (lat != null && lng != null) {
      queryParam = '$lat,$lng';
    } else {
      queryParam = 'Location';
    }

    final queryEncoded = Uri.encodeComponent(queryParam);
    var url = 'https://www.google.com/maps/search/?api=1&query=$queryEncoded';
    if (placeId != null && placeId.isNotEmpty) {
      url += '&query_place_id=${Uri.encodeComponent(placeId)}';
    }
    return url;
  }

  /// Builds Google Maps directions URL from structured objects
  /// `https://www.google.com/maps/dir/?api=1&origin=<origin>&origin_place_id=<id>&destination=<dest>&destination_place_id=<id>&travelmode=<mode>`
  static String buildGoogleMapsDirectionsUrlFromObjects({
    RoadmapLocation? origin,
    required RoadmapLocation destination,
    String mode = 'driving',
    List<String> waypoints = const [],
  }) {
    final validMode = _normalizeTravelMode(mode);
    final buffer = StringBuffer('https://www.google.com/maps/dir/?api=1');

    // Origin: For "My location" or null origin, omit origin
    if (origin != null && !origin.isMyLocation) {
      final originVal = origin.name.trim().isNotEmpty
          ? origin.name.trim()
          : '${origin.lat},${origin.lng}';
      buffer.write('&origin=${Uri.encodeComponent(originVal)}');
      if (origin.placeId != null && origin.placeId!.isNotEmpty) {
        buffer.write('&origin_place_id=${Uri.encodeComponent(origin.placeId!)}');
      }
    }

    // Destination
    final destVal = destination.name.trim().isNotEmpty
        ? destination.name.trim()
        : '${destination.lat},${destination.lng}';
    buffer.write('&destination=${Uri.encodeComponent(destVal)}');
    if (destination.placeId != null && destination.placeId!.isNotEmpty) {
      buffer.write('&destination_place_id=${Uri.encodeComponent(destination.placeId!)}');
    }

    // Travelmode
    buffer.write('&travelmode=${Uri.encodeComponent(validMode)}');

    // Waypoints (max 9 joined with |)
    if (waypoints.isNotEmpty) {
      final joined = waypoints.take(9).join('|');
      buffer.write('&waypoints=${Uri.encodeComponent(joined)}');
    }

    return buffer.toString();
  }

  /// Builds Google Maps directions URL
  /// https://www.google.com/maps/dir/?api=1&origin=...&destination=...&travelmode=driving|walking|bicycling|transit|two-wheeler&waypoints=a|b
  static String buildGoogleMapsDirectionsUrl({
    required String origin,
    required String destination,
    String mode = 'driving',
    List<String> waypoints = const [],
  }) {
    final validMode = _normalizeTravelMode(mode);
    final originEncoded = Uri.encodeComponent(origin);
    final destEncoded = Uri.encodeComponent(destination);
    final modeEncoded = Uri.encodeComponent(validMode);

    var url =
        'https://www.google.com/maps/dir/?api=1&origin=$originEncoded&destination=$destEncoded&travelmode=$modeEncoded';
    if (waypoints.isNotEmpty) {
      final waypointsJoined = waypoints.join('|');
      url += '&waypoints=${Uri.encodeComponent(waypointsJoined)}';
    }
    return url;
  }

  /// Builds Google Maps search query URL
  static String buildGoogleMapsSearchUrl(
    String query, {
    double? nearLat,
    double? nearLng,
  }) {
    final queryEncoded = Uri.encodeComponent(query.trim());
    if (nearLat != null && nearLng != null) {
      return 'https://www.google.com/maps/search/?api=1&query=$queryEncoded&center=$nearLat%2C$nearLng';
    }
    return 'https://www.google.com/maps/search/?api=1&query=$queryEncoded';
  }

  /// Builds Waze navigation URL
  /// `https://waze.com/ul?ll=<lat>,<lng>&navigate=yes`
  static String buildWazeUrl(double lat, double lng) {
    return 'https://waze.com/ul?ll=$lat,$lng&navigate=yes';
  }

  /// Builds Apple Maps destination URL
  /// `https://maps.apple.com/?daddr=<lat>,<lng>&q=<name>`
  static String buildAppleMapsUrl(double lat, double lng, {String? name}) {
    if (name != null && name.isNotEmpty) {
      return 'https://maps.apple.com/?daddr=$lat,$lng&q=${Uri.encodeComponent(name)}';
    }
    return 'https://maps.apple.com/?daddr=$lat,$lng';
  }

  /// Builds Android geo: intent URL
  /// `geo:<lat>,<lng>?q=<lat>,<lng>(<label>)`
  static String buildGeoIntentUrl(double lat, double lng, {String? label}) {
    if (label != null && label.isNotEmpty) {
      return 'geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(label)})';
    }
    return 'geo:$lat,$lng';
  }

  static String _normalizeTravelMode(String mode) {
    switch (mode.toLowerCase()) {
      case 'walk':
      case 'walking':
        return 'walking';
      case 'bicycling':
      case 'bike':
      case 'cycle':
        return 'bicycling';
      case 'transit':
      case 'bus':
      case 'train':
      case 'metro':
        return 'transit';
      case 'two-wheeler':
      case 'two_wheeler':
      case 'motorcycle':
      case 'bike_taxi':
        return 'two-wheeler';
      case 'driving':
      case 'drive':
      case 'auto':
      case 'cab':
      case 'taxi':
      default:
        return 'driving';
    }
  }

  // --- External Launchers ---

  Future<bool> openPlace({
    String? placeId,
    String? name,
    double? lat,
    double? lng,
    BuildContext? context,
  }) async {
    final preferred = await getPreferredApp();

    if (preferred == PreferredMapApp.waze && lat != null && lng != null) {
      return _launchUrlString(buildWazeUrl(lat, lng));
    }

    if (preferred == PreferredMapApp.appleMaps && lat != null && lng != null) {
      return _launchUrlString(buildAppleMapsUrl(lat, lng, name: name));
    }

    if (preferred == PreferredMapApp.askEachTime &&
        context != null &&
        context.mounted &&
        lat != null &&
        lng != null) {
      final chosen = await showMapChooserDialog(
        context,
        lat: lat,
        lng: lng,
        name: name,
      );
      if (chosen != null) {
        return _launchAppSpecific(
          chosen,
          lat: lat,
          lng: lng,
          name: name,
          placeId: placeId,
        );
      }
    }

    final url = buildGoogleMapsPlaceUrl(
      placeId: placeId,
      name: name,
      lat: lat,
      lng: lng,
    );
    return _launchUrlString(url);
  }

  /// Synchronously opens full route navigation directly inside user gesture (popup-safe)
  bool openDirectionsSynchronously({
    RoadmapLocation? origin,
    required RoadmapLocation destination,
    String mode = 'driving',
    List<String> waypoints = const [],
  }) {
    if (_cachedApp == PreferredMapApp.waze) {
      final wazeUrl = buildWazeUrl(destination.lat, destination.lng);
      _launchUrlDirect(wazeUrl);
      return true;
    }
    if (_cachedApp == PreferredMapApp.appleMaps) {
      final appleUrl = buildAppleMapsUrl(
        destination.lat,
        destination.lng,
        name: destination.name,
      );
      _launchUrlDirect(appleUrl);
      return true;
    }
    final googleUrl = buildGoogleMapsDirectionsUrlFromObjects(
      origin: origin,
      destination: destination,
      mode: mode,
      waypoints: waypoints,
    );
    _launchUrlDirect(googleUrl);
    return true;
  }

  /// Synchronously opens single step navigation directly inside user gesture (popup-safe)
  bool openStepDirectionsSynchronously({
    required RoadmapStep step,
  }) {
    final stepOrigin = RoadmapLocation(
      name: step.fromName,
      lat: step.startLat,
      lng: step.startLng,
    );
    final stepDest = RoadmapLocation(
      name: step.toName,
      lat: step.endLat,
      lng: step.endLng,
    );
    return openDirectionsSynchronously(
      origin: stepOrigin,
      destination: stepDest,
      mode: step.mode,
    );
  }

  void _launchUrlDirect(String urlStr) {
    if (!isAllowedMapUrl(urlStr)) {
      debugPrint('[SECURITY] Rejected map URL: $urlStr');
      return;
    }
    final uri = Uri.parse(urlStr);
    launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
  }

  Future<bool> openDirections({
    String? origin,
    String? destination,
    double? originLat,
    double? originLng,
    double? destLat,
    double? destLng,
    String? originName,
    String? destName,
    String mode = 'driving',
    List<String> waypoints = const [],
    BuildContext? context,
  }) async {
    final preferred = await getPreferredApp();

    final originStr =
        origin ??
        originName ??
        (originLat != null && originLng != null ? '$originLat,$originLng' : '');
    final destStr =
        destination ??
        destName ??
        (destLat != null && destLng != null ? '$destLat,$destLng' : '');

    double? targetLat = destLat;
    double? targetLng = destLng;
    if (targetLat == null && destStr.contains(',')) {
      final parts = destStr.split(',');
      if (parts.length >= 2) {
        targetLat = double.tryParse(parts[0].trim());
        targetLng = double.tryParse(parts[1].trim());
      }
    }

    if (preferred == PreferredMapApp.waze &&
        targetLat != null &&
        targetLng != null) {
      return _launchUrlString(buildWazeUrl(targetLat, targetLng));
    }

    if (preferred == PreferredMapApp.appleMaps &&
        targetLat != null &&
        targetLng != null) {
      return _launchUrlString(
        buildAppleMapsUrl(targetLat, targetLng, name: destName ?? destination),
      );
    }

    if (preferred == PreferredMapApp.askEachTime &&
        context != null &&
        context.mounted &&
        targetLat != null &&
        targetLng != null) {
      final chosen = await showMapChooserDialog(
        context,
        lat: targetLat,
        lng: targetLng,
        name: destName ?? destination,
      );
      if (chosen != null) {
        return _launchAppSpecific(
          chosen,
          lat: targetLat,
          lng: targetLng,
          name: destName ?? destination,
          originLat: originLat,
          originLng: originLng,
          mode: mode,
          waypoints: waypoints,
        );
      }
    }

    final url = buildGoogleMapsDirectionsUrl(
      origin: originStr,
      destination: destStr,
      mode: mode,
      waypoints: waypoints,
    );
    return _launchUrlString(url);
  }

  Future<bool> openSearch(
    String query, {
    double? nearLat,
    double? nearLng,
  }) async {
    final url = buildGoogleMapsSearchUrl(
      query,
      nearLat: nearLat,
      nearLng: nearLng,
    );
    return _launchUrlString(url);
  }

  Future<bool> _launchAppSpecific(
    PreferredMapApp app, {
    required double lat,
    required double lng,
    String? name,
    String? placeId,
    double? originLat,
    double? originLng,
    String mode = 'driving',
    List<String> waypoints = const [],
  }) async {
    switch (app) {
      case PreferredMapApp.waze:
        return _launchUrlString(buildWazeUrl(lat, lng));
      case PreferredMapApp.appleMaps:
        return _launchUrlString(buildAppleMapsUrl(lat, lng, name: name));
      case PreferredMapApp.googleMaps:
      case PreferredMapApp.askEachTime:
        if (originLat != null && originLng != null) {
          final originStr = '$originLat,$originLng';
          final destStr = name ?? '$lat,$lng';
          return _launchUrlString(
            buildGoogleMapsDirectionsUrl(
              origin: originStr,
              destination: destStr,
              mode: mode,
              waypoints: waypoints,
            ),
          );
        }
        return _launchUrlString(
          buildGoogleMapsPlaceUrl(
            placeId: placeId,
            name: name,
            lat: lat,
            lng: lng,
          ),
        );
    }
  }

  static final Set<String> _allowedHosts = {
    'google.com',
    'www.google.com',
    'maps.google.com',
    'waze.com',
    'www.waze.com',
    'maps.apple.com',
  };

  /// Validates that an external navigation URL targets an approved map host over HTTPS (or native geo: intent)
  static bool isAllowedMapUrl(String urlStr) {
    try {
      final uri = Uri.parse(urlStr.trim());
      if (uri.scheme == 'geo') return true;
      if (uri.scheme != 'https') return false;
      final host = uri.host.toLowerCase();
      if (_allowedHosts.contains(host)) return true;
      return _allowedHosts.any((allowed) => host.endsWith('.$allowed'));
    } catch (_) {
      return false;
    }
  }

  Future<bool> _launchUrlString(String urlStr) async {
    if (!isAllowedMapUrl(urlStr)) {
      debugPrint('[SECURITY] Rejected map URL outside allowlist: $urlStr');
      return false;
    }
    final uri = Uri.parse(urlStr);
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch map URL: $urlStr error: $e');
      return false;
    }
  }

  Future<PreferredMapApp?> showMapChooserDialog(
    BuildContext context, {
    required double lat,
    required double lng,
    String? name,
  }) async {
    final isIOS = !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS);

    return showModalBottomSheet<PreferredMapApp>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Open in Maps',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.map_rounded, color: Colors.blue),
                title: const Text('Google Maps'),
                onTap: () => Navigator.pop(ctx, PreferredMapApp.googleMaps),
              ),
              ListTile(
                leading: const Icon(
                  Icons.navigation_rounded,
                  color: Colors.cyan,
                ),
                title: const Text('Waze'),
                onTap: () => Navigator.pop(ctx, PreferredMapApp.waze),
              ),
              if (isIOS)
                ListTile(
                  leading: const Icon(
                    Icons.apple_rounded,
                    color: Colors.black87,
                  ),
                  title: const Text('Apple Maps'),
                  onTap: () => Navigator.pop(ctx, PreferredMapApp.appleMaps),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

final mapLauncherServiceProvider = Provider<MapLauncherService>((ref) {
  return MapLauncherService();
});

class PreferredMapAppNotifier extends Notifier<PreferredMapApp> {
  @override
  PreferredMapApp build() {
    final service = ref.watch(mapLauncherServiceProvider);
    return service._cachedApp;
  }

  Future<void> setApp(PreferredMapApp app) async {
    final service = ref.read(mapLauncherServiceProvider);
    await service.setPreferredApp(app);
    state = app;
  }
}

final preferredMapAppNotifierProvider =
    NotifierProvider<PreferredMapAppNotifier, PreferredMapApp>(
      PreferredMapAppNotifier.new,
    );
