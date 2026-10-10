import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/app_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_card.dart';

/// Modal sheet showing full Tourist Trap details, how to avoid it, and Report CTA
class TrapDetailSheet extends StatelessWidget {
  final TouristTrap trap;
  final VoidCallback onClose;

  const TrapDetailSheet({super.key, required this.trap, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      elevation: 12,
      borderColor: AppColors.danger.withOpacity(0.6),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.danger,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trap.type.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: AppColors.danger,
                      ),
                    ),
                    Text(
                      'Service: ${trap.serviceType.displayName} • Severity ${trap.severity}/5',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
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
          const SizedBox(height: AppSpacing.sm),

          Text(
            trap.description,
            style: const TextStyle(fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: AppSpacing.md),

          // How to avoid it tip box
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm + 2),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withOpacity(0.4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.shield_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'How to Avoid This Trap',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        trap.avoidTip,
                        style: const TextStyle(fontSize: 12, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Footer stats and Report CTA
          Row(
            children: [
              Text(
                '${trap.reportCount} reports • Source: ${trap.source}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  context.push(
                    '/report-scam',
                    extra: {'place': trap.description, 'type': trap.type},
                  );
                },
                icon: const Icon(Icons.report_problem_rounded, size: 16),
                label: const Text('Report Similar Incident'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
