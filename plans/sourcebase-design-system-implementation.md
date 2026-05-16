# SourceBase Design System - Detaylı Uygulama Stratejisi

## 📋 Executive Summary

This document provides a detailed implementation strategy for establishing a unified design system across the SourceBase application. The plan addresses critical design inconsistencies identified across features and establishes a scalable, maintainable component library.

### Key Objectives
- ✅ Eliminate duplicate button implementations across features
- ✅ Establish consistent typography, spacing, and sizing systems
- ✅ Ensure semantic accessibility compliance (AGENTS.md §30)
- ✅ Enable rapid, consistent UI development
- ✅ Maintain visual continuity during migration

### Implementation Approach
**Phased Migration**: Create new components → Migrate features incrementally → Deprecate old components → Clean up

**Risk Mitigation**: Feature-by-feature migration with testing at each stage, no breaking changes to existing functionality

---

## 🎯 Phase 1: Foundation Layer (Priority: CRITICAL)

### 1.1 Directory Structure

Create the following structure under [`lib/core/design_system/`](lib/core/design_system/):

```
lib/core/design_system/
├── constants/
│   ├── sb_dimensions.dart      # Border radius, heights, icon sizes
│   └── sb_spacing.dart         # 8px grid spacing system
├── typography/
│   └── sb_text_styles.dart     # Standardized text styles
├── buttons/
│   ├── sb_primary_button.dart  # Gradient action button
│   ├── sb_secondary_button.dart # Outline button
│   ├── sb_icon_button.dart     # Round icon button
│   └── sb_text_button.dart     # Minimal text button
├── cards/
│   ├── sb_card.dart            # Standard card container
│   └── sb_panel.dart           # Enhanced panel with header
├── inputs/
│   ├── sb_text_field.dart      # Standard text input
│   └── sb_search_field.dart    # Search-specific input
└── design_system.dart          # Barrel export file
```

### 1.2 Core Constants Implementation

#### File: `lib/core/design_system/constants/sb_spacing.dart`

```dart
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
```

#### File: `lib/core/design_system/constants/sb_dimensions.dart`

```dart
/// SourceBase Dimensions System
/// 
/// Standardized dimensions for consistent sizing across components.
class SBDimensions {
  const SBDimensions._();

  // Border Radius
  /// Extra small radius: 6px - Subtle rounding
  static const double radiusXs = 6;
  
  /// Small radius: 8px - Buttons, small cards
  static const double radiusSm = 8;
  
  /// Medium radius: 12px - Standard cards, inputs
  static const double radiusMd = 12;
  
  /// Large radius: 16px - Panels, large cards
  static const double radiusLg = 16;
  
  /// Extra large radius: 20px - Hero elements
  static const double radiusXl = 20;
  
  /// Full radius: 999px - Circular elements
  static const double radiusFull = 999;

  // Button Heights
  /// Small button: 48px
  static const double buttonSmall = 48;
  
  /// Medium button: 56px (default)
  static const double buttonMedium = 56;
  
  /// Large button: 64px
  static const double buttonLarge = 64;
  
  /// Extra large button: 72px
  static const double buttonXLarge = 72;

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
  /// Small input: 48px
  static const double inputSmall = 48;
  
  /// Medium input: 56px (default)
  static const double inputMedium = 56;
  
  /// Large input: 64px
  static const double inputLarge = 64;

  // Icon Button Sizes
  /// Compact icon button: 44px
  static const double iconButtonCompact = 44;
  
  /// Default icon button: 50px
  static const double iconButtonDefault = 50;
  
  /// Large icon button: 56px
  static const double iconButtonLarge = 56;
}
```

### 1.3 Typography System Implementation

#### File: `lib/core/design_system/typography/sb_text_styles.dart`

```dart
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
```

### 1.4 Enhanced Color System

#### File: `lib/core/theme/app_colors.dart` (Enhanced)

Add these semantic colors and opacity variants to the existing [`AppColors`](lib/core/theme/app_colors.dart:3) class:

