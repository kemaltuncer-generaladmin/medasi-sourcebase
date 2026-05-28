import 'package:flutter/material.dart';

import '../../../../core/design_system/layout/sourcebase_mobile_metrics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/drive_models.dart';
import '../widgets/drive_ui.dart';

class DriveHomeScreen extends StatelessWidget {
  const DriveHomeScreen({
    required this.data,
    required this.onSearch,
    required this.onOpenCourse,
    required this.onOpenFile,
    required this.onCreateCourse,
    required this.onRenameCourse,
    required this.onDeleteCourse,
    required this.onOpenUploads,
    required this.onOpenUploadsPage,
    required this.onOpenCollections,
    this.onRefresh,
    super.key,
  });

  final DriveWorkspaceData data;
  final VoidCallback onSearch;
  final ValueChanged<DriveCourse> onOpenCourse;
  final ValueChanged<DriveFile> onOpenFile;
  final VoidCallback onCreateCourse;
  final ValueChanged<DriveCourse> onRenameCourse;
  final ValueChanged<DriveCourse> onDeleteCourse;
  final VoidCallback onOpenUploads;
  final VoidCallback onOpenUploadsPage;
  final VoidCallback onOpenCollections;
  final RefreshCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final hasCourses = data.courses.isNotEmpty;
    final mobile = MediaQuery.sizeOf(context).width < 430;
    final files = [
      for (final course in data.courses)
        for (final section in course.sections) ...section.files,
    ];

    return WorkspaceScroll(
      onRefresh: onRefresh,
      children: [
        DriveTopBar(title: 'Drive', onSearch: onSearch),
        LayoutBuilder(
          builder: (context, constraints) {
            final upload = _HeroPanel(onUpload: onOpenUploads);
            final stats = _DriveStatusSummary(
              files: files,
              onUpload: onOpenUploads,
            );
            if (constraints.maxWidth < 760) {
              return Column(
                children: [upload, const SizedBox(height: 10), stats],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: upload),
                const SizedBox(width: 14),
                Expanded(flex: 4, child: stats),
              ],
            );
          },
        ),
        SizedBox(height: mobile ? 10 : 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 430;
            final actions = [
              _QuickAction(
                icon: Icons.note_add_rounded,
                label: 'Ders Oluştur',
                onTap: onCreateCourse,
              ),
              _QuickAction(
                icon: Icons.create_new_folder_rounded,
                label: 'Bölüm Ekle',
                onTap: () {
                  if (data.primaryCourse != null) {
                    onOpenCourse(data.primaryCourse!);
                  } else {
                    onCreateCourse();
                  }
                },
              ),
              _QuickAction(
                icon: Icons.collections_bookmark_outlined,
                label: 'Koleksiyon',
                onTap: onOpenCollections,
                color: AppColors.clinicalActive,
              ),
            ];
            if (!compact) {
              return Row(
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    Expanded(child: actions[i]),
                    if (i != actions.length - 1) const SizedBox(width: 10),
                  ],
                ],
              );
            }
            final phone = SourceBaseMobileMetrics.isCompactPhone(context);
            return GridView.count(
              crossAxisCount: phone ? 1 : 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: phone ? 4.8 : 1.32,
              children: actions,
            );
          },
        ),
        SectionTitle(
          title: 'Derslerim',
          actionLabel: hasCourses ? null : 'Ders Ekle',
          onAction: hasCourses ? null : onCreateCourse,
        ),
        GlassPanel(
          padding: EdgeInsets.zero,
          child: hasCourses
              ? Column(
                  children: [
                    for (final course in data.courses)
                      _CourseRow(
                        course: course,
                        onTap: () => onOpenCourse(course),
                        onRename: () => onRenameCourse(course),
                        onDelete: () => onDeleteCourse(course),
                      ),
                  ],
                )
              : _CourseEmptyPanel(onCreateCourse: onCreateCourse),
        ),
        SectionTitle(
          title: 'Son Yüklemeler',
          actionLabel: 'Tümünü Gör',
          onAction: onOpenUploadsPage,
        ),
        _HomeStorageOverview(
          recentFiles: data.recentFiles,
          collections: data.collections,
          onOpenFile: onOpenFile,
          onOpenUploads: onOpenUploads,
          onOpenCollections: onOpenCollections,
        ),
        SizedBox(height: mobile ? 12 : 22),
        const TrustStrip(),
        const WorkspaceBottomNavGuard(),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.onUpload});

  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Kaynak yükleme alanı',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 430;
          return GlassPanel(
            padding: EdgeInsets.fromLTRB(
              mobile ? 14 : 16,
              mobile ? 14 : 16,
              mobile ? 14 : 16,
              mobile ? 14 : 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.clinicalActiveBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.clinicalActive.withValues(
                            alpha: .10,
                          ),
                        ),
                      ),
                      child: const Icon(
                        Icons.cloud_upload_outlined,
                        color: AppColors.clinicalActive,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Kaynak yükle',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.clinicalActive,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Kaynaklarını Drive’a ekle',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: mobile ? 20 : 22,
                    fontWeight: FontWeight.w800,
                    height: 1.16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'PDF, PPTX veya DOCX ekle. Hazır olunca çıktı üretimine geç.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: mobile ? 13 : 14,
                    height: 1.34,
                  ),
                ),
                const SizedBox(height: 10),
                const _FormatSupportText(),
                const SizedBox(height: 12),
                SizedBox(
                  width: mobile ? double.infinity : 176,
                  child: SBPrimaryButton(
                    label: 'Kaynak yükle',
                    icon: Icons.cloud_upload_outlined,
                    onPressed: onUpload,
                    size: SBButtonSize.medium,
                    fullWidth: mobile,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FormatSupportText extends StatelessWidget {
  const _FormatSupportText();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: const [
        _SupportChip(label: 'PDF', message: 'Metin içeren PDF'),
        _SupportChip(label: 'PPTX', message: 'Sunum'),
        _SupportChip(label: 'DOCX', message: 'Doküman'),
        _SupportChip(label: 'PPT/DOC', message: 'Sınırlı'),
      ],
    );
  }
}

