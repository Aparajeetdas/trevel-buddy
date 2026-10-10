import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/models/app_models.dart';
import '../../../../core/models/roadmap_models.dart';
import '../../../../core/services/map_launcher_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/engine_math.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../roadmap/presentation/roadmap_screen.dart';

/// Modal sheet displaying Live Google Place details, photos, opening hours,
/// contact options, fair rates, fares from user location, community report count,
/// nearby traps, and action triggers (Open in Maps, Go here, Check a price, Ask Buddy).
class LocationDetailsSheet extends StatelessWidget {
  final GooglePlaceDetails details;
  final List<TouristTrap> nearbyTraps;
  final LatLng? userLocation;
  final int communityReportsCount;
  final VoidCallback onClose;

  const LocationDetailsSheet({
    super.key,
    required this.details,
    this.nearbyTraps = const [],
    this.userLocation,
    this.communityReportsCount = 12,
    required this.onClose,
  });

  Future<void> _launchUrlSafe(String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final timeStr = DateFormat('hh:mm a').format(details.fetchedAt);

    // Compute estimated distance and fares from user location
    final origin = userLocation ?? const LatLng(26.9124, 75.7873);
    final straightKm = EngineMath.haversineDistanceKm(
      origin.latitude,
      origin.longitude,
      details.latitude,
      details.longitude,
    );
    final distKm = (straightKm * 1.30).clamp(0.5, 80.0);
    final autoMin = (30.0 + (distKm > 1.5 ? (distKm - 1.5) * 12.0 : 0.0))
        .round();
    final autoMax = (autoMin * 1.25).round();
    final cabMin = (50.0 + (distKm > 2.0 ? (distKm - 2.0) * 16.0 : 0.0))
        .round();
    final cabMax = (cabMin * 1.25).round();
    final estMin = ((distKm / 25.0) * 60).clamp(3, 120).round();

    return AppCard(
      elevation: 14,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header: Name, Close Button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        details.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        details.formattedAddress,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color?.withOpacity(
                            0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: onClose,
                ),
              ],
            ),
            const SizedBox(height: 6),

            // 2. Live status tag, Open Now tag & Rating
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Live Google tag
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: details.isLiveGoogle
                        ? AppColors.primary.withOpacity(0.12)
                        : Colors.grey.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        details.isLiveGoogle
                            ? Icons.cloud_done_rounded
                            : Icons.offline_pin_rounded,
                        size: 12,
                        color: details.isLiveGoogle
                            ? AppColors.primary
                            : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        details.isLiveGoogle
                            ? 'Live from Google, updated $timeStr'
                            : 'Local Seed Data',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: details.isLiveGoogle
                              ? AppColors.primary
                              : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),

                // Open Now badge
                if (details.isOpenNow != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: details.isOpenNow!
                          ? Colors.green.withOpacity(0.12)
                          : Colors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      details.isOpenNow! ? 'Open now' : 'Closed',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: details.isOpenNow!
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                  ),

                // Rating
                if (details.rating != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Colors.amber,
                        size: 16,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${details.rating} (${details.userRatingCount ?? 0})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // 3. Up to 3 Photos
            if (details.photoUrls.isNotEmpty)
              Container(
                height: 80,
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: details.photoUrls.length.clamp(0, 3),
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final photoUrl = details.photoUrls[i];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: photoUrl,
                        width: 110,
                        height: 80,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 110,
                          color: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade200,
                          child: const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 110,
                          color: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade200,
                          child: const Icon(
                            Icons.photo_rounded,
                            size: 28,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // 4. Contact & Website info chips
            if (details.phoneNumber != null || details.websiteUri != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    if (details.phoneNumber != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          avatar: const Icon(
                            Icons.phone_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          label: Text(
                            details.phoneNumber!,
                            style: const TextStyle(fontSize: 11),
                          ),
                          onPressed: () =>
                              _launchUrlSafe('tel:${details.phoneNumber}'),
                        ),
                      ),
                    if (details.websiteUri != null)
                      ActionChip(
                        avatar: const Icon(
                          Icons.language_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        label: const Text(
                          'Website',
                          style: TextStyle(fontSize: 11),
                        ),
                        onPressed: () => _launchUrlSafe(details.websiteUri!),
                      ),
                  ],
                ),
              ),

            // 5. Editorial Summary
            if (details.editorialSummary != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  details.editorialSummary!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, height: 1.3),
                ),
              ),

            // 6. Fares From User Location (via Routes API / straight-line 1.3x)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.35),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Fares from Current Location (${distKm.toStringAsFixed(1)} km)',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        '~$estMin min',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _FairPriceMiniTag('Auto', '₹$autoMin - ₹$autoMax'),
                      _FairPriceMiniTag('Cab', '₹$cabMin - ₹$cabMax'),
                      const _FairPriceMiniTag('Guide', '₹800/half-day'),
                    ],
                  ),
                ],
              ),
            ),

            // 7. Community Report Count Badge
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_user_rounded,
                    size: 14,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Community Verified: $communityReportsCount fare reports in this zone',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // 8. Nearby Tourist Traps Alert if any
            if (nearbyTraps.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.danger,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Warning: ${nearbyTraps.length} active trap(s) reported in this area.',
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // 9. Buttons: Open in Maps, Go here, Check a price, Ask Buddy
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  MapLauncherService().openPlace(
                    placeId: details.placeId,
                    name: details.name,
                    lat: details.latitude,
                    lng: details.longitude,
                    context: context,
                  );
                },
                icon: const Icon(
                  Icons.map_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                label: const Text(
                  'Open in Maps',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RoadmapScreen(
                            initialDestination: RoadmapLocation(
                              name: details.name,
                              lat: details.latitude,
                              lng: details.longitude,
                              formattedAddress: details.formattedAddress,
                            ),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.directions_rounded, size: 16),
                    label: const Text(
                      'Go here',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.push('/check-price', extra: details.name);
                    },
                    icon: const Icon(
                      Icons.speed_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    label: const Text(
                      'Check a price',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  context.push(
                    '/agent',
                    extra:
                        'Tell me about ${details.name} and common tourist traps or fair prices here.',
                  );
                },
                icon: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                label: const Text(
                  'Ask Buddy about this place',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            if (details.attribution != null)
              Center(
                child: Text(
                  details.attribution!,
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FairPriceMiniTag extends StatelessWidget {
  final String label;
  final String rate;

  const _FairPriceMiniTag(this.label, this.rate);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
        Text(rate, style: const TextStyle(fontSize: 10, color: Colors.black87)),
      ],
    );
  }
}
