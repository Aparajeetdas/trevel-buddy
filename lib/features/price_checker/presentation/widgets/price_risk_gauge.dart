import 'package:flutter/material.dart';

import '../../../../core/models/app_models.dart';
import '../../../../core/theme/app_theme.dart';

/// Section 2: Risk score gauge 0-100 and a confidence label (High / Medium / Low)
class PriceRiskGauge extends StatelessWidget {
  final int riskScore;
  final ConfidenceLevel confidence;
  final PriceVerdictLevel level;

  const PriceRiskGauge({
    super.key,
    required this.riskScore,
    required this.confidence,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scoreClamped = riskScore.clamp(0, 100);
    final progress = scoreClamped / 100.0;

    Color confColor;
    IconData confIcon;
    switch (confidence) {
      case ConfidenceLevel.high:
        confColor = AppColors.primary;
        confIcon = Icons.verified_rounded;
        break;
      case ConfidenceLevel.medium:
        confColor = AppColors.warning;
        confIcon = Icons.info_rounded;
        break;
      case ConfidenceLevel.low:
        confColor = Colors.grey.shade600;
        confIcon = Icons.help_outline_rounded;
        break;
    }

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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Risk Score Gauge',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              // Confidence Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: confColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: confColor.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(confIcon, size: 14, color: confColor),
                    const SizedBox(width: 4),
                    Text(
                      confidence.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: confColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Score bar with gradient fill
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 14,
              child: Stack(
                children: [
                  Container(color: Colors.grey.withOpacity(0.15)),
                  FractionallySizedBox(
                    widthFactor: progress.clamp(0.02, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF10B981),
                            if (scoreClamped > 30) const Color(0xFFF59E0B),
                            if (scoreClamped > 60) const Color(0xFFEF4444),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Scale Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '0 (Low Risk)',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              Text(
                'Score: $scoreClamped / 100',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: level.color,
                ),
              ),
              const Text(
                '100 (Critical)',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
