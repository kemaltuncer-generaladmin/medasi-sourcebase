import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const page = Color(0xFFF6F8FA);
  static const white = Color(0xFFFFFFFF);
  static const navy = Color(0xFF07133F);
  static const ink = Color(0xFF0A1642);
  static const muted = Color(0xFF657395);
  static const softText = Color(0xFF8492AE);
  static const blue = Color(0xFF2563EB);
  static const deepBlue = Color(0xFF1D4ED8);
  static const sky = Color(0xFF0284C7);
  static const cyan = Color(0xFF0E7490);
  static const line = Color(0xFFDDE4EC);
  static const softLine = Color(0xFFE8EDF3);
  static const softBlue = Color(0xFFEAF4FF);
  static const selectedBlue = Color(0xFFEFF6FF);
  static const clinicalSurface = Color(0xFFF8FAFC);
  static const clinicalBorder = Color(0xFFDDE5ED);
  static const clinicalActive = Color(0xFF155E75);
  static const clinicalActiveBg = Color(0xFFEAF3F8);
  static const clinicalInk = Color(0xFF17212B);
  static const clinicalError = Color(0xFFB42318);
  static const clinicalErrorBg = Color(0xFFFEF3F2);
  static const green = Color(0xFF12AE55);
  static const greenBg = Color(0xFFEAFBF1);
  static const red = Color(0xFFFF2E2E);
  static const redBg = Color(0xFFFFEFEF);
  static const warning = Color(0xFFF59E0B);
  static const warningBg = Color(0xFFFFF7E6);
  static const purple = Color(0xFF7B3FF2);
  static const orange = Color(0xFFFF6B13);

  static const primaryGradient = LinearGradient(
    colors: [clinicalActive, blue],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const brandGradient = LinearGradient(
    colors: [cyan, blue, deepBlue],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );
}
