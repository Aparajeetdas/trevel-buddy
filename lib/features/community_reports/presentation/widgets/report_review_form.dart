import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Sub-form for reviewing a driver or local business
class ReportReviewForm extends StatefulWidget {
  const ReportReviewForm({super.key});

  @override
  State<ReportReviewForm> createState() => _ReportReviewFormState();
}

class _ReportReviewFormState extends State<ReportReviewForm> {
  final TextEditingController _entityNameController = TextEditingController();
  final TextEditingController _vehicleOrRegController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  int _rating = 5;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _entityNameController.dispose();
    _vehicleOrRegController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    final name = _entityNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter driver or business name')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() => _isSubmitting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Review submitted! Thank you for helping travellers.'),
          backgroundColor: AppColors.primary,
        ),
      );
      _entityNameController.clear();
      _vehicleOrRegController.clear();
      _commentController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Review a Driver or Business',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'Leave an honest rating to build transparent trust scores.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: AppSpacing.md),

          TextField(
            controller: _entityNameController,
            decoration: const InputDecoration(
              labelText: 'Driver Name or Business Name *',
              hintText: 'e.g. Ramesh Singh / Sunrise Haveli',
              prefixIcon: Icon(Icons.person_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          TextField(
            controller: _vehicleOrRegController,
            decoration: const InputDecoration(
              labelText: 'Vehicle Number or Address (Optional)',
              hintText: 'e.g. RJ 14 TA 8821',
              prefixIcon: Icon(Icons.badge_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Rating Stars
          Row(
            children: [
              const Text(
                'Rating: ',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              ...List.generate(5, (index) {
                final starIndex = index + 1;
                return IconButton(
                  icon: Icon(
                    starIndex <= _rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: Colors.amber,
                    size: 28,
                  ),
                  onPressed: () => setState(() => _rating = starIndex),
                );
              }),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Review & Feedback',
              hintText: 'Did they follow the meter? Were they respectful?',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitReview,
              icon: const Icon(Icons.rate_review_rounded),
              label: Text(_isSubmitting ? 'Posting...' : 'Post Review'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
