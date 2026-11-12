import 'package:flutter/material.dart';

import 'package:chronosync_calender/core/l10n/strings.dart';
import 'package:chronosync_calender/core/theme/app_theme.dart';
import 'package:chronosync_calender/core/utils/app_format.dart';
import 'package:chronosync_calender/core/utils/calendar_palette.dart';
import 'package:chronosync_calender/data/models/event_model.dart';
import 'package:chronosync_calender/data/models/occurrence.dart';
import 'package:chronosync_calender/features/calendar/view_model/calendar_view_model.dart';

/// Colour for an event: its own colour if set, otherwise its calendar's colour.
Color eventColor(CalendarViewModel controller, EventModel event) {
  final value = event.colorValue ?? controller.calendarById(event.calendarId)?.colorValue ?? calendarPalette[0];
  return Color(value);
}

String timeRangeLabel(Occurrence occ) {
  if (occ.isAllDay) return Strings.t('all_day');
  return AppFormat.range(occ.start, occ.end);
}

/// Card used in lists (agenda, day panel, search). Shows a colour bar, title, time, location and calendar.
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

    return Semantics(
      button: true,
      label: '${event.title}, ${timeRangeLabel(occurrence)}',
      child: Material(
        color: cs.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.45)),
        ),
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.md, AppSpace.sm, AppSpace.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title.isEmpty ? Strings.t('no_title') : event.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: AppSpace.xs),
                        Row(
                          children: [
                            Icon(Icons.schedule, size: 14, color: cs.onSurfaceVariant),
                            const SizedBox(width: 4),
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
                ),
                if (calendarName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, AppSpace.md, AppSpace.md, 0),
                    child: Text(
                      calendarName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
