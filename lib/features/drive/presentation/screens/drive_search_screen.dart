import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/drive_models.dart';
import '../widgets/drive_ui.dart';

class DriveSearchScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final resultCount = files.length;
    return WorkspaceScroll(
      children: [
        DriveTopBar(title: 'Dosya Arama', onSearch: () {}, onBack: onBack),
        const _SearchInput(),
        const SizedBox(height: 18),
        const SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: BouncingScrollPhysics(),
          child: Row(
            children: [
              _FilterChip(
                icon: Icons.picture_as_pdf_rounded,
                label: 'PDF',
                color: Color(0xFFFF3131),
              ),
              _FilterChip(
                icon: Icons.slideshow_outlined,
                label: 'PPT',
                color: AppColors.orange,
              ),
              _FilterChip(
                icon: Icons.description_outlined,
                label: 'DOCX',
                color: AppColors.blue,
              ),
              _FilterChip(
                icon: Icons.sync_rounded,
                label: 'İşleniyor',
                color: AppColors.blue,
              ),
              _FilterChip(
                icon: Icons.check_circle_rounded,
                label: 'Tamamlandı',
                color: AppColors.green,
              ),
              _FilterChip(
                icon: Icons.favorite_border_rounded,
                label: 'Favoriler',
                color: AppColors.red,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _ResultHeader(resultCount: resultCount),
        const SizedBox(height: 18),
        GlassPanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: const [
              _FilterRow(
                icon: Icons.filter_alt_outlined,
                title: 'Filtreler',
                value: 'Temizle',
                headline: true,
              ),
              _FilterRow(
                icon: Icons.menu_book_outlined,
                title: 'Ders',
                value: 'Tümü',
              ),
              _FilterRow(
                icon: Icons.list_alt_outlined,
                title: 'Bölüm',
                value: 'Tümü',
              ),
              _FilterRow(
                icon: Icons.insert_drive_file_outlined,
                title: 'Dosya Türü',
                value: 'Tümü',
              ),
              _FilterRow(
                icon: Icons.sync_rounded,
                title: 'Durum',
                value: 'Tümü',
              ),
              _FilterRow(
                icon: Icons.calendar_today_outlined,
                title: 'Tarih',
                value: 'Tümü',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        for (final file in files.take(3)) ...[
          _SearchResult(file: file, onTap: () => onOpenFile(file)),
          const SizedBox(height: 12),
        ],
        const _ClearFiltersPanel(),
      ],
    );
  }
}

class _SearchInput extends StatelessWidget {
  const _SearchInput();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 390;
        return Container(
          height: compact ? 52 : 58,
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: AppColors.blue, width: 1.4),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                color: AppColors.navy,
                size: compact ? 26 : 30,
              ),
              SizedBox(width: compact ? 10 : 14),
              Expanded(
                child: Text(
                  'Dosya ara...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: compact ? 18 : 24,
                  ),
                ),
              ),
              const CircleAvatar(
                radius: 14,
                backgroundColor: Color(0xFF9AA8C1),
                child: Icon(Icons.close_rounded, color: Colors.white, size: 20),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.resultCount});

  final int resultCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Dosya arama sonuçları ve sıralama',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 390;
          final resultLabel = Text(
            '$resultCount sonuç bulundu',
            style: const TextStyle(color: AppColors.muted, fontSize: 19),
          );
          final sortButton = OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.swap_vert_rounded),
            label: const Text(
              'En Yeni',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.navy,
              backgroundColor: AppColors.selectedBlue,
              side: const BorderSide(color: AppColors.softLine),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          if (compact) {
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
      ),
    );
  }
}

class _ClearFiltersPanel extends StatelessWidget {
  const _ClearFiltersPanel();

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 390;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 25,
                backgroundColor: AppColors.selectedBlue,
                child: Icon(
                  Icons.search_rounded,
                  color: AppColors.blue,
                  size: 28,
                ),
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
              if (!compact) const SizedBox(width: 12),
              if (!compact)
                const Text(
                  'Filtreleri temizle',
                  style: TextStyle(
                    color: AppColors.blue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 9),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.icon,
    required this.title,
    required this.value,
    this.headline = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool headline;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 390;
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 18,
            vertical: 16,
          ),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.softLine)),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.navy, size: compact ? 22 : 25),
              SizedBox(width: compact ? 12 : 16),
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
                    fontSize: compact ? 14 : 16,
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
        );
      },
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 390;
            return Row(
              children: [
                FileKindBadge(kind: file.kind, plain: true, large: !compact),
                SizedBox(width: compact ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.navy,
                          fontSize: compact ? 16 : 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (highlighted) ...[
                        const SizedBox(height: 6),
                        const _RecentBadge(),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        '${file.courseTitle}  ›  ${file.sectionTitle}',
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
                if (!compact) ...[
                  StatusPill(status: file.status, compact: true),
                  const Icon(Icons.more_vert_rounded, color: AppColors.muted),
                ],
              ],
            );
          },
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
