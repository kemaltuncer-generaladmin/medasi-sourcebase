import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/drive_models.dart';
import '../widgets/drive_ui.dart';

class CourseDetailScreen extends StatelessWidget {
  const CourseDetailScreen({
    required this.course,
    required this.onSearch,
    required this.onBack,
    required this.onOpenSection,
    required this.onCreateSection,
    required this.onOpenUploads,
    super.key,
  });

  final DriveCourse course;
  final VoidCallback onSearch;
  final VoidCallback onBack;
  final VoidCallback onOpenSection;
  final VoidCallback onCreateSection;
  final VoidCallback onOpenUploads;

  @override
  Widget build(BuildContext context) {
    return WorkspaceScroll(
      children: [
        DriveTopBar(title: 'Drive', onSearch: onSearch, showMore: false),
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 32),
              color: AppColors.navy,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                course.title,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.more_horiz_rounded, size: 31),
              color: AppColors.navy,
            ),
          ],
        ),
        const SizedBox(height: 18),
        GlassPanel(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: course.iconBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(course.icon, color: course.iconColor, size: 52),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${course.sections.length} bölüm  •  ${course.fileCount} dosya  •  ${course.updatedLabel}',
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      course.description,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 16,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlineIconButton(
                            label: 'Bölüm Ekle',
                            icon: Icons.create_new_folder_outlined,
                            onTap: onCreateSection,
                            height: 48,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PrimaryGradientButton(
                            label: 'Dosya Yükle',
                            icon: Icons.cloud_upload_outlined,
                            onTap: onOpenUploads,
                            height: 48,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SegmentedTabs(),
        const SizedBox(height: 18),
        for (final section in course.sections) ...[
          _SectionCard(section: section, onTap: onOpenSection),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(4),
      radius: 12,
      child: Row(
        children: const [
          _TabChip(label: 'Bölümler', selected: true),
          _TabChip(label: 'Dosyalar'),
          _TabChip(label: 'Ayrıntılar'),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: selected
              ? const Border(
                  bottom: BorderSide(color: AppColors.blue, width: 2),
                )
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.blue : AppColors.navy,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section, required this.onTap});

  final DriveSection section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: GlassPanel(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.drag_indicator_rounded,
              color: AppColors.line,
              size: 30,
            ),
            const SizedBox(width: 12),
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.selectedBlue,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.folder_outlined,
                color: AppColors.blue,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          section.title,
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _SectionStatus(status: section.status),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.more_vert_rounded,
                        color: AppColors.muted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${section.files.length} dosya',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final file in section.files.take(3)) ...[
                          _TinyFileChip(file: file),
                          const SizedBox(width: 8),
                        ],
                        if (section.files.length > 3)
                          Container(
                            height: 40,
                            width: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Text(
                              '+${section.files.length - 3}',
                              style: const TextStyle(
                                color: AppColors.navy,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
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

class _SectionStatus extends StatelessWidget {
  const _SectionStatus({required this.status});

  final DriveItemStatus status;

  @override
  Widget build(BuildContext context) {
    final draft = status == DriveItemStatus.draft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: draft ? AppColors.selectedBlue : AppColors.greenBg,
        borderRadius: BorderRadius.circular(14),
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
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TinyFileChip extends StatelessWidget {
  const _TinyFileChip({required this.file});

  final DriveFile file;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          FileKindBadge(kind: file.kind, large: false),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              file.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.navy, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
