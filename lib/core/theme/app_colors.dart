import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const page = Color(0xFFF8FBFF);
  static const white = Color(0xFFFFFFFF);
  static const navy = Color(0xFF07133F);
  static const ink = Color(0xFF0A1642);
  static const muted = Color(0xFF657395);
  static const softText = Color(0xFF8492AE);
  static const blue = Color(0xFF075FFF);
  static const deepBlue = Color(0xFF123BF2);
  static const sky = Color(0xFF0D95FF);
  static const cyan = Color(0xFF08C7D6);
  static const line = Color(0xFFD9E3F2);
  static const softLine = Color(0xFFE9EFF8);
  static const softBlue = Color(0xFFEAF4FF);
  static const selectedBlue = Color(0xFFEFF6FF);
  static const green = Color(0xFF12AE55);
  static const greenBg = Color(0xFFEAFBF1);
  static const red = Color(0xFFFF2E2E);
  static const redBg = Color(0xFFFFEFEF);
  static const warning = Color(0xFFF59E0B);
  static const warningBg = Color(0xFFFFF7E6);
  static const purple = Color(0xFF7B3FF2);
  static const orange = Color(0xFFFF6B13);

  static const primaryGradient = LinearGradient(
    colors: [deepBlue, blue, sky],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const brandGradient = LinearGradient(
    colors: [cyan, blue, Color(0xFF2315C9)],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );
}
