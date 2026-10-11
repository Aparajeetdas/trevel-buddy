import 'package:flutter/material.dart';

import '../../../../core/models/roadmap_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../price_checker/presentation/widgets/price_route_autocomplete_field.dart';

/// Top header card for configuring From/To locations, departure time, travelers, and preferences
class RoadmapHeaderCard extends StatelessWidget {
  final TextEditingController originController;
  final TextEditingController destController;
  final VoidCallback onSwap;
  final DateTime departTime;
  final ValueChanged<DateTime> onDepartTimeChanged;
  final int travelers;
  final ValueChanged<int> onTravelersChanged;
  final String selectedPreference;
  final ValueChanged<String> onPreferenceChanged;
  final VoidCallback onRefreshRoute;
  final ValueChanged<RoadmapLocation>? onOriginLocationSelected;
  final ValueChanged<RoadmapLocation>? onDestLocationSelected;

  const RoadmapHeaderCard({
    super.key,
    required this.originController,
    required this.destController,
    required this.onSwap,
    required this.departTime,
    required this.onDepartTimeChanged,
    required this.travelers,
    required this.onTravelersChanged,
    required this.selectedPreference,
    required this.onPreferenceChanged,
    required this.onRefreshRoute,
    this.onOriginLocationSelected,
    this.onDestLocationSelected,
  });

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(departTime),
    );
    if (picked != null) {
      final now = DateTime.now();
      onDepartTimeChanged(
        DateTime(now.year, now.month, now.day, picked.hour, picked.minute),
      );
      onRefreshRoute();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preferences = ['Fastest', 'Cheapest', 'Comfortable'];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? AppColors.outlineDark
              : AppColors.outlineLight,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Origin & Destination with Swap Button
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    PriceRouteAutocompleteField(
                      controller: originController,
                      label: 'Starting Point',
                      hint: 'My current location or station...',
                      icon: Icons.my_location_rounded,
                      allowMyLocation: true,
                      onLocationSelected: onOriginLocationSelected,
                      onPlaceSelected: (_) => onRefreshRoute(),
                    ),
                    const SizedBox(height: 6),
                    PriceRouteAutocompleteField(
                      controller: destController,
                      label: 'Destination',
                      hint: 'Fort, monument or hotel...',
                      icon: Icons.location_on_rounded,
                      iconColor: AppColors.danger,
                      onLocationSelected: onDestLocationSelected,
                      onPlaceSelected: (_) => onRefreshRoute(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.swap_vert_rounded),
                onPressed: onSwap,
                tooltip: 'Swap origin and destination',
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Depart Time & Travelers Row
          Row(
            children: [
              // Depart Time Chip
              InkWell(
                onTap: () => _pickTime(context),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 15,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Depart: ${departTime.hour.toString().padLeft(2, '0')}:${departTime.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),

              // Travelers Counter
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_rounded,
                      size: 15,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$travelers',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: travelers > 1
                          ? () => onTravelersChanged(travelers - 1)
                          : null,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.remove, size: 14),
                      ),
                    ),
                    InkWell(
                      onTap: travelers < 6
                          ? () => onTravelersChanged(travelers + 1)
                          : null,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.add, size: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Preference Chips
          Row(
            children: [
              Text(
                'Priority: ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
              ),
              const SizedBox(width: 4),
              ...preferences.map((p) {
                final isSelected =
                    selectedPreference.toLowerCase() == p.toLowerCase();
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(p),
                    selected: isSelected,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: isSelected ? Colors.white : null,
                    ),
                    selectedColor: AppColors.primary,
                    onSelected: (_) => onPreferenceChanged(p),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}