class _SupportChip extends StatelessWidget {
  const _SupportChip({required this.label, required this.message});

  final String label;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      child: SourceBaseChip(
        label: label,
        selected: true,
        foregroundColor: AppColors.clinicalActive,
      ),
    );
  }
}

class _DriveStatusSummary extends StatelessWidget {
  const _DriveStatusSummary({required this.files, required this.onUpload});

  final List<DriveFile> files;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final ready = files.where(driveFileUsableForGeneration).length;
    final processing = files
        .where((file) => file.status == DriveItemStatus.processing)
        .length;
    final failed = files
        .where((file) => file.status == DriveItemStatus.failed)
        .length;
    final nextAction = files.isEmpty
        ? 'İlk kaynağını yükle.'
        : processing > 0
        ? 'İşlenen kaynaklar tamamlanınca üretime geçebilirsin.'
        : ready > 0
        ? 'Hazır kaynaklarınla BaseForce veya SourceLab içinde çıktı üret.'
        : 'Hatalı kaynakları kontrol edip tekrar yüklemeyi dene.';

    return GlassPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kaynak durumu',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DriveMetricPill(label: 'Toplam', value: files.length),
              _DriveMetricPill(
                label: 'Hazır',
                value: ready,
                color: AppColors.green,
              ),
              _DriveMetricPill(
                label: 'İşleniyor',
                value: processing,
                color: AppColors.clinicalActive,
              ),
              _DriveMetricPill(
                label: 'Hatalı',
                value: failed,
                color: AppColors.clinicalError,
              ),
            ],
          ),
          const Divider(height: 18, color: AppColors.line),
          Text(
            nextAction,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          SBSecondaryButton(
            label: 'Kaynak yükle',
            icon: Icons.cloud_upload_outlined,
            onPressed: onUpload,
            size: SBButtonSize.small,
          ),
        ],
      ),
    );
  }
}

