import 'package:flutter/material.dart';

/// SourceBase Spacing System
/// 
/// Based on 8px grid system for consistent spacing throughout the app.
/// All spacing values are multiples of 8px (base unit).
class SBSpacing {
  const SBSpacing._();

  /// Extra small spacing: 4px (0.5x base)
  /// Use for: Tight icon-text gaps, minimal separators
  static const double xs = 4;

  /// Small spacing: 8px (1x base)
  /// Use for: Icon-text gaps, compact list items
  static const double sm = 8;

  /// Medium spacing: 16px (2x base)
  /// Use for: Standard padding, form field gaps
  static const double md = 16;

  /// Large spacing: 24px (3x base)
  /// Use for: Section padding, card internal spacing
  static const double lg = 24;

  /// Extra large spacing: 32px (4x base)
  /// Use for: Major section gaps, screen padding
  static const double xl = 32;

  /// 2X large spacing: 48px (6x base)
  /// Use for: Large section separators
  static const double xxl = 48;

  /// 3X large spacing: 64px (8x base)
  /// Use for: Hero section spacing, major layout gaps
  static const double xxxl = 64;

  // Convenience methods for EdgeInsets
  static EdgeInsets all(double value) => EdgeInsets.all(value);
  static EdgeInsets horizontal(double value) => EdgeInsets.symmetric(horizontal: value);
  static EdgeInsets vertical(double value) => EdgeInsets.symmetric(vertical: value);
  
  static const EdgeInsets allXs = EdgeInsets.all(xs);
  static const EdgeInsets allSm = EdgeInsets.all(sm);
  static const EdgeInsets allMd = EdgeInsets.all(md);
  static const EdgeInsets allLg = EdgeInsets.all(lg);
  static const EdgeInsets allXl = EdgeInsets.all(xl);
}
