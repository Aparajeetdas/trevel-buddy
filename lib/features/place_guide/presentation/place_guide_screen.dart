import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/local_data_repository.dart';
import '../../../core/models/app_models.dart';
import '../../../core/services/map_launcher_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_brand_app_bar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../ask_buddy/presentation/ask_buddy_sheet.dart';
import 'widgets/place_bottom_bar.dart';
import 'widgets/place_gallery_header.dart';
import 'widgets/place_pricing_sections.dart';
import 'widgets/place_reviews_and_businesses.dart';
import 'widgets/place_scam_section.dart';
import 'widgets/place_transport_section.dart';

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
    final placesAsync = ref.watch(placesFutureProvider);

    return placesAsync.when(
      loading: () => const Scaffold(
        appBar: AppBrandAppBar(showBackButton: true),
        body: SkeletonLoader(count: 4),
      ),
      error: (err, _) => Scaffold(
        appBar: const AppBrandAppBar(showBackButton: true),
        body: ErrorState(
          message: 'Failed to load place guide: $err',
          onRetry: () => ref.invalidate(placesFutureProvider),
        ),
      ),
      data: (places) {
        final place = places.cast<Place?>().firstWhere(
          (p) => p?.id == widget.placeId,
          orElse: () => null,
        );

        if (place == null) {
          return Scaffold(
            appBar: const AppBrandAppBar(showBackButton: true),
            body: EmptyState(
              icon: Icons.location_off_rounded,
              title: 'Place Not Found',
              message: 'The requested guide could not be located in seed data.',
              buttonLabel: 'Back to Home',
              onAction: () => context.go('/'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBrandAppBar(
            title: place.name,
            showBackButton: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.map_rounded, color: AppColors.primary),
                tooltip: 'Open in Map',
                onPressed: () {
                  ref
                      .read(mapLauncherServiceProvider)
                      .openPlace(
                        name: place.name,
                        lat: place.latitude,
                        lng: place.longitude,
                        context: context,
                      );
                },
              ),
              IconButton(
                icon: const Icon(
                  Icons.smart_toy_rounded,
                  color: AppColors.primary,
                ),
                tooltip: 'Ask Buddy Guide',
                onPressed: () => AskBuddySheet.show(context, place: place.name),
              ),
              IconButton(
                icon: Icon(
                  _isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
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
              IconButton(
                icon: const Icon(Icons.share_rounded),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Guide link copied to clipboard!'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
          bottomNavigationBar: PlaceBottomBar(
            place: place,
            isSaved: _isSaved,
            onToggleSave: () {
              setState(() => _isSaved = !_isSaved);
            },
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              // 1. Photo Gallery & 2. Rating & Best Time to Visit
              PlaceGalleryHeader(place: place),

              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero Action: Check a Price Button
                    _buildCheckPriceButton(context, place),
                    const SizedBox(height: AppSpacing.lg),

                    // 3. Scam Risk Badge & Common Scams
                    PlaceScamSection(place: place),
                    const SizedBox(height: AppSpacing.lg),

                    // 4. How to Get There (Transport Options)
                    PlaceTransportSection(place: place),
                    const SizedBox(height: AppSpacing.lg),

                    // 5. Route Warnings, 6. Food Prices, 7. Stay Prices
                    PlacePricingSections(place: place),
                    const SizedBox(height: AppSpacing.lg),

                    // 8. Reviews & 9. Verified Businesses
                    PlaceReviewsAndBusinessesSection(place: place),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCheckPriceButton(BuildContext context, Place place) {
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
          onTap: () => context.push('/fair-price-checker', extra: place.name),
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
                        'Check a Price Before You Pay',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Instant verdict: Fair, Suspicious, or High Risk',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
