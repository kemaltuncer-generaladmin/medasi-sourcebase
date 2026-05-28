import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../core/design_system/components/sourcebase_section_header.dart';
import '../../../../core/design_system/components/sourcebase_state.dart'
    as sourcebase_state;
import '../../../../core/design_system/layout/sourcebase_mobile_metrics.dart';
import '../../../../core/design_system/layout/sourcebase_page_header.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sourcebase_brand.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../data/drive_models.dart';
import 'sourcebase_bottom_nav.dart';

// Re-export design system buttons for backward compatibility
export '../../../../core/design_system/buttons/sb_primary_button.dart';
export '../../../../core/design_system/buttons/sb_secondary_button.dart';
export '../../../../core/design_system/buttons/sb_icon_button.dart';
export '../../../../core/design_system/components/sourcebase_chip.dart';

class WorkspacePage extends StatelessWidget {
  const WorkspacePage({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final maxWidth = ResponsiveLayout.getContentMaxWidth(context);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
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
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final horizontalPadding = SourceBaseMobileMetrics.horizontalPadding(
      context,
    );
    final bottomPadding = isDesktop || isTablet
        ? 48.0
        : keyboardInset > 0
        ? keyboardInset + 24
        : SourceBaseBottomNav.scrollEndPadding(context);
    final topPadding = SourceBaseMobileMetrics.topSafePadding(
      context,
      extra: isDesktop || isTablet ? 14.0 : 6.0,
    );

    final scroll = ListView(
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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

double mobileBottomSafePadding(BuildContext context, {double extra = 0}) {
  final base = SourceBaseBottomNav.contentBottomPadding(context);
  return base + extra;
}

class WorkspaceBottomNavGuard extends StatelessWidget {
  const WorkspaceBottomNavGuard({super.key});

  @override
  Widget build(BuildContext context) {
    if (ResponsiveLayout.isTablet(context) ||
        ResponsiveLayout.isDesktop(context)) {
      return const SizedBox.shrink();
    }
    return SizedBox(height: SourceBaseBottomNav.contentTailGuard);
  }
}

class DriveTopBar extends StatelessWidget {
  const DriveTopBar({
    required this.title,
    required this.onSearch,
    this.onBack,
    this.onMore,
    this.showBrand = true,
    this.showMore = false,
    this.showSearch = true,
    super.key,
  });

  final String title;
  final VoidCallback onSearch;
  final VoidCallback? onBack;
  final VoidCallback? onMore;
  final bool showBrand;
  final bool showMore;
  final bool showSearch;

  @override
  Widget build(BuildContext context) {
    final isPhone = SourceBaseMobileMetrics.isPhone(context);
    final Widget? leading = onBack != null
        ? IconButton(
            onPressed: onBack,
            tooltip: 'Geri dön',
            icon: const Icon(Icons.arrow_back_rounded, size: 24),
            color: AppColors.navy,
          )
        : showBrand
        ? isPhone
              ? const SourceBaseMark(size: 30)
              : const SourceBaseBrand(compact: true)
        : null;

    final actions = <Widget>[
      if (showMore)
        IconButton(
          onPressed: onMore,
          tooltip: 'Diğer işlemler',
          icon: const Icon(Icons.more_horiz_rounded, size: 24),
          color: AppColors.navy,
        )
      else ...[
        if (showSearch)
          IconButton(
            onPressed: onSearch,
            tooltip: 'Ara',
            icon: const Icon(Icons.search_rounded, size: 24),
            color: AppColors.navy,
          ),
        IconButton(
          onPressed: () => showSourceBaseNotifications(context),
          tooltip: 'Bildirimler',
          icon: const Icon(Icons.notifications_none_rounded, size: 24),
          color: AppColors.navy,
        ),
      ],
    ];

    return SourceBasePageHeader(
      title: title,
      subtitle: _sourceBaseHeaderSubtitle(title),
      leading: leading,
      actions: actions,
    );
  }
}

String? _sourceBaseHeaderSubtitle(String title) {
  return switch (title) {
    'Drive' => null,
    'BaseForce' => null,
    'SourceLab' => null,
    'Profil' => null,
    'Paketler' => null,
    _ => null,
  };
}

Future<void> showSourceBaseNotifications(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _NotificationPanel(),
  );
}

class _NotificationPanel extends StatefulWidget {
  const _NotificationPanel();

  @override
  State<_NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<_NotificationPanel> {
  bool _onlyUnread = false;
  final List<_SourceBaseNotification> _items =
      const <_SourceBaseNotification>[];

  List<_SourceBaseNotification> get _visibleItems =>
      _onlyUnread ? _items.where((item) => !item.read).toList() : _items;

  int get _unreadCount => _items.where((item) => !item.read).length;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * .86;
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: height, maxWidth: 720),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.page,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: .16),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bildirimler',
                              style: TextStyle(
                                color: AppColors.navy,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _unreadCount == 0
                                  ? 'Yeni bildiriminiz yok'
                                  : '$_unreadCount okunmamış bildirim',
                              style: const TextStyle(color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tümünü okundu işaretle',
                        onPressed: null,
                        icon: const Icon(Icons.done_all_rounded),
                      ),
                      IconButton(
                        tooltip: 'Kapat',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Tümü'),
                        selected: !_onlyUnread,
                        onSelected: (_) => setState(() => _onlyUnread = false),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Okunmamış'),
                        selected: _onlyUnread,
                        onSelected: (_) => setState(() => _onlyUnread = true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: _visibleItems.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.fromLTRB(22, 28, 22, 36),
                          child: EmptyState(
                            message: 'Burada gösterilecek bildirim yok.',
                            subMessage:
                                'Yeni işlem ve üretim durumları burada görünür.',
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                          itemCount: _visibleItems.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) =>
                              _NotificationTile(item: _visibleItems[index]),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item});

  final _SourceBaseNotification item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: item.read ? Colors.white : AppColors.selectedBlue,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: item.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (!item.read)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted, height: 1.3),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Text(
                        item.timeLabel,
                        style: const TextStyle(
                          color: AppColors.softText,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                    ],
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

class _SourceBaseNotification {
  const _SourceBaseNotification({
    required this.id,
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.timeLabel,
    required this.read,
  });

  final String id;
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String timeLabel;
  final bool read;
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.borderColor,
    this.radius = 8,
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            width: constraints.hasBoundedWidth ? double.infinity : null,
            padding: padding,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: .96),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: borderColor ?? AppColors.line),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1A4288).withValues(alpha: .035),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: child,
          );
        },
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
      child: SourceBaseSectionHeader(
        title: title,
        actionLabel: actionLabel,
        onAction: onAction,
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
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled ? AppColors.primaryGradient : null,
          color: enabled ? null : AppColors.line,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            if (enabled)
              BoxShadow(
                color: AppColors.clinicalActive.withValues(alpha: .14),
                blurRadius: 10,
                offset: const Offset(0, 4),
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
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
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
          foregroundColor: AppColors.clinicalActive,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          side: const BorderSide(color: AppColors.clinicalActive, width: 1.3),
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
    final info = driveStatusInfo(status);
    return Semantics(
      label: 'Durum: ${info.label}',
      child: ExcludeSemantics(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 5 : 8,
          ),
          decoration: BoxDecoration(
            color: info.backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: info.color.withValues(alpha: .14)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (status == DriveItemStatus.completed)
                Icon(
                  Icons.check_circle_rounded,
                  color: info.color,
                  size: compact ? 15 : 18,
                )
              else if (status == DriveItemStatus.failed)
                Icon(
                  Icons.warning_amber_rounded,
                  color: info.color,
                  size: compact ? 15 : 18,
                )
              else if (status == DriveItemStatus.processing ||
                  status == DriveItemStatus.uploading)
                SizedBox(
                  width: compact ? 14 : 18,
                  height: compact ? 14 : 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(info.color),
                  ),
                ),
              if (status != DriveItemStatus.draft)
                SizedBox(width: compact ? 5 : 8),
              Text(
                info.label,
                style: TextStyle(
                  color: info.color,
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

class DriveStatusInfo {
  const DriveStatusInfo({
    required this.label,
    required this.description,
    required this.color,
    required this.backgroundColor,
    required this.icon,
  });

  final String label;
  final String description;
  final Color color;
  final Color backgroundColor;
  final IconData icon;
}

DriveStatusInfo driveStatusInfo(DriveItemStatus status) {
  return switch (status) {
    DriveItemStatus.completed => const DriveStatusInfo(
      label: 'Hazır',
      description: 'Bu kaynakla çıktı üretebilirsin.',
      color: AppColors.green,
      backgroundColor: AppColors.greenBg,
      icon: Icons.check_circle_rounded,
    ),
    DriveItemStatus.processing => const DriveStatusInfo(
      label: 'İşleniyor',
      description: 'Kaynak hazır olduğunda üretim için kullanılabilir.',
      color: AppColors.clinicalActive,
      backgroundColor: AppColors.clinicalActiveBg,
      icon: Icons.hourglass_top_rounded,
    ),
    DriveItemStatus.uploading => const DriveStatusInfo(
      label: 'Yükleniyor',
      description: 'Dosya yükleme tamamlanmadan üretim başlatılamaz.',
      color: AppColors.warning,
      backgroundColor: AppColors.warningBg,
      icon: Icons.cloud_upload_outlined,
    ),
    DriveItemStatus.failed => const DriveStatusInfo(
      label: 'Hatalı',
      description: 'Bu kaynakla çıktı üretilemez.',
      color: AppColors.clinicalError,
      backgroundColor: AppColors.clinicalErrorBg,
      icon: Icons.error_outline_rounded,
    ),
    DriveItemStatus.draft => const DriveStatusInfo(
      label: 'Eksik yükleme',
      description: 'Dosya yükleme tamamlanmamış.',
      color: AppColors.warning,
      backgroundColor: AppColors.warningBg,
      icon: Icons.edit_document,
    ),
  };
}

String driveStatusLabel(DriveItemStatus status) =>
    driveStatusInfo(status).label;

String driveFriendlyStatusDescription(DriveFile file) {
  final message = file.statusMessage;
  if (message != null && message.trim().isNotEmpty) {
    return driveFriendlyErrorMessage(message);
  }
  return driveStatusInfo(file.status).description;
}

String driveFriendlyErrorMessage(String message) {
  final text = message.toLowerCase();
  if (text.contains('no_readable_text') ||
      text.contains('file_text_empty') ||
      text.contains('okunabilir metin') ||
      text.contains('taranmış') ||
      text.contains('scanned')) {
    return 'Okunabilir metin bulunamadı. Bu PDF taranmış olabilir. Metin seçilebilen bir PDF yüklemeyi deneyebilirsin.';
  }
  if (text.contains('unsupported') ||
      text.contains('file_type_unsupported') ||
      text.contains('desteklenmiyor')) {
    return 'Bu dosya türü desteklenmiyor. PPTX, DOCX veya metin içeren PDF dosyalarıyla devam edebilirsin.';
  }
  if (text.contains('limited_support') ||
      text.contains('.pptx') ||
      text.contains('.docx') ||
      text.contains('sınırlı destek')) {
    return 'Bu dosya türü sınırlı destekleniyor. Dosyayı PPTX veya DOCX olarak kaydedip tekrar yüklemeyi deneyebilirsin.';
  }
  if (text.contains('upload') ||
      text.contains('yüklenemedi') ||
      text.contains('gcs') ||
      text.contains('xmlhttprequest')) {
    return 'Dosya yüklenemedi. Bağlantını kontrol edip tekrar deneyebilirsin.';
  }
  if (text.contains('network') ||
      text.contains('socket') ||
      text.contains('connection') ||
      text.contains('bağlantı')) {
    return 'Bağlantı hatası oluştu. İnternet bağlantını kontrol edip tekrar dene.';
  }
  if (text.contains('unauthorized') ||
      text.contains('401') ||
      text.contains('oturum')) {
    return 'Oturum süren dolmuş olabilir. Lütfen tekrar giriş yap.';
  }
  return 'İşlem tamamlanamadı. Dosyayı kontrol edip tekrar deneyebilirsin.';
}

bool driveFileUsableForGeneration(DriveFile file) {
  if (file.status != DriveItemStatus.completed) return false;
  final size = file.sizeLabel.trim().toLowerCase();
  return size.isNotEmpty && size != '-' && !size.startsWith('0 ');
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
    final compact = MediaQuery.sizeOf(context).width < 430;
    final items = const [
      _TrustItem(
        icon: Icons.verified_user_rounded,
        title: 'Güvenli Yedekleme',
        subtitle: 'Verilerin güvende',
      ),
      _TrustItem(
        icon: Icons.group_rounded,
        title: 'Her Yerde Erişim',
        subtitle: 'Tüm cihazlarında',
      ),
      _TrustItem(
        icon: Icons.fact_check_outlined,
        title: 'Çalışma Çıktısı',
        subtitle: 'Kart, soru, özet',
      ),
    ];
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: compact
          ? Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  items[i],
                  if (i != items.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: AppColors.line),
                    ),
                ],
              ],
            )
          : Row(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  Expanded(child: items[i]),
                  if (i != items.length - 1) const _VerticalRule(),
                ],
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
            Icon(icon, color: AppColors.clinicalActive, size: 22),
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
                  const SizedBox(height: 2),
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
    GeneratedKind.infographic => Icons.insert_chart_outlined_rounded,
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
    GeneratedKind.infographic => AppColors.cyan,
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
    return sourcebase_state.SourceBaseEmptyState(
      icon: icon,
      title: message,
      message: subMessage,
    );
  }
}
