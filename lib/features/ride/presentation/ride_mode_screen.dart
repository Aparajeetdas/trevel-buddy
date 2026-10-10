import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/fair_price_calculator.dart';
import '../../../core/widgets/app_brand_app_bar.dart';

/// Real-time Ride Mode with live fare tracker and Price Intelligence integration
class RideModeScreen extends StatefulWidget {
  final String? initialOrigin;
  final String? initialDestination;
  final double? quotedPrice;

  const RideModeScreen({
    super.key,
    this.initialOrigin,
    this.initialDestination,
    this.quotedPrice,
  });

  @override
  State<RideModeScreen> createState() => _RideModeScreenState();
}

class _RideModeScreenState extends State<RideModeScreen> {
  Timer? _timer;
  int _seconds = 0;
  double _distanceKm = 0.0;
  double _runningFare = 30.0; // Starting base fare
  bool _isRideActive = true;
  double? _driverQuotedPrice;

  @override
  void initState() {
    super.initState();
    _driverQuotedPrice = widget.quotedPrice ?? 250.0;
    _startMeter();
  }

  void _startMeter() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isRideActive) return;
      setState(() {
        _seconds++;
        _distanceKm += 0.015; // Simulated travel progression
        _runningFare = 30.0 + (_distanceKm * 12.0) + ((_seconds / 60.0) * 0.5);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final origin = widget.initialOrigin ?? 'Jaipur Railway Station';
    final destination = widget.initialDestination ?? 'Hawa Mahal, Pink City';

    // Real-time evaluation against current running estimate
    final eval = FairPriceCalculator.evaluate(
      quotedPrice: _driverQuotedPrice ?? _runningFare,
      fairMin: _runningFare * 0.95,
      fairMax: _runningFare * 1.15,
    );

    return Scaffold(
      appBar: const AppBrandAppBar(
        title: 'Ride Mode: Live Fare Monitor',
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _isRideActive
                                  ? AppColors.success
                                  : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isRideActive
                                ? 'LIVE TRACKING ACTIVE'
                                : 'RIDE PAUSED',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetric(
                        'Distance',
                        '${_distanceKm.toStringAsFixed(2)} km',
                      ),
                      _buildMetric(
                        'Running Fare',
                        '₹${_runningFare.toStringAsFixed(0)}',
                      ),
                      _buildMetric(
                        'Quoted Price',
                        '₹${_driverQuotedPrice?.toStringAsFixed(0) ?? "--"}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Route Points
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.my_location_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            origin,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(height: 16, child: VerticalDivider()),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: AppColors.danger,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            destination,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Driver Quoted Price Verdict Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: eval.verdictColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: eval.verdictColor.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Icon(eval.verdictIcon, color: eval.verdictColor, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Driver Quote Verdict: ${eval.verdictTitle}',
                          style: TextStyle(
                            color: eval.verdictColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          eval.verdictMessage,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Hero Action: Check a Price Before You Pay
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.push('/check-price', extra: destination);
                },
                icon: const Icon(Icons.calculate_rounded),
                label: const Text('Check a Price Before You Pay'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Ride controls
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        setState(() => _isRideActive = !_isRideActive),
                    child: Text(_isRideActive ? 'Pause Ride' : 'Resume Ride'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('End Ride'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}
