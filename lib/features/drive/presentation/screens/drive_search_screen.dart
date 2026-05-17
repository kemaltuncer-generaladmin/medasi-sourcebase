import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/drive_models.dart';
import '../widgets/drive_ui.dart';

enum _SearchSort { newest, name, course }

class DriveSearchScreen extends StatefulWidget {
  const DriveSearchScreen({
    required this.files,
    required this.onBack,
    required this.onOpenFile,
    super.key,
  });

  final List<DriveFile> files;
  final VoidCallback onBack;
  final ValueChanged<DriveFile> onOpenFile;

  @override
  State<DriveSearchScreen> createState() => _DriveSearchScreenState();
}

class _DriveSearchScreenState extends State<DriveSearchScreen> {
  final TextEditingController _queryController = TextEditingController();
  String _query = '';
  DriveFileKind? _kind;
  DriveItemStatus? _status;
  String? _course;
  String? _section;
  bool _featuredOnly = false;
  _SearchSort _sort = _SearchSort.newest;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  List<DriveFile> get _results {
    final query = _query.trim().toLowerCase();
    final results = widget.files.where((file) {
      final matchesQuery =
          query.isEmpty ||
          file.title.toLowerCase().contains(query) ||
          file.courseTitle.toLowerCase().contains(query) ||
          file.sectionTitle.toLowerCase().contains(query) ||
          (file.tag ?? '').toLowerCase().contains(query);
      return matchesQuery &&
          (_kind == null || file.kind == _kind) &&
          (_status == null || file.status == _status) &&
          (_course == null || file.courseTitle == _course) &&
          (_section == null || file.sectionTitle == _section) &&
          (!_featuredOnly || file.featured || file.selected);
    }).toList();

    switch (_sort) {
      case _SearchSort.newest:
        return results;
      case _SearchSort.name:
        results.sort((a, b) => a.title.compareTo(b.title));
        return results;
      case _SearchSort.course:
        results.sort(
          (a, b) => '${a.courseTitle}${a.sectionTitle}${a.title}'.compareTo(
            '${b.courseTitle}${b.sectionTitle}${b.title}',
          ),
        );
        return results;
    }
  }

  List<String> get _courses =>
      {for (final file in widget.files) file.courseTitle}.toList()..sort();

  List<String> get _sections => {
    for (final file in widget.files)
      if (_course == null || file.courseTitle == _course) file.sectionTitle,
  }.toList()..sort();

  bool get _hasFilters =>
      _query.isNotEmpty ||
      _kind != null ||
      _status != null ||
      _course != null ||
      _section != null ||
      _featuredOnly ||
      _sort != _SearchSort.newest;

