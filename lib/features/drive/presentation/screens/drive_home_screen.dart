import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/drive_models.dart';
import '../widgets/drive_ui.dart';

String _driveStatusLabel(DriveItemStatus status) {
  return switch (status) {
    DriveItemStatus.completed => 'Tamamlandı',
    DriveItemStatus.processing => 'İşleniyor',
    DriveItemStatus.uploading => 'Yükleniyor',
    DriveItemStatus.failed => 'Hata',
    DriveItemStatus.draft => 'Taslak',
  };
}

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
    final hasRecent = data.recentFiles.isNotEmpty;
    final hasCollections = data.collections.isNotEmpty;

    return WorkspaceScroll(
      onRefresh: onRefresh,
      children: [
        DriveTopBar(title: 'Drive', onSearch: onSearch),
        _HeroPanel(onUpload: onOpenUploads),
        const SizedBox(height: 16),
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
                icon: Icons.layers_rounded,
                label: 'Koleksiyonlar',
                onTap: onOpenCollections,
                color: AppColors.purple,
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
            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.95,
              children: actions,
            );
          },
        ),
        SectionTitle(
          title: 'Derslerim',
          actionLabel: 'Tümünü Gör',
          onAction: () {},
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
              : const EmptyState(
                  message: 'Henüz bir ders eklenmemiş.',
                  subMessage: 'Yeni bir ders alanı oluşturarak başlayın.',
                ),
        ),
        SectionTitle(
          title: 'Son Yüklemeler',
          actionLabel: 'Tümünü Gör',
          onAction: onOpenUploadsPage,
        ),
        if (hasCollections)
          GlassPanel(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: data.collections.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) =>
                    _CollectionCard(bundle: data.collections[index]),
              ),
            ),
          )
        else
          const GlassPanel(
            padding: EdgeInsets.all(22),
            child: EmptyState(
              message: 'Henüz bir koleksiyonunuz yok.',
              subMessage:
                  'Dosyalarınızdan flashcard veya özet üreterek başlayın.',
            ),
          ),
        GlassPanel(
          padding: EdgeInsets.zero,
          child: hasRecent
              ? Column(
                  children: [
                    for (final file in data.recentFiles)
                      _RecentUploadRow(
                        file: file,
                        onTap: () => onOpenFile(file),
                      ),
                  ],
                )
              : const EmptyState(
                  message: 'Henüz yüklenmiş dosya yok.',
                  subMessage: 'Dosyalarınızı buraya yükleyip AI ile işleyin.',
                ),
        ),
        const SizedBox(height: 22),
        const TrustStrip(),
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
      label: 'Kaynak Üssün tanıtım paneli',
      child: GlassPanel(
        padding: const EdgeInsets.fromLTRB(20, 24, 18, 20),
        child: Stack(
          children: [
            const Positioned(
              right: 0,
              top: 14,
              child: SizedBox(width: 148, height: 150, child: _StackHeroArt()),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 118),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Kaynak Üssün',
                      maxLines: 1,
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 31,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Derslerini oluştur,\nbölümler ekle ve\nmateryallerini öğrenme\naraçlarına dönüştür.',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 16.5,
                      height: 1.28,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: 180,
                    child: SBPrimaryButton(
                      label: 'Kaynak Yükle',
                      icon: Icons.add_rounded,
                      onPressed: onUpload,
                      size: SBButtonSize.medium,
                      fullWidth: false,
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

class _StackHeroArt extends StatelessWidget {
  const _StackHeroArt();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Kaynak dosyaları illüstrasyonu',
      child: CustomPaint(painter: _StackHeroPainter()),
    );
  }
}

class _StackHeroPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final shadow = Paint()
      ..color = AppColors.blue.withValues(alpha: .10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    final fill = Paint()
      ..color = const Color(0xFFDCEBFF).withValues(alpha: .82);
    final line = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    for (var i = 0; i < 3; i++) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width * .55, 48 + i * 36),
          width: 118,
          height: 66,
        ),
        const Radius.circular(16),
      );
      canvas.drawRRect(rect.shift(const Offset(0, 9)), shadow);
      canvas.drawRRect(rect, fill);
      canvas.drawRRect(rect, line);
    }
    final dot = Paint()..color = const Color(0xFFBBD8FF);
    for (final offset in const [
      Offset(18, 100),
      Offset(40, 86),
      Offset(55, 112),
      Offset(24, 132),
    ]) {
      canvas.drawCircle(offset, 5, dot);
    }
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
        borderRadius: BorderRadius.circular(14),
        child: ExcludeSemantics(
          child: GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 14),
            radius: 14,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 31),
                const SizedBox(height: 9),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
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
      child: InkWell(
        onTap: onTap,
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: course.iconBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(course.icon, color: course.iconColor, size: 34),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.title,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${course.sections.length} bölüm  •  ${course.fileCount} dosya',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                _CourseStatus(status: course.status),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Ders işlemleri',
                  onPressed: () => _showCourseActions(context),
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
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
    final statusLabel = file.status == DriveItemStatus.uploading
        ? 'Yükleniyor...'
        : _driveStatusLabel(file.status);
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
                          Text(file.tag ?? file.courseTitle),
                        ],
                      ),
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
        FileKindBadge(kind: file.kind, large: true, plain: true),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                file.title,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 11),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final output in bundle.outputs)
                    _OutputLabel(output: output),
                ],
              ),
              const SizedBox(height: 16),
              _MetaLine(icon: Icons.school_outlined, text: bundle.subject),
              const SizedBox(height: 8),
              _MetaLine(
                icon: Icons.schedule_rounded,
                text: 'Son güncelleme: ${file.updatedLabel}',
              ),
            ],
          ),
        ),
      ],
    );

    final preview = Column(
      children: [
        OutlinedButton(
          onPressed: () => _showCollectionsToast(
            context,
            '${bundle.file.title} koleksiyonu görüntüleniyor.',
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.blue,
            backgroundColor: AppColors.selectedBlue,
            side: const BorderSide(color: AppColors.softLine),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: const Text('Görüntüle'),
        ),
        const SizedBox(height: 10),
        _CollectionPreview(kind: bundle.previewKind),
        const SizedBox(height: 8),
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
            if (constraints.maxWidth < 520) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  details,
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [preview, const Spacer(), menu],
                  ),
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
