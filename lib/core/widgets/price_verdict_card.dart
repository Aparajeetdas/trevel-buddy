import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/fair_price_calculator.dart';

class PriceVerdictCard extends StatelessWidget {
  final FairPriceEvaluation evaluation;
  final VoidCallback? onReportPrice;
  final String? tip;

  const PriceVerdictCard({
    super.key,
    required this.evaluation,
    this.onReportPrice,
    this.tip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eval = evaluation;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: eval.verdictColor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            // Status Icon & Verdict Title
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: eval.verdictColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(eval.verdictIcon, size: 48, color: eval.verdictColor),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              eval.verdictTitle,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: eval.verdictColor,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              eval.verdictMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
            ),
            const SizedBox(height: AppSpacing.md),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),

            // Comparison Metrics: Fair Range, Quoted Price, Difference
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text(
                      'Fair Range',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${eval.fairMin.toStringAsFixed(0)} - ₹${eval.fairMax.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Container(height: 36, width: 1, color: AppColors.outlineLight),
                Column(
                  children: [
                    const Text(
                      'Quoted Price',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${eval.quotedPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Container(height: 36, width: 1, color: AppColors.outlineLight),
                Column(
                  children: [
                    const Text(
                      'Difference',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      eval.differenceRupees > 0
                          ? '+₹${eval.differenceRupees.toStringAsFixed(0)}'
                          : '₹0 (Fair)',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: eval.differenceRupees > 0
                            ? eval.verdictColor
                            : AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Tip if provided
            if (tip != null && tip!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm + 2),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.tips_and_updates_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        tip!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // Report button
            if (onReportPrice != null)
              OutlinedButton.icon(
                onPressed: onReportPrice,
                icon: const Icon(Icons.flag_rounded),
                label: const Text('Report this price'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
