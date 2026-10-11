import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_buddy/core/data/community_repository.dart';
import 'package:travel_buddy/core/data/tariff_repository.dart';
import 'package:travel_buddy/core/models/ai_price_models.dart';
import 'package:travel_buddy/core/models/roadmap_models.dart';
import 'package:travel_buddy/core/services/google_maps_service.dart';
import 'package:travel_buddy/core/services/roadmap_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GovTariffRepository tariffRepo;
  late CommunityRepository communityRepo;
  late GoogleMapsService googleMapsService;
  late RoadmapService roadmapService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tariffRepo = LocalGovTariffRepository();
    communityRepo = LocalCommunityRepository();
    googleMapsService = GoogleMapsService();
    roadmapService = RoadmapService(
      tariffRepo: tariffRepo,
      communityRepo: communityRepo,
      googleMapsService: googleMapsService,
    );
  });

  group('RoadmapService & Engine Unit Tests', () {
    test('1. Dynamic roadmap generation: Computes multi-modal options via live engine', () async {
      const origin = RoadmapLocation(
        name: 'Guwahati Railway Station',
        lat: 26.1822,
        lng: 91.7512,
      );
      const destination = RoadmapLocation(
        name: 'Kamakhya Temple',
        lat: 26.1664,
        lng: 91.7055,
      );

      final roadmap = await roadmapService.planRoadmap(
        origin: origin,
        destination: destination,
      );

      expect(roadmap.options.isNotEmpty, isTrue);
      final firstOption = roadmap.options.first;
      expect(firstOption.steps.length, greaterThanOrEqualTo(1));
      expect(firstOption.totalFairMin, greaterThan(0));
      expect(
        firstOption.totalFairMax,
        greaterThanOrEqualTo(firstOption.totalFairMin),
      );
    });

    test('2. Summing step prices: Total fair price equals sum of individual step ranges', () async {
      const origin = RoadmapLocation(
        name: 'Jaipur Junction',
        lat: 26.9200,
        lng: 75.7878,
      );
      const destination = RoadmapLocation(
        name: 'Hawa Mahal',
        lat: 26.9239,
        lng: 75.8267,
      );

      final roadmap = await roadmapService.planRoadmap(
        origin: origin,
        destination: destination,
      );

      for (final option in roadmap.options) {
        final calculatedMin = option.steps.fold(
          0.0,
          (acc, s) => acc + s.fairMin,
        );
        final calculatedMax = option.steps.fold(
          0.0,
          (acc, s) => acc + s.fairMax,
        );

        expect(option.totalFairMin, closeTo(calculatedMin, 0.01));
        expect(option.totalFairMax, closeTo(calculatedMax, 0.01));
      }
    });

    test(
      '3. Attaching tourist traps and warnings by proximity (<300m)',
      () async {
        // Jaipur Junction coordinates where scam syndicate is located
        const origin = RoadmapLocation(
          name: 'Jaipur Junction',
          lat: 26.9200,
          lng: 75.7878,
        );
        const destination = RoadmapLocation(
          name: 'City Palace',
          lat: 26.9258,
          lng: 75.8236,
        );

        final roadmap = await roadmapService.planRoadmap(
          origin: origin,
          destination: destination,
        );

        final firstOption = roadmap.options.first;
        final stepWithOrigin = firstOption.steps.first;

        // Trap near Jaipur Junction (within 300m) should be attached
        expect(stepWithOrigin.traps.isNotEmpty, isTrue);
        expect(stepWithOrigin.trapIds.isNotEmpty, isTrue);
        expect(
          stepWithOrigin.warnings.any(
            (w) => w.contains('tout') || w.contains('Trap'),
          ),
          isTrue,
        );
      },
    );

    test('4. Option risk level elevation: Multiple traps produce High Risk or Suspicious verdict', () async {
      const origin = RoadmapLocation(
        name: 'Jaipur Junction',
        lat: 26.9200,
        lng: 75.7878,
      );
      const destination = RoadmapLocation(
        name: 'Amer Fort Town',
        lat: 26.9830,
        lng: 75.8495,
      );

      final roadmap = await roadmapService.planRoadmap(
        origin: origin,
        destination: destination,
      );

      // Options starting near heavily targeted transit stations have non-trivial risk
      final highRiskOrSuspicious = roadmap.options.any(
        (o) =>
            o.riskLevel == PriceVerdictLevel.highRisk ||
            o.riskLevel == PriceVerdictLevel.suspicious,
      );
      expect(highRiskOrSuspicious, isTrue);
    });

    test('5. Straight-line x 1.3 fallback: Generates valid options when no curated match or external route exists', () async {
      // Arbitrary non-curated coordinates in Jodhpur
      const origin = RoadmapLocation(
        name: 'Clock Tower Jodhpur',
        lat: 26.2968,
        lng: 73.0247,
      );
      const destination = RoadmapLocation(
        name: 'Mehrangarh Fort',
        lat: 26.2978,
        lng: 73.0185,
      );

      final roadmap = await roadmapService.planRoadmap(
        origin: origin,
        destination: destination,
      );

      expect(roadmap.options.length, greaterThanOrEqualTo(2));
      final fastest = roadmap.options.firstWhere((o) => o.label == 'Fastest');
      expect(fastest.steps.isNotEmpty, isTrue);
      expect(fastest.totalFairMin, greaterThan(0));
      expect(
        fastest.steps.first.dontPayMoreThan,
        greaterThan(fastest.steps.first.fairMax),
      );
    });

    test('6. Checklist generator: Produces essential items and conditional items for night/distance', () async {
      const origin = RoadmapLocation(
        name: 'Station',
        lat: 26.9200,
        lng: 75.7878,
      );
      const destination = RoadmapLocation(
        name: 'Far Suburb',
        lat: 27.1500,
        lng: 76.1000,
      );

      // Late night departure (23:30)
      final nightTime = DateTime(2026, 10, 10, 23, 30);
      final roadmap = await roadmapService.planRoadmap(
        origin: origin,
        destination: destination,
        departTime: nightTime,
      );

      expect(roadmap.checklist.any((c) => c.id == 'chk_cash_upi'), isTrue);
      expect(roadmap.checklist.any((c) => c.id == 'chk_night'), isTrue);
      expect(roadmap.checklist.any((c) => c.id == 'chk_offline_map'), isTrue);
    });
  });
}
