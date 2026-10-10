import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class RiskBadge extends StatelessWidget {
  final String risk;
  final bool showIcon;
  final bool compact;

  const RiskBadge({
    super.key,
    required this.risk,
    this.showIcon = true,
    this.compact = false,
  });

  Color _getRiskColor() {
    switch (risk.toLowerCase()) {
      case 'low':
      case 'fair':
        return AppColors.success;
      case 'medium':
      case 'suspicious':
        return AppColors.warning;
      case 'high':
      case 'high risk':
      case 'highrisk':
      default:
        return AppColors.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getRiskColor();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.full),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            const Icon(Icons.shield_rounded, size: 13, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            compact ? risk : '$risk Risk',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
