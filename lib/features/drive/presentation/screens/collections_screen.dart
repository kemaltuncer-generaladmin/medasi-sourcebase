import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/drive_models.dart';
import '../widgets/drive_ui.dart';

void _showCollectionsToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1100),
      ),
    );
}

class CollectionsScreen extends StatelessWidget {
  const CollectionsScreen({
    required this.data,
    required this.onSearch,
    required this.onBackToDrive,
    super.key,
  });

  final DriveWorkspaceData data;
  final VoidCallback onSearch;
  final VoidCallback onBackToDrive;

  @override
  Widget build(BuildContext context) {
    return WorkspaceScroll(
      children: [
        DriveTopBar(title: 'Koleksiyonlar', onSearch: onSearch),
        Row(
          children: const [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Koleksiyonlar',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Materyallerinden üretilen çıktılar',
                    style: TextStyle(color: AppColors.muted, fontSize: 19),
                  ),
                ],
              ),
            ),
            SizedBox(width: 150, height: 122, child: _CollectionHeroArt()),
          ],
        ),
        const SizedBox(height: 16),
        GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Row(
            children: const [
              _Metric(
                icon: Icons.style_rounded,
                color: AppColors.blue,
                value: '-',
                label: 'Flashcard',
              ),
              _MetricDivider(),
              _Metric(
                icon: Icons.help_rounded,
                color: Color(0xFF0BB0D4),
                value: '-',
                label: 'Soru',
              ),
              _MetricDivider(),
              _Metric(
                icon: Icons.description_rounded,
                color: AppColors.purple,
                value: '-',
                label: 'Özet',
              ),
              _MetricDivider(),
              _Metric(
                icon: Icons.account_tree_rounded,
                color: AppColors.green,
                value: '-',
                label: 'Algoritma',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: const [
              _CollectionFilter(label: 'Tümü', selected: true),
              _CollectionFilter(label: 'Flashcard', icon: Icons.style_rounded),
              _CollectionFilter(label: 'Soru', icon: Icons.help_rounded),
              _CollectionFilter(label: 'Özet', icon: Icons.description_rounded),
              _CollectionFilter(
                label: 'Tablo',
                icon: Icons.table_chart_rounded,
              ),
              _CollectionFilter(
                label: 'Podcast',
                icon: Icons.headphones_rounded,
              ),
            ],
          ),
        ),
        Row(
          children: [
            const Expanded(
              child: SectionTitle(title: 'Kaynaklara göre koleksiyonlar'),
            ),
            TextButton(
              onPressed: () =>
                  _showCollectionsToast(context, 'Sıralama: en yeni.'),
              style: TextButton.styleFrom(foregroundColor: AppColors.blue),
              child: const Row(
                children: [
                  Text(
                    'En yeni',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded),
                ],
              ),
            ),
          ],
        ),
        if (data.collections.isEmpty)
          const GlassPanel(
            child: EmptyState(
              message: 'Henüz bir koleksiyonunuz yok.',
              subMessage: 'Dosyalarınızdan AI çıktıları üreterek başlayın.',
            ),
          )
        else
          for (final bundle in data.collections) ...[
            _CollectionCard(bundle: bundle),
            const SizedBox(height: 12),
          ],
        const SizedBox(height: 10),
        const TrustStrip(),
      ],
    );
  }
}

class _CollectionHeroArt extends StatelessWidget {
  const _CollectionHeroArt();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Koleksiyon kartları illüstrasyonu',
      child: CustomPaint(painter: _CollectionHeroPainter()),
    );
  }
}

class _CollectionHeroPainter extends CustomPainter {
  const _CollectionHeroPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = const Color(0xFFC8DAFF).withValues(alpha: .78);
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    for (var i = 0; i < 3; i++) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width * .56, 30 + i * 28),
          width: 110,
          height: 50,
        ),
        const Radius.circular(14),
      );
      canvas.drawRRect(rect, fill);
      canvas.drawRRect(rect, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: '$label sayısı: $value',
        child: ExcludeSemantics(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 30),
                const SizedBox(width: 9),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: SizedBox(
        width: 1,
        height: 42,
        child: DecoratedBox(decoration: BoxDecoration(color: AppColors.line)),
      ),
    );
  }
}

class _CollectionFilter extends StatelessWidget {
  const _CollectionFilter({
    required this.label,
    this.icon,
    this.selected = false,
  });

