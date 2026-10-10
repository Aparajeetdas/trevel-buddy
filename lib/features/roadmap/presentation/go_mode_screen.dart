import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/roadmap_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/map_launcher_service.dart';
import 'widgets/go_mode_step_hud.dart';
import 'widgets/journey_arrival_sheet.dart';

/// Live "Go Mode" guiding traveler step-by-step with live GPS HUD and fare alerts
class GoModeScreen extends ConsumerStatefulWidget {
  final RoadmapLocation origin;
  final RoadmapLocation destination;
  final RoadmapOption option;

  const GoModeScreen({
    super.key,
    required this.origin,
    required this.destination,
    required this.option,
  });

  @override
  ConsumerState<GoModeScreen> createState() => _GoModeScreenState();
}

class _GoModeScreenState extends ConsumerState<GoModeScreen> {
  int _currentStepIndex = 0;
  bool _isOffRoute = false;

  List<RoadmapStep> get _steps => widget.option.steps;
  RoadmapStep get _currentStep => _steps.isNotEmpty
      ? _steps[_currentStepIndex.clamp(0, _steps.length - 1)]
      : _dummyStep;

  RoadmapStep get _dummyStep => RoadmapStep(
    index: 1,
    mode: 'walk',
    title: 'Proceed to destination',
    instruction: 'Follow main road to arrival point',
    fromName: widget.origin.name,
    toName: widget.destination.name,
    startLat: widget.origin.lat,
    startLng: widget.origin.lng,
    endLat: widget.destination.lat,
    endLng: widget.destination.lng,
    distanceM: 500,
    durationMin: 5,
    fairMin: 0,
    fairMax: 0,
    dontPayMoreThan: 0,
    priceSource: '[Estimate]',
    boardingPoint: '',
  );

  void _advanceStep() {
    if (_currentStepIndex < _steps.length - 1) {
      setState(() {
        _currentStepIndex++;
        _isOffRoute = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '📍 Step ${_currentStepIndex + 1}: ${_currentStep.title}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      _finishJourney();
    }
  }

  void _previousStep() {
    if (_currentStepIndex > 0) {
      setState(() {
        _currentStepIndex--;
        _isOffRoute = false;
      });
    }
  }

  void _recalculateRoute() {
    setState(() => _isOffRoute = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '🔄 Route recalculated from current location! Back on track.',
        ),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _finishJourney() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => JourneyArrivalSheet(
        origin: widget.origin,
        destination: widget.destination,
        option: widget.option,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(theme),
            if (_isOffRoute) _buildOffRouteBanner(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ref
                            .read(mapLauncherServiceProvider)
                            .openDirections(
                              origin:
                                  '${_currentStep.startLat},${_currentStep.startLng}',
                              destination:
                                  '${_currentStep.endLat},${_currentStep.endLng}',
                              originName: _currentStep.fromName,
                              destName: _currentStep.toName,
                              mode: _currentStep.mode == 'walk'
                                  ? 'walking'
                                  : 'driving',
                              context: context,
                            );
                      },
                      icon: const Icon(Icons.navigation_rounded, size: 16),
                      label: const Text('Open step in Maps'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: 'Full route in Maps',
                    icon: const Icon(
                      Icons.map_rounded,
                      color: AppColors.primary,
                    ),
                    onPressed: () {
                      ref
                          .read(mapLauncherServiceProvider)
                          .openDirections(
                            origin: '${widget.origin.lat},${widget.origin.lng}',
                            destination:
                                '${widget.destination.lat},${widget.destination.lng}',
                            originName: widget.origin.name,
                            destName: widget.destination.name,
                            context: context,
                          );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: GoModeStepHud(
                currentStep: _currentStep,
                currentStepIndex: _currentStepIndex,
                totalSteps: _steps.length,
                originName: widget.origin.name,
                destinationName: widget.destination.name,
                onPrevious: _previousStep,
                onNext: _advanceStep,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Exit Go Mode',
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step ${_currentStepIndex + 1} of ${_steps.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(
                  widget.destination.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              _isOffRoute ? Icons.gps_off_rounded : Icons.gps_fixed_rounded,
            ),
            color: _isOffRoute ? AppColors.warning : AppColors.primary,
            tooltip: 'Simulate off-route drift',
            onPressed: () => setState(() => _isOffRoute = !_isOffRoute),
          ),
        ],
      ),
    );
  }

  Widget _buildOffRouteBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.warningContainer,
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: AppColors.warning,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Off-route by >200m! Recalculate?',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.warning,
              ),
            ),
          ),
          TextButton(
            onPressed: _recalculateRoute,
            child: const Text(
              'Recalculate',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
