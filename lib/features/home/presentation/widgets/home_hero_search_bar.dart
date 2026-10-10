import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/app_models.dart';
import '../../../../core/services/google_maps_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_places_search_bar.dart';

class HomeHeroSearchBar extends ConsumerWidget {
  final ValueChanged<GooglePlaceDetails> onPlaceSelected;
  final VoidCallback? onUseMyLocation;
  final String selectedFilter;
  final ValueChanged<String> onFilterSelected;
  final List<String> filters;

  const HomeHeroSearchBar({
    super.key,
    required this.onPlaceSelected,
    this.onUseMyLocation,
    required this.selectedFilter,
    required this.onFilterSelected,
    required this.filters,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activeCity = ref.watch(activeCityProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PROMINENT HERO FEATURE: Check a Price Before You Pay Card
          InkWell(
            onTap: () => context.push('/check-price'),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF0D9488)], // Rich Teal
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0D9488).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.white,
                              size: 12,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'AI PRICE INTELLIGENCE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Check a Price Before You Pay',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Instant verdict: Fair, Suspicious or High Risk. Based on official tariffs, community benchmarks & tourist trap alerts.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.speed_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Check Any Quoted Price Now',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Secondary Quick Actions: Ride Mode & Verify Driver
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => context.push('/ride-mode'),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.sm + 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: theme.brightness == Brightness.dark
                            ? AppColors.outlineDark
                            : AppColors.outlineLight,
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.navigation_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Ride Mode',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: InkWell(
                  onTap: () => context.push('/verify-driver'),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.sm + 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: theme.brightness == Brightness.dark
                            ? AppColors.outlineDark
                            : AppColors.outlineLight,
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_user_rounded,
                          size: 18,
                          color: AppColors.warning,
                        ),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Verify Driver',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
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
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
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

          // Shared Google Places Search Bar
          AppPlacesSearchBar(
            onPlaceSelected: onPlaceSelected,
            onUseMyLocation: onUseMyLocation,
            biasCenter: activeCity?.center,
            hintText: activeCity != null
                ? 'Search places in ${activeCity.name} or worldwide...'
                : 'Search any city, landmark, or place worldwide...',
          ),
          const SizedBox(height: AppSpacing.md),

          // Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.map((filter) {
                final isSelected = selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : null,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        onFilterSelected(filter);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
