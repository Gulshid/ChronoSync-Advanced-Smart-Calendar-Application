import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:chronosync_calender/core/utils/app_format.dart';
import 'package:chronosync_calender/core/l10n/strings.dart';

import 'package:chronosync_calender/core/theme/app_theme.dart';
import 'package:chronosync_calender/core/utils/date_helpers.dart';
import 'package:chronosync_calender/data/models/occurrence.dart';
import 'package:chronosync_calender/features/calendar/view_model/calendar_view_model.dart';
import 'package:chronosync_calender/features/events/view/event_actions.dart';
import 'package:chronosync_calender/features/calendar/view/event_tile.dart';
import 'package:chronosync_calender/features/calendar/view/overlap_layout.dart';

const double _hourHeight = 60;
const double _gutterWidth = 52;
const double _allDayChipHeight = 22;
const int _maxAllDayChips = 2;
const double _minBlockHeight = 22;

/// Hour grid used by Day (one column) and Week (seven columns) views.
class TimeGrid extends StatefulWidget {
  const TimeGrid({super.key, required this.controller, required this.days});

  final CalendarViewModel controller;

  /// Local midnights, one per column.
  final List<DateTime> days;

  @override
  State<TimeGrid> createState() => _TimeGridState();
}

class _TimeGridState extends State<TimeGrid> {
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController(initialScrollOffset: _initialOffset());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Opens the grid one hour before now when today is visible, otherwise at 7 AM.
  double _initialOffset() {
    final showsToday = widget.days.any(isToday);
    final hour = showsToday ? (DateTime.now().hour - 1).clamp(0, 23).toInt() : 7;
    return hour * _hourHeight;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final days = widget.days;
    final occurrences = controller.occurrencesBetween(days.first, addDays(days.last, 1));
    final allDay = [for (final o in occurrences) if (o.isAllDay) o];
    final timed = [for (final o in occurrences) if (!o.isAllDay) o];

    return Column(
      children: [
        _DayHeader(days: days),
        if (allDay.isNotEmpty) _AllDayLane(controller: controller, days: days, items: allDay),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            child: SizedBox(
              height: 24 * _hourHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(width: _gutterWidth, child: _HourLabels()),
                  for (final day in days)
                    Expanded(child: _DayColumn(controller: controller, day: day, items: timed)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.days});

  final List<DateTime> days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Row(
        children: [
          const SizedBox(width: _gutterWidth),
          for (final day in days)
            Expanded(
              child: Column(
                children: [
                  Text(
                    DateFormat.E().format(day).toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isToday(day) ? cs.primary : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${day.day}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: isToday(day) ? cs.onPrimary : cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AllDayLane extends StatelessWidget {
  const _AllDayLane({required this.controller, required this.days, required this.items});

  final CalendarViewModel controller;
  final List<DateTime> days;
  final List<Occurrence> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _gutterWidth,
            child: Padding(
              padding: const EdgeInsets.only(top: 4, right: 6),
              child: Text(
                Strings.t('all_day'),
                textAlign: TextAlign.right,
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
          for (final day in days)
            Expanded(
              child: _AllDayCell(
                controller: controller,
                items: items.where((o) => o.overlaps(day, addDays(day, 1))).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _AllDayCell extends StatelessWidget {
  const _AllDayCell({required this.controller, required this.items});

  final CalendarViewModel controller;
  final List<Occurrence> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = items.take(_maxAllDayChips).toList();
    final extra = items.length - shown.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        children: [
          for (final occ in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Material(
                color: eventColor(controller, occ.event),
                borderRadius: BorderRadius.circular(6),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => openEventDetail(context, controller, occ),
                  child: Container(
                    height: _allDayChipHeight,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      occ.event.title.isEmpty ? Strings.t('no_title') : occ.event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (extra > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                Strings.t('more_count', {'n': extra}),
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

class _HourLabels extends StatelessWidget {
  const _HourLabels();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var h = 1; h < 24; h++)
          Positioned(
            top: h * _hourHeight - 7,
            left: 0,
            right: 8,
            child: Text(
              AppFormat.hour(h),
              textAlign: TextAlign.right,
              style: style,
            ),
          ),
      ],
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({required this.controller, required this.day, required this.items});

  final CalendarViewModel controller;
  final DateTime day;
  final List<Occurrence> items;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dayStart = startOfDay(day);
    final dayEnd = addDays(dayStart, 1);
    final clipped = [
      for (final o in items)
        if (o.overlaps(dayStart, dayEnd)) o.clippedTo(dayStart, dayEnd),
    ];
    final placed = layoutOverlaps(clipped);
    final now = DateTime.now();

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            // Round to the nearest 15 minutes and open the editor at that time.
            final quarters = (details.localPosition.dy / _hourHeight * 4).round();
            final minutes = clampInt(quarters, 0, 95) * 15;
            openEventEditor(
              ctx,
              controller,
              defaultStart: DateTime(dayStart.year, dayStart.month, dayStart.day, 0, minutes),
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _GridPainter(color: cs.outlineVariant.withValues(alpha: 0.35)),
                ),
              ),
              for (final p in placed) _placedBlock(ctx, p, width),
              if (isToday(day)) _nowIndicator(now, cs.primary),
            ],
          ),
        );
      },
    );
  }

  Widget _placedBlock(BuildContext context, PlacedOccurrence p, double width) {
    final occ = p.occurrence;
    final startMin = occ.start.hour * 60 + occ.start.minute;
    final endMin = isSameDay(occ.end, day) ? occ.end.hour * 60 + occ.end.minute : 1440;
    final rawHeight = (endMin - startMin) / 60 * _hourHeight;
    final height = rawHeight < _minBlockHeight ? _minBlockHeight : rawHeight;
    final columnWidth = width / p.columns;

    return Positioned(
      top: startMin / 60 * _hourHeight + 1,
      height: height - 2,
      left: p.column * columnWidth + 2,
      width: columnWidth - 4,
      child: _TimeBlock(controller: controller, occurrence: occ, height: height - 2),
    );
  }

  Widget _nowIndicator(DateTime now, Color color) {
    final top = (now.hour * 60 + now.minute) / 60 * _hourHeight;
    return Positioned(
      top: top - 4,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            Expanded(child: Container(height: 2, color: color)),
          ],
        ),
      ),
    );
  }
}

class _TimeBlock extends StatelessWidget {
  const _TimeBlock({required this.controller, required this.occurrence, required this.height});

  final CalendarViewModel controller;
  final Occurrence occurrence;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = eventColor(controller, occurrence.event);
    final title = occurrence.event.title.isEmpty ? Strings.t('no_title') : occurrence.event.title;
    final showTime = height >= 52;

    // Count how many title lines fit, allowing for the text size setting.
    final titleFontSize = theme.textTheme.labelMedium?.fontSize ?? 12;
    final lineHeight = titleFontSize * 1.4 * MediaQuery.textScalerOf(context).scale(1);
    final lines = ((height - 6) / lineHeight).floor();
    final maxLines = clampInt(lines - (showTime ? 1 : 0), 1, 3);

    return Semantics(
      label: '$title, ${timeRangeLabel(occurrence)}',
      button: true,
      child: Material(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openEventDetail(context, controller, occurrence),
          child: Container(
            decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 3))),
            padding: const EdgeInsets.fromLTRB(6, 3, 4, 2),
            alignment: Alignment.topLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: title,
                    style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface),
                  ),
                  if (showTime)
                    TextSpan(
                      text: '\n${AppFormat.time(occurrence.start)}',
                      style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                ],
              ),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var h = 0; h < 24; h++) {
      final y = h * _hourHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => oldDelegate.color != color;
}
