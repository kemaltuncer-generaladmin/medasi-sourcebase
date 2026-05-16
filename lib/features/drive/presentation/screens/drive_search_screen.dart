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
  final VoidCallback onOpenFile;

  @override
  Widget build(BuildContext context) {
    final resultCount = files.length;
    return WorkspaceScroll(
      children: [
        DriveTopBar(title: 'Dosya Arama', onSearch: () {}, onBack: onBack),
        Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: AppColors.blue, width: 1.4),
          ),
          child: const Row(
            children: [
              Icon(Icons.search_rounded, color: AppColors.navy, size: 30),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Dosya ara...',
                  style: TextStyle(color: AppColors.muted, fontSize: 24),
                ),
              ),
              CircleAvatar(
                radius: 14,
                backgroundColor: Color(0xFF9AA8C1),
                child: Icon(Icons.close_rounded, color: Colors.white, size: 20),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: const [
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
        Semantics(
          container: true,
          explicitChildNodes: true,
          label: 'Dosya arama sonuçları ve sıralama',
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$resultCount sonuç bulundu',
                  style: TextStyle(color: AppColors.muted, fontSize: 19),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.swap_vert_rounded),
                label: const Text('Sırala: En Yeni'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.navy,
                  backgroundColor: AppColors.selectedBlue,
                  side: const BorderSide(color: AppColors.softLine),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        GlassPanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: const [
              _FilterRow(
                icon: Icons.filter_alt_outlined,
                title: 'Filtreler',
                value: 'Filtreleri Temizle',
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
          _SearchResult(file: file, onTap: onOpenFile),
          const SizedBox(height: 12),
        ],
        GlassPanel(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: const [
              CircleAvatar(
                radius: 25,
                backgroundColor: AppColors.selectedBlue,
                child: Icon(
                  Icons.search_rounded,
                  color: AppColors.blue,
                  size: 28,
                ),
              ),
              SizedBox(width: 14),
              Expanded(
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
              Text(
                'Tüm filtreleri temizle',
                style: TextStyle(
                  color: AppColors.blue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.softLine)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.navy, size: 25),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.navy,
                fontSize: headline ? 19 : 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
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
            const SizedBox(width: 12),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.navy,
            ),
          ],
        ],
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
                  Wrap(
                    children: [
                      Text(
                        file.title,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (highlighted)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.selectedBlue,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.blue.withValues(alpha: .2),
                            ),
                          ),
                          child: const Text(
                            'Son açıldı',
                            style: TextStyle(
                              color: AppColors.blue,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${file.courseTitle}  ›  ${file.sectionTitle}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${file.sizeLabel}  •  ${file.pageLabel}  •  ${file.updatedLabel}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            StatusPill(status: file.status, compact: true),
            const Icon(Icons.more_vert_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
