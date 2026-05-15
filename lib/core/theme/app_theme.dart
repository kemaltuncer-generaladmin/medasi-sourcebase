import 'package:flutter/material.dart';

import 'app_colors.dart';

class SourceBaseTheme {
  const SourceBaseTheme._();

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.page,
      fontFamily: 'SF Pro Display',
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.blue,
        primary: AppColors.blue,
        surface: AppColors.white,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.blue,
        selectionColor: Color(0x33246BFF),
      ),
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
