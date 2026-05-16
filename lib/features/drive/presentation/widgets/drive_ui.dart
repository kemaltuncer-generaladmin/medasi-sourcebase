import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sourcebase_brand.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../data/drive_models.dart';

// Re-export design system buttons for backward compatibility
export '../../../../core/design_system/buttons/sb_primary_button.dart';
export '../../../../core/design_system/buttons/sb_secondary_button.dart';
export '../../../../core/design_system/buttons/sb_icon_button.dart';

class WorkspacePage extends StatelessWidget {
  const WorkspacePage({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final maxWidth = ResponsiveLayout.getContentMaxWidth(context);
    final padding = ResponsiveLayout.getHorizontalPadding(context);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: child,
        ),
      ),
    );
  }
}

class WorkspaceScroll extends StatelessWidget {
  const WorkspaceScroll({required this.children, this.onRefresh, super.key});

  final List<Widget> children;
  final RefreshCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isTablet = ResponsiveLayout.isTablet(context);
    final horizontalPadding = ResponsiveLayout.getHorizontalPadding(context);
    final bottomPadding = isDesktop ? 48.0 : (isTablet ? 48.0 : 138.0);
    final topPadding = isDesktop || isTablet
        ? 18.0
        : MediaQuery.viewPaddingOf(context).top + 8.0;

    final scroll = ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        topPadding,
        horizontalPadding,
        bottomPadding,
      ),
      children: [
        for (var i = 0; i < children.length; i++)
          Semantics(
            container: true,
            explicitChildNodes: true,
            sortKey: OrdinalSortKey(i.toDouble()),
            child: children[i],
          ),
      ],
    );

    return WorkspacePage(
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        child: onRefresh != null
            ? RefreshIndicator(
                onRefresh: onRefresh!,
                displacement: 20,
                color: AppColors.blue,
                child: scroll,
              )
            : scroll,
      ),
    );
  }
}

class DriveTopBar extends StatelessWidget {
  const DriveTopBar({
    required this.title,
    required this.onSearch,
    this.onBack,
    this.showBrand = true,
    this.showMore = false,
    super.key,
  });

  final String title;
  final VoidCallback onSearch;
  final VoidCallback? onBack;
  final bool showBrand;
  final bool showMore;

