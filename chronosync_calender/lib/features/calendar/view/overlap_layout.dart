import 'package:chronosync_calender/data/models/occurrence.dart';

class PlacedOccurrence {
  const PlacedOccurrence(this.occurrence, {required this.column, required this.columns});

  final Occurrence occurrence;

  /// Which column (0-based) this event takes inside its overlap cluster.
  final int column;

  /// How many columns the cluster uses. Each event takes 1/columns of the width.
  final int columns;
}

/// Places time-overlapping events side by side, like Google Calendar does.
///
/// Events are grouped into clusters of transitively overlapping events. Each cluster
/// gets the fewest columns that keep overlapping events apart.
List<PlacedOccurrence> layoutOverlaps(List<Occurrence> items) {
  final sorted = [...items]..sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      return byStart != 0 ? byStart : b.end.compareTo(a.end);
    });

  final placed = <PlacedOccurrence>[];
  var cluster = <(Occurrence, int)>[];
  final columnEnds = <DateTime>[];
  DateTime? clusterEnd;

  void flush() {
    final columns = columnEnds.length;
    for (final (occ, column) in cluster) {
      placed.add(PlacedOccurrence(occ, column: column, columns: columns));
    }
    cluster = [];
    columnEnds.clear();
    clusterEnd = null;
  }

  for (final occ in sorted) {
    if (clusterEnd != null && !occ.start.isBefore(clusterEnd!)) flush();

    var column = columnEnds.indexWhere((end) => !occ.start.isBefore(end));
    if (column == -1) {
      columnEnds.add(occ.end);
      column = columnEnds.length - 1;
    } else {
      columnEnds[column] = occ.end;
    }

    cluster.add((occ, column));
    if (clusterEnd == null || occ.end.isAfter(clusterEnd!)) clusterEnd = occ.end;
  }
  flush();
  return placed;
}
