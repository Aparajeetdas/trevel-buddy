import 'package:flutter/material.dart';

import '../../../../core/models/app_models.dart';
import '../../../../core/theme/app_theme.dart';

class FairPriceTestPresets extends StatelessWidget {
  final FairPrice item;
  final ValueChanged<int> onSelectPrice;

  const FairPriceTestPresets({
    super.key,
    required this.item,
    required this.onSelectPrice,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        const Text(
          'Test Presets: ',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        ActionChip(
          label: Text(
            'Fair: ₹${item.fairMin.toInt()}',
            style: const TextStyle(fontSize: 11),
          ),
          backgroundColor: AppColors.successContainer.withOpacity(0.5),
          onPressed: () => onSelectPrice(item.fairMin.toInt()),
        ),
        ActionChip(
          label: Text(
            'High: ₹${(item.fairMax * 1.2).toInt()}',
            style: const TextStyle(fontSize: 11),
          ),
          backgroundColor: AppColors.warningContainer.withOpacity(0.5),
          onPressed: () => onSelectPrice((item.fairMax * 1.2).toInt()),
        ),
        ActionChip(
          label: Text(
            'Rip-off: ₹${(item.fairMax * 1.75).toInt()}',
            style: const TextStyle(fontSize: 11),
          ),
          backgroundColor: AppColors.dangerContainer.withOpacity(0.5),
          onPressed: () => onSelectPrice((item.fairMax * 1.75).toInt()),
        ),
      ],
    );
  }
}
