import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/models/price_engine_models.dart';
import '../../../../core/theme/app_theme.dart';

/// Renders a single message bubble in Ask Buddy with avatar, sources, copy/retry, and action cards
class AskBuddyMessageBubble extends StatelessWidget {
  final AgentMessage message;
  final ValueChanged<AgentAction> onActionTap;
  final VoidCallback? onRetry;

  const AskBuddyMessageBubble({
    super.key,
    required this.message,
    required this.onActionTap,
    this.onRetry,
  });

  IconData _iconForAction(String type) {
    if (type.contains('map') || type.contains('direction')) {
      return Icons.map_rounded;
    }
    if (type.contains('price')) {
      return Icons.speed_rounded;
    }
    if (type.contains('trap') || type.contains('scam')) {
      return Icons.warning_amber_rounded;
    }
    if (type.contains('roadmap')) {
      return Icons.alt_route_rounded;
    }
    if (type.contains('112') || type.contains('emergency')) {
      return Icons.emergency_rounded;
    }
    return Icons.arrow_forward_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.sender == 'user';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primary,
                  child: Icon(
                    Icons.smart_toy_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isUser ? AppColors.primary : theme.cardColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    border: isUser ? null : Border.all(color: Colors.black12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        message.text,
                        style: TextStyle(
                          color: isUser
                              ? Colors.white
                              : theme.textTheme.bodyMedium?.color,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      if (!isUser && message.sources.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: message.sources.map((s) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '[$s]',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Message utility buttons for model replies (Copy & Retry)
          if (!isUser) ...[
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 14, color: Colors.grey),
                    tooltip: 'Copy',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: message.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 14, color: Colors.grey),
                      tooltip: 'Retry',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      onPressed: onRetry,
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Action cards
          if (message.actions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: message.actions.map((act) {
                  return ActionChip(
                    avatar: Icon(
                      _iconForAction(act.type),
                      size: 14,
                      color: AppColors.primary,
                    ),
                    label: Text(
                      act.label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: () => onActionTap(act),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Typing indicator animation for Ask Buddy
class AskBuddyTypingIndicator extends StatelessWidget {
  const AskBuddyTypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primary,
            child: Icon(Icons.smart_toy_rounded, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text(
                  'Buddy is typing...',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
