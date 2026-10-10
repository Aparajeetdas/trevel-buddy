import 'package:flutter/material.dart';

import '../../../../core/models/app_models.dart';

/// Adaptive service-specific fields for the Check a Price form
class PriceInputAdaptiveFields extends StatelessWidget {
  final ServiceType serviceType;
  final bool isNightTime;
  final bool meterUsed;
  final double guideHours;
  final int guideGroupSize;
  final int mealPeople;
  final int roomNights;
  final ValueChanged<bool> onNightTimeChanged;
  final ValueChanged<bool> onMeterUsedChanged;
  final ValueChanged<double> onGuideHoursChanged;
  final ValueChanged<int> onGuideGroupSizeChanged;
  final ValueChanged<int> onMealPeopleChanged;
  final ValueChanged<int> onRoomNightsChanged;

  const PriceInputAdaptiveFields({
    super.key,
    required this.serviceType,
    required this.isNightTime,
    required this.meterUsed,
    required this.guideHours,
    required this.guideGroupSize,
    required this.mealPeople,
    required this.roomNights,
    required this.onNightTimeChanged,
    required this.onMeterUsedChanged,
    required this.onGuideHoursChanged,
    required this.onGuideGroupSizeChanged,
    required this.onMealPeopleChanged,
    required this.onRoomNightsChanged,
  });

  bool get _isRideType =>
      serviceType == ServiceType.auto ||
      serviceType == ServiceType.taxi ||
      serviceType == ServiceType.bikeTaxi;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_isRideType) ...[
          SwitchListTile(
            title: const Text(
              'Night time ride (11 PM - 5 AM)?',
              style: TextStyle(fontSize: 14),
            ),
            value: isNightTime,
            onChanged: onNightTimeChanged,
          ),
          SwitchListTile(
            title: const Text(
              'Was meter used?',
              style: TextStyle(fontSize: 14),
            ),
            value: meterUsed,
            onChanged: onMeterUsedChanged,
          ),
        ],
        if (serviceType == ServiceType.guide)
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<double>(
                  value: guideHours,
                  decoration: const InputDecoration(labelText: 'Duration'),
                  items: [1.0, 2.0, 4.0, 8.0]
                      .map(
                        (h) => DropdownMenuItem(
                          value: h,
                          child: Text('${h.toInt()} Hours'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => onGuideHoursChanged(v ?? 2.0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: guideGroupSize,
                  decoration: const InputDecoration(labelText: 'Group Size'),
                  items: [1, 2, 4, 8]
                      .map(
                        (g) => DropdownMenuItem(
                          value: g,
                          child: Text('$g Persons'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => onGuideGroupSizeChanged(v ?? 2),
                ),
              ),
            ],
          ),
        if (serviceType == ServiceType.meal)
          DropdownButtonFormField<int>(
            value: mealPeople,
            decoration: const InputDecoration(labelText: 'Number of Diners'),
            items: [1, 2, 3, 4, 6]
                .map(
                  (p) => DropdownMenuItem(value: p, child: Text('$p People')),
                )
                .toList(),
            onChanged: (v) => onMealPeopleChanged(v ?? 2),
          ),
        if (serviceType == ServiceType.room)
          DropdownButtonFormField<int>(
            value: roomNights,
            decoration: const InputDecoration(labelText: 'Nights'),
            items: [1, 2, 3, 5, 7]
                .map(
                  (n) => DropdownMenuItem(value: n, child: Text('$n Night(s)')),
                )
                .toList(),
            onChanged: (v) => onRoomNightsChanged(v ?? 1),
          ),
      ],
    );
  }
}
