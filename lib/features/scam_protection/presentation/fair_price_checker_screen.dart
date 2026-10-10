import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/local_data_repository.dart';
import '../../../core/models/app_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/fair_price_calculator.dart';
import '../../../core/widgets/app_brand_app_bar.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/price_verdict_card.dart';
import '../../../core/widgets/skeleton_loader.dart';
import 'widgets/fair_price_test_presets.dart';

class FairPriceCheckerScreen extends ConsumerStatefulWidget {
  final String? initialPlaceName;

  const FairPriceCheckerScreen({super.key, this.initialPlaceName});

  @override
  ConsumerState<FairPriceCheckerScreen> createState() =>
      _FairPriceCheckerScreenState();
}

class _FairPriceCheckerScreenState
    extends ConsumerState<FairPriceCheckerScreen> {
  PriceCategory _selectedCategory = PriceCategory.ride;
  FairPrice? _selectedItem;
  final TextEditingController _quotedPriceController = TextEditingController();
  FairPriceEvaluation? _evaluationResult;
  bool _initializedFromQuery = false;

  @override
  void dispose() {
    _quotedPriceController.dispose();
    super.dispose();
  }

  void _calculateVerdict() {
    if (_selectedItem == null) return;
    final quoted = double.tryParse(_quotedPriceController.text.trim());
    if (quoted == null || quoted <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quoted price in ₹')),
      );
      return;
    }

    final eval = FairPriceCalculator.evaluate(
      quotedPrice: quoted,
      fairMin: _selectedItem!.fairMin,
      fairMax: _selectedItem!.fairMax,
    );

    setState(() {
      _evaluationResult = eval;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fairPricesAsync = ref.watch(fairPricesFutureProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const AppBrandAppBar(
        title: 'Fair Price Checker',
        showBackButton: true,
      ),
      body: fairPricesAsync.when(
        loading: () => const SkeletonLoader(count: 2),
        error: (err, _) => ErrorState(
          message: 'Unable to load fair prices: $err',
          onRetry: () => ref.invalidate(fairPricesFutureProvider),
        ),
        data: (allItems) {
          // Pre-match from initial place if provided and not yet initialized
          if (!_initializedFromQuery &&
              widget.initialPlaceName != null &&
              allItems.isNotEmpty) {
            final query = widget.initialPlaceName!.toLowerCase();
            final matched = allItems.where((item) {
              final t = item.title.toLowerCase();
              final r = item.routeOrItem.toLowerCase();
              return t.contains(query) ||
                  r.contains(query) ||
                  ['jaipur', 'agra', 'manali', 'goa', 'varanasi'].any(
                    (c) =>
                        query.contains(c) && (t.contains(c) || r.contains(c)),
                  );
            }).firstOrNull;

            if (matched != null) {
              _selectedCategory = matched.category;
              _selectedItem = matched;
            }
            _initializedFromQuery = true;
          }

          final categoryItems = allItems
              .where((item) => item.category == _selectedCategory)
              .toList();

          if (_selectedItem == null ||
              _selectedItem!.category != _selectedCategory) {
            if (categoryItems.isNotEmpty) _selectedItem = categoryItems.first;
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: AppColors.primary,
                      size: 28,
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Real Market Rates',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'Compare quotes against local tariffs before agreeing to any service in India.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Category Selector Tabs
              Text(
                '1. Select Category',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<PriceCategory>(
                segments: const [
                  ButtonSegment(
                    value: PriceCategory.ride,
                    label: Text('Ride'),
                    icon: Icon(Icons.local_taxi_rounded),
                  ),
                  ButtonSegment(
                    value: PriceCategory.meal,
                    label: Text('Meal'),
                    icon: Icon(Icons.restaurant_rounded),
                  ),
                  ButtonSegment(
                    value: PriceCategory.room,
                    label: Text('Room'),
                    icon: Icon(Icons.hotel_rounded),
                  ),
                ],
                selected: {_selectedCategory},
                onSelectionChanged: (set) {
                  setState(() {
                    _selectedCategory = set.first;
                    _quotedPriceController.clear();
                    _evaluationResult = null;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // Route or Item Dropdown
              Text(
                '2. Choose Route or Item',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: theme.brightness == Brightness.dark
                        ? AppColors.outlineDark
                        : AppColors.outlineLight,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<FairPrice>(
                    isExpanded: true,
                    value: _selectedItem,
                    hint: const Text('Select route or item'),
                    items: categoryItems.map((item) {
                      return DropdownMenuItem<FairPrice>(
                        value: item,
                        child: Text(
                          item.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                    onChanged: (item) {
                      setState(() {
                        _selectedItem = item;
                        _quotedPriceController.clear();
                        _evaluationResult = null;
                      });
                    },
                  ),
                ),
              ),

              if (_selectedItem != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Fair standard range: ₹${_selectedItem!.fairMin.toStringAsFixed(0)} - ₹${_selectedItem!.fairMax.toStringAsFixed(0)} (${_selectedItem!.unit})',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),

              // Quoted Price Input
              Text(
                '3. Enter What You Were Quoted',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _quotedPriceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  prefixStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                  hintText: 'e.g. 500',
                  filled: true,
                  fillColor: theme.cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                onSubmitted: (_) => _calculateVerdict(),
              ),

              if (_selectedItem != null) ...[
                const SizedBox(height: AppSpacing.sm),
                FairPriceTestPresets(
                  item: _selectedItem!,
                  onSelectPrice: (price) {
                    _quotedPriceController.text = price.toString();
                    _calculateVerdict();
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.md),

              ElevatedButton.icon(
                onPressed: _calculateVerdict,
                icon: const Icon(Icons.analytics_rounded),
                label: const Text('Get Instant Verdict'),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Verdict Card Result
              if (_evaluationResult != null)
                PriceVerdictCard(
                  evaluation: _evaluationResult!,
                  tip: _selectedItem?.tip,
                  onReportPrice: () => context.push('/report-scam'),
                ),
            ],
          );
        },
      ),
    );
  }
}
