import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/drive_models.dart';
import '../widgets/drive_ui.dart';

class DriveHomeScreen extends StatelessWidget {
  const DriveHomeScreen({
    required this.data,
    required this.onSearch,
    required this.onOpenCourse,
    required this.onCreateCourse,
    required this.onOpenUploads,
    required this.onOpenUploadsPage,
    required this.onOpenCollections,
    super.key,
  });

  final DriveWorkspaceData data;
  final VoidCallback onSearch;
  final VoidCallback onOpenCourse;
  final VoidCallback onCreateCourse;
  final VoidCallback onOpenUploads;
  final VoidCallback onOpenUploadsPage;
  final VoidCallback onOpenCollections;

  @override
  Widget build(BuildContext context) {
    return WorkspaceScroll(
      children: [
        DriveTopBar(title: 'Drive', onSearch: onSearch),
        _HeroPanel(onUpload: onOpenUploads),
        const SizedBox(height: 16),
        Row(
          children: [
            _QuickAction(
              icon: Icons.note_add_rounded,
              label: 'Ders Oluştur',
              onTap: onCreateCourse,
            ),
            const SizedBox(width: 10),
            _QuickAction(
              icon: Icons.create_new_folder_rounded,
              label: 'Bölüm Ekle',
              onTap: onOpenCourse,
            ),
            const SizedBox(width: 10),
            _QuickAction(
              icon: Icons.picture_as_pdf_rounded,
              label: 'PDF/PPT',
              onTap: onOpenUploads,
            ),
            const SizedBox(width: 10),
            _QuickAction(
              icon: Icons.layers_rounded,
              label: 'Koleksiyonlar',
              onTap: onOpenCollections,
              color: AppColors.purple,
            ),
          ],
        ),
        SectionTitle(
          title: 'Derslerim',
          actionLabel: 'Tümünü Gör',
          onAction: () {},
        ),
        GlassPanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final course in data.courses)
                _CourseRow(course: course, onTap: onOpenCourse),
            ],
          ),
        ),
        SectionTitle(
          title: 'Son Yüklemeler',
          actionLabel: 'Tümünü Gör',
          onAction: onOpenUploadsPage,
        ),
        GlassPanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final file in data.recentFiles)
                _RecentUploadRow(
                  file: file,
                  onTap: file.id == 'file-aritmiler-final'
                      ? onOpenUploads
                      : () {},
                ),
            ],
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
    return GlassPanel(
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
                  child: PrimaryGradientButton(
                    label: 'Kaynak Yükle',
                    icon: Icons.add_rounded,
                    onTap: onUpload,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StackHeroArt extends StatelessWidget {
  const _StackHeroArt();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _StackHeroPainter());
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
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 18),
          radius: 14,
          child: Column(
            children: [
              Icon(icon, color: color, size: 34),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
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
    );
  }
}

class _CourseRow extends StatelessWidget {
  const _CourseRow({required this.course, required this.onTap});

  final DriveCourse course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
            const Icon(Icons.chevron_right_rounded, color: AppColors.navy),
          ],
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
    return Container(
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
        draft ? 'Taslak' : 'Aktif',
        style: TextStyle(
          color: draft ? AppColors.blue : AppColors.green,
          fontSize: 15,
          fontWeight: FontWeight.w700,
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
    return InkWell(
      onTap: onTap,
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
                      'Yükleniyor %78',
                      style: TextStyle(
                        color: AppColors.blue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: const LinearProgressIndicator(
                        value: .78,
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
    );
  }
}
