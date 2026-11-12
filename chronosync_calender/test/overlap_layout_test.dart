import 'package:chronosync_calender/data/models/event_model.dart';
import 'package:chronosync_calender/data/models/occurrence.dart';
import 'package:chronosync_calender/features/calendar/widgets/overlap_layout.dart';
import 'package:flutter_test/flutter_test.dart';

final _event = EventModel(
  id: 'e',
  calendarId: 'cal',
  title: 'x',
  start: DateTime(2026, 1, 1),
  end: DateTime(2026, 1, 2),
  updatedAt: DateTime(2026),
);

Occurrence _at(int sh, int sm, int eh, int em) => Occurrence(
      event: _event,
      start: DateTime(2026, 1, 1, sh, sm),
      end: DateTime(2026, 1, 1, eh, em),
      originalStart: DateTime(2026, 1, 1, sh, sm),
      isGenerated: false,
    );

void main() {
  test('a lone event takes the full width', () {
    final placed = layoutOverlaps([_at(9, 0, 10, 0)]);
    expect(placed.single.column, 0);
    expect(placed.single.columns, 1);
  });

  test('two overlapping events share the width', () {
    final placed = layoutOverlaps([_at(9, 0, 11, 0), _at(10, 0, 12, 0)]);
    expect(placed.map((p) => p.columns).toSet(), {2});
    expect(placed.map((p) => p.column).toSet(), {0, 1});
  });

  test('a chain of overlaps reuses columns when possible', () {
    // A 9:00-10:00, B 9:30-11:00, C 10:00-11:00. C can reuse A's column.
    final a = _at(9, 0, 10, 0);
    final b = _at(9, 30, 11, 0);
    final c = _at(10, 0, 11, 0);
    final placed = layoutOverlaps([a, b, c]);
    final byStart = {for (final p in placed) p.occurrence.start: p};
    expect(byStart[c.start]!.column, 0);
    expect(byStart[b.start]!.column, 1);
    expect(placed.every((p) => p.columns == 2), isTrue);
  });

  test('separate clusters do not affect each other', () {
    final placed = layoutOverlaps([_at(9, 0, 10, 0), _at(11, 0, 12, 0)]);
    expect(placed.every((p) => p.columns == 1), isTrue);
  });
}
