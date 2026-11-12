import 'package:chronosync_calender/data/repositories/transfer_repository.dart';
import 'package:chronosync_calender/features/calendar/view_model/calendar_view_model.dart';

/// Shared handles set once in main(), so screens deep in the tree can reach them.
abstract final class AppServices {
  static late CalendarViewModel controller;
  static late TransferRepository transfer;
}
