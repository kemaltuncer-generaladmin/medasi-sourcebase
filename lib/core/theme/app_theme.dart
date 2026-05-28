import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../design_system/typography/sb_text_styles.dart';
import 'app_colors.dart';

class SourceBaseTheme {
  const SourceBaseTheme._();

  static ThemeData light() {
    final base = ThemeData(
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

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: SBTextStyles.display1.copyWith(color: AppColors.navy),
        displayMedium: SBTextStyles.display2.copyWith(color: AppColors.navy),
        headlineLarge: SBTextStyles.heading1.copyWith(color: AppColors.navy),
        headlineMedium: SBTextStyles.heading2.copyWith(color: AppColors.navy),
        headlineSmall: SBTextStyles.heading3.copyWith(color: AppColors.navy),
        bodyLarge: SBTextStyles.bodyLarge.copyWith(color: AppColors.ink),
        bodyMedium: SBTextStyles.bodyMedium.copyWith(color: AppColors.ink),
        bodySmall: SBTextStyles.bodySmall.copyWith(color: AppColors.muted),
        labelLarge: SBTextStyles.labelLarge.copyWith(color: AppColors.navy),
        labelMedium: SBTextStyles.labelMedium.copyWith(color: AppColors.navy),
        labelSmall: SBTextStyles.labelSmall.copyWith(color: AppColors.muted),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        contentTextStyle: SBTextStyles.bodySmall.copyWith(
          color: AppColors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
