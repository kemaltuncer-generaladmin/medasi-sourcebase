import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../constants/sb_dimensions.dart';
import '../constants/sb_spacing.dart';
import 'sb_primary_button.dart';

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
      hint: loading ? 'Yükleniyor' : null,
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
