import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/local_data_repository.dart';
import '../../../core/models/app_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_brand_app_bar.dart';
import 'widgets/driver_verification_result.dart';

class VerifyDriverScreen extends ConsumerStatefulWidget {
  const VerifyDriverScreen({super.key});

  @override
  ConsumerState<VerifyDriverScreen> createState() => _VerifyDriverScreenState();
}

class _VerifyDriverScreenState extends ConsumerState<VerifyDriverScreen> {
  final TextEditingController _vehicleController = TextEditingController();
  Driver? _foundDriver;
  bool _searched = false;

  @override
  void dispose() {
    _vehicleController.dispose();
    super.dispose();
  }

  Future<void> _searchDriver() async {
    final query = _vehicleController.text.trim();
    if (query.isEmpty) return;

    final repo = ref.read(appRepositoryProvider);
    final driver = await repo.getDriverByVehicleNumber(query);

    setState(() {
      _searched = true;
      _foundDriver = driver;
    });
  }

  void _fillSample(String vehicleNum) {
    _vehicleController.text = vehicleNum;
    _searchDriver();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const AppBrandAppBar(
        title: 'Verify Driver & Vehicle',
        showBackButton: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withOpacity(0.4),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.security_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Instant verification for tourist taxis, autos, and commercial drivers across India.',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Vehicle Number Search Input
          Text(
            'Enter Vehicle Registration Number',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _vehicleController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'e.g. RJ 14 TA 8821 or UP 80 BT 9924',
              prefixIcon: const Icon(
                Icons.pin_rounded,
                color: AppColors.primary,
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search_rounded),
                onPressed: _searchDriver,
              ),
              filled: true,
              fillColor: theme.cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            onSubmitted: (_) => _searchDriver(),
          ),
          const SizedBox(height: AppSpacing.md),

          // Quick seed vehicle number chips for easy demo tapping
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              const Text(
                'Quick Test: ',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              InkWell(
                onTap: () => _fillSample('RJ 14 TA 8821'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'RJ 14 TA 8821 (Verified)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ),
              InkWell(
                onTap: () => _fillSample('UP 80 BT 9924'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.dangerContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'UP 80 BT 9924 (Unverified)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          ElevatedButton.icon(
            onPressed: _searchDriver,
            icon: const Icon(Icons.verified_user_rounded),
            label: const Text('Check Verification Status'),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Result Card
          if (_searched) ...[
            if (_foundDriver != null)
              DriverVerificationResultCard(driver: _foundDriver!)
            else
              const DriverNotFoundCard(),
          ],
        ],
      ),
    );
  }
}
