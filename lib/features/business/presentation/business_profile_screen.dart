import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/local_data_repository.dart';
import '../../../core/models/app_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_brand_app_bar.dart';
import 'widgets/business_reviews_section.dart';

class BusinessProfileScreen extends ConsumerWidget {
  final String businessId;

  const BusinessProfileScreen({super.key, required this.businessId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessListAsync = ref.watch(businessProfileNotifierProvider);
    final placesAsync = ref.watch(placesFutureProvider);
    final theme = Theme.of(context);

    BusinessProfile? profile = businessListAsync.value
        ?.where((b) => b.id == businessId)
        .firstOrNull;

    if (profile == null && placesAsync.value != null) {
      for (final p in placesAsync.value!) {
        final match = p.verifiedBusinesses
            .where((b) => b.id == businessId)
            .firstOrNull;
        if (match != null) {
          profile = match;
          break;
        }
      }
    }

    profile ??= BusinessProfile(
      id: businessId,
      businessName: 'Verified Partner',
      businessType: 'Driver',
      ownerName: 'Certified Driver',
      vehicleOrRegNumber: 'DL 01 TA 9988',
      isVerified: true,
      trustScore: 4.9,
      reviewsCount: 38,
      services: ['Airport Transfer', 'City Tour'],
      ownPrices: {'Full Day': 1800.0, 'Airport Drop': 500.0},
      priceCap: 2200.0,
      phone: '+91 98111 22334',
      address: 'Delhi NCR',
    );

    final p = profile;

    return Scaffold(
      appBar: AppBrandAppBar(title: p.businessName, showBackButton: true),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: theme.cardColor,
            border: Border(
              top: BorderSide(
                color: theme.brightness == Brightness.dark
                    ? AppColors.outlineDark
                    : AppColors.outlineLight,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/report-scam'),
                  icon: const Icon(
                    Icons.flag_outlined,
                    color: AppColors.danger,
                  ),
                  label: const Text(
                    'Report Dispute',
                    style: TextStyle(color: AppColors.danger),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Contacting ${p.businessName} at ${p.phone}',
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  icon: const Icon(Icons.call_rounded),
                  label: const Text('Call Business'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Header Card with Verified Badge & Trust Score
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.verified_rounded,
                          color: AppColors.primary,
                          size: 36,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    p.businessName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.successContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'VERIFIED',
                                    style: TextStyle(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${p.businessType} • Reg: ${p.vehicleOrRegNumber}',
                              style: theme.textTheme.bodyMedium,
                            ),
                            Text(
                              'Owner: ${p.ownerName}',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Divider(),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text(
                            'Trust Score',
                            style: TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.shield_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${p.trustScore}★',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        height: 30,
                        width: 1,
                        color: AppColors.outlineLight,
                      ),
                      Column(
                        children: [
                          const Text('Reviews', style: TextStyle(fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            '${p.reviewsCount} verified',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        height: 30,
                        width: 1,
                        color: AppColors.outlineLight,
                      ),
                      Column(
                        children: [
                          const Text(
                            'Fair Price Cap',
                            style: TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            p.priceCap != null
                                ? '₹${p.priceCap!.toStringAsFixed(0)} max'
                                : 'Standard',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Services Offered
          Text(
            'Services Offered',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: p.services.map((svc) {
              return Chip(
                avatar: const Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: AppColors.primary,
                ),
                label: Text(svc),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Own Published Prices
          Text(
            'Transparent Published Rates',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...p.ownPrices.entries.map((entry) {
            return Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ListTile(
                title: Text(
                  entry.key,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: Text(
                  '₹${entry.value.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: AppSpacing.lg),

          // Traveler Feedback / Reviews
          BusinessReviewsSection(businessName: p.businessName),
        ],
      ),
    );
  }
}
