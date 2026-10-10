import 'package:flutter/material.dart';

import '../constants/price_thresholds.dart';

/// Legacy and unified verdict levels: Fair (green), Suspicious (amber), High Risk (red)
enum PriceVerdictType {
  fair('Fair', Color(0xFF10B981)),
  suspicious('Suspicious', Color(0xFFF59E0B)),
  highRisk('High Risk', Color(0xFFEF4444));

  final String label;
  final Color color;
  const PriceVerdictType(this.label, this.color);

  // Backwards compatibility aliases
  static const PriceVerdictType slightlyHigh = PriceVerdictType.suspicious;
  static const PriceVerdictType overcharged = PriceVerdictType.highRisk;
}

class FairPriceEvaluation {
  final PriceVerdictType verdict;
  final double quotedPrice;
  final double fairMin;
  final double fairMax;
  final double differenceRupees;
  final String verdictTitle;
  final String verdictMessage;
  final Color verdictColor;
  final IconData verdictIcon;

  const FairPriceEvaluation({
    required this.verdict,
    required this.quotedPrice,
    required this.fairMin,
    required this.fairMax,
    required this.differenceRupees,
    required this.verdictTitle,
    required this.verdictMessage,
    required this.verdictColor,
    required this.verdictIcon,
  });

  bool get isOvercharged => verdict == PriceVerdictType.highRisk;
  bool get isSuspicious => verdict == PriceVerdictType.suspicious;
  bool get isFair => verdict == PriceVerdictType.fair;
}

class FairPriceCalculator {
  FairPriceCalculator._();

  static FairPriceEvaluation evaluate({
    required double quotedPrice,
    required double fairMin,
    required double fairMax,
  }) {
    if (quotedPrice <= fairMax * PriceThresholds.fairMultiplier) {
      final double diff = quotedPrice > fairMax ? quotedPrice - fairMax : 0.0;
      return FairPriceEvaluation(
        verdict: PriceVerdictType.fair,
        quotedPrice: quotedPrice,
        fairMin: fairMin,
        fairMax: fairMax,
        differenceRupees: diff,
        verdictTitle: 'Fair',
        verdictMessage: quotedPrice <= fairMax
            ? 'Great deal! This price is well within the standard local fair rate.'
            : 'Acceptable rate within reasonable 10% tourist tolerance.',
        verdictColor: const Color(0xFF10B981), // Emerald Green
        verdictIcon: Icons.check_circle_rounded,
      );
    } else if (quotedPrice <=
        fairMax * PriceThresholds.slightlyHighMultiplier) {
      final double diff = quotedPrice - fairMax;
      return FairPriceEvaluation(
        verdict: PriceVerdictType.suspicious,
        quotedPrice: quotedPrice,
        fairMin: fairMin,
        fairMax: fairMax,
        differenceRupees: diff,
        verdictTitle: 'Suspicious',
        verdictMessage:
            'You are being asked ₹${diff.toStringAsFixed(0)} more than fair price. Try to negotiate down.',
        verdictColor: const Color(0xFFF59E0B), // Amber
        verdictIcon: Icons.warning_amber_rounded,
      );
    } else {
      final double diff = quotedPrice - fairMax;
      return FairPriceEvaluation(
        verdict: PriceVerdictType.highRisk,
        quotedPrice: quotedPrice,
        fairMin: fairMin,
        fairMax: fairMax,
        differenceRupees: diff,
        verdictTitle: 'High Risk',
        verdictMessage:
            'High risk markup! This is ₹${diff.toStringAsFixed(0)} above fair market rate.',
        verdictColor: const Color(0xFFEF4444), // Danger Red
        verdictIcon: Icons.error_rounded,
      );
    }
  }
}
