import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/airport_fares/presentation/airport_prepaid_fares_screen.dart';
import '../../features/business/presentation/business_onboarding_screen.dart';
import '../../features/business/presentation/business_profile_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/explore/presentation/explore_screen.dart';
import '../../features/place_guide/presentation/place_guide_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/scam_protection/presentation/verify_driver_screen.dart';
import '../../features/price_checker/presentation/check_price_input_screen.dart';
import '../../features/ride/presentation/ride_mode_screen.dart';
import '../../features/community_reports/presentation/community_reports_screen.dart';
import '../../features/tourist_traps/presentation/tourist_traps_screen.dart';
import '../../features/roadmap/presentation/roadmap_screen.dart';
import '../models/ai_price_models.dart';
import '../models/roadmap_models.dart';
import '../widgets/main_shell_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [

    // Bottom Navigation Shell with exactly 3 tabs: Home, Map, Profile
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainShellScreen(navigationShell: navigationShell);
      },
      branches: [
        // Tab 1: Home
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          ],
        ),
        // Tab 2: Explore (replaces in-app Map)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/explore',
              builder: (context, state) => const ExploreScreen(),
            ),
            GoRoute(path: '/map', redirect: (context, state) => '/explore'),
          ],
        ),
        // Tab 3: Profile
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),

    // Full screen routes pushed on top of the root navigator (outside bottom tabs)
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/airport-fares',
      builder: (context, state) => const AirportPrepaidFaresScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/place/:id',
      builder: (context, state) {
        final placeId = state.pathParameters['id'] ?? 'plc_1';
        return PlaceGuideScreen(placeId: placeId);
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/fair-price-checker',
      builder: (context, state) {
        if (state.extra is Map<String, dynamic>) {
          final m = state.extra as Map<String, dynamic>;
          return CheckPriceInputScreen(
            initialPickupName: m['pickup'] as String?,
            initialDropName: (m['drop'] ?? m['destination']) as String?,
            initialQuotedPrice: (m['quotedPrice'] as num?)?.toDouble(),
            initialServiceType: m['serviceType'] as ServiceType?,
          );
        }
        final initialPlaceName = state.extra as String?;
        return CheckPriceInputScreen(initialPlaceName: initialPlaceName);
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/check-price',
      builder: (context, state) {
        if (state.extra is Map<String, dynamic>) {
          final m = state.extra as Map<String, dynamic>;
          return CheckPriceInputScreen(
            initialPickupName: m['pickup'] as String?,
            initialDropName: (m['drop'] ?? m['destination']) as String?,
            initialQuotedPrice: (m['quotedPrice'] as num?)?.toDouble(),
            initialServiceType: m['serviceType'] as ServiceType?,
          );
        }
        final initialPlaceName = state.extra as String?;
        return CheckPriceInputScreen(initialPlaceName: initialPlaceName);
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/ride-mode',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return RideModeScreen(
          initialOrigin: extra?['origin'] as String?,
          initialDestination: extra?['destination'] as String?,
          quotedPrice: (extra?['quotedPrice'] as num?)?.toDouble(),
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/verify-driver',
      builder: (context, state) => const VerifyDriverScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/report-scam',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return CommunityReportsScreen(initialData: extra);
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/community-reports',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return CommunityReportsScreen(initialData: extra);
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/tourist-traps',
      builder: (context, state) => const TouristTrapsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/business/onboarding',
      builder: (context, state) => const BusinessOnboardingScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/roadmap',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final origin = extra?['origin'] as RoadmapLocation?;
        final destination =
            extra?['destination'] as RoadmapLocation? ??
            const RoadmapLocation(
              name: 'Hawa Mahal',
              formattedAddress:
                  'Badi Choupad, J.D.A. Market, Pink City, Jaipur',
              lat: 26.9239,
              lng: 75.8267,
            );
        final preference = extra?['preference'] as String? ?? 'Fastest';
        return RoadmapScreen(
          initialOrigin: origin,
          initialDestination: destination,
          preference: preference,
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/business/profile/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? 'biz_1';
        return BusinessProfileScreen(businessId: id);
      },
    ),
  ],
);
