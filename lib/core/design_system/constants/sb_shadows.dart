import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class SBShadows {
  const SBShadows._();

  static List<BoxShadow> get card => [
    BoxShadow(
      color: AppColors.navy.withValues(alpha: 0.04),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get elevated => [
    BoxShadow(
      color: AppColors.blue.withValues(alpha: 0.12),
      blurRadius: 12,
      offset: const Offset(0, 5),
    ),
  ];
}
