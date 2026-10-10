import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/models/app_models.dart';
import '../../../../core/theme/app_theme.dart';

/// Section 3: Fair price range (min-max) bar with quoted price marker and diff stats
class PriceRangeBar extends StatelessWidget {
  final PriceCheckResult result;

  const PriceRangeBar({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fairMin = result.fairMin;
    final fairMax = result.fairMax;
    final quoted = result.quotedPrice;
    final diffRupees = result.differenceRupees;
    final diffPercent = result.differencePercent;

    final double displayMax = max(quoted * 1.15, fairMax * 1.35);
    final double minFraction = (fairMin / displayMax).clamp(0.05, 0.90);
    final double maxFraction = (fairMax / displayMax).clamp(0.10, 0.95);
    final double quotedFraction = (quoted / displayMax).clamp(0.02, 0.98);

    final bool isOvercharged = diffRupees > 0;

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
                'Fair Price Benchmark Bar',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              if (isOvercharged)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '+₹${diffRupees.round()} (${diffPercent.round()}%)',
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Fair Market Rate',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Visual Track
          SizedBox(
            height: 48,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final leftFair = width * minFraction;
                final rightFair = width * maxFraction;
                final fairWidth = max(24.0, rightFair - leftFair);
                final markerPos = (width * quotedFraction).clamp(
                  0.0,
                  width - 24.0,
                );

                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // Base background bar
                    Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),

                    // Green Fair Range Band
                    Positioned(
                      left: leftFair,
                      width: fairWidth,
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),

                    // Quoted Price Indicator Pointer
                    Positioned(
                      left: markerPos,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: result.level.color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '₹${quoted.round()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            color: result.level.color,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Range Bounds Info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fair Min: ₹${fairMin.round()}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              Text(
                'Fair Max: ₹${fairMax.round()}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
