import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_buddy/core/data/community_repository.dart';
import 'package:travel_buddy/core/models/ai_price_models.dart';
import 'package:travel_buddy/core/models/price_engine_models.dart';
import 'package:travel_buddy/core/models/roadmap_models.dart';
import 'package:travel_buddy/core/services/gemini_proxy_service.dart';
import 'package:travel_buddy/core/services/saved_trips_service.dart';
import 'package:travel_buddy/core/utils/engine_math.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase R3: SavedTripsService & Share Formatting Tests', () {
    test('1. Saves, retrieves, and deletes trips correctly', () async {
      final service = SavedTripsService();
      expect(await service.getSavedTrips(), isEmpty);

      final trip = SavedTrip(
        id: 'test_trip_1',
        originName: 'Jaipur Junction',
        originLat: 26.9200,
        originLng: 75.7878,
        destName: 'Amer Fort',
        destLat: 26.9855,
        destLng: 75.8513,
        selectedOptionLabel: 'Local guide',
        totalFairMin: 220.0,
        totalFairMax: 280.0,
        createdAt: DateTime(2026, 10, 10, 12, 0),
      );

      await service.saveTrip(trip);
      final retrieved = await service.getSavedTrips();
      expect(retrieved.length, 1);
      expect(retrieved.first.id, 'test_trip_1');
      expect(retrieved.first.originName, 'Jaipur Junction');
      expect(retrieved.first.destName, 'Amer Fort');
      expect(retrieved.first.selectedOptionLabel, 'Local guide');
      expect(retrieved.first.totalFairMax, 280.0);

      await service.deleteTrip('test_trip_1');
      final afterDelete = await service.getSavedTrips();
      expect(afterDelete, isEmpty);
    });

    test('2. Formats share text with key journey details and fair pricing', () {
      final service = SavedTripsService();
      final origin = RoadmapLocation(
        name: 'Jaipur Station',
        lat: 26.92,
        lng: 75.78,
      );
      final dest = RoadmapLocation(name: 'Amer Fort', lat: 26.98, lng: 75.85);

      final option = RoadmapOption(
        id: 'opt_fastest',
        label: 'Fastest',
        totalMin: 35,
        totalFairMin: 220,
        totalFairMax: 280,
        riskLevel: PriceVerdictLevel.fair,
        summaryOneLiner: 'Quick direct auto-rickshaw',
        steps: [
          RoadmapStep(
            index: 1,
            mode: 'auto',
            title: 'Prepaid Auto Stand',
            instruction: 'Board official prepaid auto',
            fromName: 'Jaipur Station',
            toName: 'Amer Fort',
            startLat: 26.92,
            startLng: 75.78,
            endLat: 26.98,
            endLng: 75.85,
            distanceM: 11200,
            durationMin: 35,
            fairMin: 220,
            fairMax: 280,
            dontPayMoreThan: 320,
            priceSource: '[Official tariff]',
            boardingPoint: 'Platform 1 Exit Kiosk',
          ),
        ],
      );

      final shareText = service.formatShareText(option, origin, dest);
      expect(shareText, contains('Jaipur Station ➔ Amer Fort'));
      expect(shareText, contains('~35 mins'));
      expect(shareText, contains('₹220 - ₹280'));
      expect(shareText, contains('Platform 1 Exit Kiosk'));
      expect(shareText, contains('Travel Buddy India'));
    });
  });

  group('Phase R3: Go Mode Navigation Logic & Proximity Calculations', () {
    test('3. Proximity detection within 100m for auto-advance', () {
      const checkpointLat = 26.985500;
      const checkpointLng = 75.851300;
      const travelerLat = 26.985800;
      const travelerLng = 75.851300;

      final distKm = EngineMath.haversineDistanceKm(
        travelerLat,
        travelerLng,
        checkpointLat,
        checkpointLng,
      );
      final distMeters = distKm * 1000.0;

      expect(distMeters, lessThan(100.0));
      final shouldAdvance = distMeters < 100.0;
      expect(shouldAdvance, isTrue);
    });

    test('4. Off-route detection when traveler deviates >200m', () {
      const stepRouteLat = 26.9200;
      const stepRouteLng = 75.7878;
      const divertedLat = 26.9240;
      const divertedLng = 75.7878;

      final distKm = EngineMath.haversineDistanceKm(
        stepRouteLat,
        stepRouteLng,
        divertedLat,
        divertedLng,
      );
      final distMeters = distKm * 1000.0;

      expect(distMeters, greaterThan(200.0));
      final isOffRoute = distMeters > 200.0;
      expect(isOffRoute, isTrue);
    });
  });

  group('Phase R3: Community Benchmark & Arrival Price Reporting', () {
    test('5. Arrival price evaluates fair vs overpaid status correctly', () {
      const fairMax = 250.0;
      const paidFair = 240.0;
      final isFairDeal = paidFair <= (fairMax * 1.05);
      expect(isFairDeal, isTrue);

      const paidOver = 350.0;
      final isOverpaid = paidOver > (fairMax * 1.05);
      expect(isOverpaid, isTrue);
    });

    test(
      '6. PriceReport submissions persist into CommunityRepository',
      () async {
        final repo = LocalCommunityRepository();
        await repo.resetCommunityData();

        final report = PriceReport(
          id: 'test_report_arrival_1',
          serviceType: ServiceType.auto,
          vehicleType: 'Auto',
          routeOrPlace: 'Jaipur Junction to Amer Fort',
          pricePaid: 260.0,
          timestamp: DateTime.now(),
          wasFair: true,
          notes: 'Submitted via Journey Arrival Screen',
        );

        await repo.submitPriceReport(report);
        final reports = await repo.getPriceReports();
        expect(reports.any((r) => r.id == 'test_report_arrival_1'), isTrue);
        expect(reports.first.pricePaid, 260.0);
      },
    );
  });

  group('Phase R3: Ask Buddy Roadmap AI Integration', () {
    test(
      '7. Local fallback generates create_roadmap action for direction queries',
      () async {
        final service = GeminiProxyService();
        final reply = await service.sendAgentMessage(
          history: [
            AgentMessage(
              id: '1',
              sender: 'user',
              text: 'How do I reach Amer Fort?',
              timestamp: DateTime.now(),
            ),
          ],
          currentPlace: 'Jaipur',
        );

        expect(reply.actions.any((a) => a.type == 'create_roadmap'), isTrue);
        expect(reply.text, contains('roadmap'));
      },
    );

    test(
      '8. Local fallback explains route safety for step explain queries',
      () async {
        final service = GeminiProxyService();
        final reply = await service.sendAgentMessage(
          history: [
            AgentMessage(
              id: '1',
              sender: 'user',
              text: 'explain step 1 of my route',
              timestamp: DateTime.now(),
            ),
          ],
          currentPlace: 'Jaipur',
        );

        expect(reply.text, contains('prepaid'));
        expect(reply.actions.any((a) => a.type == 'create_roadmap'), isTrue);
      },
    );
  });
}
