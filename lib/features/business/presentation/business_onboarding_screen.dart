import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/local_data_repository.dart';
import '../../../core/models/app_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_brand_app_bar.dart';

class BusinessOnboardingScreen extends ConsumerStatefulWidget {
  const BusinessOnboardingScreen({super.key});

  @override
  ConsumerState<BusinessOnboardingScreen> createState() =>
      _BusinessOnboardingScreenState();
}

class _BusinessOnboardingScreenState
    extends ConsumerState<BusinessOnboardingScreen> {
  String _businessType = 'Driver';
  final TextEditingController _businessNameController = TextEditingController(
    text: 'Jaipur Heritage Express',
  );
  final TextEditingController _ownerNameController = TextEditingController(
    text: 'Vikram Singh',
  );
  final TextEditingController _regNumberController = TextEditingController(
    text: 'RJ 14 TB 9901',
  );
  final TextEditingController _serviceController = TextEditingController(
    text: 'Airport Transfer, Full Day Tour',
  );
  final TextEditingController _rateController = TextEditingController(
    text: '1500',
  );

  @override
  void dispose() {
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _regNumberController.dispose();
    _serviceController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _submitBusiness() async {
    final name = _businessNameController.text.trim();
    if (name.isEmpty) return;

    final id = 'biz_${DateTime.now().millisecondsSinceEpoch}';
    final rate = double.tryParse(_rateController.text.trim()) ?? 1200.0;
    final services = _serviceController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final profile = BusinessProfile(
      id: id,
      businessName: name,
      businessType: _businessType,
      ownerName: _ownerNameController.text.trim(),
      vehicleOrRegNumber: _regNumberController.text.trim(),
      isVerified: true, // Instantly verified as required
      trustScore: 4.9,
      reviewsCount: 14,
      services: services.isNotEmpty ? services : ['Standard Service'],
      ownPrices: {'Standard Tariff': rate, 'Full Day Package': rate * 1.8},
      priceCap: rate * 1.25,
      phone: '+91 98290 12345',
      address: 'City Center, Rajasthan',
    );

    await ref
        .read(businessProfileNotifierProvider.notifier)
        .addProfile(profile);

    if (mounted) {
      context.pushReplacement('/business/profile/$id');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const AppBrandAppBar(
        title: 'Business Account Setup',
        showBackButton: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withOpacity(0.4),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.verified_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Join the verified network. Stand out to tourists with transparent prices and trust badges.',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Business Type
          Text(
            'Select Business Type',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'Driver',
                label: Text('Driver'),
                icon: Icon(Icons.local_taxi_rounded),
              ),
              ButtonSegment(
                value: 'Hotel',
                label: Text('Hotel'),
                icon: Icon(Icons.hotel_rounded),
              ),
              ButtonSegment(
                value: 'Restaurant',
                label: Text('Restaurant'),
                icon: Icon(Icons.restaurant_rounded),
              ),
            ],
            selected: {_businessType},
            onSelectionChanged: (set) {
              setState(() => _businessType = set.first);
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          // Details Form
          TextField(
            controller: _businessNameController,
            decoration: const InputDecoration(
              labelText: 'Business / Fleet Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          TextField(
            controller: _ownerNameController,
            decoration: const InputDecoration(
              labelText: 'Owner / Contact Person',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          TextField(
            controller: _regNumberController,
            decoration: InputDecoration(
              labelText: _businessType == 'Driver'
                  ? 'Vehicle Registration Number'
                  : 'Trade License / Reg Number',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          TextField(
            controller: _serviceController,
            decoration: const InputDecoration(
              labelText: 'Services Offered (comma separated)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          TextField(
            controller: _rateController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Standard Fair Price (₹)',
              prefixText: '₹ ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          ElevatedButton.icon(
            onPressed: _submitBusiness,
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('Register & Get Instantly Verified'),
          ),
        ],
      ),
    );
  }
}