class _DriveMetricPill extends StatelessWidget {
  const _DriveMetricPill({
    required this.label,
    required this.value,
    this.color = AppColors.navy,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 86),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: .12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseEmptyPanel extends StatelessWidget {
  const _CourseEmptyPanel({required this.onCreateCourse});

  final VoidCallback onCreateCourse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      child: Column(
        children: [
          const SizedBox(width: 78, height: 66, child: _DriveEmptyArt()),
          const SizedBox(height: 12),
          const Text(
            'Ders yok',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 420),
            child: const Text(
              'Kaynaklarını düzenlemek için bir ders alanı oluştur.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.34,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 180,
            child: SBSecondaryButton(
              label: 'Ders Oluştur',
              icon: Icons.add_rounded,
              onPressed: onCreateCourse,
              size: SBButtonSize.medium,
              fullWidth: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeStorageOverview extends StatelessWidget {
  const _HomeStorageOverview({
    required this.recentFiles,
    required this.collections,
    required this.onOpenFile,
    required this.onOpenUploads,
    required this.onOpenCollections,
  });

  final List<DriveFile> recentFiles;
  final List<CollectionBundle> collections;
  final ValueChanged<DriveFile> onOpenFile;
  final VoidCallback onOpenUploads;
  final VoidCallback onOpenCollections;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final uploads = GlassPanel(
          padding: EdgeInsets.zero,
          child: recentFiles.isEmpty
              ? _StorageSummaryCard(
                  icon: Icons.folder_open_rounded,
                  message: 'Henüz yüklenmiş dosya yok.',
                  subMessage:
                      'İlk PDF veya PPTX dosyanı yükleyerek çalışma çıktıları oluşturabilirsin.',
                  onTap: onOpenUploads,
                )
              : Column(
                  children: [
                    for (final file in recentFiles)
                      _RecentUploadRow(
                        file: file,
                        onTap: () => onOpenFile(file),
                      ),
                  ],
                ),
        );
        final collectionPanel = GlassPanel(
          padding: EdgeInsets.zero,
          child: collections.isEmpty
              ? _StorageSummaryCard(
                  icon: Icons.layers_rounded,
                  message: 'Henüz koleksiyon yok.',
                  subMessage:
                      'Dosyalarını gruplandırarak koleksiyonlar oluşturabilirsin.',
                  onTap: onOpenCollections,
                )
              : SizedBox(
                  height: 222,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: collections.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) => SizedBox(
                      width: 300,
                      child: _CollectionCard(bundle: collections[index]),
                    ),
                  ),
                ),
        );

        if (compact) {
          return Column(
            children: [uploads, const SizedBox(height: 12), collectionPanel],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: uploads),
            const SizedBox(width: 14),
            Expanded(child: collectionPanel),
          ],
        );
      },
    );
  }
}

class _StorageSummaryCard extends StatelessWidget {
  const _StorageSummaryCard({
    required this.icon,
    required this.message,
    required this.subMessage,
    required this.onTap,
  });

  final IconData icon;
  final String message;
  final String subMessage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: AppColors.blue.withValues(alpha: .46),
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.34,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriveEmptyArt extends StatelessWidget {
  const _DriveEmptyArt();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _DriveEmptyPainter());
  }
}

