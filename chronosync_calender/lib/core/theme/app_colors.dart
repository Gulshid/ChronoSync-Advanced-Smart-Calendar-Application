import 'package:flutter/material.dart';

/// App brand colours. Change [seed] to re-theme the whole app: buttons, chips,
/// the nav bar, selected states and focus rings are all derived from it.
abstract final class AppColors {
  /// Professional deep teal. Replace with any hex, e.g. 0xFF1E3A8A for navy.
  static const seed = Color(0xFF0F766E);

  /// Page background, light and dark.
  static const surfaceLight = Color(0xFFF5F7F8);
  static const surfaceDark = Color(0xFF0C1214);

  /// Card and sheet background in dark mode.
  static const cardDark = Color(0xFF141C1E);

  /// Destructive actions.
  static const danger = Color(0xFFB42318);
}
