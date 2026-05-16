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
                      color: AppColors.navy.withValues(alpha: 0.05),
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
