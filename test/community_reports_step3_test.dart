import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_buddy/core/data/community_repository.dart';
import 'package:travel_buddy/core/models/ai_price_models.dart';
import 'package:travel_buddy/core/models/app_models.dart';
import 'package:travel_buddy/features/community_reports/presentation/community_reports_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Step 3: Community Reports Validation, Schema & UI Tests', () {
    test('1. PriceReport model serializes and deserializes all required fields', () {
      final now = DateTime.now();
      final report = PriceReport(
        id: 'test_rep_101',
        serviceType: ServiceType.auto,
        vehicleType: 'Auto-rickshaw',
        routeOrPlace: 'Guwahati Station to Paltan Bazaar',
        pricePaid: 80.0,
        areaId: 'Guwahati',
        status: 'under_review',
        createdAt: now,
        timestamp: now,
        wasFair: true,
        userId: 'user_xyz',
        notes: 'Good driver',
      );

      final json = report.toJson();
      expect(json['areaId'], 'Guwahati');
      expect(json['status'], 'under_review');
      expect(json['createdAt'], isNotNull);
      expect(json['pricePaid'], 80.0);
      expect(json['userId'], 'user_xyz');

      final fromJson = PriceReport.fromJson(json);
      expect(fromJson.id, 'test_rep_101');
      expect(fromJson.areaId, 'Guwahati');
      expect(fromJson.status, 'under_review');
      expect(fromJson.pricePaid, 80.0);
      expect(fromJson.userId, 'user_xyz');
    });

    test('2. Submitting report immediately appears at top of getPriceReports', () async {
      final repo = LocalCommunityRepository();
      await repo.resetCommunityData();

      final report = PriceReport(
        id: 'pr-user-99999',
        serviceType: ServiceType.taxi,
        vehicleType: 'Sedan Cab',
        routeOrPlace: 'Airport to City Center',
        pricePaid: 600.0,
        areaId: 'Guwahati',
        status: 'approved',
        createdAt: DateTime.now(),
        timestamp: DateTime.now(),
        wasFair: true,
        userId: 'user_123',
      );

      await repo.submitPriceReport(report);
      final list = await repo.getPriceReports();
      expect(list.first.id, 'pr-user-99999');
      expect(list.first.pricePaid, 600.0);
      expect(list.first.areaId, 'Guwahati');
    });

    testWidgets('3. CommunityReportsScreen renders Near Me and My Reports tabs', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CommunityReportsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Near Me'), findsOneWidget);
      expect(find.text('My Reports'), findsOneWidget);
      expect(find.text('Report Price'), findsOneWidget);
      expect(find.text('Report Trap'), findsOneWidget);
      expect(find.text('Review Driver'), findsOneWidget);
    });
  });
}
