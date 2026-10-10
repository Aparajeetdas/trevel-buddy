import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_brand_app_bar.dart';
import 'widgets/report_price_form.dart';
import 'widgets/report_review_form.dart';
import 'widgets/report_trap_form.dart';

/// Merged Community Reports Hub (Report Price, Report Trap, Review Driver/Biz)
class CommunityReportsScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const CommunityReportsScreen({super.key, this.initialData});

  @override
  State<CommunityReportsScreen> createState() => _CommunityReportsScreenState();
}

class _CommunityReportsScreenState extends State<CommunityReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Tab 0: Price, Tab 1: Trap, Tab 2: Review
    int initialIndex = 0;
    if (widget.initialData != null && widget.initialData!['type'] != null) {
      initialIndex = 1; // Open trap report if trap type given
    }
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? initPlace = widget.initialData?['place'] as String?;
    final double? initPrice = (widget.initialData?['pricePaid'] as num?)
        ?.toDouble();
    final String? initType = widget.initialData?['type'] as String?;

    return Scaffold(
      appBar: AppBrandAppBar(
        title: 'Community Intelligence Reports',
        showBackButton: true,
        bottom: TabBar(
          controller: _tabController,
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
          ReportPriceForm(initialPlace: initPlace, initialPrice: initPrice),
          ReportTrapForm(initialDescription: initPlace, initialType: initType),
          const ReportReviewForm(),
        ],
      ),
    );
  }
}
