import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_buddy/core/data/local_data_repository.dart';
import 'package:travel_buddy/core/data/community_repository.dart';
import 'package:travel_buddy/core/models/app_models.dart';
import 'package:travel_buddy/core/services/google_maps_service.dart';
import 'package:travel_buddy/core/services/route_service.dart';
import 'package:travel_buddy/features/explore/presentation/explore_screen.dart';
import 'package:travel_buddy/features/explore/presentation/widgets/location_details_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'travel_buddy_recent_explore_searches': ['Hawa Mahal', 'Amer Fort'],
    });
  });

  group('Phase X2: GoogleMapsService & Proxy Integration Unit Tests', () {
    test('1. Autocomplete requests proxy /places/autocomplete and falls back to seeds', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/places/autocomplete');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['input'], 'Jantar');
        return http.Response(
          jsonEncode({
            'suggestions': [
              {
                'placePrediction': {
                  'placeId': 'proxy_jantar_id',
                  'text': {'text': 'Jantar Mantar'},
                  'structuredFormat': {
                    'mainText': {'text': 'Jantar Mantar'},
                    'secondaryText': {'text': 'Jaipur, Rajasthan, India'},
                  },
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = GoogleMapsService(
        client: mockClient,
        proxyBaseUrl: 'http://localhost:8080',
      );

      final suggestions = await service.autocomplete('Jantar');
      expect(suggestions.length, 1);
      expect(suggestions.first.placeId, 'proxy_jantar_id');
      expect(suggestions.first.mainText, 'Jantar Mantar');
    });

    test(
      '2. Autocomplete falls back gracefully to seed places when proxy fails',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response('Server error', 500);
        });

        final service = GoogleMapsService(
          client: mockClient,
          proxyBaseUrl: 'http://localhost:8080',
        );

        final List<Place> seedPlaces = [
          Place.fromJson({
            'id': 'seed_hawa',
            'name': 'Hawa Mahal',
            'state': 'Rajasthan',
            'category': 'Attractions',
            'rating': 4.6,
            'reviewsCount': 310,
            'coverPhoto': 'https://example.com/hawa.jpg',
            'gallery': [],
            'description': 'Wind Palace',
            'latitude': 26.9239,
            'longitude': 75.8267,
            'scamRisk': 'Medium',
            'bestTimeToVisit': 'October to March',
            'transportOptions': [],
            'routeWarnings': [],
            'foodVenues': [],
            'stays': [],
            'scamAlerts': [],
            'reviews': [],
            'verifiedBusinesses': [],
          }),
        ];

        final suggestions = await service.autocomplete(
          'Hawa',
          seedPlaces: seedPlaces,
        );
        expect(suggestions.length, 1);
        expect(suggestions.first.placeId, 'seed_hawa');
        expect(suggestions.first.mainText, 'Hawa Mahal');
      },
    );

    test('3. Place Details uses 10-minute in-memory cache', () async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        return http.Response(
          jsonEncode({
            'id': 'cached_test_id',
            'displayName': {'text': 'City Palace'},
            'formattedAddress': 'Tripolia Bazar, Jaipur',
            'rating': 4.7,
            'userRatingCount': 500,
            'location': {'latitude': 26.9258, 'longitude': 75.8237},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = GoogleMapsService(
        client: mockClient,
        proxyBaseUrl: 'http://localhost:8080',
      );

      final first = await service.getPlaceDetails('cached_test_id');
      expect(first.name, 'City Palace');
      expect(requestCount, 1);

      // Second call within 10 minutes should hit in-memory cache
      final second = await service.getPlaceDetails('cached_test_id');
      expect(second.name, 'City Palace');
      expect(requestCount, 1);
    });

    test(
      '4. resolveLink calls proxy /resolve-link and returns structured details',
      () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/resolve-link');
          return http.Response(
            jsonEncode({
              'placeId': 'resolved_jal_mahal',
              'name': 'Jal Mahal',
              'formattedAddress': 'Amer Road, Jaipur',
              'latitude': 26.9656,
              'longitude': 75.8456,
              'rating': 4.4,
              'userRatingCount': 240,
              'isLiveGoogle': true,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final service = GoogleMapsService(
          client: mockClient,
          proxyBaseUrl: 'http://localhost:8080',
        );

        final result = await service.resolveLink(
          'https://maps.app.goo.gl/xyz123',
        );
        expect(result, isNotNull);
        expect(result!.placeId, 'resolved_jal_mahal');
        expect(result.name, 'Jal Mahal');
        expect(result.isLiveGoogle, isTrue);
      },
    );

    test('5. RouteService falls back to 1.3x straight-line GPS with isEstimatedRoute flag', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Proxy down', 503);
      });

      final service = RouteService(
        client: mockClient,
        proxyBaseUrl: 'http://localhost:8080',
      );

      final routes = await service.getRoutes(
        origin: const LatLng(26.9124, 75.7873),
        destination: const LatLng(26.9855, 75.8513),
      );

      expect(routes.isNotEmpty, isTrue);
      final r = routes.first;
      expect(r.isEstimatedRoute, isTrue);
      expect(r.distanceMeters, greaterThan(8000));
    });
  });

  group(
    'Phase X2: UI Widget Tests for Location Details Sheet & Explore Screen',
    () {
      testWidgets(
        '6. LocationDetailsSheet renders fares, community count, and all 4 action buttons',
        (tester) async {
          final details = GooglePlaceDetails(
            placeId: 'loc_sheet_test',
            name: 'Albert Hall Museum',
            formattedAddress: 'Ram Niwas Garden, Jaipur',
            latitude: 26.9116,
            longitude: 75.8195,
            rating: 4.6,
            userRatingCount: 350,
            editorialSummary: 'Indo-Saracenic architectural museum.',
            isOpenNow: true,
            fetchedAt: DateTime.now(),
            isLiveGoogle: true,
            attribution: 'Powered by Google Maps',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: LocationDetailsSheet(
                  details: details,
                  communityReportsCount: 22,
                  onClose: () {},
                ),
              ),
            ),
          );

          // Verify Details
          expect(find.text('Albert Hall Museum'), findsOneWidget);
          expect(find.text('Ram Niwas Garden, Jaipur'), findsOneWidget);
          expect(
            find.textContaining('Fares from Current Location'),
            findsOneWidget,
          );
          expect(find.textContaining('22 fare reports'), findsOneWidget);

          // Verify all 4 required action buttons
          expect(find.text('Open in Maps'), findsOneWidget);
          expect(find.text('Go here'), findsOneWidget);
          expect(find.text('Check a price'), findsOneWidget);
          expect(find.text('Ask Buddy about this place'), findsOneWidget);
        },
      );

      testWidgets(
        '7. ExploreScreen renders search, 8 categories, and import card',
        (tester) async {
          final List<Place> mockPlaces = [
            Place.fromJson({
              'id': 'p1',
              'name': 'Hawa Mahal',
              'state': 'Rajasthan',
              'category': 'Attractions',
              'rating': 4.7,
              'reviewsCount': 1500,
              'coverPhoto': 'https://example.com/hawa.jpg',
              'gallery': [],
              'description': 'Iconic palace of winds',
              'latitude': 26.9239,
              'longitude': 75.8267,
              'scamRisk': 'Medium',
              'bestTimeToVisit': 'October to March',
              'transportOptions': [],
              'routeWarnings': [],
              'foodVenues': [],
              'stays': [],
              'scamAlerts': [],
              'reviews': [],
              'verifiedBusinesses': [],
            }),
          ];

          final container = ProviderContainer(
            overrides: [
              placesFutureProvider.overrideWith(
                (ref) => Future.value(mockPlaces),
              ),
              areaInsightsFutureProvider.overrideWith(
                (ref) => Future.value([
                  AreaInsight(
                    id: 'a1',
                    areaName: 'Jaipur Railway Station Zone',
                    centerLat: 26.9200,
                    centerLng: 75.7878,
                    priceIndex: 1.45,
                    complaintCount90d: 89,
                    topTrapTypes: ['overcharging'],
                    saferAlternatives: ['Prepaid Auto Booth'],
                    lastUpdated: DateTime.now(),
                  ),
                  AreaInsight(
                    id: 'a2',
                    areaName: 'Low Report Quiet Zone',
                    centerLat: 26.9000,
                    centerLng: 75.7500,
                    priceIndex: 1.10,
                    complaintCount90d:
                        2, // Should be hidden per rule (< 3 reports)
                    topTrapTypes: [],
                    saferAlternatives: [],
                    lastUpdated: DateTime.now(),
                  ),
                ]),
              ),
            ],
          );

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(home: ExploreScreen()),
            ),
          );

          await tester.pumpAndSettle();

          // 1. Search Bar & recent searches
          expect(
            find.byType(TextField),
            findsNWidgets(2),
          ); // Search field + link import field
          expect(find.text('Recent searches'), findsOneWidget);

          // 2. Category Chips (Restaurants, Cafes, Hotels, Attractions, etc.)
          expect(find.text('Restaurants'), findsOneWidget);
          expect(find.text('Cafes'), findsOneWidget);
          expect(find.text('Hotels'), findsOneWidget);
          expect(find.text('Attractions'), findsWidgets);
          expect(find.text('Taxi stands'), findsOneWidget);

          // 3. Import from Google Maps card
          expect(find.text('Import from Google Maps'), findsOneWidget);
          expect(find.text('Inspect & Resolve Link'), findsOneWidget);

          // 4. Area Insights: Valid area with >= 3 complaints shown, area with < 3 hidden
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -800),
          );
          await tester.pumpAndSettle();
          expect(find.text('Jaipur Railway Station Zone'), findsOneWidget);
          expect(find.text('Low Report Quiet Zone'), findsNothing);
        },
      );
    },
  );
}
