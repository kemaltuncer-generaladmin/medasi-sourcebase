import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/drive_models.dart';
import '../widgets/drive_ui.dart';

class FolderScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return WorkspaceScroll(
      children: [
        DriveTopBar(title: 'Drive', onSearch: onSearch),
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
                onPressed: onBack,
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
                    section.title,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${course.title}  ›  Bölüm',
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
                onPressed: onOpenUploads,
                size: SBButtonSize.medium,
                fullWidth: false,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 95,
              child: SBSecondaryButton(
                label: 'Seç',
                icon: Icons.select_all_rounded,
                onPressed: () {},
                size: SBButtonSize.medium,
                fullWidth: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _Toolbar(),
        const SizedBox(height: 18),
        _HeaderRow(),
        const SizedBox(height: 10),
        if (section.files.isEmpty)
          const GlassPanel(
            child: EmptyState(
              message: 'Bu bölümde henüz dosya yok.',
              subMessage: 'Yeni dosyalar yükleyerek başlayabilirsiniz.',
            ),
          )
        else
          for (final file in section.files) ...[
            _FileListRow(file: file, onTap: () => onOpenFile(file)),
            const SizedBox(height: 12),
          ],
        _SelectionTray(onOpenCollections: onOpenCollections),
        SectionTitle(
          title: 'Akıllı Öneriler',
          actionLabel: 'Tümünü Gör',
          onAction: () {},
        ),
        GlassPanel(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: const [
              _SuggestionRow(
                icon: Icons.description_outlined,
                color: AppColors.purple,
                title: 'Bu bölüm için sınav sabahı özeti üret',
                subtitle:
                    'Önemli noktaları çıkarıp hızlı bir özet hazırlayabilirsin.',
              ),
              SizedBox(height: 10),
              _SuggestionRow(
                icon: Icons.style_outlined,
                color: Color(0xFF21C56B),
                title: 'Yüklediğin PDF dosyalarından flashcard üret',
                subtitle: 'Ders çalışma verimliliğini artırmak için uygundur.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 12,
      child: const SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: BouncingScrollPhysics(),
        child: Row(
          children: [
            _ToolbarItem(
              icon: Icons.format_list_bulleted_rounded,
              label: 'Liste',
              active: true,
            ),
            SizedBox(width: 16),
            _ToolbarItem(icon: Icons.grid_view_rounded, label: 'Grid'),
            _Divider(),
            _ToolbarItem(icon: Icons.filter_alt_outlined, label: 'Filtrele'),
            _Divider(),
            _ToolbarItem(icon: Icons.swap_vert_rounded, label: 'Sırala'),
            Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.navy),
          ],
        ),
      ),
    );
  }
}

class _ToolbarItem extends StatelessWidget {
  const _ToolbarItem({
    required this.icon,
    required this.label,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
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
  const _FileListRow({required this.file, required this.onTap});

  final DriveFile file;
  final VoidCallback onTap;

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
            borderColor: file.selected ? const Color(0xFFB9D5FF) : null,
            child: Row(
              children: [
                _SelectBox(selected: file.selected, compact: compact),
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
  const _SelectionTray({required this.onOpenCollections});

  final VoidCallback onOpenCollections;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(22, 18, 18, 18),
      borderColor: const Color(0xFFB9D5FF),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 430;
          final summary = const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '- öğe seçildi',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Toplam - MB',
                style: TextStyle(color: AppColors.navy, fontSize: 16),
              ),
            ],
          );
          final actions = [
            _TrayAction(
              icon: Icons.drive_file_move_outline,
              label: 'Taşı',
              color: AppColors.navy,
              onTap: () {},
            ),
            _TrayAction(
              icon: Icons.delete_outline_rounded,
              label: 'Sil',
              color: AppColors.red,
              onTap: () {},
            ),
            _TrayAction(
              icon: Icons.layers_outlined,
              label: 'Koleksiyona Ekle',
              color: AppColors.navy,
              onTap: onOpenCollections,
            ),
            _TrayAction(
              icon: Icons.more_vert_rounded,
              label: 'Daha fazla',
              color: AppColors.navy,
              onTap: () {},
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
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

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
            onPressed: () {},
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
