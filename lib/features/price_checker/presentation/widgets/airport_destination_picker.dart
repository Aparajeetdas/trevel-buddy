import 'package:flutter/material.dart';

import '../../../../core/models/app_models.dart';

/// Modal bottom sheet or dialog to resolve ambiguous or unconfident airport destination matches.
/// Gives the user a clear picker of candidate prepaid routes with a 'Not listed' option.
class AirportDestinationPicker extends StatelessWidget {
  final String query;
  final List<FixedRouteTariff> candidates;
  final bool isAmbiguous;
  final ValueChanged<FixedRouteTariff?> onSelect;

  const AirportDestinationPicker({
    super.key,
    required this.query,
    required this.candidates,
    this.isAmbiguous = true,
    required this.onSelect,
  });

  /// Static helper to display picker as a bottom sheet
  static Future<FixedRouteTariff?> show(
    BuildContext context, {
    required String query,
    required List<FixedRouteTariff> candidates,
    bool isAmbiguous = true,
  }) {
    return showModalBottomSheet<FixedRouteTariff?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AirportDestinationPicker(
        query: query,
        candidates: candidates,
        isAmbiguous: isAmbiguous,
        onSelect: (selected) => Navigator.of(ctx).pop(selected),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
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
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.alt_route_rounded,
                          color: Color(0xFF3B82F6),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAmbiguous
                                  ? 'Select Specific Area'
                                  : 'Confirm Prepaid Destination',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Matches for "$query"',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => onSelect(null),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'The LGBI Airport prepaid taxi counter has fixed official fares. Please select your exact destination or choose "Not listed":',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white70 : Colors.black87,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Candidate List
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: candidates.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final tariff = candidates[index];
                  return _CandidateTile(
                    tariff: tariff,
                    isDark: isDark,
                    onTap: () => onSelect(tariff),
                  );
                },
              ),
            ),

            const Divider(height: 1),

            // 'Not Listed' Option
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                key: const Key('airport_picker_not_listed_btn'),
                onPressed: () => onSelect(null),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.help_outline_rounded, size: 20),
                label: const Text(
                  'Not listed / Other area',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  final FixedRouteTariff tariff;
  final bool isDark;
  final VoidCallback onTap;

  const _CandidateTile({
    required this.tariff,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              // Icon Badge
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_taxi_rounded,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),

              // Destination & details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            tariff.destinationName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (tariff.destinationNameHi != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            '(${tariff.destinationNameHi})',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${tariff.km.round()} km',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tariff.category,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                          ),
                        ),
                        if (tariff.hasFlagCheckPrintedList) ...[
                          const SizedBox(width: 6),
                          const Text(
                            '• Confirm at counter',
                            style: TextStyle(fontSize: 11, color: Color(0xFFF59E0B)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Fare Badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${tariff.fare.round()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const Text(
                    'Official Fare',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
