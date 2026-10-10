import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/community_repository.dart';
import '../theme/app_theme.dart';

/// Mandatory disclaimer banner across all community intelligence screens
class CommunityDisclaimerBanner extends StatelessWidget {
  const CommunityDisclaimerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, size: 16, color: Colors.blueGrey),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Community reports, not verified facts',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Photo attachment notice emphasizing privacy and evidence rules
class PhotoEvidenceNotice extends StatelessWidget {
  const PhotoEvidenceNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withOpacity(0.25)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.privacy_tip_outlined, size: 16, color: Colors.amber),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Do not include faces. Include a vehicle number only if needed as evidence. Metadata and GPS EXIF are automatically stripped.',
              style: TextStyle(fontSize: 11, color: Colors.amber, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog for filing takedown and defamation appeals
class TakedownAppealDialog extends ConsumerStatefulWidget {
  final String? initialEntityName;

  const TakedownAppealDialog({super.key, this.initialEntityName});

  static Future<void> show(BuildContext context, {String? initialEntityName}) {
    return showDialog(
      context: context,
      builder: (_) => TakedownAppealDialog(initialEntityName: initialEntityName),
    );
  }

  @override
  ConsumerState<TakedownAppealDialog> createState() => _TakedownAppealDialogState();
}

class _TakedownAppealDialogState extends ConsumerState<TakedownAppealDialog> {
  final _entityController = TextEditingController();
  final _detailsController = TextEditingController();
  final _emailController = TextEditingController();
  String _reason = 'Inaccurate Information';
  bool _isSubmitting = false;

  final _reasons = [
    'Inaccurate Information',
    'Defamation or Personal Target',
    'Dispute Resolved / Outdated',
    'False Commercial Competitor Report',
    'Other Legal Concern',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialEntityName != null) {
      _entityController.text = widget.initialEntityName!;
    }
  }

  @override
  void dispose() {
    _entityController.dispose();
    _detailsController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final entity = _entityController.text.trim();
    final details = _detailsController.text.trim();
    if (entity.isEmpty || details.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide entity name and appeal details')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    await ref.read(communityRepositoryProvider).submitTakedownAppeal(
      entityName: entity,
      reason: _reason,
      details: details,
      contactEmail: _emailController.text.trim(),
    );
    setState(() => _isSubmitting = false);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appeal submitted. Our compliance team will review within 24-48 hours.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.gavel_rounded, color: AppColors.primary, size: 20),
          SizedBox(width: 8),
          Text('Takedown & Appeal Request', style: TextStyle(fontSize: 16)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'If you are a driver, business, or traveller affected by an inaccurate or unfair community report, submit an appeal below.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _entityController,
              decoration: const InputDecoration(
                labelText: 'Business / Driver / Listing Name *',
                hintText: 'e.g. Amber Auto 441 / Sunset Cafe',
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _reason,
              decoration: const InputDecoration(labelText: 'Reason for Appeal *'),
              items: _reasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setState(() => _reason = v ?? _reason),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _detailsController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Explanation / Evidence *',
                hintText: 'Explain why this report should be reviewed or removed',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Contact Email (Optional)',
                hintText: 'For status notifications',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: Text(_isSubmitting ? 'Submitting...' : 'Submit Appeal'),
        ),
      ],
    );
  }
}
