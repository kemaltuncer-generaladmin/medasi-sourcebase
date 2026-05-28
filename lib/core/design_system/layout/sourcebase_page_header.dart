import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/responsive_layout.dart';
import '../constants/sb_spacing.dart';
import '../typography/sb_text_styles.dart';

class SourceBasePageHeader extends StatelessWidget {
  const SourceBasePageHeader({
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final titleBlock = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: (isMobile ? SBTextStyles.heading2 : SBTextStyles.heading1)
                .copyWith(color: AppColors.navy),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: SBSpacing.xs),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SBTextStyles.bodySmall.copyWith(color: AppColors.muted),
            ),
          ],
        ],
      ),
    );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      header: true,
      label: title,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: SBSpacing.sm),
            ],
            titleBlock,
            if (actions.isNotEmpty) ...[
              const SizedBox(width: SBSpacing.sm),
              Wrap(spacing: SBSpacing.xs, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}