  @override
  Widget build(BuildContext context) {
    final leading = onBack != null
        ? IconButton(
            onPressed: onBack,
            tooltip: 'Geri dön',
            icon: const Icon(Icons.arrow_back_rounded, size: 31),
            color: AppColors.navy,
          )
        : showBrand
        ? const SourceBaseBrand(compact: true)
        : const SizedBox.shrink();

    final actions = showMore
        ? IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Diğer işlemler açıldı.'),
                    duration: Duration(milliseconds: 1000),
                  ),
                );
            },
            tooltip: 'Diğer işlemler',
            icon: const Icon(Icons.more_horiz_rounded, size: 30),
            color: AppColors.navy,
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: onSearch,
                tooltip: 'Ara',
                icon: const Icon(Icons.search_rounded, size: 34),
                color: AppColors.navy,
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text('Bildirim merkezi açıldı.'),
                            duration: Duration(milliseconds: 1000),
                          ),
                        );
                    },
                    tooltip: 'Bildirimler',
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      size: 32,
                    ),
                    color: AppColors.navy,
                  ),
                  Positioned(
                    top: 9,
                    right: 10,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: AppColors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.4),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Üst çubuk',
      child: Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final titleText = Semantics(
              container: true,
              header: true,
              label: title,
              child: ExcludeSemantics(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
            );

            if (constraints.maxWidth < 430 && showBrand && onBack == null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: leading),
                      const Spacer(),
                      actions,
                    ],
                  ),
                  const SizedBox(height: 12),
                  titleText,
                ],
              );
            }

            return Row(
              children: [
                leading,
                if (showBrand && onBack == null) ...[
                  ExcludeSemantics(
                    child: Container(
                      width: 1,
                      height: 24,
                      margin: const EdgeInsets.symmetric(horizontal: 18),
                      color: AppColors.line,
                    ),
                  ),
                ],
                Expanded(child: titleText),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    this.radius = 16,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: .92),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor ?? AppColors.line),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A4288).withValues(alpha: .055),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    required this.title,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      header: true,
      label: title,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
        child: Row(
          children: [
            Expanded(
              child: ExcludeSemantics(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            if (actionLabel != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(foregroundColor: AppColors.blue),
                child: Row(
                  children: [
                    Text(
                      actionLabel!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right_rounded, size: 24),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PrimaryGradientButton extends StatelessWidget {
  const PrimaryGradientButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.height = 52,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: AppColors.blue.withValues(alpha: .20),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 24),
                const SizedBox(width: 9),
                Text(label, maxLines: 1, softWrap: false),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OutlineIconButton extends StatelessWidget {
  const OutlineIconButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.height = 52,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.blue,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          side: const BorderSide(color: AppColors.blue, width: 1.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 23),
              const SizedBox(width: 8),
              Text(label, maxLines: 1, softWrap: false),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({required this.status, this.compact = false, super.key});

  final DriveItemStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      DriveItemStatus.completed => 'Tamamlandı',
      DriveItemStatus.processing => 'İşleniyor',
      DriveItemStatus.uploading => 'Yükleniyor',
      DriveItemStatus.failed => 'Hata',
      DriveItemStatus.draft => 'Taslak',
    };
    final color = switch (status) {
      DriveItemStatus.completed => AppColors.green,
      DriveItemStatus.processing => AppColors.blue,
      DriveItemStatus.uploading => AppColors.blue,
      DriveItemStatus.failed => AppColors.red,
      DriveItemStatus.draft => AppColors.blue,
    };
    final bg = switch (status) {
      DriveItemStatus.completed => AppColors.greenBg,
      DriveItemStatus.failed => AppColors.redBg,
      _ => AppColors.selectedBlue,
    };
    return Semantics(
      label: 'Durum: $label',
      child: ExcludeSemantics(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 5 : 8,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: .14)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (status == DriveItemStatus.completed)
                Icon(
                  Icons.check_circle_rounded,
                  color: color,
                  size: compact ? 15 : 18,
                )
              else if (status == DriveItemStatus.failed)
                Icon(
                  Icons.warning_amber_rounded,
                  color: color,
                  size: compact ? 15 : 18,
                )
              else if (status == DriveItemStatus.processing ||
                  status == DriveItemStatus.uploading)
                SizedBox(
                  width: compact ? 14 : 18,
                  height: compact ? 14 : 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              if (status != DriveItemStatus.draft)
                SizedBox(width: compact ? 5 : 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: compact ? 12 : 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FileKindBadge extends StatelessWidget {
  const FileKindBadge({
    required this.kind,
    this.large = false,
    this.plain = false,
    this.compact = false,
    super.key,
  });

  final DriveFileKind kind;
  final bool large;
  final bool plain;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = kindColor(kind);
    final label = kindLabel(kind);
    final size = large ? 64.0 : (compact ? 40.0 : 46.0);
    return Semantics(
      image: true,
      label: '$label dosya türü',
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: plain ? color.withValues(alpha: .08) : color,
            borderRadius: BorderRadius.circular(large ? 9 : 7),
            boxShadow: large
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: .18),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              Positioned(
                right: 0,
                top: 0,
                child: CustomPaint(
                  size: Size(
                    large ? 18 : (compact ? 12 : 14),
                    large ? 18 : (compact ? 12 : 14),
                  ),
                  painter: FoldPainter(color: plain ? color : Colors.white),
                ),
              ),
              Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: plain ? color : Colors.white,
                    fontSize: large ? 20 : (compact ? 10.5 : 12),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color kindColor(DriveFileKind kind) {
    return switch (kind) {
      DriveFileKind.pdf => const Color(0xFFFF3131),
      DriveFileKind.pptx => AppColors.orange,
      DriveFileKind.docx => AppColors.blue,
      DriveFileKind.doc => const Color(0xFF146AF2),
      DriveFileKind.zip => AppColors.purple,
    };
  }

  static String kindLabel(DriveFileKind kind) {
    return switch (kind) {
      DriveFileKind.pdf => 'PDF',
      DriveFileKind.pptx => 'PPTX',
      DriveFileKind.docx => 'DOCX',
      DriveFileKind.doc => 'DOC',
      DriveFileKind.zip => 'ZIP',
    };
  }
}

class FoldPainter extends CustomPainter {
  const FoldPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: .86);
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant FoldPainter oldDelegate) =>
      oldDelegate.color != color;
}

class MetaDot extends StatelessWidget {
  const MetaDot({super.key});

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 7),
        child: Text(
          '•',
          style: TextStyle(color: AppColors.muted, fontSize: 16),
        ),
      ),
    );
  }
}

class TrustStrip extends StatelessWidget {
  const TrustStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      child: Row(
        children: const [
          Expanded(
            child: _TrustItem(
              icon: Icons.verified_user_rounded,
              title: 'Güvenli Yedekleme',
              subtitle: 'Verilerin güvende',
            ),
          ),
          _VerticalRule(),
          Expanded(
            child: _TrustItem(
              icon: Icons.group_rounded,
              title: 'Her Yerde Erişim',
              subtitle: 'Tüm cihazlarında',
            ),
          ),
          _VerticalRule(),
          Expanded(
            child: _TrustItem(
              icon: Icons.auto_awesome_rounded,
              title: 'Akıllı Dönüştürme',
              subtitle: 'Öğrenmeye hazırla',
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  const _TrustItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title. $subtitle.',
      child: ExcludeSemantics(
        child: Row(
          children: [
            Icon(icon, color: AppColors.blue, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerticalRule extends StatelessWidget {
  const _VerticalRule();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 1,
        height: 42,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: AppColors.line,
      ),
    );
  }
}

IconData generatedIcon(GeneratedKind kind) {
  return switch (kind) {
    GeneratedKind.flashcard => Icons.flip_to_front_rounded,
    GeneratedKind.question => Icons.help_outline_rounded,
    GeneratedKind.summary => Icons.description_outlined,
    GeneratedKind.algorithm => Icons.account_tree_outlined,
    GeneratedKind.comparison => Icons.balance_rounded,
    GeneratedKind.podcast => Icons.keyboard_voice_outlined,
    GeneratedKind.table => Icons.table_chart_outlined,
    GeneratedKind.mindMap => Icons.hub_outlined,
  };
}

Color generatedColor(GeneratedKind kind) {
  return switch (kind) {
    GeneratedKind.flashcard => AppColors.blue,
    GeneratedKind.question => const Color(0xFF0CB7D4),
    GeneratedKind.summary => AppColors.purple,
    GeneratedKind.algorithm => AppColors.orange,
    GeneratedKind.comparison => AppColors.blue,
    GeneratedKind.podcast => const Color(0xFFFF3F96),
    GeneratedKind.table => const Color(0xFF13B857),
    GeneratedKind.mindMap => AppColors.purple,
  };
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.message,
    required this.subMessage,
    this.icon = Icons.inbox_outlined,
    super.key,
  });

  final String message;
  final String subMessage;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: AppColors.blue.withValues(alpha: .4)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
