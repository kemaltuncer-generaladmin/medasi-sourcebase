import 'package:flutter/material.dart';

/// SourceBase Typography System
/// 
/// Standardized text styles following 8px-based scale.
/// Font sizes: 12, 14, 16, 18, 20, 24, 32, 40, 48
class SBTextStyles {
  const SBTextStyles._();

  // Display Styles (Hero Headlines)
  /// Display 1: 48px, w900 - Hero headlines, splash screens
  static const TextStyle display1 = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w900,
    height: 1.08,
    letterSpacing: -0.5,
  );

  /// Display 2: 40px, w900 - Large feature headlines
  static const TextStyle display2 = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w900,
    height: 1.1,
    letterSpacing: -0.5,
  );

  // Heading Styles (Section Headers)
  /// Heading 1: 32px, w800 - Main page titles
  static const TextStyle heading1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: -0.3,
  );

  /// Heading 2: 24px, w800 - Section titles
  static const TextStyle heading2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1.25,
    letterSpacing: -0.2,
  );

  /// Heading 3: 20px, w700 - Subsection titles
  static const TextStyle heading3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: 0,
  );

  // Body Styles (Content Text)
  /// Body Large: 18px, w500 - Emphasized content
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0,
  );

  /// Body Medium: 16px, w500 - Standard content (default)
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,
    letterSpacing: 0,
  );

  /// Body Small: 14px, w500 - Secondary content
  static const TextStyle bodySmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.5,
    letterSpacing: 0,
  );

  // Label Styles (Buttons, Form Labels)
  /// Label Large: 18px, w700 - Large button text
  static const TextStyle labelLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 0,
  );

  /// Label Medium: 16px, w700 - Standard button text
  static const TextStyle labelMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 0,
  );

  /// Label Small: 14px, w600 - Small button text, form labels
  static const TextStyle labelSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0,
  );

  // Caption Style (Helper Text)
  /// Caption: 12px, w500 - Helper text, timestamps, metadata
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0,
  );
}