```dart
// Add to existing AppColors class:

// Semantic Color Aliases
static const success = green;
static const error = red;
static const warning = orange;
static const info = blue;

// Opacity Variants (using new Flutter 3.27+ API)
static Color get blueLight => blue.withValues(alpha: 0.1);
static Color get blueMedium => blue.withValues(alpha: 0.5);
static Color get navyLight => navy.withValues(alpha: 0.1);
static Color get mutedLight => muted.withValues(alpha: 0.5);

// Shadow Colors
static Color get shadowLight => navy.withValues(alpha: 0.05);
static Color get shadowMedium => navy.withValues(alpha: 0.1);
static Color get shadowDark => navy.withValues(alpha: 0.15);
```

---

## 🎯 Phase 2: Button Components (Priority: HIGH)

### 2.1 SBPrimaryButton - Gradient Action Button

**Purpose**: Primary call-to-action buttons (Login, Save, Create, Submit)

**Replaces**:
- [`GradientActionButton`](lib/features/auth/presentation/widgets/auth_widgets.dart:201) (Auth)
- [`PrimaryGradientButton`](lib/features/drive/presentation/widgets/drive_ui.dart:328) (Drive)
- [`_PrimaryLabButton`](lib/features/sourcelab/presentation/screens/source_lab_screen.dart:3710) (SourceLab)

#### File: `lib/core/design_system/buttons/sb_primary_button.dart`

```dart
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../constants/sb_dimensions.dart';
import '../constants/sb_spacing.dart';

enum SBButtonSize { small, medium, large, xLarge }

/// SourceBase Primary Button
/// 
/// Gradient button for primary actions. Features:
/// - Gradient background with shadow
/// - Loading state support
/// - Optional icon
/// - Semantic labeling (AGENTS.md §30)
/// - Disabled state handling
class SBPrimaryButton extends StatelessWidget {
  const SBPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.size = SBButtonSize.medium,
    this.loading = false,
    this.fullWidth = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final SBButtonSize size;
  final bool loading;
  final bool fullWidth;

  double get _height {
    return switch (size) {
      SBButtonSize.small => SBDimensions.buttonSmall,
      SBButtonSize.medium => SBDimensions.buttonMedium,
      SBButtonSize.large => SBDimensions.buttonLarge,
      SBButtonSize.xLarge => SBDimensions.buttonXLarge,
    };
  }

  double get _fontSize {
    return switch (size) {
      SBButtonSize.small => 16,
      SBButtonSize.medium => 18,
      SBButtonSize.large => 20,
      SBButtonSize.xLarge => 22,
    };
  }

  double get _iconSize {
    return switch (size) {
      SBButtonSize.small => SBDimensions.iconSm,
      SBButtonSize.medium => SBDimensions.iconMd,
      SBButtonSize.large => SBDimensions.iconLg,
      SBButtonSize.xLarge => SBDimensions.iconXl,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || loading;
    
    return Semantics(
      button: true,
      enabled: !isDisabled,
      label: label,
      hint: loading ? 'Loading' : null,
      child: SizedBox(
        width: fullWidth ? double.infinity : null,
        height: _height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: isDisabled ? null : AppColors.primaryGradient,
            color: isDisabled ? AppColors.line : null,
            borderRadius: BorderRadius.circular(SBDimensions.radiusMd),
            boxShadow: isDisabled
                ? null
                : [
                    BoxShadow(
                      color: AppColors.blue.withValues(alpha: 0.24),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isDisabled ? null : onPressed,
              borderRadius: BorderRadius.circular(SBDimensions.radiusMd),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: SBSpacing.lg,
                  vertical: SBSpacing.md,
                ),
                child: loading
                    ? Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDisabled ? AppColors.muted : AppColors.white,
                            ),
                          ),
                        ),
                      )
                    : Row(
                        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (icon != null) ...[
                            Icon(
                              icon,
                              size: _iconSize,
                              color: isDisabled ? AppColors.muted : AppColors.white,
                            ),
                            SizedBox(width: SBSpacing.sm),
                          ],
                          Flexible(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: _fontSize,
                                fontWeight: FontWeight.w700,
                                color: isDisabled ? AppColors.muted : AppColors.white,
                                letterSpacing: 0,
                              ),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

### 2.2 SBSecondaryButton - Outline Button

**Purpose**: Secondary actions (Cancel, Back, Edit)

**Replaces**:
- [`OutlineActionButton`](lib/features/auth/presentation/widgets/auth_widgets.dart:253) (Auth)
- [`OutlineIconButton`](lib/features/drive/presentation/widgets/drive_ui.dart:391) (Drive)
- [`_SecondaryLabButton`](lib/features/sourcelab/presentation/screens/source_lab_screen.dart:3783) (SourceLab)

#### File: `lib/core/design_system/buttons/sb_secondary_button.dart`

```dart
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../constants/sb_dimensions.dart';
import '../constants/sb_spacing.dart';