  void _clearFilters() {
    setState(() {
      _queryController.clear();
      _query = '';
      _kind = null;
      _status = null;
      _course = null;
      _section = null;
      _featuredOnly = false;
      _sort = _SearchSort.newest;
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return WorkspaceScroll(
      children: [
        DriveTopBar(
          title: 'Dosya Arama',
          onSearch: () {},
          onBack: widget.onBack,
        ),
        _SearchInput(
          controller: _queryController,
          onChanged: (value) => setState(() => _query = value),
          onClear: _query.isEmpty
              ? null
              : () {
                  _queryController.clear();
                  setState(() => _query = '');
                },
        ),
        const SizedBox(height: 18),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _KindChip(
                icon: Icons.picture_as_pdf_rounded,
                label: 'PDF',
                color: const Color(0xFFFF3131),
                selected: _kind == DriveFileKind.pdf,
                onTap: () => setState(
                  () => _kind = _kind == DriveFileKind.pdf
                      ? null
                      : DriveFileKind.pdf,
                ),
              ),
              _KindChip(
                icon: Icons.slideshow_outlined,
                label: 'PPT',
                color: AppColors.orange,
                selected: _kind == DriveFileKind.pptx,
                onTap: () => setState(
                  () => _kind = _kind == DriveFileKind.pptx
                      ? null
                      : DriveFileKind.pptx,
                ),
              ),
              _KindChip(
                icon: Icons.description_outlined,
                label: 'DOC',
                color: AppColors.blue,
                selected:
                    _kind == DriveFileKind.docx || _kind == DriveFileKind.doc,
                onTap: () => setState(
                  () => _kind =
                      (_kind == DriveFileKind.docx ||
                          _kind == DriveFileKind.doc)
                      ? null
                      : DriveFileKind.docx,
                ),
              ),
              _StatusChip(
                icon: Icons.sync_rounded,
                label: 'İşleniyor',
                color: AppColors.blue,
                status: DriveItemStatus.processing,
                selectedStatus: _status,
                onChanged: (status) => setState(() => _status = status),
              ),
              _StatusChip(
                icon: Icons.check_circle_rounded,
                label: 'Tamamlandı',
                color: AppColors.green,
                status: DriveItemStatus.completed,
                selectedStatus: _status,
                onChanged: (status) => setState(() => _status = status),
              ),
              _KindChip(
                icon: Icons.favorite_border_rounded,
                label: 'Favoriler',
                color: AppColors.red,
                selected: _featuredOnly,
                onTap: () => setState(() => _featuredOnly = !_featuredOnly),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _ResultHeader(
          resultCount: results.length,
          sort: _sort,
          onSortChanged: (sort) => setState(() => _sort = sort),
        ),
        const SizedBox(height: 18),
        GlassPanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _FilterRow(
                icon: Icons.filter_alt_outlined,
                title: 'Filtreler',
                value: _hasFilters ? 'Temizle' : 'Aktif filtre yok',
                headline: true,
                onTap: _hasFilters ? _clearFilters : null,
              ),
              _OptionFilterRow(
                icon: Icons.menu_book_outlined,
                title: 'Ders',
                value: _course ?? 'Tümü',
                options: _courses,
                onSelected: (value) => setState(() {
                  _course = value;
                  if (_section != null && !_sections.contains(_section)) {
                    _section = null;
                  }
                }),
              ),
              _OptionFilterRow(
                icon: Icons.list_alt_outlined,
                title: 'Bölüm',
                value: _section ?? 'Tümü',
                options: _sections,
                onSelected: (value) => setState(() => _section = value),
              ),
              _FilterRow(
                icon: Icons.insert_drive_file_outlined,
                title: 'Dosya Türü',
                value: _kindLabel(_kind),
                onTap: () => _pickKind(context),
              ),
              _FilterRow(
                icon: Icons.sync_rounded,
                title: 'Durum',
                value: _statusLabel(_status),
                onTap: () => _pickStatus(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (results.isEmpty)
          const GlassPanel(
            padding: EdgeInsets.all(22),
            child: EmptyState(
              message: 'Sonuç bulunamadı.',
              subMessage: 'Arama metnini veya filtreleri değiştirin.',
            ),
          )
        else
          for (final file in results) ...[
            _SearchResult(file: file, onTap: () => widget.onOpenFile(file)),
            const SizedBox(height: 12),
          ],
        _ClearFiltersPanel(onClear: _clearFilters, enabled: _hasFilters),
      ],
    );
  }

  Future<void> _pickKind(BuildContext context) async {
    final value = await showModalBottomSheet<DriveFileKind?>(
      context: context,
      builder: (context) => _ChoiceSheet<DriveFileKind?>(
        title: 'Dosya Türü',
        value: _kind,
        options: const [
          _Choice(null, 'Tümü'),
          _Choice(DriveFileKind.pdf, 'PDF'),
          _Choice(DriveFileKind.pptx, 'PPT'),
          _Choice(DriveFileKind.docx, 'DOCX'),
          _Choice(DriveFileKind.doc, 'DOC'),
          _Choice(DriveFileKind.zip, 'ZIP'),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _kind = value);
  }

  Future<void> _pickStatus(BuildContext context) async {
    final value = await showModalBottomSheet<DriveItemStatus?>(
      context: context,
      builder: (context) => _ChoiceSheet<DriveItemStatus?>(
        title: 'Durum',
        value: _status,
        options: const [
          _Choice(null, 'Tümü'),
          _Choice(DriveItemStatus.completed, 'Tamamlandı'),
          _Choice(DriveItemStatus.processing, 'İşleniyor'),
          _Choice(DriveItemStatus.uploading, 'Yükleniyor'),
          _Choice(DriveItemStatus.failed, 'Hata'),
          _Choice(DriveItemStatus.draft, 'Taslak'),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _status = value);
  }
}

class _SearchInput extends StatelessWidget {
  const _SearchInput({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Dosya, ders veya bölüm ara...',
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.navy),
        suffixIcon: onClear == null
            ? null
            : IconButton(
                tooltip: 'Aramayı temizle',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: AppColors.blue, width: 1.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: AppColors.blue, width: 2),
        ),
      ),
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({
    required this.resultCount,
    required this.sort,
    required this.onSortChanged,
  });

  final int resultCount;
  final _SearchSort sort;
  final ValueChanged<_SearchSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final resultLabel = Text(
      '$resultCount sonuç bulundu',
      style: const TextStyle(color: AppColors.muted, fontSize: 19),
    );
    final sortButton = PopupMenuButton<_SearchSort>(
      initialValue: sort,
      onSelected: onSortChanged,
      itemBuilder: (context) => const [
        PopupMenuItem(value: _SearchSort.newest, child: Text('En Yeni')),
        PopupMenuItem(value: _SearchSort.name, child: Text('Ada göre')),
        PopupMenuItem(value: _SearchSort.course, child: Text('Derse göre')),
      ],
      child: OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.swap_vert_rounded),
        label: Text(_sortLabel(sort)),
        style: OutlinedButton.styleFrom(
          disabledForegroundColor: AppColors.navy,
          backgroundColor: AppColors.selectedBlue,
          side: const BorderSide(color: AppColors.softLine),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 390) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              resultLabel,
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerLeft, child: sortButton),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: resultLabel),
            sortButton,
          ],
        );
      },
    );
  }
}

class _ClearFiltersPanel extends StatelessWidget {
  const _ClearFiltersPanel({required this.onClear, required this.enabled});

