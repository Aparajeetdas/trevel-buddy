import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/community_repository.dart';
import '../../../../core/models/app_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/community_safety_widgets.dart';

/// Sub-form for reporting tourist traps into the database
class ReportTrapForm extends ConsumerStatefulWidget {
  final String? initialDescription;
  final String? initialType;

  const ReportTrapForm({super.key, this.initialDescription, this.initialType});

  @override
  ConsumerState<ReportTrapForm> createState() => _ReportTrapFormState();
}

class _ReportTrapFormState extends ConsumerState<ReportTrapForm> {
  String _trapType = 'overcharging';
  ServiceType _serviceType = ServiceType.auto;
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _tipController = TextEditingController();
  int _severity = 3;
  bool _isSubmitting = false;

  final List<String> _trapTypes = [
    'overcharging',
    'hidden charge',
    'meter tampering',
    'fake guide',
    'commission shop',
    'fake closure',
    'fake booking',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialDescription != null) {
      _descController.text = widget.initialDescription!;
    }
    if (widget.initialType != null && _trapTypes.contains(widget.initialType)) {
      _trapType = widget.initialType!;
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    _tipController.dispose();
    super.dispose();
  }

  Future<void> _submitTrap() async {
    final desc = _descController.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe the incident or location'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final trap = TouristTrap(
      id: 'trap-user-${DateTime.now().millisecondsSinceEpoch}',
      latitude: 26.9124, // Defaults to current hub
      longitude: 75.7873,
      serviceType: _serviceType,
      type: _trapType,
      description: desc,
      avoidTip: _tipController.text.trim().isNotEmpty
          ? _tipController.text.trim()
          : 'Exercise caution and verify prices beforehand.',
      severity: _severity,
      reportCount: 1,
      lastReported: DateTime.now(),
      source: 'community',
    );

    await ref.read(communityRepositoryProvider).submitTouristTrap(trap);
    ref.invalidate(touristTrapsFutureProvider);

    setState(() => _isSubmitting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tourist trap reported and added to live map intelligence!',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      _descController.clear();
      _tipController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CommunityDisclaimerBanner(),
          const Text(
            'Report a Tourist Trap or Scam',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'Alert fellow travellers about overcharging, touts, or fake closures.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: AppSpacing.md),

          // Trap Type Dropdown
          DropdownButtonFormField<String>(
            value: _trapType,
            decoration: const InputDecoration(labelText: 'Trap Type *'),
            items: _trapTypes
                .map(
                  (t) =>
                      DropdownMenuItem(value: t, child: Text(t.toUpperCase())),
                )
                .toList(),
            onChanged: (val) =>
                setState(() => _trapType = val ?? 'overcharging'),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Service Type
          DropdownButtonFormField<ServiceType>(
            value: _serviceType,
            decoration: const InputDecoration(labelText: 'Affected Service'),
            items: ServiceType.values
                .map(
                  (s) => DropdownMenuItem(value: s, child: Text(s.displayName)),
                )
                .toList(),
            onChanged: (val) =>
                setState(() => _serviceType = val ?? ServiceType.auto),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Description & Location
          TextField(
            controller: _descController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'What happened & where? *',
              hintText: 'e.g. Touts outside station claimed hotel was closed and forced us to emporium.',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Tip to Avoid
          TextField(
            controller: _tipController,
            decoration: const InputDecoration(
              labelText: 'Advice / How to Avoid',
              hintText: 'e.g. Call your hotel directly, ignore street touts.',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Severity Slider
          Text(
            'Severity Level: $_severity / 5',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          Slider(
            value: _severity.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            activeColor: AppColors.danger,
            label: '$_severity',
            onChanged: (val) => setState(() => _severity = val.toInt()),
          ),
          const SizedBox(height: AppSpacing.md),
          const PhotoEvidenceNotice(),
          const SizedBox(height: AppSpacing.lg),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitTrap,
              icon: const Icon(Icons.report_problem_rounded),
              label: Text(
                _isSubmitting ? 'Submitting...' : 'Submit Trap Report',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: AppColors.danger,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          Center(
            child: TextButton.icon(
              onPressed: () => TakedownAppealDialog.show(context),
              icon: const Icon(Icons.gavel_rounded, size: 15, color: Colors.grey),
              label: const Text(
                'Are you a driver or business? Request takedown or appeal',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