/// SourceBase Secondary Button
/// 
/// Outline button for secondary actions. Features:
/// - Border with transparent background
/// - Optional icon
/// - Semantic labeling
/// - Hover/press states
class SBSecondaryButton extends StatelessWidget {
  const SBSecondaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.size = SBButtonSize.medium,
    this.loading = false,
    this.fullWidth = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final SBButtonSize size;
  final bool loading;
  final bool fullWidth;

  double get _height {
    return switch (size) {
      SBButtonSize.small => SBDimensions.buttonSmall,
      SBButtonSize.medium => SBDimensions.buttonMedium,
      SBButtonSize.large => SBDimensions.buttonLarge,
      SBButtonSize.xLarge => SBDimensions.buttonXLarge,
    };
  }

  double get _fontSize {
    return switch (size) {
      SBButtonSize.small => 16,
      SBButtonSize.medium => 18,
      SBButtonSize.large => 20,
      SBButtonSize.xLarge => 22,
    };
  }

  double get _iconSize {
    return switch (size) {
      SBButtonSize.small => SBDimensions.iconSm,
      SBButtonSize.medium => SBDimensions.iconMd,
      SBButtonSize.large => SBDimensions.iconLg,
      SBButtonSize.xLarge => SBDimensions.iconXl,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || loading;
    
    return Semantics(
      button: true,
      enabled: !isDisabled,
      label: label,
      hint: loading ? 'Loading' : null,
      child: SizedBox(
        width: fullWidth ? double.infinity : null,
        height: _height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: isDisabled ? AppColors.line : AppColors.blue,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(SBDimensions.radiusMd),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isDisabled ? null : onPressed,
              borderRadius: BorderRadius.circular(SBDimensions.radiusMd),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: SBSpacing.lg,
                  vertical: SBSpacing.md,
                ),
                child: loading
                    ? Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDisabled ? AppColors.muted : AppColors.blue,
                            ),
                          ),
                        ),
                      )
                    : Row(
                        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (icon != null) ...[
                            Icon(
                              icon,
                              size: _iconSize,
                              color: isDisabled ? AppColors.muted : AppColors.blue,
                            ),
                            SizedBox(width: SBSpacing.sm),
                          ],
                          Flexible(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: _fontSize,
                                fontWeight: FontWeight.w700,
                                color: isDisabled ? AppColors.muted : AppColors.blue,
                                letterSpacing: 0,
                              ),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

### 2.3 SBIconButton - Round Icon Button

**Purpose**: Toolbar actions, navigation icons

**Replaces**: All `_RoundIconButton` variants across features

#### File: `lib/core/design_system/buttons/sb_icon_button.dart`

```dart
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../constants/sb_dimensions.dart';

enum SBIconButtonSize { compact, medium, large }

/// SourceBase Icon Button
/// 
/// Circular icon button for toolbar and navigation. Features:
/// - Circular shape with shadow
/// - Mandatory tooltip (AGENTS.md §30)
/// - Semantic labeling
/// - Size variants
class SBIconButton extends StatelessWidget {
  const SBIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.size = SBIconButtonSize.medium,
    this.backgroundColor = AppColors.white,
    this.iconColor = AppColors.navy,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final SBIconButtonSize size;
  final Color backgroundColor;
  final Color iconColor;

  double get _diameter {
    return switch (size) {
      SBIconButtonSize.compact => SBDimensions.iconButtonCompact,
      SBIconButtonSize.medium => SBDimensions.iconButtonDefault,
      SBIconButtonSize.large => SBDimensions.iconButtonLarge,
    };
  }

  double get _iconSize {
    return switch (size) {
      SBIconButtonSize.compact => SBDimensions.iconSm,
      SBIconButtonSize.medium => SBDimensions.iconMd,
      SBIconButtonSize.large => SBDimensions.iconLg,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;
    
    return Semantics(
      button: true,
      enabled: !isDisabled,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: _diameter,
          height: _diameter,
          decoration: BoxDecoration(
            color: isDisabled ? AppColors.line : backgroundColor,
            shape: BoxShape.circle,
            boxShadow: isDisabled
                ? null
                : [
                    BoxShadow(
                      color: AppColors.shadowLight,
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              customBorder: const CircleBorder(),
              child: Center(
                child: Icon(
                  icon,
                  size: _iconSize,
                  color: isDisabled ? AppColors.muted : iconColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

### 2.4 SBTextButton - Minimal Text Button

**Purpose**: Links, tertiary actions

**Replaces**: [`_SmallActionButton`](lib/features/sourcelab/presentation/screens/source_lab_screen.dart:3829) and similar

#### File: `lib/core/design_system/buttons/sb_text_button.dart`

```dart
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../constants/sb_spacing.dart';

/// SourceBase Text Button
/// 
/// Minimal button for links and tertiary actions. Features:
/// - Text only, no background
/// - Optional icon
/// - Semantic labeling
/// - Underline on hover (web)
class SBTextButton extends StatelessWidget {
  const SBTextButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.fontSize = 16,
    this.color = AppColors.blue,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;
    
    return Semantics(
      button: true,
      enabled: !isDisabled,
      label: label,
      link: true,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: isDisabled ? AppColors.muted : color,
          padding: EdgeInsets.symmetric(
            horizontal: SBSpacing.sm,
            vertical: SBSpacing.xs,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: fontSize + 2),
              SizedBox(width: SBSpacing.xs),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 🎯 Phase 3: Card & Panel Components (Priority: MEDIUM)

### 3.1 SBCard - Standard Card Container

#### File: `lib/core/design_system/cards/sb_card.dart`

```dart
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../constants/sb_dimensions.dart';
import '../constants/sb_spacing.dart';

enum SBCardVariant { flat, elevated, outlined }

/// SourceBase Card
/// 
/// Standard card container for content grouping. Features:
/// - Consistent padding and radius
/// - Variant support (flat, elevated, outlined)
/// - Optional tap handling
class SBCard extends StatelessWidget {
  const SBCard({
    required this.child,
    this.variant = SBCardVariant.elevated,
    this.padding = SBSpacing.md,
    this.onTap,
    super.key,
  });

  final Widget child;
  final SBCardVariant variant;
  final double padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(SBDimensions.radiusMd),
      border: variant == SBCardVariant.outlined
          ? Border.all(color: AppColors.line, width: 1)
          : null,
      boxShadow: variant == SBCardVariant.elevated
          ? [
              BoxShadow(
                color: AppColors.shadowLight,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ]
          : null,
    );

    final content = Container(
      decoration: decoration,
      padding: EdgeInsets.all(padding),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SBDimensions.radiusMd),
          child: content,
        ),
      );
    }

    return content;
  }
}
```

### 3.2 SBPanel - Enhanced Panel with Header

#### File: `lib/core/design_system/cards/sb_panel.dart`

```dart
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../constants/sb_dimensions.dart';
import '../constants/sb_spacing.dart';
import '../typography/sb_text_styles.dart';

/// SourceBase Panel
/// 
/// Enhanced panel with optional header. Features:
/// - Larger padding than SBCard
/// - Optional title and trailing widget
/// - Semantic header labeling
class SBPanel extends StatelessWidget {
  const SBPanel({
    required this.child,
    this.title,
    this.trailing,
    this.padding = SBSpacing.lg,
    super.key,
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(SBDimensions.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowMedium,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Semantics(
              header: true,
              label: title,
              child: Row(
                children: [
                  Expanded(
                    child: ExcludeSemantics(
                      child: Text(
                        title!,
                        style: SBTextStyles.heading3.copyWith(
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  ),
                  if (trailing != null)