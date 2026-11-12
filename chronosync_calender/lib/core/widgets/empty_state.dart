import 'package:flutter/material.dart';

import 'package:chronosync_calender/core/theme/app_theme.dart';

/// Friendly placeholder for empty lists and no-result states.
/// [action] is optional and lets the user fix the empty state in one tap.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.5), shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: cs.primary),
            ),
            const SizedBox(height: AppSpace.lg),
            Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
            if (message.isNotEmpty) ...[
              const SizedBox(height: AppSpace.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
            if (action != null) ...[const SizedBox(height: AppSpace.lg), action!],
          ],
        ),
      ),
    );
  }
}
