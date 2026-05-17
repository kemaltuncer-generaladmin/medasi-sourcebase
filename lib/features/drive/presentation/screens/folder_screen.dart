import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/drive_models.dart';
import '../widgets/drive_ui.dart';

class FolderScreen extends StatefulWidget {
  const FolderScreen({
    required this.course,
    required this.section,
    required this.onSearch,
    required this.onBack,
    required this.onOpenFile,
    required this.onOpenUploads,
    required this.onOpenCollections,
    required this.onGenerateFromFile,
    super.key,
  });

  final DriveCourse course;
  final DriveSection section;
  final VoidCallback onSearch;
  final VoidCallback onBack;
  final ValueChanged<DriveFile> onOpenFile;
  final VoidCallback onOpenUploads;
  final VoidCallback onOpenCollections;
  final void Function(DriveFile file, GeneratedKind kind) onGenerateFromFile;

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  final Set<String> _selectedIds = {};
  DriveFileKind? _kindFilter;
  _FolderSort _sort = _FolderSort.newest;
  bool _gridView = false;

  bool get _hasSelection => _selectedIds.isNotEmpty;

  List<DriveFile> get _visibleFiles {
    final files = [
      for (final file in widget.section.files)
        if (_kindFilter == null || file.kind == _kindFilter) file,
    ];
    switch (_sort) {
      case _FolderSort.newest:
        return files;
      case _FolderSort.name:
        return files
          ..sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          );
      case _FolderSort.kind:
        return files..sort((a, b) => a.kind.name.compareTo(b.kind.name));
      case _FolderSort.size:
        return files..sort((a, b) => a.sizeLabel.compareTo(b.sizeLabel));
    }
  }

  void _toggleSelect(DriveFile file) {
    setState(() {
      if (_selectedIds.contains(file.id)) {
        _selectedIds.remove(file.id);
      } else {
        _selectedIds.add(file.id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      final visibleFiles = _visibleFiles;
      if (_selectedIds.length == visibleFiles.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(visibleFiles.map((f) => f.id));
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedIds.clear());
  }

  DriveFile? _fileForGeneration(DriveFileKind? preferredKind) {
    final selectedFiles = widget.section.files
        .where((file) => _selectedIds.contains(file.id))
        .toList();
    final candidates = selectedFiles.isNotEmpty
        ? selectedFiles
        : widget.section.files;
    if (candidates.isEmpty) return null;
    if (preferredKind != null) {
      return candidates.where((file) => file.kind == preferredKind).firstOrNull
          ?? candidates.first;
    }
    return candidates.first;
  }

  void _generate(GeneratedKind kind, {DriveFileKind? preferredKind}) {
    final file = _fileForGeneration(preferredKind);
    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Üretim için önce bu bölüme dosya yükleyin.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    widget.onGenerateFromFile(file, kind);
  }

  @override
  Widget build(BuildContext context) {
    final visibleFiles = _visibleFiles;
    return WorkspaceScroll(
      children: [
        DriveTopBar(title: 'Drive', onSearch: widget.onSearch),
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.line),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: widget.onBack,
                icon: const Icon(Icons.chevron_left_rounded, size: 30),
                color: AppColors.navy,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.section.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${widget.course.title}  ›  Bölüm',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Spacer(),
            SizedBox(
              width: 150,
              child: SBPrimaryButton(
                label: 'Dosya Yükle',
                icon: Icons.add_rounded,
                onPressed: widget.onOpenUploads,
                size: SBButtonSize.medium,
                fullWidth: false,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 95,
              child: SBSecondaryButton(
                label: _hasSelection ? 'Seçimi Kaldır' : 'Tümünü Seç',
                icon: _hasSelection
                    ? Icons.deselect_rounded
                    : Icons.select_all_rounded,
                onPressed: _selectAll,
                size: SBButtonSize.medium,
                fullWidth: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _Toolbar(
          gridView: _gridView,
          kindFilter: _kindFilter,
          sort: _sort,
          onToggleView: () => setState(() => _gridView = !_gridView),
          onFilterChanged: (kind) => setState(() {
            _kindFilter = kind;
            _selectedIds.removeWhere(
              (id) => !_visibleFiles.any((file) => file.id == id),
            );
          }),
          onSortChanged: (sort) => setState(() => _sort = sort),
        ),
        const SizedBox(height: 18),
        if (!_gridView) ...[
          _HeaderRow(),
          const SizedBox(height: 10),
        ],
        if (widget.section.files.isEmpty)
          const GlassPanel(
            child: EmptyState(
              message: 'Bu bölümde henüz dosya yok.',
              subMessage: 'Yeni dosyalar yükleyerek başlayabilirsiniz.',
            ),
          )
        else if (visibleFiles.isEmpty)
          const GlassPanel(
            child: EmptyState(
              icon: Icons.filter_alt_off_outlined,
              message: 'Bu filtrede dosya yok.',
              subMessage: 'Dosya türü filtresini temizleyerek tekrar deneyin.',
            ),
          )
        else if (_gridView)
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 720 ? 2 : 1;
              return GridView.builder(
                itemCount: visibleFiles.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 132,
                ),
                itemBuilder: (context, index) {
                  final file = visibleFiles[index];
                  return _FileGridTile(
                    file: file,
                    selected: _selectedIds.contains(file.id),
                    onTap: () => widget.onOpenFile(file),
                    onToggleSelect: () => _toggleSelect(file),
                  );
                },
              );
            },
          )
        else
          for (final file in visibleFiles) ...[
            _FileListRow(
              file: file,
              selected: _selectedIds.contains(file.id),
              onTap: () => widget.onOpenFile(file),
              onToggleSelect: () => _toggleSelect(file),
            ),
            const SizedBox(height: 12),
          ],
        if (_hasSelection)
          _SelectionTray(
            selectedCount: _selectedIds.length,
            onOpenCollections: widget.onOpenCollections,
            onClear: _clearSelection,
          ),
        SectionTitle(
          title: 'Akıllı Öneriler',
          actionLabel: null,
          onAction: null,
        ),
        GlassPanel(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _SuggestionRow(
                icon: Icons.description_outlined,
                color: AppColors.purple,
                title: 'Bu bölüm için sınav sabahı özeti üret',
                subtitle:
                    'Önemli noktaları çıkarıp hızlı bir özet hazırlayabilirsin.',
                onTap: () => _generate(GeneratedKind.summary),
              ),
              const SizedBox(height: 10),
              _SuggestionRow(
                icon: Icons.style_outlined,
                color: const Color(0xFF21C56B),
                title: 'Yüklediğin PDF dosyalarından flashcard üret',
                subtitle: 'Ders çalışma verimliliğini artırmak için uygundur.',
                onTap: () => _generate(
                  GeneratedKind.flashcard,
                  preferredKind: DriveFileKind.pdf,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _FolderSort { newest, name, kind, size }

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.gridView,
    required this.kindFilter,
    required this.sort,
    required this.onToggleView,
    required this.onFilterChanged,
    required this.onSortChanged,
  });

  final bool gridView;
  final DriveFileKind? kindFilter;
  final _FolderSort sort;
  final VoidCallback onToggleView;
  final ValueChanged<DriveFileKind?> onFilterChanged;
  final ValueChanged<_FolderSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 12,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _ToolbarItem(
              icon: Icons.format_list_bulleted_rounded,
              label: 'Liste',
              active: !gridView,
              onTap: gridView ? onToggleView : null,
            ),
            const SizedBox(width: 16),
            _ToolbarItem(
              icon: Icons.grid_view_rounded,
              label: 'Grid',
              active: gridView,
              onTap: gridView ? null : onToggleView,
            ),
            const _Divider(),
            InkWell(
              onTap: () => _pickKind(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.filter_alt_outlined,
                      color: AppColors.navy,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      kindFilter == null
                          ? 'Filtrele'
                          : FileKindBadge.kindLabel(kindFilter!),
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const _Divider(),
            InkWell(
              onTap: () => _pickSort(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.swap_vert_rounded,
                      color: AppColors.navy,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _sortLabel(sort),
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.navy,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickKind(BuildContext context) async {
    final selected = await showModalBottomSheet<DriveFileKind?>(
      context: context,
      builder: (context) => _FolderChoiceSheet<DriveFileKind?>(
        title: 'Dosya Türü',
        value: kindFilter,
        options: const [
          _FolderChoice(null, 'Tümü'),
          _FolderChoice(DriveFileKind.pdf, 'PDF'),
          _FolderChoice(DriveFileKind.pptx, 'PPTX'),
          _FolderChoice(DriveFileKind.docx, 'DOCX'),
          _FolderChoice(DriveFileKind.doc, 'DOC'),
          _FolderChoice(DriveFileKind.zip, 'ZIP'),
        ],
      ),
    );
    onFilterChanged(selected);
  }

  Future<void> _pickSort(BuildContext context) async {
    final selected = await showModalBottomSheet<_FolderSort>(
      context: context,
      builder: (context) => _FolderChoiceSheet<_FolderSort>(
        title: 'Sıralama',
        value: sort,
        options: const [
          _FolderChoice(_FolderSort.newest, 'En yeni'),
          _FolderChoice(_FolderSort.name, 'Ada göre'),
          _FolderChoice(_FolderSort.kind, 'Türe göre'),
          _FolderChoice(_FolderSort.size, 'Boyuta göre'),
        ],
      ),
    );
    if (selected != null) onSortChanged(selected);
  }

  String _sortLabel(_FolderSort sort) {
    return switch (sort) {
      _FolderSort.newest => 'En yeni',
      _FolderSort.name => 'Ada göre',
      _FolderSort.kind => 'Türe göre',
      _FolderSort.size => 'Boyuta göre',
    };
  }
}

class _ToolbarItem extends StatelessWidget {
  const _ToolbarItem({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      children: [
        Icon(icon, color: active ? AppColors.blue : AppColors.navy, size: 24),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: active ? AppColors.blue : AppColors.navy,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: child,
      ),
    );
  }
}

class _FolderChoice<T> {
  const _FolderChoice(this.value, this.label);

  final T value;
  final String label;
}

class _FolderChoiceSheet<T> extends StatelessWidget {
  const _FolderChoiceSheet({
    required this.title,
    required this.value,
    required this.options,
  });

  final String title;
  final T value;
  final List<_FolderChoice<T>> options;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Kapat',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          for (final option in options)
            RadioListTile<T>(
              value: option.value,
              groupValue: value,
              onChanged: (selected) => Navigator.of(context).pop(selected),
              title: Text(option.label),
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 25, color: AppColors.line);
  }
}

class _HeaderRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: DecoratedBox(decoration: BoxDecoration()),
          ),
          SizedBox(width: 44),
          Expanded(
            child: Text(
              'Ad  ◆',
              style: TextStyle(color: AppColors.navy, fontSize: 16),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text('Boyut', style: TextStyle(color: AppColors.muted)),
          ),
          SizedBox(
            width: 115,
            child: Text(
              'Son Değiştirme',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileListRow extends StatelessWidget {
  const _FileListRow({
    required this.file,
    required this.selected,
    required this.onTap,
    required this.onToggleSelect,
  });

  final DriveFile file;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onToggleSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 390;
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: GlassPanel(
            padding: EdgeInsets.fromLTRB(
              10,
              compact ? 12 : 14,
              8,
              compact ? 12 : 14,
            ),
            borderColor: selected ? const Color(0xFFB9D5FF) : null,
            child: Row(
              children: [
                InkWell(
                  onTap: onToggleSelect,
                  borderRadius: BorderRadius.circular(6),
                  child: _SelectBox(selected: selected, compact: compact),
                ),
                SizedBox(width: compact ? 8 : 14),
                FileKindBadge(kind: file.kind, compact: compact),
                SizedBox(width: compact ? 10 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.navy,
                          fontSize: compact ? 16 : 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: compact ? 6 : 10,
                        runSpacing: 5,
                        children: [
                          _MiniTag(
                            label: FileKindBadge.kindLabel(file.kind),
                            color: FileKindBadge.kindColor(file.kind),
                            compact: compact,
                          ),
                          Text(
                            file.pageLabel,
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: compact ? 13 : 15,
                            ),
                          ),
                          if (file.tag != null)
                            _MiniTag(
                              label: file.tag!,
                              color: AppColors.blue,
                              muted: true,
                              compact: compact,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: compact ? 52 : 70,
                  child: Text(
                    file.sizeLabel,
                    maxLines: 1,
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: compact ? 14 : 16,
                    ),
                  ),
                ),
                SizedBox(
                  width: compact ? 66 : 88,
                  child: Text(
                    file.updatedLabel,
                    maxLines: 2,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: compact ? 13 : 15,
                      height: 1.12,
                    ),
                  ),
                ),
                const Icon(
                  Icons.more_vert_rounded,
                  color: AppColors.muted,
                  size: 23,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FileGridTile extends StatelessWidget {
  const _FileGridTile({
    required this.file,
    required this.selected,
    required this.onTap,
    required this.onToggleSelect,
  });

  final DriveFile file;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onToggleSelect;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: GlassPanel(
        padding: const EdgeInsets.all(14),
        borderColor: selected ? const Color(0xFFB9D5FF) : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onToggleSelect,
              borderRadius: BorderRadius.circular(6),
              child: _SelectBox(selected: selected),
            ),
            const SizedBox(width: 12),
            FileKindBadge(kind: file.kind),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${file.sizeLabel}  •  ${file.pageLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  StatusPill(status: file.status, compact: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectBox extends StatelessWidget {
  const _SelectBox({required this.selected, this.compact = false});

  final bool selected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 22 : 24,
      height: compact ? 22 : 24,
      decoration: BoxDecoration(
        color: selected ? AppColors.blue : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: selected ? AppColors.blue : const Color(0xFFB7C3D8),
          width: 1.2,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
          : null,
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({
    required this.label,
    required this.color,
    this.muted = false,
    this.compact = false,
  });

  final String label;
  final Color color;
  final bool muted;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: compact
          ? const BoxConstraints(maxWidth: 72)
          : const BoxConstraints(),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: muted ? .10 : .08),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: .15)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: muted ? AppColors.muted : color,
          fontSize: compact ? 11.5 : 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SelectionTray extends StatelessWidget {
  const _SelectionTray({
    required this.selectedCount,
    required this.onOpenCollections,
    required this.onClear,
  });

  final int selectedCount;
  final VoidCallback onOpenCollections;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(22, 18, 18, 18),
      borderColor: const Color(0xFFB9D5FF),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 430;
          final summary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$selectedCount öğe seçildi',
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Seçili dosyalar üzerinde işlem yapabilirsiniz.',
                style: TextStyle(color: AppColors.muted, fontSize: 14),
              ),
            ],
          );
          final actions = [
            _TrayAction(
              icon: Icons.layers_outlined,
              label: 'Koleksiyonlar',
              color: AppColors.navy,
              onTap: onOpenCollections,
            ),
            _TrayAction(
              icon: Icons.close_rounded,
              label: 'Temizle',
              color: AppColors.muted,
              onTap: onClear,
            ),
          ];
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                summary,
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(children: actions),
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: summary),
              ...actions,
            ],
          );
        },
      ),
    );
  }
}

class _TrayAction extends StatelessWidget {
  const _TrayAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 70,
        child: Column(
          children: [
            Icon(icon, color: color, size: 27),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(color: color, fontSize: 12.5, height: 1.1),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.softLine),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text('Oluştur'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.blue,
              side: const BorderSide(color: AppColors.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
