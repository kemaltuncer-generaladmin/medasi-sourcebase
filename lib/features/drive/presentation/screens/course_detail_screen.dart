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
    required this.onUploadToSection,
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
  final ValueChanged<DriveSection> onUploadToSection;
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

enum _FileSort { newest, name, section, kind }

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  var _selectedTab = _CourseDetailTab.sections;
  var _fileSort = _FileSort.newest;
  DriveFileKind? _fileKind;
  String _fileQuery = '';

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final allFiles = [for (final section in course.sections) ...section.files];
    final visibleFiles = _visibleFiles(allFiles);

    return WorkspaceScroll(
      children: [
        DriveTopBar(title: 'Drive', onSearch: widget.onSearch),
        _CourseHeader(
          course: course,
          files: allFiles,
          onBack: widget.onBack,
          onAddSection: widget.onCreateSection,
          onUpload: widget.onOpenUploads,
          onRename: widget.onRenameCourse,
          onDelete: widget.onDeleteCourse,
        ),
        const SizedBox(height: 14),
        _SegmentedTabs(
          selected: _selectedTab,
          sectionCount: course.sections.length,
          fileCount: allFiles.length,
          onSelected: (tab) => setState(() => _selectedTab = tab),
        ),
        const SizedBox(height: 14),
        switch (_selectedTab) {
          _CourseDetailTab.sections => _SectionsTab(
            course: course,
            onCreateSection: widget.onCreateSection,
            onOpenSection: widget.onOpenSection,
            onOpenUploads: widget.onOpenUploads,
            onUploadToSection: widget.onUploadToSection,
            onRenameSection: widget.onRenameSection,
            onDeleteSection: widget.onDeleteSection,
          ),
          _CourseDetailTab.files => _FilesTab(
            files: visibleFiles,
            totalFileCount: allFiles.length,
            query: _fileQuery,
            sort: _fileSort,
            kind: _fileKind,
            onQueryChanged: (value) => setState(() => _fileQuery = value),
            onSortChanged: (value) => setState(() => _fileSort = value),
            onKindChanged: (value) => setState(() => _fileKind = value),
            onOpenFile: widget.onOpenFile,
            onOpenUploads: widget.onOpenUploads,
          ),
          _CourseDetailTab.details => _DetailsTab(course: course),
        },
      ],
    );
  }

  List<DriveFile> _visibleFiles(List<DriveFile> files) {
    final query = _fileQuery.trim().toLowerCase();
    final filtered = files.where((file) {
      final matchesQuery =
          query.isEmpty ||
          file.title.toLowerCase().contains(query) ||
          file.sectionTitle.toLowerCase().contains(query) ||
          (file.tag?.toLowerCase().contains(query) ?? false);
      final matchesKind = _fileKind == null || file.kind == _fileKind;
      return matchesQuery && matchesKind;
    }).toList();

    if (_fileSort != _FileSort.newest) {
      filtered.sort((a, b) {
        return switch (_fileSort) {
          _FileSort.newest => 0,
          _FileSort.name => a.title.toLowerCase().compareTo(
            b.title.toLowerCase(),
          ),
          _FileSort.section => a.sectionTitle.toLowerCase().compareTo(
            b.sectionTitle.toLowerCase(),
          ),
          _FileSort.kind => a.kind.name.compareTo(b.kind.name),
        };
      });
    }
    return filtered;
  }
}

class _CourseHeader extends StatelessWidget {
  const _CourseHeader({
    required this.course,
    required this.files,
    required this.onBack,
    required this.onAddSection,
    required this.onUpload,
    required this.onRename,
    required this.onDelete,
  });

