import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/drive_models.dart';
import '../widgets/drive_ui.dart';

class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen({
    required this.course,
    required this.onSearch,
    required this.onBack,
    required this.onOpenSection,
    required this.onOpenFile,
    required this.onCreateSection,
    required this.onOpenUploads,
    required this.onRenameCourse,
    required this.onDeleteCourse,
    required this.onRenameSection,
    required this.onDeleteSection,
    super.key,
  });

  final DriveCourse course;
  final VoidCallback onSearch;
  final VoidCallback onBack;
  final ValueChanged<DriveSection> onOpenSection;
  final ValueChanged<DriveFile> onOpenFile;
  final VoidCallback onCreateSection;
  final VoidCallback onOpenUploads;
  final VoidCallback onRenameCourse;
  final VoidCallback onDeleteCourse;
  final ValueChanged<DriveSection> onRenameSection;
  final ValueChanged<DriveSection> onDeleteSection;

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

enum _CourseDetailTab { sections, files, details }

enum _CourseMenuAction { addSection, upload, rename, delete }

enum _SectionMenuAction { open, upload, rename, delete }

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  var _selectedTab = _CourseDetailTab.sections;

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final allFiles = [for (final section in course.sections) ...section.files];
    return WorkspaceScroll(
      children: [
        DriveTopBar(title: 'Drive', onSearch: widget.onSearch, showMore: false),
        Row(
          children: [
            IconButton(
              onPressed: widget.onBack,
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
            PopupMenuButton<_CourseMenuAction>(
              tooltip: 'Ders işlemleri',
              icon: const Icon(
                Icons.more_horiz_rounded,
                size: 31,
                color: AppColors.navy,
              ),
              onSelected: (action) {
                switch (action) {
                  case _CourseMenuAction.addSection:
                    widget.onCreateSection();
                  case _CourseMenuAction.upload:
                    widget.onOpenUploads();
                  case _CourseMenuAction.rename:
                    widget.onRenameCourse();
                  case _CourseMenuAction.delete:
                    widget.onDeleteCourse();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _CourseMenuAction.addSection,
                  child: _MenuItem(
                    icon: Icons.create_new_folder_outlined,
                    label: 'Bölüm Ekle',
                  ),
                ),
                PopupMenuItem(
                  value: _CourseMenuAction.upload,
                  child: _MenuItem(
                    icon: Icons.cloud_upload_outlined,
                    label: 'Dosya Yükle',
                  ),
                ),
                PopupMenuItem(
                  value: _CourseMenuAction.rename,
                  child: _MenuItem(
                    icon: Icons.edit_outlined,
                    label: 'Yeniden Adlandır',
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: _CourseMenuAction.delete,
                  child: _MenuItem(
                    icon: Icons.delete_outline_rounded,
                    label: 'Dersi Sil',
                    destructive: true,
                  ),
                ),
              ],
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
                          child: SBSecondaryButton(
                            label: 'Bölüm Ekle',
                            icon: Icons.create_new_folder_outlined,
                            onPressed: widget.onCreateSection,
                            size: SBButtonSize.small,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SBPrimaryButton(
                            label: 'Dosya Yükle',
                            icon: Icons.cloud_upload_outlined,
                            onPressed: widget.onOpenUploads,
                            size: SBButtonSize.small,
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
        _SegmentedTabs(
          selected: _selectedTab,
          onSelected: (tab) => setState(() => _selectedTab = tab),
        ),
        const SizedBox(height: 18),
        switch (_selectedTab) {
          _CourseDetailTab.sections => _SectionsTab(
            sections: course.sections,
            onOpenSection: widget.onOpenSection,
            onOpenUploads: widget.onOpenUploads,
            onRenameSection: widget.onRenameSection,
            onDeleteSection: widget.onDeleteSection,
          ),
          _CourseDetailTab.files => _FilesTab(
            files: allFiles,
            onOpenFile: widget.onOpenFile,
            onOpenUploads: widget.onOpenUploads,
          ),
          _CourseDetailTab.details => _DetailsTab(course: course),
        },
      ],
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.selected, required this.onSelected});

  final _CourseDetailTab selected;
  final ValueChanged<_CourseDetailTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(4),
      radius: 12,
      child: Row(
        children: [
          _TabChip(
            label: 'Bölümler',
            selected: selected == _CourseDetailTab.sections,
            onTap: () => onSelected(_CourseDetailTab.sections),
          ),
          _TabChip(
            label: 'Dosyalar',
            selected: selected == _CourseDetailTab.files,
            onTap: () => onSelected(_CourseDetailTab.files),
          ),
          _TabChip(
            label: 'Ayrıntılar',
            selected: selected == _CourseDetailTab.details,
            onTap: () => onSelected(_CourseDetailTab.details),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
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
      ),
    );
  }
}

class _SectionsTab extends StatelessWidget {
  const _SectionsTab({
    required this.sections,
    required this.onOpenSection,
    required this.onOpenUploads,
    required this.onRenameSection,
    required this.onDeleteSection,
  });

  final List<DriveSection> sections;
  final ValueChanged<DriveSection> onOpenSection;
  final VoidCallback onOpenUploads;
  final ValueChanged<DriveSection> onRenameSection;
  final ValueChanged<DriveSection> onDeleteSection;

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) {
      return const GlassPanel(
        padding: EdgeInsets.all(22),
        child: EmptyState(
          message: 'Bu derste henüz bölüm yok.',
          subMessage: 'Bölüm ekleyerek dosyalarınızı düzenlemeye başlayın.',
        ),
      );
    }
    return Column(
      children: [
        for (final section in sections) ...[
          _SectionCard(
            section: section,
            onTap: () => onOpenSection(section),
            onOpenUploads: onOpenUploads,
            onRename: () => onRenameSection(section),
            onDelete: () => onDeleteSection(section),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _FilesTab extends StatelessWidget {
  const _FilesTab({
    required this.files,
    required this.onOpenFile,
    required this.onOpenUploads,
  });

  final List<DriveFile> files;
  final ValueChanged<DriveFile> onOpenFile;
  final VoidCallback onOpenUploads;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return GlassPanel(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            const EmptyState(
              message: 'Bu derste henüz dosya yok.',
              subMessage: 'PDF, DOCX veya PPT yükleyerek başlayın.',
            ),
            const SizedBox(height: 16),
            SBPrimaryButton(
              label: 'Dosya Yükle',
              icon: Icons.cloud_upload_outlined,
              onPressed: onOpenUploads,
              size: SBButtonSize.small,
              fullWidth: false,
            ),
          ],
        ),
      );
    }
    return GlassPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final file in files)
            InkWell(
              onTap: () => onOpenFile(file),
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
                          const SizedBox(height: 6),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(file.sectionTitle),
                              const MetaDot(),
                              Text(file.sizeLabel),
                              const MetaDot(),
                              Text(file.updatedLabel),
                            ],
                          ),
                        ],
                      ),
                    ),
                    StatusPill(status: file.status, compact: true),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.muted,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({required this.course});

  final DriveCourse course;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow(label: 'Ders adı', value: course.title),
          _DetailRow(label: 'Durum', value: _statusLabel(course.status)),
          _DetailRow(label: 'Bölüm sayısı', value: '${course.sections.length}'),
          _DetailRow(label: 'Dosya sayısı', value: '${course.fileCount}'),
          _DetailRow(label: 'Son güncelleme', value: course.updatedLabel),
          const SizedBox(height: 10),
          const Text(
            'Açıklama',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            course.description,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 16,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.onTap,
    required this.onOpenUploads,
    required this.onRename,
    required this.onDelete,
  });

  final DriveSection section;
  final VoidCallback onTap;
  final VoidCallback onOpenUploads;
  final VoidCallback onRename;
  final VoidCallback onDelete;

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
                      PopupMenuButton<_SectionMenuAction>(
                        tooltip: 'Bölüm işlemleri',
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          color: AppColors.muted,
                        ),
                        onSelected: (action) {
                          switch (action) {
                            case _SectionMenuAction.open:
                              onTap();
                            case _SectionMenuAction.upload:
                              onOpenUploads();
                            case _SectionMenuAction.rename:
                              onRename();
                            case _SectionMenuAction.delete:
                              onDelete();
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: _SectionMenuAction.open,
                            child: _MenuItem(
                              icon: Icons.folder_open_outlined,
                              label: 'Bölümü Aç',
                            ),
                          ),
                          PopupMenuItem(
                            value: _SectionMenuAction.upload,
                            child: _MenuItem(
                              icon: Icons.cloud_upload_outlined,
                              label: 'Dosya Yükle',
                            ),
                          ),
                          PopupMenuItem(
                            value: _SectionMenuAction.rename,
                            child: _MenuItem(
                              icon: Icons.edit_outlined,
                              label: 'Yeniden Adlandır',
                            ),
                          ),
                          PopupMenuDivider(),
                          PopupMenuItem(
                            value: _SectionMenuAction.delete,
                            child: _MenuItem(
                              icon: Icons.delete_outline_rounded,
                              label: 'Bölümü Sil',
                              destructive: true,
                            ),
                          ),
                        ],
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

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.red : AppColors.navy;
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

String _statusLabel(DriveItemStatus status) {
  return switch (status) {
    DriveItemStatus.completed => 'Aktif',
    DriveItemStatus.processing => 'İşleniyor',
    DriveItemStatus.uploading => 'Yükleniyor',
    DriveItemStatus.failed => 'Hata',
    DriveItemStatus.draft => 'Taslak',
  };
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
