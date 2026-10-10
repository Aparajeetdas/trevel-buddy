import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/roadmap_models.dart';
import '../../../../core/services/roadmap_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_brand_app_bar.dart';
import 'go_mode_screen.dart';
import 'widgets/roadmap_checklist_card.dart';
import 'widgets/roadmap_header_card.dart';
import '../../../../core/services/map_launcher_service.dart';
import 'widgets/roadmap_option_tabs.dart';
import 'widgets/roadmap_step_card.dart';

/// Full-screen Journey Roadmap Page ("Go Here")
class RoadmapScreen extends ConsumerStatefulWidget {
  final RoadmapLocation? initialOrigin;
  final RoadmapLocation initialDestination;
  final String preference;

  const RoadmapScreen({
    super.key,
    this.initialOrigin,
    required this.initialDestination,
    this.preference = 'Fastest',
  });

  @override
  ConsumerState<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends ConsumerState<RoadmapScreen> {
  late final TextEditingController _originController;
  late final TextEditingController _destController;

  late RoadmapLocation _origin;
  late RoadmapLocation _destination;
  late DateTime _departTime;
  int _travelers = 1;
  late String _preference;

  Roadmap? _roadmap;
  int _selectedOptionIndex = 0;
  int? _focusedStepIndex;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _origin =
        widget.initialOrigin ??
        const RoadmapLocation(
          name: 'Jaipur Junction',
          lat: 26.9200,
          lng: 75.7878,
        );
    _destination = widget.initialDestination;
    _departTime = DateTime.now();
    _preference = widget.preference;

    _originController = TextEditingController(text: _origin.name);
    _destController = TextEditingController(text: _destination.name);

    _loadRoadmap();
  }

  @override
  void dispose() {
    _originController.dispose();
    _destController.dispose();
    super.dispose();
  }

  Future<void> _loadRoadmap() async {
    setState(() => _isLoading = true);
    final service = ref.read(roadmapServiceProvider);
    final roadmap = await service.planRoadmap(
      origin: _origin,
      destination: _destination,
      departTime: _departTime,
      travelers: _travelers,
      preference: _preference,
    );

    if (mounted) {
      setState(() {
        _roadmap = roadmap;
        _selectedOptionIndex = 0;
        _focusedStepIndex =
            roadmap.options.isNotEmpty && roadmap.options.first.steps.isNotEmpty
            ? roadmap.options.first.steps.first.index
            : null;
        _isLoading = false;
      });
    }
  }

  void _swapLocations() {
    final tempLoc = _origin;
    setState(() {
      _origin = _destination;
      _destination = tempLoc;
      _originController.text = _origin.name;
      _destController.text = _destination.name;
    });
    _loadRoadmap();
  }

  void _startJourney() {
    final roadmap = _roadmap;
    if (roadmap == null || roadmap.options.isEmpty) return;
    final selectedOption = roadmap
        .options[_selectedOptionIndex.clamp(0, roadmap.options.length - 1)];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GoModeScreen(
          origin: _origin,
          destination: _destination,
          option: selectedOption,
        ),
      ),
    );
  }

  void _openFullRouteInMaps(RoadmapOption option) {
    final waypoints = option.steps
        .take(9)
        .map((s) => '${s.endLat},${s.endLng}')
        .toList();
    ref
        .read(mapLauncherServiceProvider)
        .openDirections(
          origin: '${_origin.lat},${_origin.lng}',
          destination: '${_destination.lat},${_destination.lng}',
          originName: _origin.name,
          destName: _destination.name,
          waypoints: waypoints.length > 1
              ? waypoints.sublist(0, waypoints.length - 1)
              : const [],
          context: context,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roadmap = _roadmap;
    final selectedOption = (roadmap != null && roadmap.options.isNotEmpty)
        ? roadmap.options[_selectedOptionIndex.clamp(
            0,
            roadmap.options.length - 1,
          )]
        : null;

    return Scaffold(
      appBar: AppBrandAppBar(
        title: 'Roadmap • ${_destination.name}',
        showBackButton: true,
        actions: [
          if (selectedOption != null)
            IconButton(
              tooltip: 'Open full route in Maps',
              icon: const Icon(
                Icons.open_in_new_rounded,
                color: AppColors.primary,
              ),
              onPressed: () => _openFullRouteInMaps(selectedOption),
            ),
        ],
      ),
      body: _isLoading || roadmap == null || selectedOption == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Calculating multi-modal route & fair tariffs...',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                // 1. From -> To Header Card
                RoadmapHeaderCard(
                  originController: _originController,
                  destController: _destController,
                  onSwap: _swapLocations,
                  departTime: _departTime,
                  onDepartTimeChanged: (dt) => setState(() => _departTime = dt),
                  travelers: _travelers,
                  onTravelersChanged: (t) => setState(() => _travelers = t),
                  selectedPreference: _preference,
                  onPreferenceChanged: (p) {
                    setState(() => _preference = p);
                    _loadRoadmap();
                  },
                  onRefreshRoute: _loadRoadmap,
                ),
                const SizedBox(height: AppSpacing.sm),
                // Open full route in Maps button
                ElevatedButton.icon(
                  onPressed: () => _openFullRouteInMaps(selectedOption),
                  icon: const Icon(Icons.map_rounded, size: 18),
                  label: const Text(
                    'Open Full Route in Maps',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // 2. Option Tabs (Cheapest, Fastest, Comfortable, Local guide)
                RoadmapOptionTabs(
                  options: roadmap.options,
                  selectedIndex: _selectedOptionIndex,
                  onSelectIndex: (idx) {
                    setState(() {
                      _selectedOptionIndex = idx;
                      final opt = roadmap.options[idx];
                      _focusedStepIndex = opt.steps.isNotEmpty
                          ? opt.steps.first.index
                          : null;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // 3. Summary Card
                _buildSummaryCard(selectedOption, theme),
                const SizedBox(height: AppSpacing.md),

                // 4. Step Timeline Cards
                Row(
                  children: [
                    const Icon(
                      Icons.route_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Step-by-Step Guide',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...selectedOption.steps.map(
                  (step) => RoadmapStepCard(
                    step: step,
                    isFocused: _focusedStepIndex == step.index,
                    onTap: () => setState(() => _focusedStepIndex = step.index),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // 5. Pre-Trip Checklist & Start Journey Button
                RoadmapChecklistCard(
                  checklist: roadmap.checklist,
                  onStartJourney: _startJourney,
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildSummaryCard(RoadmapOption option, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withOpacity(0.35),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '~${option.totalMin.round()} mins total',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: AppColors.primary,
                ),
              ),
              const Text(' • ', style: TextStyle(color: Colors.grey)),
              Text(
                '₹${option.totalFairMin.round()} - ₹${option.totalFairMax.round()}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: option.riskLevel.color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  option.riskLevel.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: option.riskLevel.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            option.summaryOneLiner,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
