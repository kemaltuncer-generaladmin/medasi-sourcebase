import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/responsive_layout.dart';

class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({
    required this.body,
    this.mobileNavigation,
    this.tabletNavigation,
    this.desktopNavigation,
    this.busy = false,
    super.key,
  });

  final Widget body;
  final Widget? mobileNavigation;
  final Widget? tabletNavigation;
  final Widget? desktopNavigation;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final breakpoint = ResponsiveLayout.breakpointOf(context);
    final progress = busy
        ? const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.clinicalActive,
              backgroundColor: Colors.transparent,
            ),
          )
        : null;

    if (breakpoint == SourceBaseBreakpoint.mobile) {
      final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
      return Scaffold(
        backgroundColor: AppColors.page,
        extendBody: true,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            Positioned.fill(child: body),
            if (!keyboardVisible) ?mobileNavigation,
            ?progress,
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.page,
      body: Row(
        children: [
          if (breakpoint == SourceBaseBreakpoint.desktop &&
              desktopNavigation != null)
            SafeArea(right: false, child: desktopNavigation!)
          else if (tabletNavigation != null)
            SafeArea(right: false, child: tabletNavigation!),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: body),
                ?progress,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
