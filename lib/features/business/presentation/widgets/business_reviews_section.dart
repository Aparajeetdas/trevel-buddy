import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class BusinessReviewsSection extends StatelessWidget {
  final String businessName;

  const BusinessReviewsSection({super.key, required this.businessName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final reviews = [
      (
        name: 'Ananya Sharma',
        rating: 5.0,
        comment: 'Extremely polite, stuck exactly to the agreed fair price with zero detours to tourist shops. Highly recommended!',
        time: '3 days ago • Verified Ride',
      ),
      (
        name: 'David Miller',
        rating: 4.8,
        comment: 'Honest tariff and on time. Refused bribes from commission cafes and took us straight to our destination safely.',
        time: '1 week ago • International Traveler',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Traveler Feedback & Reviews',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Review prompt submitted for $businessName!'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              icon: const Icon(Icons.rate_review_outlined, size: 16),
              label: const Text('Add Review'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ...reviews.map((rev) {
          return Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        rev.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 16,
                          ),
                          Text(
                            ' ${rev.rating}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(rev.comment, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 6),
                  Text(
                    rev.time,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
