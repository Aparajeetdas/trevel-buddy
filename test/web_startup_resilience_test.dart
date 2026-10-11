import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_buddy/core/data/local_data_repository.dart';
import 'package:travel_buddy/core/data/tariff_repository.dart';
import 'package:travel_buddy/core/models/app_models.dart';
import 'package:travel_buddy/core/widgets/main_shell_screen.dart';
import 'package:travel_buddy/features/home/presentation/home_screen.dart';
import 'package:go_router/go_router.dart';

// Mock repository returning mock seed data immediately
class MockResilientAppRepository implements AppDataRepository {
  @override
  Future<List<Driver>> getDrivers() async => [];

  @override
  Future<Driver?> getDriverByVehicleNumber(String vehicleNumber) async => null;

  @override
  Future<List<ScamReportZone>> getScamReportZones() async => [];

  @override
  Future<List<FairPrice>> getFairPrices({PriceCategory? category}) async => [];

  @override
  Future<List<FareRule>> getFareRules() async => [];

  @override
  Future<List<ScamReport>> getScamReports() async => [];

  @override
  Future<void> submitScamReport(ScamReport report) async {}

  @override
  Future<void> resetAllData() async {}
}

class MockFailingTariffRepository implements GovTariffRepository {
  @override
  bool get isFetchedRemotely => false;

  @override
  DateTime? get lastRefreshed => null;

  @override
  Future<List<GovTariff>> getTariffs({bool forceRefresh = false}) async {
    throw Exception('Simulated proxy/network failure for tariffs');
  }

  @override
  Future<GovTariff?> findTariff({
    required String city,
    required ServiceType serviceType,
    String? vehicleType,
  }) async => null;

  @override
  Future<AirportPrepaidFareDataset> getAirportDataset({
    bool forceRefresh = false,
  }) async => const AirportPrepaidFareDataset(
        source: 'LGBI Airport Pre-paid Taxi Counter, Guwahati',
        verified: true,
        origin: 'LGBI Airport, Guwahati',
        routes: [],
      );

  @override
  Future<List<FixedRouteTariff>> getAirportPrepaidTariffs({
    bool forceRefresh = false,
  }) async => [];
}

Widget createTestApp({
  required double width,
  required double height,
  bool simulateTariffFailure = false,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShellScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/explore',
                builder: (context, state) => const Scaffold(body: Center(child: Text('Explore'))),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const Scaffold(body: Center(child: Text('Profile'))),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      appRepositoryProvider.overrideWithValue(MockResilientAppRepository()),
      if (simulateTariffFailure)
        govTariffRepositoryProvider.overrideWithValue(MockFailingTariffRepository()),
    ],
    child: MaterialApp.router(
      routerConfig: router,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Web Startup Resilience Tests', () {
    testWidgets('Home renders city chooser on first visit when active city is not set', (tester) async {
      tester.view.physicalSize = const Size(390 * 2.0, 844 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(width: 390, height: 844, simulateTariffFailure: true));
      await tester.pump();
      await tester.pump(Duration.zero);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Where are you traveling?', skipOffstage: false), findsOneWidget);
    });

    testWidgets('Responsive Layout at 390px (Mobile)', (tester) async {
      tester.view.physicalSize = const Size(390 * 2.0, 844 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(width: 390, height: 844));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Responsive Layout at 768px (Tablet)', (tester) async {
      tester.view.physicalSize = const Size(768 * 2.0, 1024 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(width: 768, height: 1024));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Responsive Layout at 1440px (Desktop Web)', (tester) async {
      tester.view.physicalSize = const Size(1440 * 2.0, 900 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(width: 1440, height: 900));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
