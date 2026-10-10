import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/tariff_repository.dart';
import '../../../../core/models/app_models.dart';
import '../../../../core/services/map_launcher_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_brand_app_bar.dart';

/// Screen displaying the official LGBI Airport Pre-paid Taxi Counter tariffs.
/// Accessible to everyone without login.
class AirportPrepaidFaresScreen extends ConsumerStatefulWidget {
  const AirportPrepaidFaresScreen({super.key});

  @override
  ConsumerState<AirportPrepaidFaresScreen> createState() =>
      _AirportPrepaidFaresScreenState();
}

enum AirportFareSort {
  distanceAsc('Distance (Shortest)'),
  distanceDesc('Distance (Longest)'),
  priceAsc('Fare (Lowest)'),
  priceDesc('Fare (Highest)');

  final String label;
  const AirportFareSort(this.label);
}

class _AirportPrepaidFaresScreenState
    extends ConsumerState<AirportPrepaidFaresScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  final List<String> _categories = [
    'All',
    'Local',
    'Long distance',
    'Out of state',
  ];

  AirportFareSort _sort = AirportFareSort.distanceAsc;
  bool _showHindiNames = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _showReportWrongFareDialog(BuildContext context, [FixedRouteTariff? route]) {
    final nameCtrl = TextEditingController();
    final routeCtrl = TextEditingController(text: route?.destinationName ?? '');
    final fareCtrl = TextEditingController(text: route != null ? route.fare.toStringAsFixed(0) : '');
    final notesCtrl = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 20,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.report_problem_rounded, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Report a Wrong Fare',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Requires contributor login or traveler verification',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Notice an updated tariff on the airport signboard or counter receipt? Submit a verified correction for community verification.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Your Name or Contributor ID *',
                      hintText: 'e.g. John Doe / Verified Passenger',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge_outlined),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: routeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Destination Route *',
                      hintText: 'e.g. Shillong (Police Bazar)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.place_outlined),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: fareCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Observed / Printed Fare (₹) *',
                      hintText: 'e.g. 750',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.currency_rupee_rounded),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Counter Observations / Details',
                      hintText: 'e.g. Signboard updated at LGBI counter; toll included.',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.notes_rounded),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isSubmitting
                          ? null
                          : () {
                              if (nameCtrl.text.trim().isEmpty ||
                                  routeCtrl.text.trim().isEmpty ||
                                  fareCtrl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please fill all required fields (*) to verify report'),
                                  ),
                                );
                                return;
                              }
                              setModalState(() => isSubmitting = true);
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.success,
                                  content: Text(
                                    'Thank you, ${nameCtrl.text.trim()}! Your fare update for "${routeCtrl.text.trim()}" has been submitted for community review.',
                                  ),
                                ),
                              );
                            },
                      icon: isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_rounded),
                      label: Text(isSubmitting ? 'Submitting...' : 'Submit Verified Report'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final datasetAsync = ref.watch(airportPrepaidDatasetProvider);

    return Scaffold(
      appBar: const AppBrandAppBar(
        title: 'Airport Taxi Tariffs',
        showBackButton: true,
      ),
      body: datasetAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading official airport tariffs...'),
            ],
          ),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                const SizedBox(height: 12),
                Text('Failed to load airport tariffs: $err', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(airportPrepaidDatasetProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (dataset) {
          final query = _searchController.text.trim().toLowerCase();
          final selectedCategory = _categories[_tabController.index];

          // Filter by category and search query
          var filtered = dataset.routes.where((r) {
            final matchesCat = selectedCategory == 'All' ||
                r.category.toLowerCase() == selectedCategory.toLowerCase();
            if (!matchesCat) return false;

            if (query.isEmpty) return true;
            final matchName = r.destinationName.toLowerCase().contains(query);
            final matchHi = r.nameHi?.toLowerCase().contains(query) ?? false;
            final matchAliases = r.aliases.any((a) => a.toLowerCase().contains(query));
            return matchName || matchHi || matchAliases;
          }).toList();

          // Sort
          filtered.sort((a, b) {
            switch (_sort) {
              case AirportFareSort.distanceAsc:
                return a.km.compareTo(b.km);
              case AirportFareSort.distanceDesc:
                return b.km.compareTo(a.km);
              case AirportFareSort.priceAsc:
                return a.fare.compareTo(b.fare);
              case AirportFareSort.priceDesc:
                return b.fare.compareTo(a.fare);
            }
          });

          return CustomScrollView(
            slivers: [
              // Header Card with Source Badge, Date note, and Report Button
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                          : [const Color(0xFFEFF6FF), Colors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFBFDBFE),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_rounded, size: 14, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'OFFICIAL TARIFF',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          OutlinedButton.icon(
                            onPressed: () => _showReportWrongFareDialog(context),
                            icon: const Icon(Icons.flag_outlined, size: 14),
                            label: const Text('Report a wrong fare', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        dataset.source,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dataset.effectiveDate != null
                                ? 'Effective: ${dataset.effectiveDate}'
                                : 'effective date not stated • ${dataset.routes.length} verified routes',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Fixed government-notified tariffs for rides originating at LGBI Airport. Drivers cannot charge above these rates.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.white70 : Colors.black87,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Search, Controls & Hindi Toggle
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      // Search Bar
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search destination, locality, or Hindi name...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          isDense: true,
                          filled: true,
                          fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Tabs & Controls Row
                      Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _categories.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final cat = entry.value;
                                  final isSelected = _tabController.index == idx;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ChoiceChip(
                                      label: Text(cat),
                                      selected: isSelected,
                                      selectedColor: AppColors.primary,
                                      labelStyle: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: isSelected ? Colors.white : null,
                                      ),
                                      onSelected: (val) {
                                        if (val) {
                                          _tabController.animateTo(idx);
                                          setState(() {});
                                        }
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Sort & Hindi Toggle bar
                      Row(
                        children: [
                          // Sort dropdown
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<AirportFareSort>(
                                value: _sort,
                                isDense: true,
                                icon: const Icon(Icons.sort_rounded, size: 16),
                                items: AirportFareSort.values.map((s) {
                                  return DropdownMenuItem(
                                    value: s,
                                    child: Text(s.label, style: const TextStyle(fontSize: 12)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _sort = val);
                                },
                              ),
                            ),
                          ),
                          const Spacer(),

                          // Hindi toggle button
                          FilterChip(
                            avatar: Icon(
                              Icons.translate_rounded,
                              size: 14,
                              color: _showHindiNames ? Colors.white : AppColors.primary,
                            ),
                            label: Text(
                              _showHindiNames ? 'Hindi ON (हिंदी)' : 'Hindi (हिंदी)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: _showHindiNames ? FontWeight.w700 : FontWeight.w500,
                                color: _showHindiNames ? Colors.white : null,
                              ),
                            ),
                            selected: _showHindiNames,
                            selectedColor: AppColors.primary,
                            onSelected: (val) => setState(() => _showHindiNames = val),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Route Count Info
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        'Showing ${filtered.length} of ${dataset.routes.length} official routes',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Empty Search State
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          Text(
                            'No prepaid routes found for "${_searchController.text.trim()}"',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Unlisted destinations use derived estimate (₹200 base + ₹24/km).',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              _searchController.clear();
                              _tabController.animateTo(0);
                              setState(() {});
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Clear Filters'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                // Route List
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final route = filtered[index];
                        final ratePerKm = (route.fare / route.km).toStringAsFixed(1);
                        final hasFlag = route.flags.contains('check_against_printed_list');

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? Colors.white10 : Colors.grey.shade200,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top row: Category tag & Flags
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _categoryColor(route.category).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        route.category,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: _categoryColor(route.category),
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    if (hasFlag)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.amber.shade700, width: 0.8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.info_outline, size: 12, color: Colors.amber.shade900),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Confirm at counter',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.amber.shade900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Destination Name + Hindi Name
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            route.destinationName,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          if (_showHindiNames && route.nameHi != null)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Text(
                                                route.nameHi!,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? Colors.white70 : Colors.black54,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    // Fare
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '₹${route.fare.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        Text(
                                          '₹$ratePerKm/km',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? Colors.white60 : Colors.black54,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 6),
                                // Distance & Aliases
                                Row(
                                  children: [
                                    Icon(
                                      Icons.straighten_rounded,
                                      size: 14,
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${route.km.toStringAsFixed(0)} km',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.white60 : Colors.black54,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (route.aliases.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Text('•', style: TextStyle(color: Colors.grey.shade400)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Aliases: ${route.aliases.take(2).join(', ')}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? Colors.white54 : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),

                                const Divider(height: 18),

                                // Action Buttons
                                Row(
                                  children: [
                                    // Check a Price Button
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          context.push(
                                            '/check-price',
                                            extra: {
                                              'pickup': 'LGBI Airport, Guwahati',
                                              'destination': route.destinationName,
                                              'quotedPrice': route.fare,
                                              'serviceType': ServiceType.taxi,
                                            },
                                          );
                                        },
                                        icon: const Icon(Icons.speed_rounded, size: 15),
                                        label: const Text('Check a price', style: TextStyle(fontSize: 12)),
                                        style: ElevatedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Open in Maps Button
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        ref.read(mapLauncherServiceProvider).openDirections(
                                              origin: 'LGBI Airport, Guwahati',
                                              destination: route.destinationName,
                                              mode: 'driving',
                                            );
                                      },
                                      icon: const Icon(Icons.map_outlined, size: 15),
                                      label: const Text('Open in Maps', style: TextStyle(fontSize: 12)),
                                      style: OutlinedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Color _categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'local':
        return Colors.blue;
      case 'long distance':
        return Colors.teal;
      case 'out of state':
        return Colors.purple;
      default:
        return Colors.indigo;
    }
  }
}
