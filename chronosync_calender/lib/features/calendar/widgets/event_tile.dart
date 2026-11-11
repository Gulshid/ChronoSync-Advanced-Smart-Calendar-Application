import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/calendar_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/event_model.dart';
import '../../../data/models/occurrence.dart';
import '../../../state/calendar_controller.dart';

/// Colour for an event: its own colour if set, otherwise its calendar's colour.
Color eventColor(CalendarController controller, EventModel event) {
  final value = event.colorValue ?? controller.calendarById(event.calendarId)?.colorValue ?? calendarPalette[0];
  return Color(value);
}

String timeRangeLabel(Occurrence occ) {
  if (occ.isAllDay) return 'All day';
  final fmt = DateFormat.jm();
  return '${fmt.format(occ.start)} – ${fmt.format(occ.end)}';
}

/// Card used in lists (agenda view). Shows time, title, location and calendar.
class EventTile extends StatelessWidget {
  const EventTile({
    super.key,
    required this.occurrence,
    required this.color,
    required this.calendarName,
    required this.onTap,
  });

  final Occurrence occurrence;
  final Color color;
  final String calendarName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final event = occurrence.event;
    final subdued = theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant);

    return Material(
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 44,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title.isEmpty ? '(No title)' : event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(child: Text(timeRangeLabel(occurrence), style: subdued)),
                        if (occurrence.isRecurring) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.repeat, size: 14, color: cs.onSurfaceVariant),
                        ],
                      ],
                    ),
                    if (event.location.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.place_outlined, size: 14, color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(event.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: subdued),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Text(calendarName, style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
