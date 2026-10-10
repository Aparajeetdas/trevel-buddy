import 'package:flutter/material.dart';

import '../../features/ask_buddy/presentation/ask_buddy_sheet.dart';
import '../theme/app_theme.dart';

/// Floating trigger button for opening the Ask Buddy AI Guide
class AskBuddyFloatingButton extends StatelessWidget {
  final String? place;
  final String? initialPrompt;

  const AskBuddyFloatingButton({super.key, this.place, this.initialPrompt});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: 'ask_buddy_fab',
      onPressed: () => AskBuddySheet.show(
        context,
        place: place ?? 'Jaipur',
        initialPrompt: initialPrompt,
      ),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 4,
      icon: const Icon(Icons.smart_toy_rounded, size: 20),
      label: const Text(
        'Ask Buddy',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      ),
    );
  }
}
