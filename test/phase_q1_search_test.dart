import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_buddy/core/models/app_models.dart';
import 'package:travel_buddy/core/models/google_maps_models.dart';
import 'package:travel_buddy/core/services/google_maps_service.dart';
import 'package:travel_buddy/core/widgets/app_places_search_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase Q1: Request Builders & No-Restriction Behavior Tests', () {
    test('1. Autocomplete sends no includedRegionCodes by default (no country restriction)', () async {
      Map<String, dynamic>? capturedBody;

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/places/autocomplete')) {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'suggestions': [
                {
                  'placePrediction': {
                    'placeId': 'tokyo_123',
                    'text': {'text': 'Tokyo, Japan'},
                    'structuredFormat': {
                      'mainText': {'text': 'Tokyo'},
                      'secondaryText': {'text': 'Japan'},
                    },
                    'types': ['locality', 'political'],
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final service = GoogleMapsService(client: mockClient);
      final results = await service.autocomplete(
        'Tokyo',
        searchInCountryOnly: false,
      );

      expect(results.length, 1);
      expect(results.first.placeId, 'tokyo_123');
      expect(results.first.mainText, 'Tokyo');
      expect(capturedBody, isNotNull);
      expect(capturedBody!['input'], 'Tokyo');
      expect(
        capturedBody!['includedRegionCodes'],
        isNull,
        reason: 'Must NOT restrict regions unless explicitly requested',
      );
      expect(capturedBody!['sessionToken'], isNotNull);
      expect(capturedBody!['languageCode'], 'en');
    });

    test('2. Autocomplete sets includedRegionCodes only when searchInCountryOnly is true', () async {
      Map<String, dynamic>? capturedBody;

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/places/autocomplete')) {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'suggestions': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final service = GoogleMapsService(client: mockClient);
      await service.autocomplete(
        'Goa',
        searchInCountryOnly: true,
        countryCode: 'in',
        biasCenter: const LatLng(15.2993, 74.1240),
      );

      expect(capturedBody, isNotNull);
      expect(capturedBody!['includedRegionCodes'], ['in']);
      expect(capturedBody!['locationBias'], isNotNull);
      expect(
        capturedBody!['locationBias']['circle']['center']['latitude'],
        15.2993,
      );
    });

    test(
      '3. Free-form textSearch builder sends textQuery and sessionToken',
      () async {
        Map<String, dynamic>? capturedBody;

        final mockClient = MockClient((request) async {
          if (request.url.path.contains('/places/text-search')) {
            capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'places': [
                  {
                    'id': 'cafe_shillong',
                    'displayName': {'text': 'Dylan\'s Cafe'},
                    'formattedAddress':
                        'Tripura Castle Rd, Shillong, Meghalaya',
                    'location': {'latitude': 25.5788, 'longitude': 91.8933},
                    'types': ['cafe', 'food', 'point_of_interest'],
                    'rating': 4.5,
                    'userRatingCount': 1200,
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('Not found', 404);
        });

        final service = GoogleMapsService(client: mockClient);
        final results = await service.textSearch(
          'cafes in Shillong',
          biasCenter: const LatLng(25.5788, 91.8933),
        );

        expect(capturedBody, isNotNull);
        expect(capturedBody!['textQuery'], 'cafes in Shillong');
        expect(capturedBody!['sessionToken'], isNotNull);
        expect(results.length, 1);
        expect(results.first.name, 'Dylan\'s Cafe');
        expect(results.first.rating, 4.5);
      },
    );
  });

  group('Phase Q1: Response Parsing & Classification Tests', () {
    test(
      '4. Suggestion category type parsed correctly from Places API types',
      () {
        expect(
          SuggestionCategoryType.fromTypes(['locality', 'political']),
          SuggestionCategoryType.city,
        );
        expect(
          SuggestionCategoryType.fromTypes(['sublocality', 'neighborhood']),
          SuggestionCategoryType.area,
        );
        expect(
          SuggestionCategoryType.fromTypes([
            'tourist_attraction',
            'historical_landmark',
          ]),
          SuggestionCategoryType.landmark,
        );
        expect(
          SuggestionCategoryType.fromTypes(['restaurant', 'food', 'cafe']),
          SuggestionCategoryType.food,
        );
        expect(
          SuggestionCategoryType.fromTypes(['lodging', 'hotel']),
          SuggestionCategoryType.stay,
        );
        expect(
          SuggestionCategoryType.fromTypes([
            'transit_station',
            'bus_station',
            'taxi_stand',
          ]),
          SuggestionCategoryType.transport,
        );
        expect(
          SuggestionCategoryType.fromTypes(['unknown_type']),
          SuggestionCategoryType.general,
        );
      },
    );

    test('5. Distance formatting in GooglePlaceSuggestion', () {
      final sNear = GooglePlaceSuggestion(
        placeId: 'p1',
        mainText: 'Near Spot',
        secondaryText: 'City',
        distanceMeters: 450,
      );
      expect(sNear.formattedDistance, '450m');

      final sFar = GooglePlaceSuggestion(
        placeId: 'p2',
        mainText: 'Far Spot',
        secondaryText: 'City',
        distanceMeters: 3800,
      );
      expect(sFar.formattedDistance, '3.8km');
    });

    test('6. Place details parser captures full field mask including viewport and addressComponents', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/places/details')) {
          return http.Response(
            jsonEncode({
              'id': 'place_paris',
              'displayName': {'text': 'Paris'},
              'formattedAddress': 'Paris, France',
              'location': {'latitude': 48.8566, 'longitude': 2.3522},
              'viewport': {
                'low': {'latitude': 48.8155, 'longitude': 2.2241},
                'high': {'latitude': 48.9021, 'longitude': 2.4699},
              },
              'types': ['locality', 'political'],
              'primaryType': 'locality',
              'addressComponents': [
                {
                  'longText': 'Paris',
                  'types': ['locality'],
                },
                {
                  'longText': 'France',
                  'shortText': 'FR',
                  'types': ['country'],
                },
              ],
              'rating': 4.7,
              'userRatingCount': 99999,
              'priceLevel': 'PRICE_LEVEL_MODERATE',
              'nationalPhoneNumber': '+33 1 42 68 00 00',
              'websiteUri': 'https://paris.fr',
              'editorialSummary': {'text': 'Capital of France'},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final service = GoogleMapsService(client: mockClient);
      final details = await service.getPlaceDetails('place_paris');

      expect(details.id, 'place_paris');
      expect(details.name, 'Paris');
      expect(details.isCityOrRegion, isTrue);
      expect(details.primaryType, 'locality');
      expect(details.viewport, isNotNull);
      expect(details.viewport!['low']!['latitude'], 48.8155);
      expect(details.addressComponents.length, 2);
      expect(details.editorialSummary, 'Capital of France');
    });
  });

  group('Phase Q1: Session Token Lifecycle Tests', () {
    test('7. Keystrokes share same session token until getPlaceDetails terminates it', () async {
      final capturedSessionTokens = <String>[];

      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (request.url.path.contains('/places/autocomplete') ||
            request.url.path.contains('/places/details')) {
          capturedSessionTokens.add(body['sessionToken'] as String);
          if (request.url.path.contains('/places/details')) {
            return http.Response(
              jsonEncode({
                'id': 'p_1',
                'displayName': {'text': 'Place 1'},
                'formattedAddress': 'Address 1',
                'location': {'latitude': 10.0, 'longitude': 20.0},
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({'suggestions': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final service = GoogleMapsService(client: mockClient);

      // Keystroke 1: 'J'
      await service.autocomplete('Ja');
      // Keystroke 2: 'Jai'
      await service.autocomplete('Jai');
      // Keystroke 3: 'Jaip'
      await service.autocomplete('Jaip');

      expect(capturedSessionTokens.length, 3);
      // All keystrokes in the search session must reuse the same session token
      expect(capturedSessionTokens[0], capturedSessionTokens[1]);
      expect(capturedSessionTokens[1], capturedSessionTokens[2]);
      final searchSessionToken = capturedSessionTokens[0];

      // User selects a place -> calls Place Details
      await service.getPlaceDetails('p_1');
      expect(capturedSessionTokens.length, 4);
      // Details call concludes this session token
      expect(capturedSessionTokens[3], searchSessionToken);

      // Next new search must generate a fresh session token
      await service.autocomplete('New');
      expect(capturedSessionTokens.length, 5);
      expect(capturedSessionTokens[4], isNot(equals(searchSessionToken)));
    });
  });

  group('Phase Q1: Widget Tests - Debounce, Out-of-Order & UI States', () {
    testWidgets(
      '8. AppPlacesSearchBar debounces keystrokes and renders suggestions with icons and Google attribution',
      (tester) async {
        int autocompleteCallCount = 0;

        final mockClient = MockClient((request) async {
          if (request.url.path.contains('/places/autocomplete')) {
            autocompleteCallCount++;
            return http.Response(
              jsonEncode({
                'suggestions': [
                  {
                    'placePrediction': {
                      'placeId': 'tokyo_city',
                      'text': {'text': 'Tokyo, Japan'},
                      'structuredFormat': {
                        'mainText': {'text': 'Tokyo'},
                        'secondaryText': {'text': 'Japan'},
                      },
                      'types': ['locality', 'political'],
                    },
                  },
                  {
                    'placePrediction': {
                      'placeId': 'tokyo_tower',
                      'text': {'text': 'Tokyo Tower, Minato, Tokyo'},
                      'structuredFormat': {
                        'mainText': {'text': 'Tokyo Tower'},
                        'secondaryText': {'text': 'Minato, Tokyo, Japan'},
                      },
                      'types': ['tourist_attraction'],
                    },
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('Not found', 404);
        });

        final container = ProviderContainer(
          overrides: [
            googleMapsServiceProvider.overrideWithValue(
              GoogleMapsService(client: mockClient),
            ),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: AppPlacesSearchBar(onPlaceSelected: (_) {}),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Enter 1 char ('T'): Should not search yet (min 2 chars)
        await tester.enterText(find.byType(TextField), 'T');
        await tester.pump(const Duration(milliseconds: 100));
        expect(autocompleteCallCount, 0);

        // Enter 2 chars ('To'): Fast typing before debounce finishes
        await tester.enterText(find.byType(TextField), 'To');
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          autocompleteCallCount,
          0,
          reason: 'Must wait for 250ms debounce',
        );

        // Wait remaining debounce duration (>250ms)
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        expect(autocompleteCallCount, 1);
        // Suggestions rendered
        expect(find.text('Tokyo'), findsOneWidget);
        expect(find.text('Tokyo Tower'), findsOneWidget);
        expect(find.text('Powered by Google'), findsOneWidget);
      },
    );

    testWidgets('9. Out-of-order responses do not overwrite newer results', (
      tester,
    ) async {
      // Simulate slow query 1 and fast query 2
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final input = body['input'] as String;

        if (input == 'Slow') {
          // Artificial slow network delay
          await Future.delayed(const Duration(milliseconds: 400));
          return http.Response(
            jsonEncode({
              'suggestions': [
                {
                  'placePrediction': {
                    'placeId': 'slow_result',
                    'text': {'text': 'Old Slow Result'},
                    'structuredFormat': {
                      'mainText': {'text': 'Old Slow Result'},
                    },
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (input == 'Fast') {
          return http.Response(
            jsonEncode({
              'suggestions': [
                {
                  'placePrediction': {
                    'placeId': 'fast_result',
                    'text': {'text': 'New Fast Result'},
                    'structuredFormat': {
                      'mainText': {'text': 'New Fast Result'},
                    },
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final container = ProviderContainer(
        overrides: [
          googleMapsServiceProvider.overrideWithValue(
            GoogleMapsService(client: mockClient),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(body: AppPlacesSearchBar(onPlaceSelected: (_) {})),
          ),
        ),
      );

      // 1. Type "Slow" and let debounce trigger request
      await tester.enterText(find.byType(TextField), 'Slow');
      await tester.pump(const Duration(milliseconds: 300));

      // 2. Quickly type "Fast" before "Slow" finishes
      await tester.enterText(find.byType(TextField), 'Fast');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // "Fast" should be visible
      expect(find.text('New Fast Result'), findsOneWidget);

      // Now wait until "Slow" finishes delayed response
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // "Old Slow Result" should NOT have replaced "New Fast Result"
      expect(find.text('New Fast Result'), findsOneWidget);
      expect(find.text('Old Slow Result'), findsNothing);
    });

    testWidgets(
      '10. Shows fallback error state with retry button on network failure',
      (tester) async {
        final mockClient = MockClient((request) async {
          return http.Response('Internal Server Error', 500);
        });

        final container = ProviderContainer(
          overrides: [
            googleMapsServiceProvider.overrideWithValue(
              GoogleMapsService(client: mockClient),
            ),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(body: AppPlacesSearchBar(onPlaceSelected: (_) {})),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'NetworkTest');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(find.text('Retry'), findsOneWidget);
      },
    );
  });

  group('Phase Q1 & Step 3/4: Extended Search, Coordinates, Links, Re-Ranking & Diagnostics Tests', () {
    testWidgets(
      '11. Detects coordinates "lat, lng" and renders coordinate suggestion',
      (tester) async {
        final container = ProviderContainer();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(body: AppPlacesSearchBar(onPlaceSelected: (_) {})),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), '28.6139, 77.2090');
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Coordinates: 28.6139, 77.2090'),
          findsOneWidget,
        );
        expect(
          find.text('Tap to reverse geocode & view place details'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '12. Detects Google Maps URL and displays inspect link suggestion',
      (tester) async {
        final container = ProviderContainer();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(body: AppPlacesSearchBar(onPlaceSelected: (_) {})),
            ),
          ),
        );

        await tester.enterText(
          find.byType(TextField),
          'https://maps.app.goo.gl/xyz123abc',
        );
        await tester.pumpAndSettle();

        expect(find.text('Inspect Google Maps Link'), findsOneWidget);
        expect(
          find.widgetWithText(ListTile, 'https://maps.app.goo.gl/xyz123abc'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '13. Filter chips strictly re-rank results without hiding non-matching entries',
      (tester) async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'suggestions': [
                {
                  'placePrediction': {
                    'placeId': 'museum_1',
                    'text': {'text': 'Art Museum'},
                    'structuredFormat': {
                      'mainText': {'text': 'Art Museum'},
                    },
                    'types': ['tourist_attraction', 'museum'],
                  },
                },
                {
                  'placePrediction': {
                    'placeId': 'cafe_1',
                    'text': {'text': 'Art Cafe'},
                    'structuredFormat': {
                      'mainText': {'text': 'Art Cafe'},
                    },
                    'types': ['cafe', 'food'],
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final container = ProviderContainer(
          overrides: [
            googleMapsServiceProvider.overrideWithValue(
              GoogleMapsService(client: mockClient),
            ),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(body: AppPlacesSearchBar(onPlaceSelected: (_) {})),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'Art');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        // Both initially visible under 'All'
        expect(find.text('Art Museum'), findsOneWidget);
        expect(find.text('Art Cafe'), findsOneWidget);

        // Tap 'Food' filter chip
        await tester.tap(find.text('Food'));
        await tester.pumpAndSettle();

        // BOTH MUST STILL BE VISIBLE: Never filter out or hide anything
        expect(find.text('Art Cafe'), findsOneWidget);
        expect(find.text('Art Museum'), findsOneWidget);
      },
    );

    test('14. Reverse geocode builder and response parsing', () async {
      Map<String, dynamic>? capturedBody;

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/geocode')) {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'status': 'OK',
              'results': [
                {
                  'place_id': 'place_connaught',
                  'formatted_address':
                      'Connaught Place, New Delhi, Delhi 110001, India',
                  'geometry': {
                    'location': {'lat': 28.6315, 'lng': 77.2167},
                  },
                  'types': ['neighborhood', 'political'],
                  'address_components': [
                    {
                      'long_name': 'Connaught Place',
                      'types': ['neighborhood'],
                    },
                    {
                      'long_name': 'New Delhi',
                      'types': ['locality'],
                    },
                    {
                      'long_name': 'India',
                      'short_name': 'IN',
                      'types': ['country'],
                    },
                  ],
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final service = GoogleMapsService(client: mockClient);
      final details = await service.reverseGeocode(28.6315, 77.2167);

      expect(details, isNotNull);
      expect(details!.placeId, 'place_connaught');
      expect(details.formattedAddress, contains('Connaught Place'));
      expect(capturedBody, isNotNull);
      expect(capturedBody!['lat'], 28.6315);
      expect(capturedBody!['lng'], 77.2167);
    });

    test(
      '15. Search telemetry logs to searchDebugProvider on search calls',
      () async {
        SearchDebugRecord? lastRecord;

        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'suggestions': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final service = GoogleMapsService(
          client: mockClient,
          onDebugLog: (rec) => lastRecord = rec,
        );

        await service.autocomplete('Reykjavik');

        expect(lastRecord, isNotNull);
        expect(lastRecord!.query, 'Reykjavik');
        expect(lastRecord!.endpoint, '/places/autocomplete');
        expect(lastRecord!.httpStatus, 200);
        expect(lastRecord!.likelyFix, contains('Everything working normally'));
      },
    );
  });
}
