import 'package:flutter/material.dart';

import '../../../../core/models/app_models.dart';
import '../../../../core/theme/app_theme.dart';

/// Section 4: Sources row showing Official tariff, Community benchmark, and AI model estimate
class PriceSourcesRow extends StatelessWidget {
  final List<PriceCheckSource> sources;

  const PriceSourcesRow({super.key, required this.sources});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Intelligence Data Sources',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...sources.map((src) => _buildSourceCard(context, src)),
      ],
    );
  }

  Widget _buildSourceCard(BuildContext context, PriceCheckSource src) {
    final theme = Theme.of(context);
    final isOfficial = src.type == 'official';
    final isCommunity = src.type == 'community';

    final Color badgeColor = isOfficial
        ? AppColors.primary
        : isCommunity
        ? const Color(0xFF0284C7) // Sky blue
        : Colors.grey.shade700;

    final IconData icon = isOfficial
        ? Icons.account_balance_rounded
        : isCommunity
        ? Icons.groups_rounded
        : Icons.auto_awesome_rounded;

    final String title = isOfficial
        ? 'Official Tariff'
        : isCommunity
        ? 'Community Benchmark'
        : 'AI Mobility Baseline';

    final bool isSample = src.details.toLowerCase().contains('sample');

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(
          color: theme.brightness == Brightness.dark
              ? AppColors.outlineDark
              : AppColors.outlineLight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: badgeColor, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: badgeColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isSample)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Sample data',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ),
                      const Spacer(),
                      if (src.amount != null)
                        Text(
                          '₹${src.amount!.round()}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    src.sourceName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (src.effectiveDate != null)
                    Text(
                      'Effective: as of ${src.effectiveDate}',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textTheme.bodySmall?.color?.withOpacity(
                          0.7,
                        ),
                      ),
                    ),
                  Text(
                    src.details,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
