import '../data/repositories/transfer_repository.dart';
import '../state/calendar_controller.dart';

/// Shared handles set once in main(), so screens deep in the tree can reach them.
abstract final class AppServices {
  static late CalendarController controller;
  static late TransferRepository transfer;
}
