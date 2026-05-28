import 'dart:math' as math;

import 'package:flutter/material.dart';

class SourceBaseMobileMetrics {
  const SourceBaseMobileMetrics._();

  static const double minTouchTarget = 44;
  static const double stickyCtaHeight = 56;

  static bool isPhone(BuildContext context) {
    return MediaQuery.sizeOf(context).width < 600;
  }

  static bool isCompactPhone(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width <= 390 || size.height <= 700;
  }

  static double horizontalPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 390) return 14;
    if (width < 600) return 16;
    if (width < 1024) return 24;
    return 32;
  }

  static double topSafePadding(BuildContext context, {double extra = 12}) {
    return MediaQuery.viewPaddingOf(context).top + extra;
  }

  static double keyboardAwareBottomPadding(
    BuildContext context, {
    double resting = 24,
    double keyboardGap = 12,
  }) {
    final media = MediaQuery.of(context);
    if (media.viewInsets.bottom > 0) {
      return media.viewInsets.bottom + keyboardGap;
    }
    return math.max(media.viewPadding.bottom, 10) + resting;
  }
}
