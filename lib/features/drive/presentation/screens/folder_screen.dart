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
    super.key,
  });

  final DriveCourse course;
  final DriveSection section;
  final VoidCallback onSearch;
  final VoidCallback onBack;
  final ValueChanged<DriveFile> onOpenFile;
  final VoidCallback onOpenUploads;
  final VoidCallback onOpenCollections;

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  final Set<String> _selectedIds = {};

  bool get _hasSelection => _selectedIds.isNotEmpty;

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
      if (_selectedIds.length == widget.section.files.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(widget.section.files.map((f) => f.id));
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedIds.clear());
  }

  void _showNotImplemented(String feature) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$feature bu sürümde henüz bağlanmadı. Dosya detayından devam edebilirsiniz.',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstFile = widget.section.files.isNotEmpty
        ? widget.section.files.first
        : null;
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
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${widget.course.title}  ›  Bölüm',
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
          onFilter: () => _showNotImplemented('Filtreleme'),
          onSort: () => _showNotImplemented('Sıralama'),
        ),
        const SizedBox(height: 18),
        _HeaderRow(),
        const SizedBox(height: 10),
        if (widget.section.files.isEmpty)
          const GlassPanel(
            child: EmptyState(
              message: 'Bu bölümde henüz dosya yok.',
              subMessage: 'Yeni dosyalar yükleyerek başlayabilirsiniz.',
            ),
          )
        else
          for (final file in widget.section.files) ...[
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
            onMove: () => _showNotImplemented('Taşıma'),
            onDelete: () => _showNotImplemented('Silme'),
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
                    firstFile == null
                        ? 'Özet üretmek için önce bu bölüme dosya yükleyin.'
                        : 'Dosya detayına gidip özet üretimini başlatın.',
                onTap: firstFile == null
                    ? widget.onOpenUploads
                    : () => widget.onOpenFile(firstFile),
              ),
              const SizedBox(height: 10),
              _SuggestionRow(
                icon: Icons.style_outlined,
                color: Color(0xFF21C56B),
                title: 'Yüklediğin PDF dosyalarından flashcard üret',
                subtitle: firstFile == null
                    ? 'Flashcard üretmek için önce PDF veya not yükleyin.'
                    : 'Dosya detayına gidip flashcard üretimini başlatın.',
                onTap: firstFile == null
                    ? widget.onOpenUploads
                    : () => widget.onOpenFile(firstFile),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.onFilter, required this.onSort});

  final VoidCallback onFilter;
  final VoidCallback onSort;

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
              active: true,
            ),
            const SizedBox(width: 16),
            _ToolbarItem(
              icon: Icons.grid_view_rounded,
              label: 'Grid',
              onTap: () => _showGridNotImplemented(context),
            ),
            const _Divider(),
            InkWell(
              onTap: onFilter,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.filter_alt_outlined, color: AppColors.navy, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'Filtrele',
                      style: TextStyle(
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
              onTap: onSort,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.swap_vert_rounded, color: AppColors.navy, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'Sırala',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.navy),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGridNotImplemented(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Grid görünümü bu sürümde liste olarak sunuluyor. Dosyaları aşağıdan açabilirsiniz.',
        ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
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
    required this.onMove,
    required this.onDelete,
    required this.onClear,
  });

  final int selectedCount;
  final VoidCallback onOpenCollections;
  final VoidCallback onMove;
  final VoidCallback onDelete;
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
              icon: Icons.drive_file_move_outline,
              label: 'Taşı',
              color: AppColors.navy,
              onTap: onMove,
            ),
            _TrayAction(
              icon: Icons.delete_outline_rounded,
              label: 'Sil',
              color: AppColors.red,
              onTap: onDelete,
            ),
            _TrayAction(
              icon: Icons.layers_outlined,
              label: 'Koleksiyona Ekle',
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
