import 'package:flutter/material.dart';

import 'package:chronosync_calender/core/theme/app_colors.dart';

/// Spacing scale used across the app. Use these instead of raw numbers.
abstract final class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
}

/// Corner radii. Small for chips and blocks, large for cards and sheets.
abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 20.0;
  static const xl = 28.0;
}

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.seed, brightness: brightness);
    final background = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final cardColor = isDark ? AppColors.cardDark : Colors.white;
    final border = scheme.outlineVariant.withValues(alpha: 0.45);
    final radiusMd = BorderRadius.circular(AppRadius.md);
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final text = _textTheme(base.textTheme);

    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {for (final p in TargetPlatform.values) p: const FadeUpwardsPageTransitionsBuilder()},
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 60,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        titleTextStyle: text.titleLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: cardColor,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: const StadiumBorder(),
        labelType: NavigationRailLabelType.all,
        minWidth: 84,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        highlightElevation: 4,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      filledButtonTheme: FilledButtonThemeData(style: _buttonStyle(radiusMd)),
      outlinedButtonTheme: OutlinedButtonThemeData(style: _buttonStyle(radiusMd)),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: cardColor,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        checkmarkColor: scheme.onPrimaryContainer,
        labelStyle: text.labelLarge,
        shape: const StadiumBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        hintStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(borderRadius: radiusMd, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: radiusMd, borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: radiusMd,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.md),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radiusMd),
        insetPadding: const EdgeInsets.all(AppSpace.md),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radiusMd),
      ),
      dividerTheme: DividerThemeData(color: border, space: 1, thickness: 1),
    );
  }

  static ButtonStyle _buttonStyle(BorderRadius radius) => ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(64, 44)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: AppSpace.lg)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: radius)),
        textStyle: const WidgetStatePropertyAll(TextStyle(fontWeight: FontWeight.w600)),
      );

  /// Tightens headings and gives body text comfortable line spacing.
  static TextTheme _textTheme(TextTheme t) => t.copyWith(
        headlineSmall: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
        titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        bodyMedium: t.bodyMedium?.copyWith(height: 1.4),
      );
}
