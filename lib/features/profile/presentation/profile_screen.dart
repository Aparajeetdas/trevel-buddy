import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/community_repository.dart';
import '../../../core/data/local_data_repository.dart';
import '../../../core/services/map_launcher_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_brand_app_bar.dart';
import '../../../core/widgets/community_safety_widgets.dart';
import '../../../core/widgets/privacy_notice_widgets.dart';
import 'widgets/profile_user_header.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Demo Data?'),
        content: const Text(
          'This will clear all submitted scam reports, cached locations, and reset to the clean demo state.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(scamReportsNotifierProvider.notifier).reset();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Demo data successfully restored to fresh seed state.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _clearMyData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Clear My Data?'),
          ],
        ),
        content: const Text(
          'This will permanently delete all your locally saved places, custom settings, and submitted reports from this device. This action is irreversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(communityRepositoryProvider).clearAllLocalData();
      ref.invalidate(priceReportsFutureProvider);
      ref.invalidate(touristTrapsFutureProvider);
      ref.invalidate(areaInsightsFutureProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'All local data and cached preferences have been permanently deleted.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(scamReportsNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const AppBrandAppBar(title: 'My Profile'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // 1. User Header
          const ProfileUserHeaderCard(),
          const SizedBox(height: AppSpacing.lg),

          // 2. Saved Guides & Itineraries section
          Text(
            'Saved Guides & Safety Resources',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.shield_rounded,
                color: AppColors.danger,
              ),
              title: const Text('Tourist Trap Database'),
              subtitle: const Text(
                '25+ verified traps, tout warnings & avoid tips',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/tourist-traps'),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 4. Community Reports section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Community Reports & Submissions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton.icon(
                onPressed: () => context.push('/report-scam'),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New Report'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          reportsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Text('Error: $err'),
            data: (reports) {
              if (reports.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'No reports filed yet. Keep travel in India transparent by reporting any scam encounters.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                );
              }
              return Column(
                children: reports.map((r) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.dangerContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  r.id,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                    color: AppColors.danger,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.successContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  r.status,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                    color: AppColors.success,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            r.incidentType,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  r.placeName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                '₹${r.amountLost.toStringAsFixed(0)} lost',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.danger,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          if (r.description.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              r.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.brightness == Brightness.dark
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          // 5. Settings: Map app selection
          Text(
            'Settings',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Consumer(
            builder: (context, ref, _) {
              final preferredMapApp = ref.watch(
                preferredMapAppNotifierProvider,
              );
              final isIOS =
                  !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

              return Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.map_rounded,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Map app',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(preferredMapApp.displayName),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        preferredMapApp.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      builder: (ctx) {
                        return SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  'Choose Preferred Map App',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              ListTile(
                                leading: const Icon(
                                  Icons.map_rounded,
                                  color: Colors.blue,
                                ),
                                title: const Text('Google Maps (default)'),
                                trailing:
                                    preferredMapApp ==
                                        PreferredMapApp.googleMaps
                                    ? const Icon(
                                        Icons.check_rounded,
                                        color: AppColors.primary,
                                      )
                                    : null,
                                onTap: () {
                                  ref
                                      .read(
                                        preferredMapAppNotifierProvider
                                            .notifier,
                                      )
                                      .setApp(PreferredMapApp.googleMaps);
                                  Navigator.pop(ctx);
                                },
                              ),
                              ListTile(
                                leading: const Icon(
                                  Icons.navigation_rounded,
                                  color: Colors.cyan,
                                ),
                                title: const Text('Waze'),
                                trailing:
                                    preferredMapApp == PreferredMapApp.waze
                                    ? const Icon(
                                        Icons.check_rounded,
                                        color: AppColors.primary,
                                      )
                                    : null,
                                onTap: () {
                                  ref
                                      .read(
                                        preferredMapAppNotifierProvider
                                            .notifier,
                                      )
                                      .setApp(PreferredMapApp.waze);
                                  Navigator.pop(ctx);
                                },
                              ),
                              if (isIOS)
                                ListTile(
                                  leading: const Icon(
                                    Icons.apple_rounded,
                                    color: Colors.black87,
                                  ),
                                  title: const Text('Apple Maps'),
                                  trailing:
                                      preferredMapApp ==
                                          PreferredMapApp.appleMaps
                                      ? const Icon(
                                          Icons.check_rounded,
                                          color: AppColors.primary,
                                        )
                                      : null,
                                  onTap: () {
                                    ref
                                        .read(
                                          preferredMapAppNotifierProvider
                                              .notifier,
                                        )
                                        .setApp(PreferredMapApp.appleMaps);
                                    Navigator.pop(ctx);
                                  },
                                ),
                              ListTile(
                                leading: const Icon(
                                  Icons.question_mark_rounded,
                                  color: Colors.orange,
                                ),
                                title: const Text('Ask each time'),
                                trailing:
                                    preferredMapApp ==
                                        PreferredMapApp.askEachTime
                                    ? const Icon(
                                        Icons.check_rounded,
                                        color: AppColors.primary,
                                      )
                                    : null,
                                onTap: () {
                                  ref
                                      .read(
                                        preferredMapAppNotifierProvider
                                            .notifier,
                                      )
                                      .setApp(PreferredMapApp.askEachTime);
                                  Navigator.pop(ctx);
                                },
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          // Privacy & Legal Section (DPDP Act 2023 Compliance)
          Text(
            'Privacy & Legal',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.shield_outlined, color: AppColors.primary),
                  title: const Text('Privacy & Data Protection Notice', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('DPDP Act 2023 Principles & Minimum Data Policy'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => PrivacyNoticeDialog.show(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.gavel_rounded, color: Colors.blueGrey),
                  title: const Text('Request Takedown / Appeal', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Contest an inaccurate or defamatory community report'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => TakedownAppealDialog.show(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Clear My Data Button (DPDP Act right to erasure)
          ElevatedButton.icon(
            onPressed: () => _clearMyData(context, ref),
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white),
            label: const Text('Clear My Data (Erase All Local Data)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // 6. Reset Demo Data Action
          OutlinedButton.icon(
            onPressed: () => _confirmReset(context, ref),
            icon: const Icon(
              Icons.restart_alt_rounded,
              color: AppColors.danger,
            ),
            label: const Text(
              'Reset Demo Data to Seed State',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
