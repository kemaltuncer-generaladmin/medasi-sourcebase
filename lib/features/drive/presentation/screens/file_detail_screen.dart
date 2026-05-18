import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/drive_models.dart';
import '../widgets/drive_ui.dart';

class FileDetailScreen extends StatefulWidget {
  const FileDetailScreen({
    required this.file,
    required this.onSearch,
    required this.onBack,
    required this.onGenerate,
    required this.onOpenCollections,
    required this.onOpenBaseForce,
    required this.onOpenSourceLab,
    super.key,
  });

  final DriveFile file;
  final VoidCallback onSearch;
  final VoidCallback onBack;
  final ValueChanged<GeneratedKind> onGenerate;
  final VoidCallback onOpenCollections;
  final VoidCallback onOpenBaseForce;
  final VoidCallback onOpenSourceLab;

  @override
  State<FileDetailScreen> createState() => _FileDetailScreenState();
}

class _FileDetailScreenState extends State<FileDetailScreen> {
  int _previewIndex = 0;

  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    final generatedCount = file.generated.length;
    final hasGenerated = generatedCount > 0;
    final readyForGeneration = file.status == DriveItemStatus.completed;

    return WorkspaceScroll(
      children: [
        DriveTopBar(
          title: 'Dosya Detayı',
          onSearch: widget.onSearch,
          onBack: widget.onBack,
          showBrand: false,
        ),
        GlassPanel(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                children: [
                  FileKindBadge(kind: file.kind, large: true),
                  const SizedBox(width: 18),
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
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Icon(
                              Icons.file_copy_outlined,
                              color: AppColors.muted,
                              size: 18,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              file.sizeLabel,
                              style: const TextStyle(color: AppColors.muted),
                            ),
                            const MetaDot(),
                            const Icon(
                              Icons.article_outlined,
                              color: AppColors.muted,
                              size: 18,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              file.pageLabel,
                              style: const TextStyle(color: AppColors.muted),
                            ),
                            const MetaDot(),
                            const Icon(
                              Icons.calendar_today_outlined,
                              color: AppColors.muted,
                              size: 17,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              file.updatedLabel,
                              style: const TextStyle(color: AppColors.muted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  StatusPill(status: file.status, compact: true),
                ],
              ),
              const Divider(height: 28, color: AppColors.line),
              Row(
                children: [
                  const Icon(Icons.folder_outlined, color: AppColors.muted),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      file.courseTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.navy,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      file.sectionTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.blue,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SectionTitle(title: 'Dosya Özeti'),
        GlassPanel(
          padding: const EdgeInsets.all(18),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 18,
            crossAxisSpacing: 18,
            childAspectRatio: 2.5,
            children: [
              _SummaryMetric(
                icon: Icons.description_outlined,
                color: AppColors.blue,
                title: file.pageLabel,
                subtitle: 'Sayfa bilgisi',
              ),
              _SummaryMetric(
                icon: Icons.menu_book_outlined,
                color: AppColors.purple,
                title: generatedCount > 0 ? '$generatedCount' : '-',
                subtitle: 'Üretilen çıktı',
              ),
              _SummaryMetric(
                icon: Icons.table_chart_outlined,
                color: AppColors.green,
                title: FileKindBadge.kindLabel(file.kind),
                subtitle: 'Dosya türü',
              ),
              _SummaryMetric(
                icon: Icons.task_alt_rounded,
                color: AppColors.blue,
                title: _statusShortLabel(file.status),
                subtitle: 'Durum',
              ),
            ],
          ),
        ),
        const SectionTitle(title: 'Bu dosyadan üret'),
        if (readyForGeneration)
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.65,
            children: [
              _GenerateTile(
                kind: GeneratedKind.flashcard,
                title: 'Flashcard',
                subtitle: 'Anki uyumlu kartlar',
                onTap: widget.onGenerate,
              ),
              _GenerateTile(
                kind: GeneratedKind.question,
                title: 'Soru',
                subtitle: 'Çoktan seçmeli sorular',
                onTap: widget.onGenerate,
              ),
              _GenerateTile(
                kind: GeneratedKind.summary,
                title: 'Özet',
                subtitle: 'Kısa ve kapsamlı özet',
                onTap: widget.onGenerate,
              ),
              _GenerateTile(
                kind: GeneratedKind.algorithm,
                title: 'Algoritma',
                subtitle: 'Karar algoritmaları',
                onTap: widget.onGenerate,
              ),
              _GenerateTile(
                kind: GeneratedKind.comparison,
                title: 'Karşılaştırma',
                subtitle: 'Konuları karşılaştır',
                onTap: widget.onGenerate,
              ),
              _GenerateTile(
                kind: GeneratedKind.podcast,
                title: 'Podcast',
                subtitle: 'Sesli anlatım oluştur',
                onTap: widget.onGenerate,
              ),
            ],
          )
        else
          GlassPanel(
            padding: const EdgeInsets.all(18),
            child: EmptyState(
              icon: file.status == DriveItemStatus.failed
                  ? Icons.error_outline_rounded
                  : Icons.hourglass_top_rounded,
              message: file.status == DriveItemStatus.failed
                  ? 'Dosya işlenemedi.'
                  : 'Dosya üretime hazırlanıyor.',
              subMessage: file.status == DriveItemStatus.failed
                  ? 'Bu kaynaktan üretim almak için dosyayı yeniden yükleyin.'
                  : 'İşleme tamamlandığında flashcard, soru ve özet üretebilirsiniz.',
            ),
          ),
        const SectionTitle(title: 'Üretim merkezleri'),
        GlassPanel(
          padding: const EdgeInsets.all(14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final baseForce = _GenerationCenterAction(
                icon: Icons.layers_rounded,
                title: 'BaseForce',
                subtitle: 'Flashcard, soru, özet ve algoritma üret',
                onTap: widget.onOpenBaseForce,
              );
              final sourceLab = _GenerationCenterAction(
                icon: Icons.science_outlined,
                title: 'SourceLab',
                subtitle: 'Senaryo, plan, podcast ve zihin haritası hazırla',
                onTap: widget.onOpenSourceLab,
              );
              if (compact) {
                return Column(
                  children: [
                    baseForce,
                    const SizedBox(height: 10),
                    sourceLab,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: baseForce),
                  const SizedBox(width: 10),
                  Expanded(child: sourceLab),
                ],
              );
            },
          ),
        ),
        SectionTitle(
          title: 'Üretilenler',
          actionLabel: hasGenerated ? 'Tümünü Gör' : null,
          onAction: hasGenerated ? widget.onOpenCollections : null,
        ),
        GlassPanel(
          padding: EdgeInsets.zero,
          child: hasGenerated
              ? Column(
                  children: [
                    for (final output in file.generated)
                      _GeneratedRow(output: output),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.all(22),
                  child: EmptyState(
                    message: 'Henüz çıktı üretilmedi.',
                    subMessage: readyForGeneration
                        ? 'Yukarıdaki üretim merkezlerinden birini kullanarak bu dosyadan içerik oluşturabilirsin.'
                        : 'Dosya hazır olduğunda üretilen çıktılar burada listelenir.',
                    icon: Icons.auto_awesome_outlined,
                  ),
                ),
        ),
        if (file.pageLabel != 'İşleniyor') ...[
          const SectionTitle(title: 'Önizleme'),
          GlassPanel(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              height: 128,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: 5,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) => _PreviewPage(
                  index: index,
                  selected: index == _previewIndex,
                  onTap: () => setState(() => _previewIndex = index),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _statusShortLabel(DriveItemStatus status) {
    return switch (status) {
      DriveItemStatus.completed => 'Hazır',
      DriveItemStatus.processing => 'İşleniyor',
      DriveItemStatus.uploading => 'Yükleniyor',
      DriveItemStatus.failed => 'Hata',
      DriveItemStatus.draft => 'Taslak',
    };
  }
}

class _GenerationCenterAction extends StatelessWidget {
  const _GenerationCenterAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.selectedBlue,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.softLine),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.blue, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.navy),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
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
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GenerateTile extends StatelessWidget {
  const _GenerateTile({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final GeneratedKind kind;
  final String title;
  final String subtitle;
  final ValueChanged<GeneratedKind> onTap;

  @override
  Widget build(BuildContext context) {
    final color = generatedColor(kind);
    return InkWell(
      onTap: () => onTap(kind),
      borderRadius: BorderRadius.circular(12),
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        radius: 12,
        child: Row(
          children: [
            Icon(generatedIcon(kind), color: color, size: 21),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 12.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.navy,
              size: 17,
            ),
          ],
        ),
      ),
    );
  }
}

class _GeneratedRow extends StatelessWidget {
  const _GeneratedRow({required this.output});

  final GeneratedOutput output;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Icon(
            generatedIcon(output.kind),
            color: generatedColor(output.kind),
            size: 30,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  output.title,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  output.detail,
                  style: const TextStyle(color: AppColors.muted, fontSize: 14),
                ),
              ],
            ),
          ),
          const _UpdatedPill(),
          const SizedBox(width: 12),
          Text(
            output.updatedLabel,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.navy),
        ],
      ),
    );
  }
}

class _UpdatedPill extends StatelessWidget {
  const _UpdatedPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.greenBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.green.withValues(alpha: .14)),
      ),
      child: const Text(
        'Güncellendi',
        style: TextStyle(
          color: AppColors.green,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PreviewPage extends StatelessWidget {
  const _PreviewPage({
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 96,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.blue : AppColors.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: CustomPaint(
                painter: _PreviewPainter(index: index),
                child: const SizedBox.expand(),
              ),
            ),
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.blue : AppColors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: selected ? AppColors.blue : AppColors.line,
                ),
              ),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  const _PreviewPainter({required this.index});

  final int index;

  @override
  void paint(Canvas canvas, Size size) {
    final text = Paint()
      ..color = AppColors.navy.withValues(alpha: .75)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final red = Paint()
      ..color = const Color(0xFFFF6B6B)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 5; i++) {
      canvas.drawLine(
        Offset(8, 12 + i * 10),
        Offset(size.width - 10, 12 + i * 10),
        text,
      );
    }
    if (index == 0) {
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), 14, red);
      canvas.drawLine(
        Offset(12, size.height / 2),
        Offset(size.width - 12, size.height / 2),
        red,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter oldDelegate) =>
      oldDelegate.index != index;
}
