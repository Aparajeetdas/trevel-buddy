import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/google_maps_service.dart';
import '../../../../core/data/auth_repository.dart';
import '../../../../core/data/community_repository.dart';
import '../../../../core/models/ai_price_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_brand_app_bar.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import 'widgets/report_price_form.dart';
import 'widgets/report_review_form.dart';
import 'widgets/report_trap_form.dart';

/// Merged Community Reports Hub with Near Me, My Reports, and Submission forms
class CommunityReportsScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialData;

  const CommunityReportsScreen({super.key, this.initialData});

  @override
  ConsumerState<CommunityReportsScreen> createState() => _CommunityReportsScreenState();
}

class _CommunityReportsScreenState extends ConsumerState<CommunityReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Tab 0: Near Me, Tab 1: My Reports, Tab 2: Report Price, Tab 3: Report Trap, Tab 4: Review Driver
    int initialIndex = 0;
    if (widget.initialData != null) {
      if (widget.initialData!['type'] != null) {
        initialIndex = 3; // Open trap report if trap type given
      } else if (widget.initialData!['place'] != null || widget.initialData!['pricePaid'] != null) {
        initialIndex = 2; // Open price report if place/price given
      } else if (widget.initialData!['tab'] == 'my_reports') {
        initialIndex = 1;
      }
    }
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onReportSubmitted() {
    // Switch to Near Me tab to show the optimistically added report immediately
    _tabController.animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final String? initPlace = widget.initialData?['place'] as String?;
    final double? initPrice = (widget.initialData?['pricePaid'] as num?)?.toDouble();
    final String? initType = widget.initialData?['type'] as String?;

    return Scaffold(
      appBar: AppBrandAppBar(
        title: 'Community Intelligence Reports',
        showBackButton: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
          tabs: const [
            Tab(
              icon: Icon(Icons.near_me_rounded, size: 20),
              text: 'Near Me',
            ),
            Tab(
              icon: Icon(Icons.person_pin_rounded, size: 20),
              text: 'My Reports',
            ),
            Tab(
              icon: Icon(Icons.price_check_rounded, size: 20),
              text: 'Report Price',
            ),
            Tab(
              icon: Icon(Icons.warning_amber_rounded, size: 20),
              text: 'Report Trap',
            ),
            Tab(
              icon: Icon(Icons.rate_review_rounded, size: 20),
              text: 'Review Driver',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _NearMeReportsTab(
            onNavigateToReport: () => _tabController.animateTo(2),
          ),
          _MyReportsTab(
            onNavigateToReport: () => _tabController.animateTo(2),
          ),
          ReportPriceForm(
            initialPlace: initPlace,
            initialPrice: initPrice,
            onReportSubmitted: _onReportSubmitted,
          ),
          ReportTrapForm(
            initialDescription: initPlace,
            initialType: initType,
          ),
          const ReportReviewForm(),
        ],
      ),
    );
  }
}

class _NearMeReportsTab extends ConsumerWidget {
  final VoidCallback onNavigateToReport;

  const _NearMeReportsTab({required this.onNavigateToReport});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(priceReportsFutureProvider);
    final activeCity = ref.watch(activeCityProvider);
    final cityName = activeCity?.name ?? 'Guwahati';

    return reportsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: SkeletonLoader(count: 4),
      ),
      error: (err, _) => ErrorState(
        message: 'Could not load community reports: $err',
        onRetry: () => ref.invalidate(priceReportsFutureProvider),
      ),
      data: (reports) {
        if (reports.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.price_check_rounded, size: 48, color: Colors.grey),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No reports in $cityName yet',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Be the first to share what you paid and help fellow travellers avoid unfair markups.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton.icon(
                    onPressed: onNavigateToReport,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Price Report'),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(priceReportsFutureProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: reports.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Reports in $cityName (${reports.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      TextButton.icon(
                        onPressed: onNavigateToReport,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Add Report'),
                      ),
                    ],
                  ),
                );
              }
              final r = reports[index - 1];
              return _ReportCard(report: r);
            },
          ),
        );
      },
    );
  }
}

class _MyReportsTab extends ConsumerWidget {
  final VoidCallback onNavigateToReport;

  const _MyReportsTab({required this.onNavigateToReport});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(priceReportsFutureProvider);
    final currentUser = ref.watch(authRepositoryProvider).currentUser;

    return reportsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: SkeletonLoader(count: 3),
      ),
      error: (err, _) => ErrorState(
        message: 'Could not load your reports: $err',
        onRetry: () => ref.invalidate(priceReportsFutureProvider),
      ),
      data: (reports) {
        final myReports = reports.where((r) {
          if (currentUser != null && r.userId == currentUser.uid) return true;
          return r.id.startsWith('pr-user-');
        }).toList();

        if (myReports.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_pin_rounded, size: 48, color: Colors.grey),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'No reports submitted yet',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Every price report you submit protects tourists from overcharging and strengthens transparency.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton.icon(
                    onPressed: onNavigateToReport,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Report a Price Now'),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: myReports.length,
          itemBuilder: (context, index) {
            return _ReportCard(report: myReports[index]);
          },
        );
      },
    );
  }
}

class _ReportCard extends StatelessWidget {
  final PriceReport report;

  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final isApproved = report.status == 'approved';
    final isUnderReview = report.status == 'under_review';

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    report.vehicleType,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isApproved
                        ? AppColors.successContainer
                        : (isUnderReview ? Colors.amber.withOpacity(0.15) : Colors.blue.withOpacity(0.15)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isApproved
                        ? 'Verified'
                        : (isUnderReview ? 'Under Review' : 'Pending'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isApproved
                          ? AppColors.success
                          : (isUnderReview ? Colors.amber.shade900 : Colors.blue.shade900),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '₹${report.pricePaid.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              report.routeOrPlace,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            if (report.notes != null && report.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                report.notes!,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  report.wasFair ? Icons.thumb_up_rounded : Icons.thumb_down_rounded,
                  size: 14,
                  color: report.wasFair ? AppColors.success : AppColors.danger,
                ),
                const SizedBox(width: 4),
                Text(
                  report.wasFair ? 'Reported as fair' : 'Reported as high / overcharged',
                  style: TextStyle(
                    fontSize: 11,
                    color: report.wasFair ? AppColors.success : AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  report.areaId,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
