import 'package:chronosync_calender/data/services/ics_writer.dart';
import 'package:chronosync_calender/data/repositories/transfer_repository.dart';

abstract final class IcsExportService {
  /// Builds the .ics text for every calendar and event on this phone.
  static Future<String> build(TransferRepository repo) async {
    final events = await repo.allEvents();
    final names = {for (final c in await repo.calendars()) c.id: c.name};
    return IcsWriter.build(events: events, calendarNames: names);
  }
}
