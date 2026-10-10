import 'package:flutter/material.dart';

import '../../../../core/models/roadmap_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../ride/presentation/ride_mode_screen.dart';

/// Bottom HUD card displaying current navigation step instructions and quick fare actions
class GoModeStepHud extends StatelessWidget {
  final RoadmapStep currentStep;
  final int currentStepIndex;
  final int totalSteps;
  final String originName;
  final String destinationName;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const GoModeStepHud({
    super.key,
    required this.currentStep,
    required this.currentStepIndex,
    required this.totalSteps,
    required this.originName,
    required this.destinationName,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLastStep = currentStepIndex >= totalSteps - 1;
    final isRide =
        currentStep.mode == 'auto' ||
        currentStep.mode == 'cab' ||
        currentStep.mode == 'taxi';
    final distKm = (currentStep.distanceM / 1000.0).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  radius: 18,
                  child: Icon(
                    _getModeIcon(currentStep.mode),
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentStep.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '~${currentStep.durationMin.round()} mins • $distKm km',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                currentStep.instruction,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
            if (currentStep.boardingPoint.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Board at: ${currentStep.boardingPoint}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (currentStep.fairMax > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.successContainer,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  'Fair: ₹${currentStep.fairMin.round()}-₹${currentStep.fairMax.round()} (Cap: ₹${currentStep.dontPayMoreThan.round()})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
            if (isRide) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RideModeScreen(
                          initialOrigin: currentStep.boardingPoint.isNotEmpty
                              ? currentStep.boardingPoint
                              : originName,
                          initialDestination: destinationName,
                          quotedPrice: currentStep.fairMax,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.speed_rounded, size: 18),
                  label: const Text('Open Live Ride Fare Meter'),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                if (currentStepIndex > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onPrevious,
                      child: const Text('Previous'),
                    ),
                  ),
                if (currentStepIndex > 0) const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: onNext,
                    icon: Icon(
                      isLastStep
                          ? Icons.flag_rounded
                          : Icons.arrow_forward_rounded,
                    ),
                    label: Text(isLastStep ? 'Finish & Arrive' : 'Next Step'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLastStep
                          ? AppColors.success
                          : AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
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

  IconData _getModeIcon(String mode) {
    switch (mode.toLowerCase()) {
      case 'walk':
        return Icons.directions_walk_rounded;
      case 'auto':
        return Icons.electric_rickshaw_rounded;
      case 'metro':
      case 'subway':
        return Icons.subway_rounded;
      case 'bus':
        return Icons.directions_bus_rounded;
      default:
        return Icons.local_taxi_rounded;
    }
  }
}
