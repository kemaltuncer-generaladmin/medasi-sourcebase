// ignore_for_file: unused_element, unused_element_parameter

import 'package:flutter/material.dart';

import '../../../../core/design_system/components/sourcebase_card.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/drive_models.dart';
import '../widgets/drive_ui.dart';
import '../widgets/premium_workspace_components.dart';

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
      _UploadFilterKind.active =>
        widget.uploads
            .where(
              (upload) =>
                  upload.status == DriveItemStatus.uploading ||
                  upload.status == DriveItemStatus.processing,
            )
            .toList(),
      _UploadFilterKind.completed =>
        widget.uploads
            .where((upload) => upload.status == DriveItemStatus.completed)
            .toList(),
      _UploadFilterKind.failed =>
        widget.uploads
            .where((upload) => upload.status == DriveItemStatus.failed)
            .toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final visibleUploads = _visibleUploads;
    final totalCount = widget.uploads.length;
    final readyCount = widget.uploads
        .where((upload) => upload.status == DriveItemStatus.completed)
        .length;
    final activeCount = widget.uploads
        .where(
          (upload) =>
              upload.status == DriveItemStatus.uploading ||
              upload.status == DriveItemStatus.processing,
        )
        .length;
    final failedCount = widget.uploads
        .where((upload) => upload.status == DriveItemStatus.failed)
        .length;
    return PremiumPageScaffold(
      children: [
        DriveTopBar(
          title: 'Yüklemeler',
          onSearch: widget.onSearch,
          onBack: widget.onBack,
          showBrand: false,
        ),
        const SizedBox(height: 18),
        PremiumHeroCard(
          eyebrow: 'İşlem takibi',
          title: 'Yükleme Merkezi',
          description:
              'Yükleme, metin çıkarımı ve hazır olma durumlarını buradan sakin biçimde takip edebilirsin.',
          anchorIcon: Icons.cloud_upload_rounded,
          anchorLabel: totalCount == 0
              ? 'Henüz yükleme yok'
              : '$totalCount kayıt',
          metrics: [
            MetricPillData(
              label: 'Tümü',
              value: '$totalCount',
              tint: AppColors.blue,
              icon: Icons.folder_copy_outlined,
            ),
            MetricPillData(
              label: 'Hazır',
              value: '$readyCount',
              tint: AppColors.green,
              icon: Icons.check_circle_outline_rounded,
            ),
            MetricPillData(
              label: 'İşleniyor',
              value: '$activeCount',
              tint: AppColors.orange,
              icon: Icons.sync_rounded,
            ),
            MetricPillData(
              label: 'Hatalı',
              value: '$failedCount',
              tint: AppColors.red,
              icon: Icons.error_outline_rounded,
            ),
          ],
          actions: [
            SBPrimaryButton(
              label: 'Yeni dosya',
              icon: Icons.add_rounded,
              onPressed: widget.onNewFile,
              size: SBButtonSize.small,
              fullWidth: false,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _UploadGuidancePanel(onNewFile: widget.onNewFile),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _UploadFilter(
              label: 'Tümü',
              icon: Icons.format_list_bulleted_rounded,
              active: _filter == _UploadFilterKind.all,
              onTap: () => setState(() => _filter = _UploadFilterKind.all),
            ),
            _UploadFilter(
              label: 'Aktif',
              icon: Icons.sync_rounded,
              active: _filter == _UploadFilterKind.active,
              onTap: () => setState(() => _filter = _UploadFilterKind.active),
            ),
            _UploadFilter(
              label: 'Hazır',
              icon: Icons.check_circle_outline_rounded,
              active: _filter == _UploadFilterKind.completed,
              onTap: () =>
                  setState(() => _filter = _UploadFilterKind.completed),
            ),
            _UploadFilter(
              label: 'Hatalı',
              icon: Icons.warning_amber_rounded,
              color: AppColors.red,
              active: _filter == _UploadFilterKind.failed,
              onTap: () => setState(() => _filter = _UploadFilterKind.failed),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (widget.uploads.isEmpty)
          PremiumEmptyState(
            icon: Icons.cloud_upload_outlined,
            title: 'Henüz yükleme yok',
            message:
                'PDF, PPTX veya DOCX dosyanı ekledikten sonra durum takibi burada görünür.',
            badges: const ['PDF', 'PPTX', 'DOCX'],
            actionLabel: 'Yeni dosya',
            onAction: widget.onNewFile,
          )
        else if (visibleUploads.isEmpty)
          PremiumEmptyState(
            icon: Icons.filter_alt_off_outlined,
            title: _emptyTitle,
            message: _emptySubtitle,
            badges: const ['Filtreyi temizle', 'Durum takibi'],
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
      _UploadFilterKind.completed => 'Hazır dosya yok.',
      _UploadFilterKind.failed => 'Hatalı yükleme yok.',
      _UploadFilterKind.all => 'Yükleme bulunmuyor.',
    };
  }

  String get _emptySubtitle {
    return switch (_filter) {
      _UploadFilterKind.active =>
        'Yeni dosya seçtiğinizde yükleme ilerlemesi burada görünür.',
      _UploadFilterKind.completed =>
        'Metni çıkarılıp üretime hazır olan dosyalar burada görünür.',
      _UploadFilterKind.failed =>
        'Yükleme hatası olursa dosyayı tekrar seçerek deneyebilirsiniz.',
      _UploadFilterKind.all => 'Yeni dosyalar yükleyerek başlayabilirsiniz.',
    };
  }
}

class _UploadGuidancePanel extends StatelessWidget {
  const _UploadGuidancePanel({required this.onNewFile});

  final VoidCallback onNewFile;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Kaynağını yükle',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'PDF, PPTX veya DOCX dosyanı ekleyerek çalışmaya başlayabilirsin. Taranmış PDF’lerde okunabilir metin bulunmayabilir; eski PPT/DOC dosyaları sınırlı desteklenir.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          );
          final action = SBPrimaryButton(
            label: 'Dosya seç',
            icon: Icons.cloud_upload_outlined,
            onPressed: onNewFile,
            size: SBButtonSize.medium,
            fullWidth: compact,
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [text, const SizedBox(height: 14), action],
            );
          }
          return Row(
            children: [
              Expanded(child: text),
              const SizedBox(width: 18),
              SizedBox(width: 180, child: action),
            ],
          );
        },
      ),
    );
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
    return InkWell(
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? AppColors.blue : color, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: active ? AppColors.blue : AppColors.navy,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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
    return SourceBaseCard(
      radius: 18,
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _UploadMetaPill(
                    icon: Icons.folder_outlined,
                    text: '${file.courseTitle}  ›  ${file.sectionTitle}',
                  ),
                  _UploadMetaPill(
                    icon: Icons.schedule_rounded,
                    text: file.updatedLabel,
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
    final file = upload.file;
    switch (upload.status) {
      case DriveItemStatus.completed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StatusBadge(
              label: 'Hazır',
              status: PremiumStatus.ready,
              compact: true,
            ),
            const SizedBox(height: 12),
            const Text(
              'Kaynak hazır. BaseForce ve SourceLab içinde kullanılabilir.',
              style: TextStyle(color: AppColors.muted, fontSize: 14),
            ),
          ],
        );
      case DriveItemStatus.failed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StatusBadge(
              label: 'Hatalı',
              status: PremiumStatus.failed,
              compact: true,
            ),
            const SizedBox(height: 9),
            Text(
              driveFriendlyErrorMessage(
                upload.errorLabel ?? upload.file.statusMessage ?? '',
              ),
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
        return ProcessingCard(
          title: 'Kaynak işleniyor',
          message: 'Metin çıkarılıyor ve üretime hazırlanıyor.',
          tags: [
            file.sizeLabel,
            file.pageLabel,
            'İlerleme ${(upload.progress * 100).round()}%',
          ],
        );
      case DriveItemStatus.uploading:
        return ProcessingCard(
          title: 'Dosya yükleniyor',
          message: 'Bu işlem dosya boyutuna göre kısa sürebilir.',
          tags: [
            file.sizeLabel,
            'İlerleme ${(upload.progress * 100).round()}%',
          ],
        );
      case DriveItemStatus.draft:
        return const StatusBadge(
          label: 'Taslak',
          status: PremiumStatus.draft,
          compact: true,
        );
    }
  }
}

class _UploadMetaPill extends StatelessWidget {
  const _UploadMetaPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.muted, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
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
