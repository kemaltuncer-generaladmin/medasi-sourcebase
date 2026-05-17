import 'package:flutter/material.dart';

/// SourceBase Responsive Layout System
///
/// Provides consistent layout behavior across mobile, tablet, and desktop.
/// Breakpoints:
/// - Mobile: < 600px
/// - Tablet: 600px - 1024px
/// - Desktop: > 1024px
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    required this.mobile,
    this.tablet,
    this.desktop,
    super.key,
  });

  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= 600 && width < 1024;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 1024;

  static double getContentMaxWidth(BuildContext context) {
    if (isDesktop(context)) return 960;
    if (isTablet(context)) return 720;
    return 520;
  }

  static double getHorizontalPadding(BuildContext context) {
    if (isDesktop(context)) return 32;
    if (isTablet(context)) return 24;
    return MediaQuery.sizeOf(context).width < 390 ? 14 : 16;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (width >= 1024 && desktop != null) {
      return desktop!(context);
    } else if (width >= 600 && tablet != null) {
      return tablet!(context);
    }
    return mobile(context);
  }
}

/// Adaptive content container that respects platform-specific max widths
class AdaptiveContent extends StatelessWidget {
  const AdaptiveContent({required this.child, this.padding, super.key});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final maxWidth = ResponsiveLayout.getContentMaxWidth(context);
    final defaultPadding = ResponsiveLayout.getHorizontalPadding(context);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? EdgeInsets.symmetric(horizontal: defaultPadding),
          child: child,
        ),
      ),
    );
  }
}

/// Responsive grid that adapts column count based on screen size
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    required this.children,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
    this.spacing = 16,
    super.key,
  });

  final List<Widget> children;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final columns = ResponsiveLayout.isDesktop(context)
        ? desktopColumns
        : ResponsiveLayout.isTablet(context)
        ? tabletColumns
        : mobileColumns;

    return GridView.count(
      crossAxisCount: columns,
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: columns == 1 ? 3.4 : 1.2,
      children: children,
    );
  }
}

/// Responsive spacing that adapts to screen size
class ResponsiveSpacing extends StatelessWidget {
  const ResponsiveSpacing({
    this.mobile = 16,
    this.tablet = 24,
    this.desktop = 32,
    super.key,
  });

  final double mobile;
  final double tablet;
  final double desktop;

  @override
  Widget build(BuildContext context) {
    final height = ResponsiveLayout.isDesktop(context)
        ? desktop
        : ResponsiveLayout.isTablet(context)
        ? tablet
        : mobile;

    return SizedBox(height: height);
  }
}