  final String label;
  final IconData? icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label filtresi',
      child: InkWell(
        onTap: () =>
            _showCollectionsToast(context, '$label filtresi uygulandı.'),
        borderRadius: BorderRadius.circular(18),
        child: ExcludeSemantics(
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: selected ? AppColors.blue : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? AppColors.blue : AppColors.line,
              ),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    color: selected ? Colors.white : AppColors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 7),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.bundle});

  final CollectionBundle bundle;

  @override
  Widget build(BuildContext context) {
    final file = bundle.file;
    final details = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FileKindBadge(kind: file.kind, large: true, plain: true),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                file.title,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 11),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final output in bundle.outputs)
                    _OutputLabel(output: output),
                ],
              ),
              const SizedBox(height: 16),
              _MetaLine(icon: Icons.school_outlined, text: bundle.subject),
              const SizedBox(height: 8),
              _MetaLine(
                icon: Icons.schedule_rounded,
                text: 'Son güncelleme: ${file.updatedLabel}',
              ),
            ],
          ),
        ),
      ],
    );

    final preview = Column(
      children: [
        OutlinedButton(
          onPressed: () => _showCollectionsToast(
            context,
            '${bundle.file.title} koleksiyonu görüntüleniyor.',
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.blue,
            backgroundColor: AppColors.selectedBlue,
            side: const BorderSide(color: AppColors.softLine),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: const Text('Görüntüle'),
        ),
        const SizedBox(height: 10),
        _CollectionPreview(kind: bundle.previewKind),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            4,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: index == 0 ? AppColors.blue : AppColors.line,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ],
    );

    final menu = IconButton(
      tooltip: 'Diğer işlemler',
      onPressed: () =>
          _showCollectionsToast(context, 'Koleksiyon işlemleri açıldı.'),
      icon: const Icon(Icons.more_vert_rounded, color: AppColors.muted),
      visualDensity: VisualDensity.compact,
    );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label:
          '${file.title} koleksiyonu. ${bundle.outputs.length} çıktı. ${bundle.subject}. Son güncelleme: ${file.updatedLabel}.',
      child: GlassPanel(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 520) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  details,
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [preview, const Spacer(), menu],
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: details),
                const SizedBox(width: 12),
                preview,
                const SizedBox(width: 6),
                menu,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OutputLabel extends StatelessWidget {
  const _OutputLabel({required this.output});

  final GeneratedOutput output;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: Semantics(
        label: 'Çıktı: ${output.title}',
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                generatedIcon(output.kind),
                color: generatedColor(output.kind),
                size: 18,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  output.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: Row(
          children: [
            Icon(icon, color: AppColors.muted, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionPreview extends StatelessWidget {
  const _CollectionPreview({required this.kind});

  final GeneratedKind kind;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: '${kind.name} önizlemesi',
      child: ExcludeSemantics(
        child: Container(
          width: 118,
          height: 78,
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.line),
          ),
          child: CustomPaint(painter: _PreviewMiniPainter(kind)),
        ),
      ),
    );
  }
}

class _PreviewMiniPainter extends CustomPainter {
  const _PreviewMiniPainter(this.kind);

  final GeneratedKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = AppColors.line
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final accent = Paint()
      ..color = generatedColor(kind)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    switch (kind) {
      case GeneratedKind.table:
        for (var i = 0; i <= 2; i++) {
          canvas.drawLine(
            Offset(0, i * size.height / 2),
            Offset(size.width, i * size.height / 2),
            accent,
          );
          canvas.drawLine(
            Offset(i * size.width / 2, 0),
            Offset(i * size.width / 2, size.height),
            accent,
          );
        }
        break;
      case GeneratedKind.mindMap:
        final c = Offset(size.width / 2, size.height / 2);
        for (final o in [
          Offset(12, 12),
          Offset(size.width - 12, 12),
          Offset(12, size.height - 12),
          Offset(size.width - 12, size.height - 12),
        ]) {
          canvas.drawLine(c, o, accent);
          canvas.drawCircle(o, 7, accent);
        }
        canvas.drawCircle(c, 13, accent);
        break;
      default:
        for (var i = 0; i < 4; i++) {
          canvas.drawLine(
            Offset(8, 12 + i * 13),
            Offset(size.width - 10, 12 + i * 13),
            line,
          );
        }
    }
  }

  @override
  bool shouldRepaint(covariant _PreviewMiniPainter oldDelegate) =>
      oldDelegate.kind != kind;
}
