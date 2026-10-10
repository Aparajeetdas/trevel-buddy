import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/app_models.dart';
import '../../../../core/models/roadmap_models.dart';
import '../../../../core/services/map_launcher_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../roadmap/presentation/roadmap_screen.dart';

class PlaceBottomBar extends StatelessWidget {
  final Place place;
  final bool isSaved;
  final VoidCallback onToggleSave;

  const PlaceBottomBar({
    super.key,
    required this.place,
    required this.isSaved,
    required this.onToggleSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          top: BorderSide(
            color: theme.brightness == Brightness.dark
                ? AppColors.outlineDark
                : AppColors.outlineLight,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Save Bookmark Button
            IconButton.outlined(
              tooltip: isSaved ? 'Remove bookmark' : 'Save guide',
              icon: Icon(
                isSaved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: isSaved ? AppColors.primary : null,
              ),
              onPressed: onToggleSave,
            ),
            const SizedBox(width: AppSpacing.xs),

            // Fair Price Quick Checker Action
            IconButton.outlined(
              tooltip: 'Check fair price before paying',
              icon: const Icon(Icons.speed_rounded, color: AppColors.primary),
              onPressed: () =>
                  context.push('/fair-price-checker', extra: place.name),
            ),
            const SizedBox(width: AppSpacing.xs),

            // Open in Map Action
            IconButton.outlined(
              tooltip: 'Open in Map',
              icon: const Icon(Icons.map_rounded, color: AppColors.primary),
              onPressed: () {
                MapLauncherService().openPlace(
                  name: place.name,
                  lat: place.latitude,
                  lng: place.longitude,
                  context: context,
                );
              },
            ),
            const SizedBox(width: AppSpacing.sm),

            // Go Here Button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RoadmapScreen(
                        initialDestination: RoadmapLocation(
                          name: place.name,
                          lat: place.latitude,
                          lng: place.longitude,
                        ),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.directions_rounded),
                label: const Text(
                  'Go here',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
