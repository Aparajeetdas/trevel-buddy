import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/community_repository.dart';
import '../../../core/models/app_models.dart';
import '../../../core/models/roadmap_models.dart';
import '../../../core/services/google_maps_service.dart';
import '../../../core/services/map_launcher_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/engine_math.dart';
import '../../../core/widgets/app_brand_app_bar.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_places_search_bar.dart';
import '../../../core/widgets/ask_buddy_floating_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../roadmap/presentation/roadmap_screen.dart';
import 'widgets/location_details_sheet.dart';

final exploreCategoryPlacesProvider =
    FutureProvider.family<List<GooglePlaceDetails>, ({String category, String city, LatLng? center})>(
  (ref, arg) async {
    final mapsService = ref.read(googleMapsServiceProvider);
    return mapsService.textSearch(
      '${arg.category} in ${arg.city}',
      biasCenter: arg.center,
      maxResultCount: 8,
    );
  },
);

/// Explore Screen: Discover places, external Google Map navigation,
/// paste/import Google Maps short-links, and area scams & price insights.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final TextEditingController _linkController = TextEditingController();
  bool _isResolvingLink = false;
  int _selectedCategoryIndex = 0;

  final List<_CategoryData> _categories = const [
    _CategoryData(
      label: 'Restaurants',
      icon: Icons.restaurant_rounded,
      fairNote: 'Typical thali ₹150 - ₹350 • Avoid tout-recommended eateries',
      queryType: 'restaurant',
      priceLevel: '₹₹',
    ),
    _CategoryData(
      label: 'Cafes',
      icon: Icons.local_cafe_rounded,
      fairNote: 'Chai ₹15 - ₹40 • Filter coffee ₹30 - ₹70 • No cover charges',
      queryType: 'cafe',
      priceLevel: '₹',
    ),
    _CategoryData(
      label: 'Hotels',
      icon: Icons.hotel_rounded,
      fairNote:
          'Standard AC room ₹1,200 - ₹2,500/night • Insist on tax invoice',
      queryType: 'hotel',
      priceLevel: '₹₹₹',
    ),
    _CategoryData(
      label: 'Attractions',
      icon: Icons.fort_rounded,
      fairNote:
          'Official entry ₹50 - ₹500 • Certified ASI guide ₹800/half-day max',
      queryType: 'tourist_attraction',
      priceLevel: '₹₹',
    ),
    _CategoryData(
      label: 'Taxi stands',
      icon: Icons.local_taxi_rounded,
      fairNote: 'Use government prepaid booth • Always demand printed slip',
      queryType: 'taxi_stand',
      priceLevel: '₹₹',
    ),
    _CategoryData(
      label: 'Transport hubs',
      icon: Icons.directions_transit_rounded,
      fairNote: 'Auto ₹30 base + ₹12/km • Beware of "hotel closed" diversions',
      queryType: 'transit_station',
      priceLevel: '₹',
    ),
    _CategoryData(
      label: 'Hospitals',
      icon: Icons.local_hospital_rounded,
      fairNote: 'Govt Emergency: 108 • 24x7 Jan Aushadhi generic pharmacy',
      queryType: 'hospital',
      priceLevel: '₹',
    ),
    _CategoryData(
      label: 'ATMs',
      icon: Icons.atm_rounded,
      fairNote: 'Use bank branch ATMs inside guarded lobbies • Check card slot',
      queryType: 'atm',
      priceLevel: '₹',
    ),
  ];

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _resolvePastedLink() async {
    final link = _linkController.text.trim();
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste a Google Maps link first')),
      );
      return;
    }

    setState(() => _isResolvingLink = true);
    final mapsService = ref.read(googleMapsServiceProvider);

    try {
      final details = await mapsService.resolveLink(link);
      if (!mounted) return;
      setState(() => _isResolvingLink = false);

      if (details != null) {
        _linkController.clear();
        _openLocationDetailsModal(details);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not resolve link. Please verify it is a valid Google Maps URL.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isResolvingLink = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network error connecting to resolution proxy.'),
        ),
      );
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!mounted) return;
    if (text.isNotEmpty) {
      _linkController.text = text;
      setState(() {});
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Clipboard is empty')));
    }
  }

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
          userLocation: ref.read(activeCityProvider)?.center,
          communityReportsCount: 18,
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCity = ref.watch(activeCityProvider);
    final areaInsightsAsync = ref.watch(areaInsightsFutureProvider);
    final mapLauncher = ref.watch(mapLauncherServiceProvider);
    final selectedCategory = _categories[_selectedCategoryIndex];

    final categoryPlacesAsync = activeCity != null
        ? ref.watch(
            exploreCategoryPlacesProvider((
              category: selectedCategory.label,
              city: activeCity.name,
              center: activeCity.center,
            )),
          )
        : null;

    final userPos = activeCity?.center ?? const LatLng(0, 0);

    return Scaffold(
      appBar: const AppBrandAppBar(title: 'Explore & Google Maps'),
      floatingActionButton: const AskBuddyFloatingButton(place: 'Guwahati'),
      body: CustomScrollView(
        slivers: [
          // ==========================================
          // 1. SEARCH BAR & PLACES AUTOCOMPLETE
          // ==========================================
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (activeCity != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_city_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Active City: ${activeCity.name}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => ref
                                  .read(activeCityProvider.notifier)
                                  .clearActiveCity(),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  AppPlacesSearchBar(
                    hintText: activeCity != null
                        ? 'Search in ${activeCity.name} or worldwide...'
                        : 'Search city, landmark or monument worldwide...',
                    showRecentsInitially: true,
                    biasCenter:
                        activeCity?.center ?? const LatLng(26.9124, 75.7873),
                    onCitySelected: (cityDetails) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Active city set to ${cityDetails.name}',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    onPlaceSelected: (details) {
                      _openLocationDetailsModal(details);
                    },
                  ),
                ],
              ),
            ),
          ),

          // ==========================================
          // 2. CATEGORY CHIPS & NEARBY PLACES
          // ==========================================
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 8 Horizontal Category Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Row(
                      children: List.generate(_categories.length, (index) {
                        final cat = _categories[index];
                        final isSelected = _selectedCategoryIndex == index;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            avatar: Icon(
                              cat.icon,
                              size: 16,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.primary,
                            ),
                            label: Text(cat.label),
                            selected: isSelected,
                            onSelected: (_) =>
                                setState(() => _selectedCategoryIndex = index),
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : null,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  // Fair-Price Note Banner for Selected Category
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      0,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedCategory.fairNote,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Category Places Cards
          if (activeCity == null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: EmptyState(
                  icon: Icons.location_city_rounded,
                  title: 'Select a City to Explore',
                  message:
                      'Choose a city above or tap "Use my location" to discover local places and fair prices.',
                  buttonLabel: 'Search Cities',
                  onAction: () {},
                ),
              ),
            )
          else if (categoryPlacesAsync != null)
            categoryPlacesAsync.when(
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
                      exploreCategoryPlacesProvider((
                        category: selectedCategory.label,
                        city: activeCity.name,
                        center: activeCity.center,
                      )),
                    ),
                  ),
                ),
              ),
              data: (places) {
                if (places.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No places found',
                        message:
                            'No ${selectedCategory.label} found in ${activeCity.name}. Try another category or search above.',
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final place = places[index];
                      final distKm = EngineMath.haversineDistanceKm(
                        userPos.latitude,
                        userPos.longitude,
                        place.latitude,
                        place.longitude,
                      );
                      final photoUrl = place.photoUrls.isNotEmpty
                          ? place.photoUrls.first
                          : null;

                      return Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () => _openLocationDetailsModal(place),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: photoUrl != null
                                          ? Image.network(
                                              photoUrl,
                                              width: 68,
                                              height: 68,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) =>
                                                  Container(
                                                width: 68,
                                                height: 68,
                                                color: Colors.grey.shade300,
                                                child: const Icon(
                                                  Icons.place_rounded,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            )
                                          : Container(
                                              width: 68,
                                              height: 68,
                                              color: Colors.grey.shade300,
                                              child: const Icon(
                                                Icons.place_rounded,
                                                color: Colors.grey,
                                              ),
                                            ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  place.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (place.isOpenNow == true)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green
                                                        .withOpacity(0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(4),
                                                  ),
                                                  child: const Text(
                                                    'Open now',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.green,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          Text(
                                            '${place.formattedAddress} • ${distKm.toStringAsFixed(1)} km away',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              if (place.rating != null) ...[
                                                const Icon(
                                                  Icons.star_rounded,
                                                  color: Colors.amber,
                                                  size: 14,
                                                ),
                                                const SizedBox(width: 2),
                                                Text(
                                                  '${place.rating} (${place.userRatingCount ?? 0})',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                              ],
                                              Text(
                                                selectedCategory.priceLevel,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 11,
                                                  color: Colors.teal,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              // 3 Buttons: Open in Maps, Go here, Check a price
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        mapLauncher.openPlace(
                                          placeId: place.placeId,
                                          name: place.name,
                                          lat: place.latitude,
                                          lng: place.longitude,
                                          context: context,
                                        );
                                      },
                                      icon: const Icon(Icons.map_rounded, size: 14),
                                      label: const Text(
                                        'Open in Maps',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => RoadmapScreen(
                                              initialDestination: RoadmapLocation(
                                                placeId: place.placeId,
                                                name: place.name,
                                                lat: place.latitude,
                                                lng: place.longitude,
                                                formattedAddress:
                                                    place.formattedAddress,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.directions_rounded,
                                        size: 14,
                                      ),
                                      label: const Text(
                                        'Go here',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        context.push(
                                          '/check-price',
                                          extra: place.name,
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.speed_rounded,
                                        size: 14,
                                        color: AppColors.primary,
                                      ),
                                      label: const Text(
                                        'Check price',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }, childCount: places.length),
                  ),
                );
              },
            ),

          // ==========================================
          // 3. IMPORT FROM GOOGLE MAPS CARD
          // ==========================================
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: AppCard(
                elevation: 4,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add_link_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Import from Google Maps',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Paste maps.app.goo.gl, goo.gl or google.com/maps link',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _linkController,
                      decoration: InputDecoration(
                        hintText: 'https://maps.app.goo.gl/...',
                        prefixIcon: const Icon(Icons.link_rounded, size: 18),
                        suffixIcon: IconButton(
                          icon: const Icon(
                            Icons.content_paste_rounded,
                            size: 18,
                          ),
                          tooltip: 'Paste from clipboard',
                          onPressed: _pasteFromClipboard,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isResolvingLink
                                ? null
                                : _resolvePastedLink,
                            icon: _isResolvingLink
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.search_rounded, size: 16),
                            label: Text(
                              _isResolvingLink
                                  ? 'Resolving via Proxy...'
                                  : 'Inspect & Resolve Link',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.share_rounded,
                          size: 12,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Android Share: Tap "Share" inside Google Maps and select Travel Buddy to inspect instantly.',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ==========================================
          // 4. AREA INSIGHTS LIST (SCAM & PRICE INTEL)
          // ==========================================
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Area Intelligence & Scam Alerts',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Last 90 Days',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          areaInsightsAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (err, stack) =>
                const SliverToBoxAdapter(child: SizedBox.shrink()),
            data: (allInsights) {
              // Hide areas with < 3 reports per specification
              final validInsights = allInsights
                  .where((a) => a.complaintCount90d >= 3)
                  .toList();

              return SliverPadding(
                padding: const EdgeInsets.all(AppSpacing.md),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final area = validInsights[index];
                    final isHighRisk = area.priceIndex > 1.5;

                    return Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    area.areaName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isHighRisk
                                        ? AppColors.danger.withOpacity(0.12)
                                        : Colors.orange.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${area.priceIndex}x Avg Markup',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: isHighRisk
                                          ? AppColors.danger
                                          : Colors.orange.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.report_problem_rounded,
                                  size: 13,
                                  color: Colors.grey.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${area.complaintCount90d} community complaints in last 90 days',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Top Traps
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: area.topTrapTypes.map((trap) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.danger.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    trap,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.danger,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 8),
                            // Safer Alternatives
                            if (area.saferAlternatives.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.green.withOpacity(0.2),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline_rounded,
                                          size: 12,
                                          color: Colors.green,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Safer Alternatives:',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    ...area.saferAlternatives.map(
                                      (alt) => Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          '• $alt',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            height: 1.2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: AppSpacing.sm),
                            // Open In Maps button
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  mapLauncher.openPlace(
                                    name: area.areaName,
                                    lat: area.centerLat,
                                    lng: area.centerLng,
                                    context: context,
                                  );
                                },
                                icon: const Icon(Icons.map_rounded, size: 14),
                                label: const Text(
                                  'Open in Google Maps',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }, childCount: validInsights.length),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryData {
  final String label;
  final IconData icon;
  final String fairNote;
  final String queryType;
  final String priceLevel;

  const _CategoryData({
    required this.label,
    required this.icon,
    required this.fairNote,
    required this.queryType,
    required this.priceLevel,
  });
}
