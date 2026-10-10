import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  });
}
