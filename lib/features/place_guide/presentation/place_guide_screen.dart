import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/community_repository.dart';
import '../../../core/data/tariff_repository.dart';
import '../../../core/models/app_models.dart';
import '../../../core/models/roadmap_models.dart';
import '../../../core/services/google_maps_service.dart';
import '../../../core/services/map_launcher_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/engine_math.dart';
import '../../../core/widgets/app_brand_app_bar.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../ask_buddy/presentation/ask_buddy_sheet.dart';

final placeGuideDetailsProvider =
    FutureProvider.family<GooglePlaceDetails, String>((ref, placeId) async {
      if (placeId.trim().isEmpty) {
        throw Exception('Place ID is missing');
      }
      final mapsService = ref.read(googleMapsServiceProvider);
      return mapsService.getPlaceDetails(placeId);
    });

class PlaceGuideScreen extends ConsumerStatefulWidget {
  final String placeId;

  const PlaceGuideScreen({super.key, required this.placeId});

  @override
  ConsumerState<PlaceGuideScreen> createState() => _PlaceGuideScreenState();
}

class _PlaceGuideScreenState extends ConsumerState<PlaceGuideScreen> {
  bool _isSaved = false;

  @override
  Widget build(BuildContext context) {
    if (widget.placeId.isEmpty) {
      return Scaffold(
        appBar: const AppBrandAppBar(showBackButton: true),
        body: EmptyState(
          icon: Icons.location_off_rounded,
          title: 'No Place Selected',
          message: 'Please search or select a destination to view its live guide.',
          buttonLabel: 'Back to Home',
          onAction: () => context.go('/'),
        ),
      );
    }

    final detailsAsync = ref.watch(placeGuideDetailsProvider(widget.placeId));
    final traps = ref.watch(touristTrapsFutureProvider).value ?? [];
    final tariffs = ref.watch(tariffsFutureProvider).value ?? [];

    return detailsAsync.when(
      loading: () => const Scaffold(
        appBar: AppBrandAppBar(showBackButton: true),
        body: SkeletonLoader(count: 4),
      ),
      error: (err, _) => Scaffold(
        appBar: const AppBrandAppBar(showBackButton: true),
        body: ErrorState(
          message: 'Could not load guide for this location: $err',
          onRetry: () => ref.invalidate(placeGuideDetailsProvider(widget.placeId)),
        ),
      ),
      data: (details) {
        // Find nearby tourist traps within 4km
        final nearbyTraps = traps.where((t) {
          final d = EngineMath.haversineDistanceKm(
            details.latitude,
            details.longitude,
            t.latitude,
            t.longitude,
          );
          return d <= 4.0;
        }).toList();

        // Check if near LGBI Airport (Guwahati)
        final distToAirport = EngineMath.haversineDistanceKm(
          details.latitude,
          details.longitude,
          26.1061,
          91.5859,
        );
        final isNearAirport = distToAirport <= 35.0 ||
            details.formattedAddress.toLowerCase().contains('guwahati') ||
            details.name.toLowerCase().contains('guwahati');

        return Scaffold(
          appBar: AppBrandAppBar(
            title: details.name,
            showBackButton: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.map_rounded, color: AppColors.primary),
                tooltip: 'Open in Map',
                onPressed: () {
                  ref.read(mapLauncherServiceProvider).openPlace(
                    name: details.name,
                    lat: details.latitude,
                    lng: details.longitude,
                    context: context,
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.smart_toy_rounded, color: AppColors.primary),
                tooltip: 'Ask Buddy Guide',
                onPressed: () => AskBuddySheet.show(context, place: details.name),
              ),
              IconButton(
                icon: Icon(
                  _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: _isSaved ? AppColors.primary : null,
                ),
                onPressed: () {
                  setState(() => _isSaved = !_isSaved);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _isSaved ? 'Saved to guides' : 'Removed from saved',
                      ),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
          bottomNavigationBar: _buildBottomBar(context, details),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              // Photo Header
              _buildPhotoHeader(details),

              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick Action: Check Fair Price
                    _buildCheckPriceButton(context, details),
                    const SizedBox(height: AppSpacing.lg),

                    // Airport Pre-paid Fares Banner if relevant
                    if (isNearAirport) ...[
                      _buildAirportBanner(context),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    // Safety Radar & Nearby Traps
                    _buildScamRadarSection(nearbyTraps),
                    const SizedBox(height: AppSpacing.lg),

                    // Local Transport & Pricing Intelligence
                    _buildPriceIntelligenceSection(details, tariffs),
                    const SizedBox(height: AppSpacing.lg),

                    // Opening Hours & Details
                    _buildPlaceInfoSection(details),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPhotoHeader(GooglePlaceDetails details) {
    final photo = details.photoUrls.isNotEmpty ? details.photoUrls.first : null;

    return Container(
      height: 240,
      width: double.infinity,
      color: Colors.black12,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photo != null)
            Image.network(
              photo,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _buildPlaceholderPhoto(details),
            )
          else
            _buildPlaceholderPhoto(details),
          // Gradient Scrim
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.2),
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
          ),
          // Title & Rating Overlay
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  details.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (details.rating != null) ...[
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '${details.rating} (${details.userRatingCount ?? 0} ratings)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (details.isOpenNow != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: details.isOpenNow == true
                              ? AppColors.success.withOpacity(0.9)
                              : AppColors.danger.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          details.isOpenNow == true ? 'OPEN NOW' : 'CLOSED',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                if (details.attribution != null && details.attribution!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      details.attribution!,
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderPhoto(GooglePlaceDetails details) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.place_rounded, size: 64, color: Colors.white70),
      ),
    );
  }

  Widget _buildCheckPriceButton(BuildContext context, GooglePlaceDetails details) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () => context.push('/fair-price-checker', extra: details.name),
          child: const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 14,
            ),
            child: Row(
              children: [
                Icon(Icons.speed_rounded, color: Colors.white, size: 28),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Check Fair Price Before You Pay',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Instant benchmark: Fair rate, Suspicious, or High Risk',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAirportBanner(BuildContext context) {
    return AppCard(
      color: const Color(0xFF1E3A8A),
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => context.push('/airport-fares'),
      child: const Row(
        children: [
          Icon(Icons.local_taxi_rounded, color: Colors.white, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Airport Prepaid Taxi Fares Available',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Official LGBI Airport fixed rates to Guwahati, Shillong & regional points.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildScamRadarSection(List<TouristTrap> traps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.shield_rounded, color: AppColors.danger, size: 20),
            const SizedBox(width: 8),
            Text(
              'Safety Radar & Nearby Warnings (${traps.length})',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (traps.isEmpty)
          const AppCard(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(Icons.verified_rounded, color: AppColors.success),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No active tourist traps reported near this location. Always negotiate upfront or request the official meter.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          )
        else
          ...traps.take(3).map((trap) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.dangerContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          trap.type.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Severity ${trap.severity}/5',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    trap.description,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  if (trap.avoidTip.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '💡 Avoid tip: ${trap.avoidTip}',
                        style: const TextStyle(fontSize: 12, color: AppColors.primary),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPriceIntelligenceSection(
    GooglePlaceDetails details,
    List<GovTariff> tariffs,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.payments_rounded, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text(
              'Price Intelligence & Tariffs',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                details.formattedAddress,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              const Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Auto Rickshaw', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('₹30 base + ₹12/km', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sedan / Cab', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('₹50 base + ₹16/km', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceInfoSection(GooglePlaceDetails details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.info_rounded, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text(
              'About & Operating Hours',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (details.editorialSummary != null) ...[
                Text(
                  details.editorialSummary!,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 10),
              ],
              if (details.weekdayDescriptions.isNotEmpty) ...[
                const Text(
                  'Hours:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 4),
                ...details.weekdayDescriptions.map(
                  (d) => Text(d, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, GooglePlaceDetails details) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  ref.read(mapLauncherServiceProvider).openPlace(
                    name: details.name,
                    lat: details.latitude,
                    lng: details.longitude,
                    context: context,
                  );
                },
                icon: const Icon(Icons.navigation_rounded, size: 16),
                label: const Text('Open in Maps'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  context.push(
                    '/roadmap',
                    extra: {
                      'destination': RoadmapLocation(
                        placeId: details.placeId,
                        name: details.name,
                        formattedAddress: details.formattedAddress,
                        lat: details.latitude,
                        lng: details.longitude,
                      ),
                    },
                  );
                },
                icon: const Icon(Icons.alt_route_rounded, size: 16),
                label: const Text('Plan Roadmap'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
