import 'package:flutter/material.dart';

import '../../../../core/models/app_models.dart';
import '../../../../core/theme/app_theme.dart';

/// Section 1: Verdict banner: icon + color + word (Fair / Suspicious / High Risk) + one sentence
class PriceVerdictBanner extends StatelessWidget {
  final PriceCheckResult result;

  const PriceVerdictBanner({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final level = result.level;
    final color = level.color;

    String sentence;
    switch (level) {
      case PriceVerdictLevel.fair:
        sentence = 'This price matches local standards. Safe to accept!';
        break;
      case PriceVerdictLevel.suspicious:
        sentence = result.isUnusuallyLow
            ? 'Suspiciously low quote; watch out for hidden charges later.'
            : 'Slightly higher than local rates. Consider negotiating down.';
        break;
      case PriceVerdictLevel.highRisk:
        sentence = 'Significant markup detected above official market rates.';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(level.icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      level.label,
                      style: TextStyle(
                        color: color,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Risk: ${result.riskScore}/100',
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  sentence,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).textTheme.bodyLarge?.color
                        ?.withOpacity(0.85),
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
                if (result.confidence == ConfidenceLevel.low) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.history_rounded, size: 13, color: color),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Offline estimate based on historical benchmarks as of Oct 2026',
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: Theme.of(context).textTheme.bodySmall?.color
                                ?.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
