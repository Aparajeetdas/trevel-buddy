import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/community_repository.dart';
import '../../../../core/models/ai_price_models.dart';
import '../../../../core/models/app_models.dart';
import '../../../../core/models/roadmap_models.dart';
import '../../../../core/services/saved_trips_service.dart';
import '../../../../core/theme/app_theme.dart';

/// Modal bottom sheet celebrating journey arrival and gathering benchmark feedback
class JourneyArrivalSheet extends ConsumerStatefulWidget {
  final RoadmapLocation origin;
  final RoadmapLocation destination;
  final RoadmapOption option;

  const JourneyArrivalSheet({
    super.key,
    required this.origin,
    required this.destination,
    required this.option,
  });

  @override
  ConsumerState<JourneyArrivalSheet> createState() =>
      _JourneyArrivalSheetState();
}

class _JourneyArrivalSheetState extends ConsumerState<JourneyArrivalSheet> {
  final TextEditingController _paidController = TextEditingController();
  bool _submittedBenchmark = false;
  bool _savedTrip = false;
  double? _enteredAmount;

  @override
  void dispose() {
    _paidController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String val) {
    setState(() {
      _enteredAmount = double.tryParse(val.trim());
    });
  }

  Future<void> _submitBenchmark() async {
    final amount = _enteredAmount ?? widget.option.totalFairMax;
    final isFair = amount <= (widget.option.totalFairMax * 1.05);

    final report = PriceReport(
      id: 'rpt_${DateTime.now().millisecondsSinceEpoch}',
      serviceType: ServiceType.auto,
      vehicleType: widget.option.label,
      routeOrPlace: '${widget.origin.name} to ${widget.destination.name}',
      pickupLat: widget.origin.lat,
      pickupLng: widget.origin.lng,
      dropLat: widget.destination.lat,
      dropLng: widget.destination.lng,
      pricePaid: amount,
      timestamp: DateTime.now(),
      wasFair: isFair,
      notes: 'Roadmap trip: ${widget.option.label}',
    );

    await ref.read(communityRepositoryProvider).submitPriceReport(report);
    if (!mounted) return;
    setState(() => _submittedBenchmark = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '🎉 Thank you! Price benchmark shared with fellow travelers.',
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _saveTrip() async {
    final trip = SavedTrip(
      id: 'trip_${DateTime.now().millisecondsSinceEpoch}',
      originName: widget.origin.name,
      originLat: widget.origin.lat,
      originLng: widget.origin.lng,
      destName: widget.destination.name,
      destLat: widget.destination.lat,
      destLng: widget.destination.lng,
      selectedOptionLabel: widget.option.label,
      totalFairMin: widget.option.totalFairMin,
      totalFairMax: widget.option.totalFairMax,
      createdAt: DateTime.now(),
    );

    await ref.read(savedTripsServiceProvider).saveTrip(trip);
    if (!mounted) return;
    setState(() => _savedTrip = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Trip saved to your local offline history!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _shareRoute() {
    final text = ref
        .read(savedTripsServiceProvider)
        .formatShareText(widget.option, widget.origin, widget.destination);
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Route breakdown copied to clipboard!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fairMin = widget.option.totalFairMin.round();
    final fairMax = widget.option.totalFairMax.round();

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Center(child: Text('🎉', style: TextStyle(fontSize: 42))),
            const SizedBox(height: 8),
            Text(
              'Arrived at ${widget.destination.name}!',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'From ${widget.origin.name} • ${widget.option.label} (~${widget.option.totalMin.round()}m)',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),

            // Fair estimate comparison card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.4),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Route Fair Estimate',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '₹$fairMin - ₹$fairMax',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _paidController,
                    keyboardType: TextInputType.number,
                    onChanged: _onAmountChanged,
                    decoration: InputDecoration(
                      labelText: 'Total amount you actually paid (₹)',
                      hintText: 'e.g. $fairMax',
                      prefixIcon: const Icon(
                        Icons.currency_rupee_rounded,
                        size: 18,
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                  ),
                  if (_enteredAmount != null) ...[
                    const SizedBox(height: 10),
                    _buildVerdictBadge(
                      _enteredAmount!,
                      widget.option.totalFairMax,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons
            ElevatedButton.icon(
              onPressed: _submittedBenchmark ? null : _submitBenchmark,
              icon: Icon(
                _submittedBenchmark
                    ? Icons.check_circle_rounded
                    : Icons.volunteer_activism_rounded,
              ),
              label: Text(
                _submittedBenchmark
                    ? 'Benchmark Recorded'
                    : 'Submit to Community Benchmarks',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _savedTrip ? null : _saveTrip,
                    icon: Icon(
                      _savedTrip
                          ? Icons.bookmark_added_rounded
                          : Icons.bookmark_border_rounded,
                      size: 18,
                    ),
                    label: Text(_savedTrip ? 'Saved' : 'Save Trip'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _shareRoute,
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Share Breakdown'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close sheet
                Navigator.pop(context); // Exit Go Mode
              },
              child: const Text('Done & Return to Travel Buddy'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerdictBadge(double paid, double fairMax) {
    final isFair = paid <= (fairMax * 1.05);
    final diff = (paid - fairMax).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isFair ? AppColors.successContainer : AppColors.warningContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            isFair ? Icons.verified_rounded : Icons.warning_amber_rounded,
            size: 16,
            color: isFair ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isFair
                  ? 'Great deal! You stayed within fair market rates.'
                  : 'Paid ₹$diff above upper benchmark. Thanks for reporting!',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isFair ? AppColors.success : AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
