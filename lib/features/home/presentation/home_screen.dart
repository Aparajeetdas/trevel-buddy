import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/community_repository.dart';
import '../../../core/data/local_data_repository.dart';
import '../../../core/models/app_models.dart';
import '../../../core/services/google_maps_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/engine_math.dart';
import '../../../core/widgets/app_brand_app_bar.dart';
import '../../../core/widgets/ask_buddy_floating_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../explore/presentation/widgets/location_details_sheet.dart';
import 'widgets/home_hero_search_bar.dart';
import 'widgets/home_place_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All',
    'Best places',
    'Viewpoints',
    'Nearby',
    'Budget',
  ];

  void _openLocationDetailsModal(GooglePlaceDetails details) {
    final traps = ref.read(touristTrapsFutureProvider).value ?? [];
    final nearbyTraps = traps.where((t) {
      final d = EngineMath.haversineDistanceKm(
        details.latitude,
        details.longitude,
        t.latitude,
        t.longitude,
      );
      return d <= 3.0;
    }).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: LocationDetailsSheet(
          details: details,
          nearbyTraps: nearbyTraps,
          userLocation: const LatLng(26.9124, 75.7873),
          communityReportsCount: 18,
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final placesAsync = ref.watch(placesFutureProvider);
    final activeCity = ref.watch(activeCityProvider);

    // Check if active city is Guwahati or user location is near LGBI Airport (26.1061, 91.5859)
    final isGuwahatiCity = activeCity?.name.toLowerCase().contains('guwahati') ?? false;
    final distToAirport = activeCity != null
        ? EngineMath.haversineDistanceKm(
            activeCity.centerLat,
            activeCity.centerLng,
            26.1061,
            91.5859,
          )
        : double.infinity;
    final isNearAirport = isGuwahatiCity || distToAirport <= 30.0;

    return Scaffold(
      appBar: const AppBrandAppBar(),
      floatingActionButton: const AskBuddyFloatingButton(place: 'Jaipur'),
      body: placesAsync.when(
        loading: () => const SkeletonLoader(count: 3),
        error: (err, stack) => ErrorState(
          message: 'Unable to load destinations: $err',
          onRetry: () => ref.invalidate(placesFutureProvider),
        ),
        data: (places) {
          final featuredPlaces = places.where((place) {
            final matchesFilter =
                _selectedFilter == 'All' ||
                place.category.toLowerCase() == _selectedFilter.toLowerCase();
            return matchesFilter;
          }).toList();

          return CustomScrollView(
            slivers: [
              // Hero Search & Global Google Places Search Bar
              SliverToBoxAdapter(
                child: HomeHeroSearchBar(
                  onPlaceSelected: _openLocationDetailsModal,
                  selectedFilter: _selectedFilter,
                  onFilterSelected: (val) {
                    setState(() => _selectedFilter = val);
                  },
                  filters: _filters,
                ),
              ),

              // Airport Taxi Fares Card (Shown when in Guwahati or near LGBI airport)
              if (isNearAirport)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xs,
                      AppSpacing.md,
                      AppSpacing.sm,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withOpacity(0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => context.push('/airport-fares'),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.local_taxi_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.25),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'OFFICIAL TARIFF',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Airport Taxi Fares',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'LGBI Airport pre-paid rates to Guwahati, Shillong & regional hubs.',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11.5,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Featured Destinations Header
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Featured Destinations',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Empty or Featured Place Cards Feed
              if (featuredPlaces.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No featured destinations',
                    message: 'Select another filter category to view featured destinations.',
                    buttonLabel: 'Reset Filters',
                    onAction: () {
                      setState(() {
                        _selectedFilter = 'All';
                      });
                    },
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return HomePlaceCard(place: featuredPlaces[index]);
                    }, childCount: featuredPlaces.length),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
