import 'package:flutter/material.dart';

import 'package:chronosync_calender/core/theme/app_theme.dart';

/// A titled card that groups related controls. Used by the editor, settings and data screens.
class AppSection extends StatelessWidget {
  const AppSection({super.key, this.title, this.icon, required this.children});

  final String? title;
  final IconData? icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.xs, 0, AppSpace.xs, AppSpace.sm),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: AppSpace.sm),
                ],
                Text(
                  title!,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
      ],
    );
  }
}

/// A round icon badge used at the start of list rows.
class IconBadge extends StatelessWidget {
  const IconBadge({super.key, required this.icon, this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = color ?? cs.primary;
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: base.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Icon(icon, size: 20, color: base),
    );
  }
}
