import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/drive_models.dart';
import '../widgets/drive_ui.dart';

class UploadsScreen extends StatefulWidget {
  const UploadsScreen({
    required this.uploads,
    required this.onSearch,
    required this.onBack,
    required this.onNewFile,
    required this.onRetryUpload,
    super.key,
  });

  final List<UploadTask> uploads;
  final VoidCallback onSearch;
  final VoidCallback onBack;
  final VoidCallback onNewFile;
  final ValueChanged<UploadTask> onRetryUpload;

  @override
  State<UploadsScreen> createState() => _UploadsScreenState();
}

enum _UploadFilterKind { all, active, completed, failed }

class _UploadsScreenState extends State<UploadsScreen> {
  _UploadFilterKind _filter = _UploadFilterKind.all;

  List<UploadTask> get _visibleUploads {
    return switch (_filter) {
      _UploadFilterKind.all => widget.uploads,
      _UploadFilterKind.active => widget.uploads
          .where(
            (upload) =>
                upload.status == DriveItemStatus.uploading ||
                upload.status == DriveItemStatus.processing,
          )
          .toList(),
      _UploadFilterKind.completed => widget.uploads
          .where((upload) => upload.status == DriveItemStatus.completed)
          .toList(),
      _UploadFilterKind.failed => widget.uploads
          .where((upload) => upload.status == DriveItemStatus.failed)
          .toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final visibleUploads = _visibleUploads;
    return WorkspaceScroll(
      children: [
        DriveTopBar(title: 'Drive', onSearch: widget.onSearch),
        Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: AppColors.line),
              ),
              child: IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded, size: 33),
                color: AppColors.navy,
              ),
            ),
            const SizedBox(width: 18),
            const Expanded(
              child: Text(
                'Yüklemeler',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        GlassPanel(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.uploads.length} dosya',
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 18),
                    Text(
                      'Dosyalar Drive alanınıza yükleniyor.\nİşlemleri aşağıdan takip edebilirsiniz.',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 17,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  SBSecondaryButton(
                    label: 'Yeni Dosya',
                    icon: Icons.add_rounded,
                    onPressed: widget.onNewFile,
                    size: SBButtonSize.small,
                    fullWidth: false,
                  ),
                  const SizedBox(height: 18),
                  const SizedBox(
                    width: 150,
                    height: 110,
                    child: CustomPaint(painter: _UploadHeroPainter()),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _UploadFilter(
                label: 'Tümü',
                icon: Icons.format_list_bulleted_rounded,
                active: _filter == _UploadFilterKind.all,
                onTap: () => setState(() => _filter = _UploadFilterKind.all),
              ),
              _UploadFilter(
                label: 'Yükleniyor',
                icon: Icons.sync_rounded,
                active: _filter == _UploadFilterKind.active,
                onTap: () => setState(() => _filter = _UploadFilterKind.active),
              ),
              _UploadFilter(
                label: 'Tamamlandı',
                icon: Icons.check_circle_outline_rounded,
                active: _filter == _UploadFilterKind.completed,
                onTap: () =>
                    setState(() => _filter = _UploadFilterKind.completed),
              ),
              _UploadFilter(
                label: 'Hata',
                icon: Icons.warning_amber_rounded,
                color: AppColors.red,
                active: _filter == _UploadFilterKind.failed,
                onTap: () => setState(() => _filter = _UploadFilterKind.failed),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (widget.uploads.isEmpty)
          GlassPanel(
            child: EmptyState(
              message: 'Aktif yükleme bulunmuyor.',
              subMessage: 'Yeni dosyalar yükleyerek başlayabilirsiniz.',
              icon: Icons.cloud_done_outlined,
            ),
          )
        else if (visibleUploads.isEmpty)
          GlassPanel(
            child: EmptyState(
              message: _emptyTitle,
              subMessage: _emptySubtitle,
              icon: Icons.filter_alt_off_outlined,
            ),
          )
        else
          for (final upload in visibleUploads) ...[
            _UploadRow(
              upload: upload,
              onRetry: () => widget.onRetryUpload(upload),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  String get _emptyTitle {
    return switch (_filter) {
      _UploadFilterKind.active => 'Devam eden yükleme yok.',
      _UploadFilterKind.completed => 'Tamamlanan yükleme yok.',
      _UploadFilterKind.failed => 'Hatalı yükleme yok.',
      _UploadFilterKind.all => 'Yükleme bulunmuyor.',
    };
  }

  String get _emptySubtitle {
    return switch (_filter) {
      _UploadFilterKind.active =>
        'Yeni dosya seçtiğinizde yükleme ilerlemesi burada görünür.',
      _UploadFilterKind.completed =>
        'Başarıyla yüklenen dosyalar Drive listesine eklenir.',
      _UploadFilterKind.failed =>
        'Yükleme hatası olursa dosyayı tekrar seçerek deneyebilirsiniz.',
      _UploadFilterKind.all => 'Yeni dosyalar yükleyerek başlayabilirsiniz.',
    };
  }
}

class _UploadHeroPainter extends CustomPainter {
  const _UploadHeroPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final blue = Paint()
      ..shader = AppColors.primaryGradient.createShader(Offset.zero & size);
    final pale = Paint()..color = const Color(0xFFE3F0FF);
    final white = Paint()..color = Colors.white;
    final shadow = Paint()
      ..color = AppColors.blue.withValues(alpha: .16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(18, 26, 86, 64).shift(const Offset(0, 8)),
        const Radius.circular(13),
      ),
      shadow,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(18, 26, 86, 64),
        const Radius.circular(13),
      ),
      pale,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(26, 44, 70, 44),
        const Radius.circular(10),
      ),
      blue,
    );
    canvas.drawCircle(Offset(size.width - 42, 74), 34, white);
    canvas.drawCircle(
      Offset(size.width - 42, 74),
      34,
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: .88),
    );
    final arrow = Paint()
      ..color = AppColors.blue.withValues(alpha: .62)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(size.width - 42, 88)
      ..lineTo(size.width - 42, 58)
      ..moveTo(size.width - 58, 72)
      ..lineTo(size.width - 42, 56)
      ..lineTo(size.width - 26, 72);
    canvas.drawPath(path, arrow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _UploadFilter extends StatelessWidget {
  const _UploadFilter({
    required this.label,
    required this.icon,
    required this.onTap,
    this.active = false,
    this.color = AppColors.blue,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active ? AppColors.blue : AppColors.line,
              width: active ? 1.3 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: active ? AppColors.blue : color, size: 24),
              const SizedBox(width: 9),
              Text(
                label,
                style: TextStyle(
                  color: active ? AppColors.blue : AppColors.navy,
                  fontSize: 17,
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

class _UploadRow extends StatelessWidget {
  const _UploadRow({required this.upload, required this.onRetry});

  final UploadTask upload;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final file = upload.file;
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                file.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${file.sizeLabel}  •  ${file.pageLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.folder_outlined,
                    color: AppColors.muted,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${file.courseTitle}  ›  ${file.sectionTitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FileKindBadge(kind: file.kind, large: true, plain: true),
                    const SizedBox(width: 14),
                    Expanded(child: details),
                  ],
                ),
                const SizedBox(height: 14),
                _UploadState(upload: upload, onRetry: onRetry),
              ],
            );
          }
          return Row(
            children: [
              FileKindBadge(kind: file.kind, large: true, plain: true),
              const SizedBox(width: 18),
              Expanded(child: details),
              const SizedBox(width: 10),
              SizedBox(
                width: 140,
                child: _UploadState(upload: upload, onRetry: onRetry),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _UploadState extends StatelessWidget {
  const _UploadState({required this.upload, required this.onRetry});

  final UploadTask upload;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    switch (upload.status) {
      case DriveItemStatus.completed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StatusPill(status: DriveItemStatus.completed),
            const SizedBox(height: 12),
            Text(
              upload.file.updatedLabel,
              style: const TextStyle(color: AppColors.muted, fontSize: 14),
            ),
          ],
        );
      case DriveItemStatus.failed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StatusPill(status: DriveItemStatus.failed),
            const SizedBox(height: 9),
            Text(
              upload.errorLabel ?? 'Hata',
              style: const TextStyle(color: AppColors.muted, fontSize: 14),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Tekrar Dene'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.blue,
                side: const BorderSide(color: AppColors.blue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
          ],
        );
      case DriveItemStatus.processing:
        return _ProgressStatus(
          icon: Icons.auto_awesome_rounded,
          title: 'AI Analizi',
          subtitle: 'Analiz ediliyor...',
          progress: upload.progress,
          color: AppColors.purple,
        );
      case DriveItemStatus.uploading:
        return _ProgressStatus(
          icon: Icons.sync_rounded,
          title: 'Yükleniyor',
          subtitle: 'Bekleniyor...',
          progress: upload.progress,
          color: AppColors.blue,
          bigPercent: true,
        );
      case DriveItemStatus.draft:
        return const StatusPill(status: DriveItemStatus.draft);
    }
  }
}

class _ProgressStatus extends StatelessWidget {
  const _ProgressStatus({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.color,
    this.bigPercent = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final double progress;
  final Color color;
  final bool bigPercent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        if (bigPercent)
          Text(
            '%${(progress * 100).round()}',
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          )
        else
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.muted, fontSize: 15),
          ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: AppColors.line,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          bigPercent ? subtitle : '%${(progress * 100).round()} tamamlandı',
          style: const TextStyle(color: AppColors.muted, fontSize: 14),
        ),
      ],
    );
  }
}