  final DriveCourse course;
  final List<DriveFile> files;
  final VoidCallback onBack;
  final VoidCallback onAddSection;
  final VoidCallback onUpload;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final latest = files.isEmpty
        ? course.updatedLabel
        : files.first.updatedLabel;
    return GlassPanel(
      padding: EdgeInsets.zero,
      radius: 18,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 640;
          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    tooltip: 'Geri dön',
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded, size: 30),
                    color: AppColors.navy,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      course.title,
                      maxLines: compact ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: compact ? 28 : 34,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _CourseMenu(
                    onAddSection: onAddSection,
                    onUpload: onUpload,
                    onRename: onRename,
                    onDelete: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                course.description,
                maxLines: compact ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetricPill(
                    icon: Icons.folder_copy_outlined,
                    label: '${course.sections.length} bölüm',
                  ),
                  _MetricPill(
                    icon: Icons.insert_drive_file_outlined,
                    label: '${course.fileCount} dosya',
                  ),
                  _MetricPill(icon: Icons.update_rounded, label: latest),
                ],
              ),
            ],
          );

          final actions = compact
              ? Column(
                  children: [
                    SBPrimaryButton(
                      label: 'Dosya Yükle',
                      icon: Icons.cloud_upload_outlined,
                      onPressed: onUpload,
                      size: SBButtonSize.small,
                      fullWidth: true,
                    ),
                    const SizedBox(height: 10),
                    SBSecondaryButton(
                      label: 'Bölüm Ekle',
                      icon: Icons.create_new_folder_outlined,
                      onPressed: onAddSection,
                      size: SBButtonSize.small,
                      fullWidth: true,
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 148,
                      child: SBSecondaryButton(
                        label: 'Bölüm Ekle',
                        icon: Icons.create_new_folder_outlined,
                        onPressed: onAddSection,
                        size: SBButtonSize.small,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 148,
                      child: SBPrimaryButton(
                        label: 'Dosya Yükle',
                        icon: Icons.cloud_upload_outlined,
                        onPressed: onUpload,
                        size: SBButtonSize.small,
                      ),
                    ),
                  ],
                );

          return Padding(
            padding: EdgeInsets.all(compact ? 14 : 18),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CourseAvatar(course: course, large: true),
                      const SizedBox(height: 14),
                      titleBlock,
                      const SizedBox(height: 16),
                      actions,
                    ],
                  )
                : Row(
                    children: [
                      _CourseAvatar(course: course, large: true),
                      const SizedBox(width: 18),
                      Expanded(child: titleBlock),
                      const SizedBox(width: 18),
                      actions,
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _CourseMenu extends StatelessWidget {
  const _CourseMenu({
    required this.onAddSection,
    required this.onUpload,
    required this.onRename,
    required this.onDelete,
  });

  final VoidCallback onAddSection;
  final VoidCallback onUpload;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_CourseMenuAction>(
      tooltip: 'Ders işlemleri',
      icon: const Icon(
        Icons.more_horiz_rounded,
        size: 31,
        color: AppColors.navy,
      ),
      onSelected: (action) {
        switch (action) {
          case _CourseMenuAction.addSection:
            onAddSection();
          case _CourseMenuAction.upload:
            onUpload();
          case _CourseMenuAction.rename:
            onRename();
          case _CourseMenuAction.delete:
            onDelete();
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
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.selected,
    required this.sectionCount,
    required this.fileCount,
    required this.onSelected,
  });

  final _CourseDetailTab selected;
  final int sectionCount;
  final int fileCount;
  final ValueChanged<_CourseDetailTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(5),
      radius: 12,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 430;
          return Row(
            children: [
              _TabChip(
                icon: Icons.account_tree_outlined,
                label: 'Bölümler',
                count: sectionCount,
                compact: compact,
                selected: selected == _CourseDetailTab.sections,
                onTap: () => onSelected(_CourseDetailTab.sections),
              ),
              _TabChip(
                icon: Icons.description_outlined,
                label: 'Dosyalar',
                count: fileCount,
                compact: compact,
                selected: selected == _CourseDetailTab.files,
                onTap: () => onSelected(_CourseDetailTab.files),
              ),
              _TabChip(
                icon: Icons.info_outline_rounded,
                label: 'Ayrıntılar',
                compact: compact,
                selected: selected == _CourseDetailTab.details,
                onTap: () => onSelected(_CourseDetailTab.details),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.count,
    this.compact = false,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final int? count;
  final bool compact;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: compact ? 44 : 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: compact ? 18 : 20,
                  color: selected ? Colors.white : AppColors.muted,
                ),
                SizedBox(width: compact ? 5 : 7),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.navy,
                    fontSize: compact ? 14 : 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (count != null && !compact) ...[
                  const SizedBox(width: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(alpha: .2)
                          : AppColors.selectedBlue,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionsTab extends StatelessWidget {
  const _SectionsTab({
    required this.course,
    required this.onCreateSection,
    required this.onOpenSection,
    required this.onOpenUploads,
    required this.onUploadToSection,
    required this.onRenameSection,
    required this.onDeleteSection,
  });

  final DriveCourse course;
  final VoidCallback onCreateSection;
  final ValueChanged<DriveSection> onOpenSection;
  final VoidCallback onOpenUploads;
  final ValueChanged<DriveSection> onUploadToSection;
  final ValueChanged<DriveSection> onRenameSection;
  final ValueChanged<DriveSection> onDeleteSection;

  @override
  Widget build(BuildContext context) {
    if (course.sections.isEmpty) {
      return GlassPanel(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const EmptyState(
              icon: Icons.account_tree_outlined,
              message: 'Bu derste henüz bölüm yok.',
              subMessage: 'Bölüm ekleyerek dosyalarınızı düzenlemeye başlayın.',
            ),
            SBPrimaryButton(
              label: 'Bölüm Ekle',
              icon: Icons.create_new_folder_outlined,
              onPressed: onCreateSection,
              size: SBButtonSize.small,
              fullWidth: false,
            ),
          ],
        ),
      );
    }

    final busiest = [...course.sections]
      ..sort((a, b) => b.files.length.compareTo(a.files.length));

    return Column(
      children: [
        _SectionOverview(
          sectionCount: course.sections.length,
          fileCount: course.fileCount,
          busiestSection: busiest.first,
          onCreateSection: onCreateSection,
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 980
                ? 3
                : constraints.maxWidth >= 640
                ? 2
                : 1;
            return GridView.builder(
              itemCount: course.sections.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 184,
              ),
              itemBuilder: (context, index) {
                final section = course.sections[index];
                return _SectionCard(
                  section: section,
                  index: index,
                  onTap: () => onOpenSection(section),
                  onOpenUploads: () => onUploadToSection(section),
                  onRename: () => onRenameSection(section),
                  onDelete: () => onDeleteSection(section),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _FilesTab extends StatelessWidget {
  const _FilesTab({
    required this.files,
    required this.totalFileCount,
    required this.query,
    required this.sort,
    required this.kind,
    required this.onQueryChanged,
    required this.onSortChanged,
    required this.onKindChanged,
    required this.onOpenFile,
    required this.onOpenUploads,
  });

  final List<DriveFile> files;
  final int totalFileCount;
  final String query;
  final _FileSort sort;
  final DriveFileKind? kind;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<_FileSort> onSortChanged;
  final ValueChanged<DriveFileKind?> onKindChanged;
  final ValueChanged<DriveFile> onOpenFile;
  final VoidCallback onOpenUploads;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FileToolbar(
          totalFileCount: totalFileCount,
          visibleFileCount: files.length,
          query: query,
          sort: sort,
          kind: kind,
          onQueryChanged: onQueryChanged,
          onSortChanged: onSortChanged,
          onKindChanged: onKindChanged,
          onUpload: onOpenUploads,
        ),
        const SizedBox(height: 12),
        if (totalFileCount == 0)
          GlassPanel(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                const EmptyState(
                  icon: Icons.description_outlined,
                  message: 'Bu derste henüz dosya yok.',
                  subMessage: 'PDF, DOCX veya PPT yükleyerek başlayın.',
                ),
                SBPrimaryButton(
                  label: 'Dosya Yükle',
                  icon: Icons.cloud_upload_outlined,
                  onPressed: onOpenUploads,
                  size: SBButtonSize.small,
                  fullWidth: false,
                ),
              ],
            ),
          )
        else if (files.isEmpty)
          const GlassPanel(
            padding: EdgeInsets.all(18),
            child: EmptyState(
              icon: Icons.search_off_rounded,
              message: 'Eşleşen dosya bulunamadı.',
              subMessage:
                  'Arama metnini veya dosya türü filtresini değiştirin.',
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final useGrid = constraints.maxWidth >= 760;
              if (!useGrid) {
                return GlassPanel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final file in files)
                        _FileListTile(
                          file: file,
                          onTap: () => onOpenFile(file),
                        ),
                    ],
                  ),
                );
              }
              return GridView.builder(
                itemCount: files.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: constraints.maxWidth >= 1080 ? 3 : 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 154,
                ),
                itemBuilder: (context, index) {
                  final file = files[index];
                  return _FileGridCard(
                    file: file,
                    onTap: () => onOpenFile(file),
                  );
                },
              );
            },
          ),
      ],
    );
  }
}

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({required this.course});

  final DriveCourse course;

  @override
  Widget build(BuildContext context) {
    final files = [for (final section in course.sections) ...section.files];
    final activeSections = course.sections
        .where((section) => section.status == DriveItemStatus.completed)
        .length;
    final generatedCount = files.fold<int>(
      0,
      (total, file) => total + file.generated.length,
    );
    final typeCounts = {
      for (final kind in DriveFileKind.values)
        kind: files.where((file) => file.kind == kind).length,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 780;
        final summary = GlassPanel(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PanelTitle(
                icon: Icons.analytics_outlined,
                title: 'Ders Özeti',
              ),
              const SizedBox(height: 14),
              _DetailRow(label: 'Ders adı', value: course.title),
              _DetailRow(label: 'Durum', value: _statusLabel(course.status)),
              _DetailRow(
                label: 'Bölüm sayısı',
                value: '${course.sections.length}',
              ),
              _DetailRow(label: 'Aktif bölüm', value: '$activeSections'),
              _DetailRow(label: 'Dosya sayısı', value: '${course.fileCount}'),
              _DetailRow(label: 'Üretilen çıktı', value: '$generatedCount'),
              _DetailRow(label: 'Son güncelleme', value: course.updatedLabel),
            ],
          ),
        );

        final description = GlassPanel(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PanelTitle(icon: Icons.subject_rounded, title: 'Açıklama'),
              const SizedBox(height: 12),
              Text(
                course.description,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 16,
                  height: 1.42,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              const _PanelTitle(
                icon: Icons.pie_chart_outline_rounded,
                title: 'Dosya Dağılımı',
              ),
              const SizedBox(height: 12),
              if (files.isEmpty)
                const Text(
                  'Henüz dağılım gösterecek dosya yok.',
                  style: TextStyle(color: AppColors.muted),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in typeCounts.entries)
                      if (entry.value > 0)
                        _KindCountChip(kind: entry.key, count: entry.value),
                  ],
                ),
            ],
          ),
        );

        if (!wide) {
          return Column(
            children: [summary, const SizedBox(height: 12), description],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: summary),
            const SizedBox(width: 12),
            Expanded(child: description),
          ],
        );
      },
    );
  }
}

