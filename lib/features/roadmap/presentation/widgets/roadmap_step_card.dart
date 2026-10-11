import 'package:flutter/material.dart';

import '../../../../core/models/roadmap_models.dart';
import '../../../../core/services/map_launcher_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../price_checker/presentation/check_price_input_screen.dart';
import '../../../scam_protection/presentation/verify_driver_screen.dart';

/// Detailed interactive step card for a single leg of the journey roadmap
class RoadmapStepCard extends StatelessWidget {
  final RoadmapStep step;
  final bool isFocused;
  final VoidCallback onTap;

  const RoadmapStepCard({
    super.key,
    required this.step,
    required this.isFocused,
    required this.onTap,
  });

  IconData _getModeIcon(String mode) {
    switch (mode.toLowerCase()) {
      case 'walk':
        return Icons.directions_walk_rounded;
      case 'auto':
        return Icons.electric_rickshaw_rounded;
      case 'cab':
        return Icons.local_taxi_rounded;
      case 'bus':
        return Icons.directions_bus_rounded;
      case 'metro':
      case 'train':
        return Icons.subway_rounded;
      case 'bike_taxi':
        return Icons.two_wheeler_rounded;
      case 'shared_taxi':
        return Icons.airport_shuttle_rounded;
      default:
        return Icons.navigation_rounded;
    }
  }

  void _openTurnByTurn(BuildContext context) {
    final mapLauncher = MapLauncherService();
    mapLauncher.openStepDirectionsSynchronously(step: step);
  }

  void _openPriceChecker(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckPriceInputScreen(initialPlaceName: step.toName),
      ),
    );
  }

  void _openVerifyDriver(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VerifyDriverScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRide =
        step.mode == 'auto' ||
        step.mode == 'cab' ||
        step.mode == 'bike_taxi' ||
        step.mode == 'shared_taxi';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: isFocused
                ? AppColors.primary
                : theme.dividerColor.withOpacity(0.2),
            width: isFocused ? 2.0 : 1.0,
          ),
          boxShadow: isFocused
              ? [const BoxShadow(color: Colors.black12, blurRadius: 6)]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step Header (Number, Icon, Title, Duration & Distance)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: isFocused
                      ? AppColors.primary
                      : AppColors.primaryContainer,
                  child: Text(
                    '${step.index}',
                    style: TextStyle(
                      color: isFocused ? Colors.white : AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _getModeIcon(step.mode),
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${step.distanceM >= 1000 ? (step.distanceM / 1000).toStringAsFixed(1) : step.distanceM.round()} ${step.distanceM >= 1000 ? 'km' : 'm'} • ~${step.durationMin.round()} mins',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Plain instruction text
            Text(
              step.instruction,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),

            // Boarding point container
            if (step.boardingPoint.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.pin_drop_rounded,
                      size: 14,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Boarding: ${step.boardingPoint}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),

            // Price Range & Price Cap Row
            if (step.fairMax > 0)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Fair: ₹${step.fairMin.round()} - ₹${step.fairMax.round()} ${step.priceSource}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                  if (step.dontPayMoreThan > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "Don't pay > ₹${step.dontPayMoreThan.round()}",
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                ],
              ),

            // Warnings and Tourist Traps
            if (step.warnings.isNotEmpty || step.traps.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...step.warnings.map(
                      (w) => Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 14,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              w,
                              style: const TextStyle(fontSize: 11, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...step.traps.map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '• Trap Alert: ${t.description}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),

            // Action Buttons Row
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (isRide) ...[
                  OutlinedButton.icon(
                    onPressed: () => _openPriceChecker(context),
                    icon: const Icon(Icons.speed_rounded, size: 13),
                    label: const Text(
                      'Check price',
                      style: TextStyle(fontSize: 11),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openVerifyDriver(context),
                    icon: const Icon(Icons.verified_user_rounded, size: 13),
                    label: const Text(
                      'Verify driver',
                      style: TextStyle(fontSize: 11),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                  ),
                ],
                ElevatedButton.icon(
                  onPressed: () => _openTurnByTurn(context),
                  icon: const Icon(Icons.map_rounded, size: 14),
                  label: const Text(
                    'Open step in Maps',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
