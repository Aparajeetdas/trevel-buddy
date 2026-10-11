import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/google_maps_service.dart';
import '../../../../core/data/auth_repository.dart';
import '../../../../core/data/community_repository.dart';
import '../../../../core/models/app_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/report_security_validator.dart';
import '../../../../core/widgets/community_safety_widgets.dart';

/// Sub-form for reporting paid prices to strengthen community benchmarks
class ReportPriceForm extends ConsumerStatefulWidget {
  final String? initialPlace;
  final double? initialPrice;
  final VoidCallback? onReportSubmitted;

  const ReportPriceForm({
    super.key,
    this.initialPlace,
    this.initialPrice,
    this.onReportSubmitted,
  });

  @override
  ConsumerState<ReportPriceForm> createState() => _ReportPriceFormState();
}

class _ReportPriceFormState extends ConsumerState<ReportPriceForm> {
  ServiceType _serviceType = ServiceType.auto;
  final TextEditingController _routeController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _vehicleTypeController = TextEditingController(
    text: 'Auto-rickshaw',
  );
  final TextEditingController _notesController = TextEditingController();
  bool _wasFair = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPlace != null) {
      _routeController.text = widget.initialPlace!;
    }
    if (widget.initialPrice != null) {
      _priceController.text = widget.initialPrice!.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _routeController.dispose();
    _priceController.dispose();
    _vehicleTypeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    final price = double.tryParse(_priceController.text.trim());
    final route = _routeController.text.trim();

    if (price == null || price <= 0 || route.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide route and valid price paid'),
        ),
      );
      return;
    }

    // Price sanity bounds check
    final sanityCheck = ReportSecurityValidator.validatePriceSanity(_serviceType, price);
    if (!sanityCheck.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(sanityCheck.errorMessage ?? 'Price out of realistic range'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    // Signed-out check: prompt user to sign in while preserving their entered form inputs
    final currentUser = ref.read(authRepositoryProvider).currentUser;
    if (currentUser == null) {
      final didSignIn = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sign in to submit report'),
          content: const Text(
            'Please sign in to keep community pricing accurate and prevent spam. Your entered report details are saved.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.account_circle),
              label: const Text('Sign in with Google'),
              onPressed: () async {
                await ref.read(authRepositoryProvider).signInWithGoogle();
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
            ),
          ],
        ),
      );
      if (didSignIn != true || ref.read(authRepositoryProvider).currentUser == null) {
        return;
      }
    }

    setState(() => _isSubmitting = true);

    final areaName = ref.read(activeCityProvider)?.name ?? 'Guwahati';
    final user = ref.read(authRepositoryProvider).currentUser;

    try {
      final report = PriceReport(
        id: 'pr-user-${DateTime.now().millisecondsSinceEpoch}',
        serviceType: _serviceType,
        vehicleType: _vehicleTypeController.text.trim(),
        routeOrPlace: route,
        pricePaid: price,
        areaId: areaName,
        status: 'under_review',
        createdAt: DateTime.now(),
        timestamp: DateTime.now(),
        wasFair: _wasFair,
        userId: user?.uid,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      await ref.read(communityRepositoryProvider).submitPriceReport(report);
      ref.invalidate(priceReportsFutureProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Report added - helping fellow travellers in $areaName',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        _priceController.clear();
        _notesController.clear();
        widget.onReportSubmitted?.call();
      }
    } catch (e) {
      if (mounted) {
        final plainError = e is StateError
            ? e.message
            : (e is ArgumentError ? e.message.toString() : 'Submission failed: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(plainError),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mandatory Disclaimer Banner
          const CommunityDisclaimerBanner(),

          const Text(
            'Contribute to Community Price Benchmarks',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your verified submission helps fellow travellers avoid rip-offs.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: AppSpacing.md),

          // Service Type
          DropdownButtonFormField<ServiceType>(
            value: _serviceType,
            decoration: const InputDecoration(labelText: 'Service Type'),
            items: ServiceType.values
                .map(
                  (s) => DropdownMenuItem(value: s, child: Text(s.displayName)),
                )
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _serviceType = val;
                  _vehicleTypeController.text = val == ServiceType.auto
                      ? 'Auto-rickshaw'
                      : val == ServiceType.taxi
                      ? 'Sedan Cab'
                      : 'Standard';
                });
              }
            },
          ),
          const SizedBox(height: AppSpacing.sm),

          // Route / Place
          TextField(
            controller: _routeController,
            decoration: const InputDecoration(
              labelText: 'Route or Venue / Place *',
              hintText: 'e.g. Jaipur Station to Hawa Mahal',
              prefixIcon: Icon(Icons.route_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Price Paid
          TextField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Price Paid (₹) *',
              hintText: 'e.g. 110',
              prefixText: '₹ ',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Was it fair?
          SwitchListTile(
            title: const Text('Did you feel this price was fair?'),
            subtitle: Text(
              _wasFair
                  ? 'Yes, fair local price'
                  : 'No, felt overcharged or high',
            ),
            value: _wasFair,
            activeColor: AppColors.primary,
            onChanged: (val) => setState(() => _wasFair = val),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Notes
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Optional Notes / Details',
              hintText: 'e.g. Driver negotiated nicely, or refused meter',
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          const PhotoEvidenceNotice(),
          const SizedBox(height: AppSpacing.lg),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitReport,
              icon: const Icon(Icons.check_circle_rounded),
              label: Text(
                _isSubmitting ? 'Submitting...' : 'Submit Price Report',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: AppColors.primary,
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
