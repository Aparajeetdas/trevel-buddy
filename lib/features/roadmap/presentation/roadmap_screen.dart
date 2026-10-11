import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/roadmap_models.dart';
import '../../../../core/services/roadmap_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_brand_app_bar.dart';
import '../../../../core/widgets/empty_state.dart';
import 'go_mode_screen.dart';
import 'widgets/roadmap_checklist_card.dart';
import 'widgets/roadmap_header_card.dart';
import '../../../../core/services/map_launcher_service.dart';
import 'widgets/roadmap_option_tabs.dart';
import 'widgets/roadmap_step_card.dart';

/// Full-screen Journey Roadmap Page ("Go Here")
class RoadmapScreen extends ConsumerStatefulWidget {
  final RoadmapLocation? initialOrigin;
  final RoadmapLocation? initialDestination;
  final String preference;

  const RoadmapScreen({
    super.key,
    this.initialOrigin,
    this.initialDestination,
    this.preference = 'Fastest',
  });

  @override
  ConsumerState<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends ConsumerState<RoadmapScreen> {
  late final TextEditingController _originController;
  late final TextEditingController _destController;

  RoadmapLocation? _origin;
  RoadmapLocation? _destination;
  late DateTime _departTime;
  int _travelers = 1;
  late String _preference;

  Roadmap? _roadmap;
  int _selectedOptionIndex = 0;
  int? _focusedStepIndex;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _origin = widget.initialOrigin;
    _destination = widget.initialDestination;
    _departTime = DateTime.now();
    _preference = widget.preference;

    _originController = TextEditingController(text: _origin?.name ?? '');
    _destController = TextEditingController(text: _destination?.name ?? '');

    if (_origin != null && _destination != null) {
      _loadRoadmap();
    }
  }

  @override
  void dispose() {
    _originController.dispose();
    _destController.dispose();
    super.dispose();
  }

  Future<void> _loadRoadmap() async {
    final orig = _origin;
    final dest = _destination;
    if (orig == null || dest == null) {
      setState(() {
        _isLoading = false;
        _roadmap = null;
      });
      return;
    }

    setState(() => _isLoading = true);
    final service = ref.read(roadmapServiceProvider);
    final roadmap = await service.planRoadmap(
      origin: orig,
      destination: dest,
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
      _originController.text = _origin?.name ?? '';
      _destController.text = _destination?.name ?? '';
    });
    if (_origin != null && _destination != null) {
      _loadRoadmap();
    }
  }

  void _startJourney() {
    final roadmap = _roadmap;
    final orig = _origin;
    final dest = _destination;
    if (roadmap == null || roadmap.options.isEmpty || orig == null || dest == null) return;
    final selectedOption = roadmap
        .options[_selectedOptionIndex.clamp(0, roadmap.options.length - 1)];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GoModeScreen(
          origin: orig,
          destination: dest,
          option: selectedOption,
        ),
      ),
    );
  }

  void _openFullRouteInMaps(RoadmapOption option) {
    final dest = _destination;
    if (dest == null) return;
    final waypoints = option.steps
        .take(9)
        .map((s) => '${s.endLat},${s.endLng}')
        .toList();
    ref.read(mapLauncherServiceProvider).openDirectionsSynchronously(
          origin: _origin,
          destination: dest,
          mode: option.primaryMode,
          waypoints: waypoints.length > 1
              ? waypoints.sublist(0, waypoints.length - 1)
              : const [],
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

    final originTitle = _origin?.name.isNotEmpty == true ? _origin!.name : 'Pick Origin';
    final destTitle = _destination?.name.isNotEmpty == true ? _destination!.name : 'Pick Destination';

    return Scaffold(
      appBar: AppBrandAppBar(
        title: 'Roadmap • $originTitle → $destTitle',
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
      body: _isLoading
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
          : (_origin == null || _destination == null || roadmap == null || selectedOption == null)
              ? ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    RoadmapHeaderCard(
                      originController: _originController,
                      destController: _destController,
                      onSwap: _swapLocations,
                      departTime: _departTime,
                      onDepartTimeChanged: (dt) {
                        setState(() => _departTime = dt);
                        _loadRoadmap();
                      },
                      travelers: _travelers,
                      onTravelersChanged: (t) {
                        setState(() => _travelers = t);
                        _loadRoadmap();
                      },
                      selectedPreference: _preference,
                      onPreferenceChanged: (p) {
                        setState(() => _preference = p);
                        _loadRoadmap();
                      },
                      onRefreshRoute: _loadRoadmap,
                      onOriginLocationSelected: (loc) {
                        setState(() {
                          _origin = loc;
                          _originController.text = loc.name;
                        });
                        if (_origin != null && _destination != null) {
                          _loadRoadmap();
                        }
                      },
                      onDestLocationSelected: (loc) {
                        setState(() {
                          _destination = loc;
                          _destController.text = loc.name;
                        });
                        if (_origin != null && _destination != null) {
                          _loadRoadmap();
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const EmptyState(
                      icon: Icons.alt_route_rounded,
                      title: 'Choose Starting Point & Destination',
                      message:
                          'Select your origin and destination above to compute fair tariffs and safe route options.',
                    ),
                  ],
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
                      onDepartTimeChanged: (dt) {
                        setState(() => _departTime = dt);
                        _loadRoadmap();
                      },
                      travelers: _travelers,
                      onTravelersChanged: (t) {
                        setState(() => _travelers = t);
                        _loadRoadmap();
                      },
                      selectedPreference: _preference,
                      onPreferenceChanged: (p) {
                        setState(() => _preference = p);
                        _loadRoadmap();
                      },
                      onRefreshRoute: _loadRoadmap,
                      onOriginLocationSelected: (loc) {
                        setState(() {
                          _origin = loc;
                          _originController.text = loc.name;
                        });
                        if (_origin != null && _destination != null) {
                          _loadRoadmap();
                        }
                      },
                      onDestLocationSelected: (loc) {
                        setState(() {
                          _destination = loc;
                          _destController.text = loc.name;
                        });
                        if (_origin != null && _destination != null) {
                          _loadRoadmap();
                        }
                      },
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
