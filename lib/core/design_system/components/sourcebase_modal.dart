import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../constants/sb_dimensions.dart';
import '../constants/sb_spacing.dart';
import '../typography/sb_text_styles.dart';

Future<T?> showSourceBaseModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: builder,
  );
}

class SourceBaseModal extends StatelessWidget {
  const SourceBaseModal({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 16),
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Container(
            margin: const EdgeInsets.all(10),
            padding: padding,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(SBDimensions.radiusLg),
              border: Border.all(color: AppColors.line),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: .14),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: SBTextStyles.heading3.copyWith(
                              color: AppColors.navy,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: SBSpacing.xs),
                            Text(
                              subtitle!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: SBTextStyles.bodySmall.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: SBSpacing.sm),
                      trailing!,
                    ],
                  ],
                ),
                const SizedBox(height: SBSpacing.md),
                Flexible(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
