import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../constants/sb_dimensions.dart';
import '../constants/sb_spacing.dart';
import '../typography/sb_text_styles.dart';

class SourceBaseChip extends StatelessWidget {
  const SourceBaseChip({
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
    this.foregroundColor,
    this.backgroundColor,
    super.key,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  final Color? foregroundColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final activeColor = foregroundColor ?? AppColors.clinicalActive;
    final mutedColor = foregroundColor ?? AppColors.muted;
    final fg = selected ? activeColor : mutedColor;
    final bg =
        backgroundColor ??
        (selected ? AppColors.clinicalActiveBg : AppColors.white);

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      constraints: BoxConstraints(minHeight: onTap == null ? 32 : 40),
      padding: const EdgeInsets.symmetric(
        horizontal: SBSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(SBDimensions.radiusSm),
        border: Border.all(
          color: selected ? activeColor.withValues(alpha: .18) : AppColors.line,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: SBDimensions.iconXs, color: fg),
            const SizedBox(width: SBSpacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SBTextStyles.labelSmall.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return Semantics(label: label, selected: selected, child: content);
    }

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SBDimensions.radiusSm),
          child: content,
        ),
      ),
    );
  }
}
