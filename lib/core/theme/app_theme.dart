import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../design_system/constants/sb_dimensions.dart';
import '../design_system/typography/sb_text_styles.dart';
import 'app_colors.dart';

class SourceBaseTheme {
  const SourceBaseTheme._();

  static ThemeData light() {
    const fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(SBDimensions.inputRadius)),
      borderSide: BorderSide(color: AppColors.line),
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.page,
      fontFamily: 'SF Pro Display',
      colorScheme: const ColorScheme.light(
        primary: AppColors.blue,
        secondary: AppColors.cyan,
        surface: AppColors.white,
        error: AppColors.red,
        onPrimary: AppColors.white,
        onSecondary: AppColors.white,
        onSurface: AppColors.ink,
        outline: AppColors.line,
      ),
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.navy,
        fontFamily: 'SF Pro Display',
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.blue,
        selectionColor: Color(0x33246BFF),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        hintStyle: SBTextStyles.bodyMedium.copyWith(color: AppColors.softText),
        labelStyle: SBTextStyles.bodySmall.copyWith(color: AppColors.muted),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.blue, width: 1.6),
        ),
        errorBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.red, width: 1.2),
        ),
        focusedErrorBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.red, width: 1.6),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SBDimensions.cardRadius),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(44, SBDimensions.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SBDimensions.buttonRadius),
          ),
          textStyle: SBTextStyles.labelMedium,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, SBDimensions.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          side: const BorderSide(color: AppColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SBDimensions.buttonRadius),
          ),
          textStyle: SBTextStyles.labelMedium,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.blue,
          minimumSize: const Size(40, 40),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.white,
        selectedColor: AppColors.selectedBlue,
        disabledColor: AppColors.softLine,
        side: const BorderSide(color: AppColors.line),
        labelStyle: const TextStyle(
          color: AppColors.navy,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        secondaryLabelStyle: const TextStyle(
          color: AppColors.clinicalActive,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SBDimensions.radiusLg),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppColors.clinicalBorder,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        contentTextStyle: const TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
