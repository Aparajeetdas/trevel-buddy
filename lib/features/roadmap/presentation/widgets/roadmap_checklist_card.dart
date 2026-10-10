import 'package:flutter/material.dart';

import '../../../../core/models/roadmap_models.dart';
import '../../../../core/theme/app_theme.dart';

/// Pre-trip safety checklist with interactive checkboxes and 'Start Journey' button
class RoadmapChecklistCard extends StatefulWidget {
  final List<ChecklistItem> checklist;
  final VoidCallback onStartJourney;

  const RoadmapChecklistCard({
    super.key,
    required this.checklist,
    required this.onStartJourney,
  });

  @override
  State<RoadmapChecklistCard> createState() => _RoadmapChecklistCardState();
}

class _RoadmapChecklistCardState extends State<RoadmapChecklistCard> {
  late final Map<String, bool> _checkedMap;

  @override
  void initState() {
    super.initState();
    _checkedMap = {
      for (final item in widget.checklist) item.id: item.isChecked,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? AppColors.outlineDark
              : AppColors.outlineLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.checklist_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Pre-Trip Checklist',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...widget.checklist.map((item) {
            final isChecked = _checkedMap[item.id] ?? false;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: isChecked,
                onChanged: (val) {
                  setState(() => _checkedMap[item.id] = val ?? false);
                },
                activeColor: AppColors.primary,
                title: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    decoration: isChecked ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: Text(
                  item.subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    decoration: isChecked ? TextDecoration.lineThrough : null,
                  ),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            );
          }),
          const SizedBox(height: 14),

          // Start Journey Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onStartJourney,
              icon: const Icon(Icons.navigation_rounded),
              label: const Text('Start Journey (Go Mode)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
