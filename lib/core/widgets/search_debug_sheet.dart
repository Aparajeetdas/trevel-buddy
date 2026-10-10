import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_data_repository.dart';
import '../services/google_maps_service.dart';
import '../theme/app_theme.dart';

/// Hidden diagnostic panel displaying live Places API request/response telemetry.
/// Opened by long-pressing the app logo.
class SearchDebugSheet extends ConsumerWidget {
  const SearchDebugSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SearchDebugSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final record = ref.watch(searchDebugProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.lg),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title Bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.bug_report_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Search Diagnostics Panel',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          Text(
                            'Live Google Places API telemetry & proxy status',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Content Body
              Expanded(
                child: record == null
                    ? _buildEmptyState(context, isDark, ref)
                    : _buildTelemetryView(
                        context,
                        isDark,
                        record,
                        ref,
                        scrollController,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.radar_rounded,
              size: 56,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'No Searches Recorded Yet',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Perform an autocomplete or free-form text search anywhere in the app to inspect request payloads, HTTP response codes, and rate limits.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: () => _resetDemoData(context, ref),
              icon: const Icon(Icons.restore_rounded, size: 18),
              label: const Text('Reset Demo Seed Data'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryView(
    BuildContext context,
    bool isDark,
    SearchDebugRecord record,
    WidgetRef ref,
    ScrollController scrollController,
  ) {
    final isSuccess = record.httpStatus == 200;
    final statusColor = isSuccess
        ? AppColors.success
        : (record.httpStatus == 429 ? AppColors.warning : AppColors.danger);

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // Query & Status Header Card
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LAST QUERY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '"${record.query}"',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withOpacity(0.5)),
                    ),
                    child: Text(
                      'HTTP ${record.httpStatus}',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _badge(Icons.swap_horiz_rounded, record.endpoint, isDark),
                  _badge(
                    Icons.format_list_numbered_rounded,
                    '${record.resultsCount} results',
                    isDark,
                  ),
                  _badge(
                    Icons.access_time_rounded,
                    '${record.timestamp.hour.toString().padLeft(2, '0')}:${record.timestamp.minute.toString().padLeft(2, '0')}:${record.timestamp.second.toString().padLeft(2, '0')}',
                    isDark,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Plain English Diagnosis & Suggested Fix
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isSuccess
                ? AppColors.primary.withOpacity(0.08)
                : AppColors.danger.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isSuccess
                  ? AppColors.primary.withOpacity(0.3)
                  : AppColors.danger.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isSuccess
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded,
                    size: 18,
                    color: isSuccess ? AppColors.primary : AppColors.danger,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isSuccess
                        ? 'API Health: Normal'
                        : 'Diagnosis & Recommended Fix',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: isSuccess ? AppColors.primary : AppColors.danger,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                record.likelyFix,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Request Payload Card
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Exact Request Payload',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(
                    text: const JsonEncoder.withIndent('  ')
                        .convert(record.requestBody),
                  ),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payload copied to clipboard')),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 14),
              label: const Text('Copy JSON', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131822) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
          ),
          child: SelectableText(
            const JsonEncoder.withIndent('  ').convert(record.requestBody),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Error payload if present
        if (record.errorBody != null && record.errorBody!.isNotEmpty) ...[
          const Text(
            'Raw Error Response',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A1515) : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.danger.withOpacity(0.3)),
            ),
            child: SelectableText(
              record.errorBody!,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.35,
                color: AppColors.danger,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // Reset Demo Data Button
        OutlinedButton.icon(
          onPressed: () => _resetDemoData(context, ref),
          icon: const Icon(Icons.restore_rounded, size: 18),
          label: const Text('Reset Demo Seed Data'),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _badge(IconData icon, String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: isDark ? Colors.white70 : Colors.black87),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resetDemoData(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(appRepositoryProvider);
    await repo.resetAllData();
    ref.invalidate(placesFutureProvider);
    ref.invalidate(scamZonesFutureProvider);
    ref.invalidate(fairPricesFutureProvider);
    ref.invalidate(driversFutureProvider);
    ref.invalidate(scamReportsNotifierProvider);
    ref.invalidate(businessProfileNotifierProvider);
    ref.invalidate(fareRulesFutureProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.restore_rounded, color: Colors.white, size: 20),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Text(
                  'Demo Mode: All data reset to seed state.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      );
    }
  }
}
