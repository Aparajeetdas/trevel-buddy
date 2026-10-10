import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/community_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_brand_app_bar.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/skeleton_loader.dart';
import 'widgets/trap_detail_sheet.dart';

/// Full screen browser for the Tourist Trap Database
class TouristTrapsScreen extends ConsumerStatefulWidget {
  const TouristTrapsScreen({super.key});

  @override
  ConsumerState<TouristTrapsScreen> createState() => _TouristTrapsScreenState();
}

class _TouristTrapsScreenState extends ConsumerState<TouristTrapsScreen> {
  String _selectedService = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _serviceFilters = [
    'All',
    'Auto',
    'Taxi',
    'Guide',
    'Meal',
    'Entry',
    'Other',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trapsAsync = ref.watch(touristTrapsFutureProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const AppBrandAppBar(
        title: 'Tourist Trap Database',
        showBackButton: true,
      ),
      body: trapsAsync.when(
        loading: () => const SkeletonLoader(count: 4),
        error: (err, _) => ErrorState(
          message: 'Unable to load Tourist Trap Database: $err',
          onRetry: () => ref.invalidate(touristTrapsFutureProvider),
        ),
        data: (allTraps) {
          final filtered = allTraps.where((t) {
            final matchesFilter =
                _selectedService == 'All' ||
                t.serviceType.displayName.toLowerCase().contains(
                  _selectedService.toLowerCase(),
                );
            final matchesSearch =
                _searchQuery.isEmpty ||
                t.description.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                t.type.toLowerCase().contains(_searchQuery.toLowerCase());
            return matchesFilter && matchesSearch;
          }).toList();

          return Column(
            children: [
              // Search & Filter header
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (val) =>
                          setState(() => _searchQuery = val.trim()),
                      decoration: InputDecoration(
                        hintText: 'Search trap types, touts, emporiums...',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.danger,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        filled: true,
                        fillColor: theme.cardColor,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _serviceFilters.map((filter) {
                          final isSel = _selectedService == filter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(filter),
                              selected: isSel,
                              selectedColor: AppColors.danger,
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : null,
                                fontWeight: isSel
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 12,
                              ),
                              onSelected: (_) =>
                                  setState(() => _selectedService = filter),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              // Trap list feed
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 4,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final trap = filtered[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        side: BorderSide(
                          color: AppColors.danger.withOpacity(0.3),
                        ),
                      ),
                      child: InkWell(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: TrapDetailSheet(
                                trap: trap,
                                onClose: () => Navigator.pop(context),
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.danger,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      trap.type.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    trap.serviceType.displayName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Severity ${trap.severity}/5',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.danger,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                trap.description,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.shield_outlined,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      trap.avoidTip,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/report-scam'),
        backgroundColor: AppColors.danger,
        icon: const Icon(Icons.add_alert_rounded, color: Colors.white),
        label: const Text(
          'Report a Trap',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
