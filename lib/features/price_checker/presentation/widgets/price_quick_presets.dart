import 'package:flutter/material.dart';

import '../../../../core/models/app_models.dart';

/// Preset chips for testing the price intelligence checker
class PriceQuickPresets extends StatelessWidget {
  final void Function(
    ServiceType type,
    String pickup,
    String drop,
    double quote,
  )
  onSelect;

  const PriceQuickPresets({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Test Presets:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ActionChip(
              avatar: const Icon(Icons.flight_takeoff_rounded, size: 14),
              label: const Text(
                'Airport → Ganeshguri ₹1,200 (Scam)',
                style: TextStyle(fontSize: 11),
              ),
              onPressed: () => onSelect(
                ServiceType.taxi,
                'LGBI Airport, Guwahati',
                'Ganeshguri',
                1200,
              ),
            ),
            ActionChip(
              label: const Text(
                'Jaipur Auto ₹250 (Trap)',
                style: TextStyle(fontSize: 11),
              ),
              onPressed: () => onSelect(
                ServiceType.auto,
                'Jaipur Junction',
                'Hawa Mahal',
                250,
              ),
            ),
            ActionChip(
              label: const Text(
                'Amer Guide ₹2200 (Scam)',
                style: TextStyle(fontSize: 11),
              ),
              onPressed: () =>
                  onSelect(ServiceType.guide, 'Amer Fort', 'Amer Fort', 2200),
            ),
            ActionChip(
              label: const Text(
                'Delhi Auto ₹60 (Fair)',
                style: TextStyle(fontSize: 11),
              ),
              onPressed: () => onSelect(
                ServiceType.auto,
                'NDLS Station',
                'Connaught Place',
                60,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
