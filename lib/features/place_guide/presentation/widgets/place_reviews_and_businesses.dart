import 'package:flutter/material.dart';

import '../../../../core/models/app_models.dart';
import '../../../../core/theme/app_theme.dart';

class PlaceReviewsAndBusinessesSection extends StatelessWidget {
  final Place place;

  const PlaceReviewsAndBusinessesSection({super.key, required this.place});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section 8: Reviews
        Text(
          'Verified Traveler Reviews',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...place.reviews.map((rev) {
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
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.primaryContainer,
                            child: Text(
                              rev.authorName.isNotEmpty
                                  ? rev.authorName[0]
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            rev.authorName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Colors.amber,
                          ),
                          Text(
                            ' ${rev.rating}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    rev.comment,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        rev.date,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                      if (rev.isVerifiedBuyer)
                        const Row(
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              size: 12,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'Verified Trip',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                    ],
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
