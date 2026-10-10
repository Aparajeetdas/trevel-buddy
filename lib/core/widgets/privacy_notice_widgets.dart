import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Pre-permission explanation dialog shown before the OS location prompt
class LocationPrePermissionDialog extends StatelessWidget {
  const LocationPrePermissionDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LocationPrePermissionDialog(),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.location_on_rounded, color: AppColors.primary, size: 22),
          SizedBox(width: 8),
          Text('Location Permission', style: TextStyle(fontSize: 16)),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Travel Buddy uses your device location while the app is active to:',
            style: TextStyle(fontSize: 13, height: 1.3),
          ),
          SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(
                child: Text('Accurately calculate fair fares from your pickup point to destination.', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(
                child: Text('Alert you to known tourist traps and overcharging zones nearby.', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'Your exact location is processed purely on-device and is never shared, tracked, or sold. Any community report you choose to submit rounds coordinates to ~100m for privacy.',
            style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.35),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Not Now'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

/// Comprehensive In-App Privacy Notice aligned with India's DPDP Act 2023
class PrivacyNoticeDialog extends StatelessWidget {
  const PrivacyNoticeDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const PrivacyNoticeDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.shield_outlined, color: AppColors.primary, size: 22),
          SizedBox(width: 8),
          Text('Privacy & Data Notice', style: TextStyle(fontSize: 16)),
        ],
      ),
      content: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'DPDP Act 2023 Compliance & Data Principles',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary),
            ),
            SizedBox(height: 8),
            Text(
              '1. What We Collect:',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            Text(
              '• Anonymous device preferences, saved destinations, and price check calculations stored locally on your device.\n• User-submitted price benchmarks and tourist trap tips (routes, fares paid, and optional notes). Zero names, phone numbers, or emails.',
              style: TextStyle(fontSize: 11, color: Colors.black87, height: 1.35),
            ),
            SizedBox(height: 8),
            Text(
              '2. Purpose Limitation:',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            Text(
              'Data is used solely to compute fair local price corridors and protect tourists against illegal markups and tout scams.',
              style: TextStyle(fontSize: 11, color: Colors.black87, height: 1.35),
            ),
            SizedBox(height: 8),
            Text(
              '3. Location & Photo Privacy:',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            Text(
              '• Exact GPS coordinates never leave your device. Stored reports are rounded to ~100m.\n• Photos have all EXIF metadata and GPS tags stripped prior to transmission.',
              style: TextStyle(fontSize: 11, color: Colors.black87, height: 1.35),
            ),
            SizedBox(height: 8),
            Text(
              '4. Your Right to Erasure:',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            Text(
              'You can permanently delete all device data at any time by tapping "Clear My Data" in your Profile.',
              style: TextStyle(fontSize: 11, color: Colors.black87, height: 1.35),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