class _SectionOverview extends StatelessWidget {
  const _SectionOverview({
    required this.sectionCount,
    required this.fileCount,
    required this.busiestSection,
    required this.onCreateSection,
  });

  final int sectionCount;
  final int fileCount;
  final DriveSection busiestSection;
  final VoidCallback onCreateSection;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final stats = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricPill(
                icon: Icons.account_tree_outlined,
                label: '$sectionCount bölüm',
              ),
              _MetricPill(
                icon: Icons.description_outlined,
                label: '$fileCount dosya',
              ),
              _MetricPill(
                icon: Icons.folder_special_outlined,
                label:
                    '${busiestSection.title}: ${busiestSection.files.length}',
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _PanelTitle(
                  icon: Icons.view_module_outlined,
                  title: 'Bölüm Panosu',
                ),
                const SizedBox(height: 12),
                stats,
                const SizedBox(height: 12),
                SBSecondaryButton(
                  label: 'Bölüm Ekle',
                  icon: Icons.create_new_folder_outlined,
                  onPressed: onCreateSection,
                  size: SBButtonSize.small,
                  fullWidth: true,
                ),
              ],
            );
          }

          return Row(
            children: [
              const _PanelTitle(
                icon: Icons.view_module_outlined,
                title: 'Bölüm Panosu',
              ),
              const SizedBox(width: 16),
              Expanded(child: stats),
              SizedBox(
                width: 148,
                child: SBSecondaryButton(
                  label: 'Bölüm Ekle',
                  icon: Icons.create_new_folder_outlined,
                  onPressed: onCreateSection,
                  size: SBButtonSize.small,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FileToolbar extends StatefulWidget {
  const _FileToolbar({
    required this.totalFileCount,
    required this.visibleFileCount,
    required this.query,
    required this.sort,
    required this.kind,
    required this.onQueryChanged,
    required this.onSortChanged,
    required this.onKindChanged,
    required this.onUpload,
  });

  final int totalFileCount;
  final int visibleFileCount;
  final String query;
  final _FileSort sort;
  final DriveFileKind? kind;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<_FileSort> onSortChanged;
  final ValueChanged<DriveFileKind?> onKindChanged;
  final VoidCallback onUpload;

  @override
  State<_FileToolbar> createState() => _FileToolbarState();
}

class _FileToolbarState extends State<_FileToolbar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant _FileToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.query,
        selection: TextSelection.collapsed(offset: widget.query.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final search = TextField(
            controller: _controller,
            onChanged: widget.onQueryChanged,
            decoration: InputDecoration(
              hintText: 'Dosya veya bölüm ara',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              filled: true,
              fillColor: AppColors.selectedBlue,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          );
          final controls = Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _SortMenu(sort: widget.sort, onChanged: widget.onSortChanged),
              _KindFilter(kind: widget.kind, onChanged: widget.onKindChanged),
              SizedBox(
                width: 132,
                child: SBPrimaryButton(
                  label: 'Yükle',
                  icon: Icons.cloud_upload_outlined,
                  onPressed: widget.onUpload,
                  size: SBButtonSize.small,
                ),
              ),
            ],
          );

          final countText = Text(
            '${widget.visibleFileCount} / ${widget.totalFileCount} dosya',
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _PanelTitle(
                  icon: Icons.tune_rounded,
                  title: 'Dosya Merkezi',
                ),
                const SizedBox(height: 10),
                search,
                const SizedBox(height: 10),
                countText,
                const SizedBox(height: 10),
                controls,
              ],
            );
          }

          return Column(
            children: [
              Row(
                children: [
                  const _PanelTitle(
                    icon: Icons.tune_rounded,
                    title: 'Dosya Merkezi',
                  ),
                  const SizedBox(width: 14),
                  countText,
                  const Spacer(),
                  controls,
                ],
              ),
              const SizedBox(height: 12),
              search,
            ],
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.index,
    required this.onTap,
    required this.onOpenUploads,
    required this.onRename,
    required this.onDelete,
  });

  final DriveSection section;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onOpenUploads;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.selectedBlue,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: AppColors.blue,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      section.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _SectionMenu(
                    onOpen: onTap,
                    onUpload: onOpenUploads,
                    onRename: onRename,
                    onDelete: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _SectionStatus(status: section.status),
                  const SizedBox(width: 8),
                  _MetricPill(
                    icon: Icons.description_outlined,
                    label: '${section.files.length} dosya',
                    compact: true,
                  ),
                ],
              ),
              const Spacer(),
              if (section.files.isEmpty)
                const Text(
                  'Henüz dosya yok',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final file in section.files.take(3))
                      _TinyFileChip(file: file),
                    if (section.files.length > 3)
                      _MoreChip(count: section.files.length - 3),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionMenu extends StatelessWidget {
  const _SectionMenu({
    required this.onOpen,
    required this.onUpload,
    required this.onRename,
    required this.onDelete,
  });

  final VoidCallback onOpen;
  final VoidCallback onUpload;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SectionMenuAction>(
      tooltip: 'Bölüm işlemleri',
      icon: const Icon(Icons.more_vert_rounded, color: AppColors.muted),
      onSelected: (action) {
        switch (action) {
          case _SectionMenuAction.open:
            onOpen();
          case _SectionMenuAction.upload:
            onUpload();
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
    );
  }
}

class _FileListTile extends StatelessWidget {
  const _FileListTile({required this.file, required this.onTap});

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
            const SizedBox(width: 12),
            Expanded(child: _FileText(file: file)),
            const SizedBox(width: 8),
            StatusPill(status: file.status, compact: true),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _FileGridCard extends StatelessWidget {
  const _FileGridCard({required this.file, required this.onTap});

  final DriveFile file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  FileKindBadge(kind: file.kind, plain: true),
                  const Spacer(),
                  StatusPill(status: file.status, compact: true),
                ],
              ),
              const SizedBox(height: 12),
              _FileText(file: file),
              const Spacer(),
              Row(
                children: [
                  const Icon(
                    Icons.open_in_new_rounded,
                    size: 18,
                    color: AppColors.blue,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Aç',
                    style: TextStyle(
                      color: AppColors.blue,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    file.pageLabel,
                    style: const TextStyle(
                      color: AppColors.softText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileText extends StatelessWidget {
  const _FileText({required this.file});

  final DriveFile file;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          file.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(file.sectionTitle, style: _metaStyle),
            const MetaDot(),
            Text(file.sizeLabel, style: _metaStyle),
            const MetaDot(),
            Text(file.updatedLabel, style: _metaStyle),
          ],
        ),
      ],
    );
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.sort, required this.onChanged});

  final _FileSort sort;
  final ValueChanged<_FileSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_FileSort>(
      tooltip: 'Sıralama',
      onSelected: onChanged,
      child: _ToolbarButton(
        icon: Icons.sort_rounded,
        label: switch (sort) {
          _FileSort.newest => 'Yeni',
          _FileSort.name => 'A-Z',
          _FileSort.section => 'Bölüm',
          _FileSort.kind => 'Tür',
        },
      ),
      itemBuilder: (context) => const [
        PopupMenuItem(value: _FileSort.newest, child: Text('En yeni')),
        PopupMenuItem(value: _FileSort.name, child: Text('Ada göre')),
        PopupMenuItem(value: _FileSort.section, child: Text('Bölüme göre')),
        PopupMenuItem(value: _FileSort.kind, child: Text('Türe göre')),
      ],
    );
  }
}

