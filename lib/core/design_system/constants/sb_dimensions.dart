/// SourceBase Dimensions System
///
/// Standardized dimensions for consistent sizing across components.
class SBDimensions {
  const SBDimensions._();

  // Content Width
  static const double tabletMaxContentWidth = 820;
  static const double desktopMaxContentWidth = 1120;

  // Border Radius
  static const double cardRadius = 8;
  static const double buttonRadius = 8;
  static const double inputRadius = 8;

  /// Extra small radius: 6px - Subtle rounding
  static const double radiusXs = 6;

  /// Small radius: 8px - Buttons, small cards
  static const double radiusSm = 8;

  /// Medium radius: 12px - Standard cards, inputs
  static const double radiusMd = 10;

  /// Large radius: 16px - Panels, large cards
  static const double radiusLg = 12;

  /// Extra large radius: 20px - Hero elements
  static const double radiusXl = 14;

  /// Full radius: 999px - Circular elements
  static const double radiusFull = 999;

  // Button Heights
  static const double buttonHeight = 44;

  /// Small button: 48px
  static const double buttonSmall = 40;

  /// Medium button: 56px (default)
  static const double buttonMedium = 44;

  /// Large button: 64px
  static const double buttonLarge = 48;

  /// Extra large button: 72px
  static const double buttonXLarge = 52;

  // Icon Sizes
  /// Extra small icon: 16px
  static const double iconXs = 16;

  /// Small icon: 20px
  static const double iconSm = 20;

  /// Medium icon: 24px (default)
  static const double iconMd = 24;

  /// Large icon: 28px
  static const double iconLg = 28;

  /// Extra large icon: 32px
  static const double iconXl = 32;

  // Input Heights
  static const double inputHeight = 44;

  /// Small input: 48px
  static const double inputSmall = 40;

  /// Medium input: 56px (default)
  static const double inputMedium = 44;

  /// Large input: 64px
  static const double inputLarge = 48;

  // Icon Button Sizes
  /// Compact icon button: 44px
  static const double iconButtonCompact = 36;

  /// Default icon button: 50px
  static const double iconButtonDefault = 40;

  /// Large icon button: 56px
  static const double iconButtonLarge = 44;

  // Component Padding
  static const double cardPadding = 14;
  static const double compactCardPadding = 12;
}
