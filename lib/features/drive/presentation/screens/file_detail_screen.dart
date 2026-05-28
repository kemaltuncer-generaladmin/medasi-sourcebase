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
  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    final generatedCount = file.generated.length;
    final hasGenerated = generatedCount > 0;
    final readyForGeneration = driveFileUsableForGeneration(file);
    final readinessMessage = _readinessMessage(file);

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 430;
              final fileTitle = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.title,
                    maxLines: compact ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: compact ? 21 : 24,
                      fontWeight: FontWeight.w900,
                      height: 1.12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _FileMetaChip(
                        icon: Icons.file_copy_outlined,
                        label: file.sizeLabel,
                      ),
                      _FileMetaChip(
                        icon: Icons.article_outlined,
                        label: file.pageLabel,
                      ),
                      _FileMetaChip(
                        icon: Icons.calendar_today_outlined,
                        label: file.updatedLabel,
                      ),
                    ],
                  ),
                ],
              );
              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FileKindBadge(kind: file.kind, large: !compact),
                      SizedBox(width: compact ? 14 : 18),
                      Expanded(child: fileTitle),
                      if (!compact) ...[
                        const SizedBox(width: 10),
                        StatusPill(status: file.status, compact: true),
                      ],
                    ],
                  ),
                  if (compact) ...[
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: StatusPill(status: file.status, compact: true),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        GlassPanel(
          padding: const EdgeInsets.all(14),
          child: Row(
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
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.chevron_right_rounded, color: AppColors.navy),
              ),
              Flexible(
                child: Text(
                  file.sectionTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.clinicalActive,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!readyForGeneration) ...[
          const SizedBox(height: 12),
          _ReadinessNotice(message: readinessMessage),
        ],
        const SectionTitle(title: 'Dosya Özeti'),
        GlassPanel(
          padding: const EdgeInsets.all(18),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 520 ? 2 : 1;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 72,
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
              );
            },
          ),
        ),
        const SectionTitle(title: 'Bu dosyadan üret'),
        if (readyForGeneration)
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 720
                  ? 3
                  : constraints.maxWidth < 390
                  ? 1
                  : 2;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: columns == 1
                    ? 4.1
                    : columns == 2
                    ? 2.05
                    : 1.65,
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
              );
            },
          )
        else
          GlassPanel(
            padding: const EdgeInsets.all(18),
            child: EmptyState(
              icon: file.status == DriveItemStatus.failed
                  ? Icons.error_outline_rounded
                  : Icons.hourglass_top_rounded,
              message: _blockedGenerationTitle(file.status),
              subMessage: readinessMessage,
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
                subtitle: readyForGeneration
                    ? 'Flashcard, soru, özet ve algoritma üret'
                    : readinessMessage,
                onTap: readyForGeneration ? widget.onOpenBaseForce : null,
              );
              final sourceLab = _GenerationCenterAction(
                icon: Icons.science_outlined,
                title: 'SourceLab',
                subtitle: readyForGeneration
                    ? 'Senaryo, plan, podcast ve zihin haritası hazırla'
                    : readinessMessage,
                onTap: readyForGeneration ? widget.onOpenSourceLab : null,
              );
              if (compact) {
                return Column(
                  children: [baseForce, const SizedBox(height: 10), sourceLab],
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
          title: 'Bu kaynaktan üretilenler',
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
                    icon: Icons.library_add_check_outlined,
                  ),
                ),
        ),
        const WorkspaceBottomNavGuard(),
      ],
    );
  }

  String _statusShortLabel(DriveItemStatus status) {
    return driveStatusLabel(status);
  }

  String _readinessMessage(DriveFile file) {
    final message = file.statusMessage;
    if (message != null && message.isNotEmpty) {
      return driveFriendlyErrorMessage(message);
    }
    if (file.status == DriveItemStatus.completed &&
        !driveFileUsableForGeneration(file)) {
      return 'Bu kaynağın boyut bilgisi eksik görünüyor. Dosyayı kontrol edip tekrar yüklemeyi deneyebilirsin.';
    }
    return driveStatusInfo(file.status).description;
  }

  String _blockedGenerationTitle(DriveItemStatus status) {
    return switch (status) {
      DriveItemStatus.failed => 'Kaynak işlenemedi.',
      DriveItemStatus.processing => 'Dosya işleniyor.',
      DriveItemStatus.uploading => 'Yükleme devam ediyor.',
      DriveItemStatus.draft => 'Eksik yükleme.',
      DriveItemStatus.completed => 'Dosya hazır.',
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: enabled ? AppColors.selectedBlue : AppColors.page,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.softLine),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: enabled ? AppColors.blue : AppColors.muted,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: enabled ? AppColors.navy : AppColors.muted,
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
            Icon(
              enabled
                  ? Icons.chevron_right_rounded
                  : Icons.lock_outline_rounded,
              color: enabled ? AppColors.navy : AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _FileMetaChip extends StatelessWidget {
  const _FileMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.clinicalSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.clinicalBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.muted, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadinessNotice extends StatelessWidget {
  const _ReadinessNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      borderColor: AppColors.softLine,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
        ],
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
            Icon(generatedIcon(kind), color: color, size: 22),
            const SizedBox(width: 8),
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
                      fontSize: 13.5,
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
                      fontSize: 11.5,
                      height: 1.15,
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
