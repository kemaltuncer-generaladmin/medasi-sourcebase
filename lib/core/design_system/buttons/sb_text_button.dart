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
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: fontSize + 2),
                SizedBox(width: SBSpacing.xs),
              ],
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