class _DriveEmptyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final bg = Paint()..color = AppColors.blue.withValues(alpha: .07);
    final cap = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF8CB8FF), Color(0xFF1E68FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawCircle(center, 44, bg);
    final path = Path()
      ..moveTo(center.dx - 44, center.dy - 8)
      ..lineTo(center.dx, center.dy - 28)
      ..lineTo(center.dx + 44, center.dy - 8)
      ..lineTo(center.dx, center.dy + 12)
      ..close();
    canvas.drawPath(path, cap);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + 14),
          width: 54,
          height: 28,
        ),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFFCFE0FF),
    );
    final tassel = Paint()
      ..color = AppColors.blue
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx + 32, center.dy - 3),
      Offset(center.dx + 32, center.dy + 34),
      tassel,
    );
    canvas.drawCircle(
      Offset(center.dx + 32, center.dy + 37),
      4,
      Paint()..color = AppColors.blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.blue,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ExcludeSemantics(
          child: GlassPanel(
            padding: EdgeInsets.symmetric(
              horizontal: SourceBaseMobileMetrics.isCompactPhone(context)
                  ? 12
                  : 14,
              vertical: SourceBaseMobileMetrics.isCompactPhone(context)
                  ? 12
                  : 14,
            ),
            radius: 8,
            child: Row(
              children: [
                Container(
                  width: SourceBaseMobileMetrics.isCompactPhone(context)
                      ? 34
                      : 38,
                  height: SourceBaseMobileMetrics.isCompactPhone(context)
                      ? 34
                      : 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: SourceBaseMobileMetrics.isCompactPhone(context)
                        ? 19
                        : 21,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: SourceBaseMobileMetrics.isCompactPhone(context)
                          ? 13
                          : 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (!SourceBaseMobileMetrics.isCompactPhone(context))
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.navy,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CourseRow extends StatelessWidget {
  const _CourseRow({
    required this.course,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final DriveCourse course;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusLabel = course.status == DriveItemStatus.draft
        ? 'Taslak'
        : 'Aktif';
    return Semantics(
      button: true,
      label:
          '${course.title}. ${course.sections.length} bölüm. ${course.fileCount} dosya. $statusLabel.',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: course.iconBackground,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              course.icon,
                              color: course.iconColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  course.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.navy,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${course.sections.length} bölüm  •  ${course.fileCount} dosya',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _CourseStatus(status: course.status),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: 'Ders işlemleri',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showCourseActions(context),
                    borderRadius: BorderRadius.circular(24),
                    child: const SizedBox(
                      width: 38,
                      height: 38,
                      child: Icon(
                        Icons.more_vert_rounded,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCourseActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                _CourseActionTile(
                  icon: Icons.open_in_new_rounded,
                  label: 'Dersi Aç',
                  onTap: () {
                    Navigator.of(context).pop();
                    onTap();
                  },
                ),
                _CourseActionTile(
                  icon: Icons.edit_outlined,
                  label: 'Yeniden Adlandır',
                  onTap: () {
                    Navigator.of(context).pop();
                    onRename();
                  },
                ),
                _CourseActionTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'Dersi Sil',
                  destructive: true,
                  onTap: () {
                    Navigator.of(context).pop();
                    onDelete();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CourseActionTile extends StatelessWidget {
  const _CourseActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.red : AppColors.navy;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: destructive ? const Color(0xFFFFF1F2) : AppColors.selectedBlue,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CourseStatus extends StatelessWidget {
  const _CourseStatus({required this.status});

  final DriveItemStatus status;

  @override
  Widget build(BuildContext context) {
    final draft = status == DriveItemStatus.draft;
    final label = draft ? 'Taslak' : 'Aktif';
    return Semantics(
      label: 'Durum: $label',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: draft ? AppColors.selectedBlue : AppColors.greenBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: draft
                  ? AppColors.blue.withValues(alpha: .14)
                  : AppColors.green.withValues(alpha: .14),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: draft ? AppColors.blue : AppColors.green,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentUploadRow extends StatelessWidget {
  const _RecentUploadRow({required this.file, required this.onTap});

  final DriveFile file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusLabel = driveStatusLabel(file.status);
    return Semantics(
      button: true,
      label:
          '${file.title}. ${file.sizeLabel}. ${file.updatedLabel}. ${file.tag ?? file.courseTitle}. $statusLabel.',
      child: InkWell(
        onTap: onTap,
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                FileKindBadge(kind: file.kind, plain: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(file.sizeLabel),
                          const MetaDot(),
                          Text(file.updatedLabel),
                          const MetaDot(),
                          Text(statusLabel),
                        ],
                      ),
                      if (!driveFileUsableForGeneration(file)) ...[
                        const SizedBox(height: 5),
                        Text(
                          driveFriendlyStatusDescription(file),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (file.status == DriveItemStatus.uploading)
                  SizedBox(
                    width: 130,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Yükleniyor...',
                          style: TextStyle(
                            color: AppColors.blue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: const LinearProgressIndicator(
                            value: null,
                            minHeight: 7,
                            backgroundColor: AppColors.line,
                            valueColor: AlwaysStoppedAnimation(AppColors.blue),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  StatusPill(status: file.status, compact: true),
                const SizedBox(width: 8),
                const Icon(Icons.more_vert_rounded, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _showCollectionsToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.bundle});

  final CollectionBundle bundle;

  @override
  Widget build(BuildContext context) {
    final file = bundle.file;
    final details = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FileKindBadge(kind: file.kind, large: false, plain: true),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                file.title,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 5,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final output in bundle.outputs)
                    _OutputLabel(output: output),
                ],
              ),
              const SizedBox(height: 10),
              _MetaLine(icon: Icons.school_outlined, text: bundle.subject),
              const SizedBox(height: 5),
              _MetaLine(
                icon: Icons.schedule_rounded,
                text: 'Son güncelleme: ${file.updatedLabel}',
              ),
            ],
          ),
        ),
      ],
    );

    final viewButton = OutlinedButton(
      onPressed: () => _showCollectionsToast(
        context,
        '${bundle.file.title} koleksiyonu görüntüleniyor.',
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.blue,
        backgroundColor: AppColors.selectedBlue,
        side: const BorderSide(color: AppColors.softLine),
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text('Görüntüle'),
    );

    final preview = Column(
      children: [
        viewButton,
        const SizedBox(height: 8),
        _CollectionPreview(kind: bundle.previewKind),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            4,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: index == 0 ? AppColors.blue : AppColors.line,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ],
    );

    final menu = IconButton(
      tooltip: 'Diğer işlemler',
      onPressed: () =>
          _showCollectionsToast(context, 'Koleksiyon işlemleri açıldı.'),
      icon: const Icon(Icons.more_vert_rounded, color: AppColors.muted),
      visualDensity: VisualDensity.compact,
    );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label:
          '${file.title} koleksiyonu. ${bundle.outputs.length} çıktı. ${bundle.subject}. Son güncelleme: ${file.updatedLabel}.',
      child: GlassPanel(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (!constraints.hasBoundedWidth || constraints.maxWidth < 520) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  details,
                  const SizedBox(height: 10),
                  Row(children: [viewButton, const Spacer(), menu]),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: details),
                const SizedBox(width: 12),
                preview,
                const SizedBox(width: 6),
                menu,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OutputLabel extends StatelessWidget {
  const _OutputLabel({required this.output});

  final GeneratedOutput output;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: Semantics(
        label: 'Çıktı: ${output.title}',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.selectedBlue,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.softLine),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                switch (output.kind) {
                  GeneratedKind.flashcard => Icons.style_outlined,
                  GeneratedKind.question => Icons.quiz_outlined,
                  _ => Icons.description_outlined,
                },
                size: 14,
                color: AppColors.blue,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  output.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.blue,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.muted),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(color: AppColors.muted, fontSize: 14),
        ),
      ],
    );
  }
}

class _CollectionPreview extends StatelessWidget {
  const _CollectionPreview({required this.kind});

  final GeneratedKind kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: CustomPaint(painter: _PreviewMiniPainter(kind: kind)),
    );
  }
}

class _PreviewMiniPainter extends CustomPainter {
  const _PreviewMiniPainter({required this.kind});

  final GeneratedKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.line
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    if (kind == GeneratedKind.flashcard) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: size.width * 0.7,
            height: size.height * 0.6,
          ),
          const Radius.circular(4),
        ),
        paint..style = PaintingStyle.stroke,
      );
    } else {
      for (var i = 1; i <= 3; i++) {
        canvas.drawLine(
          Offset(size.width * 0.2, size.height * (0.2 + i * 0.2)),
          Offset(size.width * 0.8, size.height * (0.2 + i * 0.2)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