class _KindFilter extends StatelessWidget {
  const _KindFilter({required this.kind, required this.onChanged});

  final DriveFileKind? kind;
  final ValueChanged<DriveFileKind?> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<DriveFileKind?>(
      tooltip: 'Dosya türü',
      onSelected: onChanged,
      child: _ToolbarButton(
        icon: Icons.filter_alt_outlined,
        label: kind == null ? 'Tümü' : FileKindBadge.kindLabel(kind!),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(value: null, child: Text('Tüm türler')),
        for (final item in DriveFileKind.values)
          PopupMenuItem(
            value: item,
            child: Text(FileKindBadge.kindLabel(item)),
          ),
      ],
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.selectedBlue,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.softLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 19, color: AppColors.blue),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseAvatar extends StatelessWidget {
  const _CourseAvatar({required this.course, this.large = false});

  final DriveCourse course;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? 82.0 : 54.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: course.iconBackground,
        borderRadius: BorderRadius.circular(large ? 18 : 13),
      ),
      child: Icon(course.icon, color: course.iconColor, size: large ? 52 : 32),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.icon,
    required this.label,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 11,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.selectedBlue,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.softLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.blue, size: compact ? 15 : 17),
          SizedBox(width: compact ? 5 : 7),
          Text(
            label,
            style: TextStyle(
              color: AppColors.navy,
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: draft ? AppColors.selectedBlue : AppColors.greenBg,
        borderRadius: BorderRadius.circular(99),
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
          fontSize: 12,
          fontWeight: FontWeight.w900,
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
      constraints: const BoxConstraints(maxWidth: 146),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            FileKindBadge.kindLabel(file.kind),
            style: TextStyle(
              color: FileKindBadge.kindColor(file.kind),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              file.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreChip extends StatelessWidget {
  const _MoreChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.selectedBlue,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.softLine),
      ),
      child: Text(
        '+$count',
        style: const TextStyle(
          color: AppColors.blue,
          fontWeight: FontWeight.w900,
        ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 126,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KindCountChip extends StatelessWidget {
  const _KindCountChip({required this.kind, required this.count});

  final DriveFileKind kind;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = FileKindBadge.kindColor(kind);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .16)),
      ),
      child: Text(
        '${FileKindBadge.kindLabel(kind)}  $count',
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 21, color: AppColors.blue),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
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
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
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

const _metaStyle = TextStyle(
  color: AppColors.muted,
  fontSize: 13,
  fontWeight: FontWeight.w700,
);
