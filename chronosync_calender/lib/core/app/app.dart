import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:chronosync_calender/core/theme/app_theme.dart';
import 'package:chronosync_calender/data/services/app_settings.dart';
import 'package:chronosync_calender/features/calendar/view_model/calendar_view_model.dart';
import 'package:chronosync_calender/core/app/app_navigator.dart';
import 'package:chronosync_calender/core/app/home_shell.dart';
import 'package:chronosync_calender/core/app/splash_screen.dart';
class ChronoSyncApp extends StatelessWidget {
  const ChronoSyncApp({super.key, required this.controller});

  final CalendarViewModel controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final settings = AppSettings.instance;
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'ChronoSync',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themeMode,
          locale: settings.locale,
          supportedLocales: const [Locale('en'), Locale('ur')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // Urdu is right-to-left; Flutter applies the direction from the locale automatically.
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            final scale = mq.textScaler.scale(1) * settings.textScale;
            return MediaQuery(
              data: mq.copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            );
          },
          home: SplashGate(child: HomeShell(controller: controller)),
        );
      },
    );
  }
}
