import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_buddy/core/models/roadmap_models.dart';
import 'package:travel_buddy/core/services/map_launcher_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MapLauncherService - URL Builder Unit Tests', () {
    test('1. buildGoogleMapsPlaceUrl: correctly encodes name, placeId and coordinates', () {
      // With name and placeId
      final url1 = MapLauncherService.buildGoogleMapsPlaceUrl(
        name: 'Hawa Mahal & Museum',
        placeId: 'ChIJX9...abc123',
        lat: 26.9239,
        lng: 75.8267,
      );
      expect(url1, contains('https://www.google.com/maps/search/?api=1'));
      expect(url1, contains('query=Hawa%20Mahal%20%26%20Museum'));
      expect(url1, contains('query_place_id=ChIJX9...abc123'));

      // Without name (falls back to lat,lng)
      final url2 = MapLauncherService.buildGoogleMapsPlaceUrl(
        lat: 26.9239,
        lng: 75.8267,
      );
      expect(url2, contains('query=26.9239%2C75.8267'));

      // With only placeId
      final url3 = MapLauncherService.buildGoogleMapsPlaceUrl(
        placeId: 'ChIJtest_id',
      );
      expect(url3, contains('query_place_id=ChIJtest_id'));
    });

    test('2. buildGoogleMapsDirectionsUrl: parameter encoding and waypoint formatting', () {
      final url = MapLauncherService.buildGoogleMapsDirectionsUrl(
        origin: 'Jaipur Junction Railway Station',
        destination: 'Amer Fort, Rajasthan',
        waypoints: ['Hawa Mahal', 'Jal Mahal'],
      );

      expect(url, startsWith('https://www.google.com/maps/dir/?api=1'));
      expect(url, contains('origin=Jaipur%20Junction%20Railway%20Station'));
      expect(url, contains('destination=Amer%20Fort%2C%20Rajasthan'));
      expect(url, contains('travelmode=driving'));
      expect(url, contains('waypoints=Hawa%20Mahal%7CJal%20Mahal'));
    });

    test('3. buildGoogleMapsDirectionsUrl: verifies each travel mode', () {
      final modes = {
        'driving': 'driving',
        'drive': 'driving',
        'auto': 'driving',
        'cab': 'driving',
        'walking': 'walking',
        'walk': 'walking',
        'bicycling': 'bicycling',
        'bike': 'bicycling',
        'transit': 'transit',
        'bus': 'transit',
        'metro': 'transit',
        'two-wheeler': 'two-wheeler',
        'motorcycle': 'two-wheeler',
        'bike_taxi': 'two-wheeler',
      };

      for (final entry in modes.entries) {
        final url = MapLauncherService.buildGoogleMapsDirectionsUrl(
          origin: 'A',
          destination: 'B',
          mode: entry.key,
        );
        expect(
          url,
          contains('travelmode=${Uri.encodeComponent(entry.value)}'),
          reason: 'Mode "${entry.key}" should normalize to "${entry.value}"',
        );
      }
    });

    test(
      '4. buildGoogleMapsSearchUrl: encodes query and optional near center',
      () {
        final urlNoNear = MapLauncherService.buildGoogleMapsSearchUrl(
          'ATM & Bank',
        );
        expect(
          urlNoNear,
          'https://www.google.com/maps/search/?api=1&query=ATM%20%26%20Bank',
        );

        final urlWithNear = MapLauncherService.buildGoogleMapsSearchUrl(
          'Taxi stand',
          nearLat: 26.9124,
          nearLng: 75.7873,
        );
        expect(urlWithNear, contains('query=Taxi%20stand'));
        expect(urlWithNear, contains('center=26.9124%2C75.7873'));
      },
    );

    test('5. buildWazeUrl: exact navigation format https://waze.com/ul?ll=<lat>,<lng>&navigate=yes', () {
      final url = MapLauncherService.buildWazeUrl(26.9124, 75.7873);
      expect(url, 'https://waze.com/ul?ll=26.9124,75.7873&navigate=yes');
    });

    test('6. buildAppleMapsUrl: destination format https://maps.apple.com/?daddr=<lat>,<lng>', () {
      final url = MapLauncherService.buildAppleMapsUrl(26.9124, 75.7873);
      expect(url, 'https://maps.apple.com/?daddr=26.9124,75.7873');

      final urlWithName = MapLauncherService.buildAppleMapsUrl(
        26.9124,
        75.7873,
        name: 'City Palace',
      );
      expect(
        urlWithName,
        'https://maps.apple.com/?daddr=26.9124,75.7873&q=City%20Palace',
      );
    });

    test('7. buildGeoIntentUrl: Android geo intent format geo:<lat>,<lng>', () {
      final url = MapLauncherService.buildGeoIntentUrl(26.9124, 75.7873);
      expect(url, 'geo:26.9124,75.7873');

      final urlWithLabel = MapLauncherService.buildGeoIntentUrl(
        26.9124,
        75.7873,
        label: 'Amer Fort',
      );
      expect(
        urlWithLabel,
        'geo:26.9124,75.7873?q=26.9124,75.7873(Amer%20Fort)',
      );
    });

    test('8. PreferredMapApp preference storage & retrieval', () async {
      final service = MapLauncherService();
      expect(await service.getPreferredApp(), PreferredMapApp.googleMaps);

      await service.setPreferredApp(PreferredMapApp.waze);
      expect(await service.getPreferredApp(), PreferredMapApp.waze);

      await service.setPreferredApp(PreferredMapApp.appleMaps);
      expect(await service.getPreferredApp(), PreferredMapApp.appleMaps);

      await service.setPreferredApp(PreferredMapApp.askEachTime);
      expect(await service.getPreferredApp(), PreferredMapApp.askEachTime);
    });

    group('Step 2: buildGoogleMapsDirectionsUrlFromObjects specifications', () {
      test('Name only origin and destination', () {
        final url = MapLauncherService.buildGoogleMapsDirectionsUrlFromObjects(
          origin: const RoadmapLocation(name: 'Airport Arrival', lat: 0, lng: 0),
          destination: const RoadmapLocation(name: 'Grand Hotel', lat: 0, lng: 0),
        );
        expect(url, contains('origin=Airport%20Arrival'));
        expect(url, contains('destination=Grand%20Hotel'));
        expect(url, isNot(contains('origin_place_id')));
        expect(url, isNot(contains('destination_place_id')));
      });

      test('Place ID included together with name', () {
        final url = MapLauncherService.buildGoogleMapsDirectionsUrlFromObjects(
          origin: const RoadmapLocation(
            placeId: 'origin_pid_123',
            name: 'Airport Gate 1',
            lat: 26.10,
            lng: 91.58,
          ),
          destination: const RoadmapLocation(
            placeId: 'dest_pid_456',
            name: 'City Center',
            lat: 26.18,
            lng: 91.74,
          ),
        );
        expect(url, contains('origin=Airport%20Gate%201'));
        expect(url, contains('origin_place_id=origin_pid_123'));
        expect(url, contains('destination=City%20Center'));
        expect(url, contains('destination_place_id=dest_pid_456'));
      });

      test('Coordinates only origin and destination (empty names)', () {
        final url = MapLauncherService.buildGoogleMapsDirectionsUrlFromObjects(
          origin: const RoadmapLocation(name: '', lat: 26.1061, lng: 91.5859),
          destination: const RoadmapLocation(name: '', lat: 26.1822, lng: 91.7412),
        );
        expect(url, contains('origin=26.1061%2C91.5859'));
        expect(url, contains('destination=26.1822%2C91.7412'));
      });

      test('My location origin omits origin parameter entirely', () {
        final url = MapLauncherService.buildGoogleMapsDirectionsUrlFromObjects(
          origin: const RoadmapLocation(
            name: 'My location',
            lat: 26.11,
            lng: 91.59,
            isMyLocation: true,
          ),
          destination: const RoadmapLocation(
            placeId: 'dest_pid_999',
            name: 'Kamakhya Temple',
            lat: 26.1664,
            lng: 91.7055,
          ),
        );
        expect(url, isNot(contains('origin=')));
        expect(url, isNot(contains('origin_place_id=')));
        expect(url, contains('destination=Kamakhya%20Temple'));
        expect(url, contains('destination_place_id=dest_pid_999'));
      });

      test('Waypoints capped at 9 and joined with pipes', () {
        final waypoints = List.generate(12, (i) => 'Point $i');
        final url = MapLauncherService.buildGoogleMapsDirectionsUrlFromObjects(
          origin: const RoadmapLocation(name: 'Start', lat: 0, lng: 0),
          destination: const RoadmapLocation(name: 'End', lat: 0, lng: 0),
          waypoints: waypoints,
        );
        expect(url, contains('waypoints=Point%200%7CPoint%201%7CPoint%202%7CPoint%203%7CPoint%204%7CPoint%205%7CPoint%206%7CPoint%207%7CPoint%208'));
        expect(url, isNot(contains('Point%209')));
      });

      test('Special characters are fully encoded', () {
        final url = MapLauncherService.buildGoogleMapsDirectionsUrlFromObjects(
          origin: const RoadmapLocation(name: 'Cafe & Bar @ 5th St / North', lat: 0, lng: 0),
          destination: const RoadmapLocation(name: 'Park #1 (Main)', lat: 0, lng: 0),
        );
        expect(url, contains('origin=Cafe%20%26%20Bar%20%40%205th%20St%20%2F%20North'));
        expect(url, contains('destination=Park%20%231%20(Main)'));
      });

      test('openDirectionsSynchronously runs synchronously without awaiting', () {
        final service = MapLauncherService();
        final success = service.openDirectionsSynchronously(
          origin: const RoadmapLocation(name: 'Start', lat: 26.1, lng: 91.5),
          destination: const RoadmapLocation(name: 'End', lat: 26.2, lng: 91.6),
        );
        expect(success, isTrue);
      });
    });
  });
}
