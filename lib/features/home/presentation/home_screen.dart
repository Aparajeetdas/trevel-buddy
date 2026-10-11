import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/community_repository.dart';
import '../../../core/models/app_models.dart';
import '../../../core/services/google_maps_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/engine_math.dart';
import '../../../core/widgets/app_brand_app_bar.dart';
import '../../../core/widgets/app_places_search_bar.dart';
import '../../../core/widgets/ask_buddy_floating_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../explore/presentation/widgets/location_details_sheet.dart';
import 'widgets/home_hero_search_bar.dart';
import 'widgets/home_place_card.dart';

/// Provider fetching live popular attractions for the active city
final featuredDestinationsProvider =
    FutureProvider.family<List<GooglePlaceDetails>, ({String city, LatLng center})>(
  (ref, arg) async {
    final mapsService = ref.read(googleMapsServiceProvider);
    return mapsService.textSearch(
      'top attractions in ${arg.city}',
      biasCenter: arg.center,
      maxResultCount: 8,
    );
  },
);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _selectedFilter = 'All';
  bool _isLocating = false;

  final List<String> _filters = [
    'All',
    'Best places',
    'Viewpoints',
    'Nearby',
    'Budget',
  ];

  final List<({String name, double lat, double lng})> _popularCities = const [
    (name: 'Guwahati', lat: 26.1445, lng: 91.7362),
    (name: 'New Delhi', lat: 28.6139, lng: 77.2090),
    (name: 'Mumbai', lat: 19.0760, lng: 72.8777),
    (name: 'Jaipur', lat: 26.9124, lng: 75.7873),
    (name: 'Bengaluru', lat: 12.9716, lng: 77.5946),
    (name: 'Shillong', lat: 25.5788, lng: 91.8933),
    (name: 'Kolkata', lat: 22.5726, lng: 88.3639),
    (name: 'Goa', lat: 15.2993, lng: 74.1240),
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

    final activeCity = ref.read(activeCityProvider);

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
          userLocation: activeCity?.center,
          communityReportsCount: 18,
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Future<void> _handleUseMyLocation() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission denied. Please search or pick a city below.',
              ),
            ),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      ).timeout(const Duration(seconds: 5));

      final mapsService = ref.read(googleMapsServiceProvider);
      final details = await mapsService.reverseGeocode(
        pos.latitude,
        pos.longitude,
      );

      if (details != null && mounted) {
        final city = ActiveCity(
          name: details.name,
          placeId: details.placeId,
          centerLat: details.latitude,
          centerLng: details.longitude,
        );
        await ref.read(activeCityProvider.notifier).setActiveCity(city);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not detect current location. Please choose a city below.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCity = ref.watch(activeCityProvider);

    // If no active city has been chosen yet, show the City Chooser
    if (activeCity == null) {
      return Scaffold(
        appBar: const AppBrandAppBar(),
        body: _buildCityChooser(context),
      );
    }

    // Check if active city is Guwahati or user location is near LGBI Airport (26.1061, 91.5859)
    final isGuwahatiCity =
        activeCity.name.toLowerCase().contains('guwahati');
    final distToAirport = EngineMath.haversineDistanceKm(
      activeCity.centerLat,
      activeCity.centerLng,
      26.1061,
      91.5859,
    );
    final isNearAirport = isGuwahatiCity || distToAirport <= 30.0;

    final featuredAsync = ref.watch(
      featuredDestinationsProvider((
        city: activeCity.name,
        center: activeCity.center,
      )),
    );

    return Scaffold(
      appBar: AppBrandAppBar(
        actions: [
          TextButton.icon(
            onPressed: () {
              ref.read(activeCityProvider.notifier).clearActiveCity();
            },
            icon: const Icon(Icons.location_city_rounded, size: 16),
            label: Text(
              activeCity.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
      floatingActionButton: AskBuddyFloatingButton(place: activeCity.name),
      body: CustomScrollView(
        slivers: [
          // Hero Search Bar with Active City Context
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
                                          borderRadius:
                                              BorderRadius.circular(6),
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

          // Active City Header with Switcher
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Top Attractions in ${activeCity.name}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      ref.read(activeCityProvider.notifier).clearActiveCity();
                    },
                    child: const Text(
                      'Change City',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Live Featured Places Feed
          featuredAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: SkeletonLoader(count: 3),
              ),
            ),
            error: (err, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: ErrorState(
                  message: 'We could not load places right now.',
                  onRetry: () => ref.invalidate(
                    featuredDestinationsProvider((
                      city: activeCity.name,
                      center: activeCity.center,
                    )),
                  ),
                ),
              ),
            ),
            data: (places) {
              if (places.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No attractions found',
                    message:
                        'We could not find places right now in ${activeCity.name}.',
                    buttonLabel: 'Retry',
                    onAction: () => ref.invalidate(
                      featuredDestinationsProvider((
                        city: activeCity.name,
                        center: activeCity.center,
                      )),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final place = places[index];
                    return HomePlaceCard(
                      details: place,
                      isTrending: index == 0,
                      onTap: () => _openLocationDetailsModal(place),
                    );
                  }, childCount: places.length),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCityChooser(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.sm),
          // Heading
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.location_city_rounded,
              size: 32,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Where are you traveling?',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Select your active city to see verified government tariffs, scam radar warnings, and live attractions.',
            style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Search Bar for City
          AppPlacesSearchBar(
            hintText: 'Search any city worldwide...',
            showRecentsInitially: false,
            onPlaceSelected: (details) async {
              final city = ActiveCity(
                name: details.name,
                placeId: details.placeId,
                centerLat: details.latitude,
                centerLng: details.longitude,
              );
              await ref.read(activeCityProvider.notifier).setActiveCity(city);
            },
          ),
          const SizedBox(height: AppSpacing.md),

          // Use My Location Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLocating ? null : _handleUseMyLocation,
              icon: _isLocating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded),
              label: Text(_isLocating ? 'Detecting Location...' : 'Use My Location'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Popular Cities Grid
          const Text(
            'Popular Destinations',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _popularCities.map((city) {
              return ActionChip(
                avatar: const Icon(Icons.place_rounded, size: 16, color: AppColors.primary),
                label: Text(
                  city.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onPressed: () async {
                  final active = ActiveCity(
                    name: city.name,
                    placeId: 'city_${city.name.toLowerCase()}',
                    centerLat: city.lat,
                    centerLng: city.lng,
                  );
                  await ref.read(activeCityProvider.notifier).setActiveCity(active);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
