import 'package:flutter/material.dart';

/// Brand palette. Material 3 derives the rest of the colour scheme from [seed].
abstract final class AppColors {
  static const seed = Color(0xFF2F5BEA);

  /// Page background, light and dark.
  static const surfaceLight = Color(0xFFF6F7FB);
  static const surfaceDark = Color(0xFF0D1117);

  /// Card and sheet background in dark mode.
  static const cardDark = Color(0xFF161B22);

  /// Used for destructive actions when the scheme's error colour is not enough.
  static const danger = Color(0xFFD64560);
}