  final VoidCallback onClear;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 25,
            backgroundColor: AppColors.selectedBlue,
            child: Icon(Icons.search_rounded, color: AppColors.blue, size: 28),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text.rich(
              TextSpan(
                text: 'Aradığını bulamadın mı?\n',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
                children: [
                  TextSpan(
                    text:
                        'Daha geniş sonuçlar için filtreleri kaldırmayı deneyebilirsin.',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: enabled ? onClear : null,
            child: const Text('Temizle'),
          ),
        ],
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 9),
      child: FilterChip(
        selected: selected,
        onSelected: (_) => onTap(),
        avatar: Icon(icon, color: selected ? Colors.white : color, size: 19),
        label: Text(label),
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.navy,
          fontWeight: FontWeight.w700,
        ),
        selectedColor: color,
        backgroundColor: Colors.white,
        checkmarkColor: Colors.white,
        side: BorderSide(color: color.withValues(alpha: .22)),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.status,
    required this.selectedStatus,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final Color color;
  final DriveItemStatus status;
  final DriveItemStatus? selectedStatus;
  final ValueChanged<DriveItemStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    return _KindChip(
      icon: icon,
      label: label,
      color: color,
      selected: selectedStatus == status,
      onTap: () => onChanged(selectedStatus == status ? null : status),
    );
  }
}

class _OptionFilterRow extends StatelessWidget {
  const _OptionFilterRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final IconData icon;
  final String title;
  final String value;
  final List<String> options;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return _FilterRow(
      icon: icon,
      title: title,
      value: value,
      onTap: () async {
        final selected = await showModalBottomSheet<String?>(
          context: context,
          builder: (context) => _ChoiceSheet<String?>(
            title: title,
            value: value == 'Tümü' ? null : value,
            options: [
              const _Choice(null, 'Tümü'),
              for (final option in options) _Choice(option, option),
            ],
          ),
        );
        onSelected(selected);
      },
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.icon,
    required this.title,
    required this.value,
    this.headline = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool headline;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.softLine)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.navy, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: headline ? 18 : 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: headline ? AppColors.blue : AppColors.muted,
                  fontSize: 16,
                  fontWeight: headline ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (!headline) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.navy,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SearchResult extends StatelessWidget {
  const _SearchResult({required this.file, required this.onTap});

  final DriveFile file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlighted = file.featured;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: GlassPanel(
        padding: const EdgeInsets.all(14),
        borderColor: highlighted ? AppColors.blue : null,
        child: Row(
          children: [
            FileKindBadge(kind: file.kind, plain: true, large: true),
            const SizedBox(width: 16),
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
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (highlighted) ...[
                    const SizedBox(height: 6),
                    const _RecentBadge(),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    '${file.courseTitle}  >  ${file.sectionTitle}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${file.sizeLabel}  •  ${file.pageLabel}  •  ${file.updatedLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            StatusPill(status: file.status, compact: true),
          ],
        ),
      ),
    );
  }
}

class _RecentBadge extends StatelessWidget {
  const _RecentBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.selectedBlue,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.blue.withValues(alpha: .2)),
      ),
      child: const Text(
        'Son açıldı',
        style: TextStyle(color: AppColors.blue, fontSize: 12),
      ),
    );
  }
}

class _Choice<T> {
  const _Choice(this.value, this.label);

  final T value;
  final String label;
}

class _ChoiceSheet<T> extends StatelessWidget {
  const _ChoiceSheet({
    required this.title,
    required this.value,
    required this.options,
  });

  final String title;
  final T value;
  final List<_Choice<T>> options;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
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
                  onPressed: () => Navigator.of(context).pop(value),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          for (final option in options)
            ListTile(
              onTap: () => Navigator.of(context).pop(option.value),
              title: Text(option.label),
              trailing: option.value == value
                  ? const Icon(Icons.check_rounded, color: AppColors.blue)
                  : null,
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

String _kindLabel(DriveFileKind? kind) {
  return switch (kind) {
    null => 'Tümü',
    DriveFileKind.pdf => 'PDF',
    DriveFileKind.pptx => 'PPT',
    DriveFileKind.docx => 'DOCX',
    DriveFileKind.doc => 'DOC',
    DriveFileKind.zip => 'ZIP',
  };
}

String _statusLabel(DriveItemStatus? status) {
  return switch (status) {
    null => 'Tümü',
    DriveItemStatus.completed => 'Tamamlandı',
    DriveItemStatus.processing => 'İşleniyor',
    DriveItemStatus.uploading => 'Yükleniyor',
    DriveItemStatus.failed => 'Hata',
    DriveItemStatus.draft => 'Taslak',
  };
}

String _sortLabel(_SearchSort sort) {
  return switch (sort) {
    _SearchSort.newest => 'En Yeni',
    _SearchSort.name => 'Ada göre',
    _SearchSort.course => 'Derse göre',
  };
}
