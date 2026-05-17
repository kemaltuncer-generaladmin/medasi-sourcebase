import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sourcebase_brand.dart';
import '../../../drive/data/drive_models.dart';
import '../../../drive/presentation/widgets/drive_ui.dart';

enum BaseForceView {
  home,
  sourcePicker,
  flashcardFactory,
  questionFactory,
  summaryFactory,
  algorithmFactory,
  comparisonFactory,
  queue,
  allGenerations,
  flashcardResults,
}

class BaseForceScreen extends StatefulWidget {
  const BaseForceScreen({
    required this.data,
    required this.onSearch,
    super.key,
  });

  final DriveWorkspaceData data;
  final VoidCallback onSearch;

  @override
  State<BaseForceScreen> createState() => _BaseForceScreenState();
}

class _BaseForceScreenState extends State<BaseForceScreen> {
  BaseForceView view = BaseForceView.home;
  late final Set<String> selectedSources;

  @override
  void initState() {
    super.initState();
    selectedSources = widget.data.recentFiles.take(2).map((f) => f.id).toSet();
  }

  String selectedFactory = 'flashcard';
  String selectedFilter = 'Tümü';
  String selectedQuestionDifficulty = 'Orta';

  String flashcardStyle = 'Klasik';
  int flashcardCount = 50;
  String flashcardDifficulty = 'Orta';
  bool flashcardExtractKey = true;
  bool flashcardAddHints = true;

  String questionType = 'Çoktan Seçmeli';
  int questionCount = 20;
  bool questionAddExplanation = true;

  String summaryLength = '1 sayfa';
  String summaryFocus = 'Yüksek Olasılıklı Sorular';
  bool summaryMarkTerms = true;
  bool summaryToTable = true;
  bool summaryChecklist = true;

  String algorithmMode = 'Tanı Algoritması';
  String algorithmLayout = 'Dikey';
  String algorithmDetail = 'Orta';
  bool algorithmColorfulNodes = true;
  bool algorithmClinicalNotes = true;

  String queueFilter = 'Tümü';

  void _open(BaseForceView next) {
    setState(() => view = next);
  }

  void _backToHome() {
    setState(() => view = BaseForceView.home);
  }

  void _toast(String message) {
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

  void _honestToast() {
    _toast('Bu özellik henüz hazır değil.');
  }

  void _handleFlashcardGenerate() {
    _toast(
      'Flashcard üretimi başlatıldı.\nStil: $flashcardStyle, '
      'Sayı: $flashcardCount, Zorluk: $flashcardDifficulty, '
      'Kavram çıkar: $flashcardExtractKey, İpuçları: $flashcardAddHints',
    );
    _open(BaseForceView.queue);
  }

  void _handleQuestionGenerate() {
    _toast(
      'Soru üretimi başlatıldı.\nTip: $questionType, '
      'Sayı: $questionCount, Zorluk: $selectedQuestionDifficulty, '
      'Açıklama: $questionAddExplanation',
    );
    _open(BaseForceView.queue);
  }

  void _handleSummaryGenerate() {
    _toast(
      'Özet üretimi başlatıldı.\nUzunluk: $summaryLength, '
      'Odak: $summaryFocus',
    );
    _open(BaseForceView.queue);
  }

  void _handleAlgorithmGenerate() {
    _toast(
      'Algoritma üretimi başlatıldı.\nMod: $algorithmMode, '
      'Yerleşim: $algorithmLayout, Detay: $algorithmDetail, '
      'Renkli: $algorithmColorfulNodes, Klinik not: $algorithmClinicalNotes',
    );
    _open(BaseForceView.queue);
  }

  void _handleComparisonGenerate() {
    _toast('Karşılaştırma tablosu üretimi başlatıldı.');
    _open(BaseForceView.queue);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: KeyedSubtree(
        key: ValueKey(view),
        child: switch (view) {
          BaseForceView.home => _BaseForceHome(
            onSearch: widget.onSearch,
            onOpenSources: () => _open(BaseForceView.sourcePicker),
            onOpenAll: () => _open(BaseForceView.allGenerations),
            onOpenQueue: () => _open(BaseForceView.queue),
            data: widget.data,
            onOpenFactory: (factory) {
              selectedFactory = factory;
              _open(switch (factory) {
                'question' => BaseForceView.questionFactory,
                'summary' => BaseForceView.summaryFactory,
                'algorithm' => BaseForceView.algorithmFactory,
                'comparison' => BaseForceView.comparisonFactory,
                _ => BaseForceView.flashcardFactory,
              });
            },
            onOpenResult: () => _open(BaseForceView.flashcardResults),
          ),
          BaseForceView.sourcePicker => _SourcePickerScreen(
            data: widget.data,
            selectedSources: selectedSources,
            onSearch: widget.onSearch,
            onBack: _backToHome,
            onToggleSource: (id) {
              setState(() {
                if (selectedSources.contains(id)) {
                  selectedSources.remove(id);
                } else {
                  selectedSources.add(id);
                }
              });
            },
            onContinue: () => _open(switch (selectedFactory) {
              'question' => BaseForceView.questionFactory,
              'summary' => BaseForceView.summaryFactory,
              'algorithm' => BaseForceView.algorithmFactory,
              'comparison' => BaseForceView.comparisonFactory,
              _ => BaseForceView.flashcardFactory,
            }),
            onUpload: _honestToast,
          ),
          BaseForceView.flashcardFactory => _FlashcardFactoryScreen(
            data: widget.data,
            onSearch: widget.onSearch,
            onBack: _backToHome,
            onPickSources: () => _open(BaseForceView.sourcePicker),
            cardStyle: flashcardStyle,
            cardCount: flashcardCount,
            cardDifficulty: flashcardDifficulty,
            extractKey: flashcardExtractKey,
            addHints: flashcardAddHints,
            onStyleChanged: (v) => setState(() => flashcardStyle = v),
            onCountChanged: (v) => setState(() => flashcardCount = v),
            onDifficultyChanged: (v) =>
                setState(() => flashcardDifficulty = v),
            onExtractKeyChanged: (v) =>
                setState(() => flashcardExtractKey = v),
            onAddHintsChanged: (v) => setState(() => flashcardAddHints = v),
            onGenerate: _handleFlashcardGenerate,
            onSavePreview: _honestToast,
          ),
          BaseForceView.questionFactory => _QuestionFactoryScreen(
            data: widget.data,
            selectedDifficulty: selectedQuestionDifficulty,
            questionType: questionType,
            questionCount: questionCount,
            addExplanation: questionAddExplanation,
            onSearch: widget.onSearch,
            onBack: _backToHome,
            onPickSources: () => _open(BaseForceView.sourcePicker),
            onDifficulty: (value) =>
                setState(() => selectedQuestionDifficulty = value),
            onTypeChanged: (v) => setState(() => questionType = v),
            onCountChanged: (v) => setState(() => questionCount = v),
            onExplanationChanged: (v) =>
                setState(() => questionAddExplanation = v),
            onGenerate: _handleQuestionGenerate,
          ),
          BaseForceView.summaryFactory => _SummaryFactoryScreen(
            data: widget.data,
            onSearch: widget.onSearch,
            onBack: _backToHome,
            onPickSources: () => _open(BaseForceView.sourcePicker),
            summaryLength: summaryLength,
            summaryFocus: summaryFocus,
            markTerms: summaryMarkTerms,
            toTable: summaryToTable,
            checklist: summaryChecklist,
            onLengthChanged: (v) => setState(() => summaryLength = v),
            onFocusChanged: (v) => setState(() => summaryFocus = v),
            onMarkTermsChanged: (v) =>
                setState(() => summaryMarkTerms = v),
            onToTableChanged: (v) => setState(() => summaryToTable = v),
            onChecklistChanged: (v) =>
                setState(() => summaryChecklist = v),
            onGenerate: _handleSummaryGenerate,
          ),
          BaseForceView.algorithmFactory => _AlgorithmFactoryScreen(
            data: widget.data,
            onSearch: widget.onSearch,
            onBack: _backToHome,
            onPickSources: () => _open(BaseForceView.sourcePicker),
            algorithmMode: algorithmMode,
            algorithmLayout: algorithmLayout,
            algorithmDetail: algorithmDetail,
            colorfulNodes: algorithmColorfulNodes,
            clinicalNotes: algorithmClinicalNotes,
            onModeChanged: (v) => setState(() => algorithmMode = v),
            onLayoutChanged: (v) => setState(() => algorithmLayout = v),
            onDetailChanged: (v) => setState(() => algorithmDetail = v),
            onColorfulNodesChanged: (v) =>
                setState(() => algorithmColorfulNodes = v),
            onClinicalNotesChanged: (v) =>
                setState(() => algorithmClinicalNotes = v),
            onGenerate: _handleAlgorithmGenerate,
          ),
          BaseForceView.comparisonFactory => _ComparisonFactoryScreen(
            data: widget.data,
            onSearch: widget.onSearch,
            onBack: _backToHome,
            onPickSources: () => _open(BaseForceView.sourcePicker),
            onGenerate: _handleComparisonGenerate,
            onOpenResult: () => _open(BaseForceView.flashcardResults),
          ),
          BaseForceView.queue => _QueueScreen(
            data: widget.data,
            onSearch: widget.onSearch,
            onBack: _backToHome,
            queueFilter: queueFilter,
            onFilterChanged: (v) => setState(() => queueFilter = v),
            onOpenResult: () => _open(BaseForceView.flashcardResults),
            onRetry: () => _open(BaseForceView.algorithmFactory),
            onStop: _honestToast,
          ),
          BaseForceView.flashcardResults => _FlashcardResultsScreen(
            onSearch: widget.onSearch,
            onBack: _backToHome,
            onSave: _honestToast,
            onExport: _honestToast,
            onRegenerate: () => _open(BaseForceView.flashcardFactory),
            onEdit: _honestToast,
          ),
          BaseForceView.allGenerations => _AllGenerationsScreen(
            data: widget.data,
            selectedFilter: selectedFilter,
            onSearch: widget.onSearch,
            onBack: _backToHome,
            onFilter: (filter) => setState(() => selectedFilter = filter),
            onOpenResult: () => _open(BaseForceView.flashcardResults),
            onRegenerate: () => _open(BaseForceView.flashcardFactory),
            onShare: _honestToast,
            onClear: () => setState(() => selectedFilter = 'Tümü'),
          ),
        },
      ),
    );
  }
}

class _BaseForcePage extends StatelessWidget {
  const _BaseForcePage({
    required this.title,
    required this.subtitle,
    required this.children,
    required this.onSearch,
    this.art = _BaseForceArtKind.stack,
    this.actions = const [],
    this.heroTight = false,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final VoidCallback onSearch;
  final _BaseForceArtKind art;
  final List<Widget> actions;
  final bool heroTight;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 940),
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(32, 18, 32, 142),
          children: [
            _BaseForceTopBar(onSearch: onSearch, onBack: onBack),
            _BaseForceHero(
              title: title,
              subtitle: subtitle,
              art: art,
              tight: heroTight,
              actions: actions,
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _BaseForceTopBar extends StatelessWidget {
  const _BaseForceTopBar({required this.onSearch, this.onBack});

  final VoidCallback onSearch;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final backButton = onBack != null
        ? Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _RoundIconButton(
              icon: Icons.arrow_back_rounded,
              label: 'Geri',
              onTap: onBack!,
            ),
          )
        : const SizedBox.shrink();

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundIconButton(
          icon: Icons.search_rounded,
          label: 'Ara',
          onTap: onSearch,
        ),
        const SizedBox(width: 8),
        Stack(
          clipBehavior: Clip.none,
          children: [
            _RoundIconButton(
              icon: Icons.notifications_none_rounded,
              label: 'Bildirimler',
              onTap: () => showSourceBaseNotifications(context),
            ),
            Positioned(
              top: 5,
              right: 5,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.4),
                ),
              ),
            ),
          ],
        ),
      ],
    );

    final baseForceLabel = Semantics(
      container: true,
      header: true,
      label: 'BaseForce',
      child: ExcludeSemantics(
        child: Text(
          'BaseForce',
          style: TextStyle(
            color: AppColors.blue,
            fontSize: 23,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 430) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (onBack != null) ...[backButton, const SizedBox(width: 6)],
                    const Flexible(child: SourceBaseBrand(compact: true)),
                    const Spacer(),
                    actions,
                  ],
                ),
                const SizedBox(height: 14),
                baseForceLabel,
              ],
            );
          }
          return Row(
            children: [
              if (onBack != null) ...[backButton, const SizedBox(width: 6)],
              Expanded(
                child: Row(
                  children: [
                    const Flexible(child: SourceBaseBrand(compact: true)),
                    const _TopDivider(),
                    baseForceLabel,
                  ],
                ),
              ),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _TopDivider extends StatelessWidget {
  const _TopDivider();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 1,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        color: const Color(0xFFC8D4E8),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: ExcludeSemantics(
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: AppColors.line),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: .04),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: AppColors.navy, size: 28),
          ),
        ),
      ),
    );
  }
}

class _BaseForceHero extends StatelessWidget {
  const _BaseForceHero({
    required this.title,
    required this.subtitle,
    required this.art,
    required this.tight,
    this.actions = const [],
  });

  final String title;
  final String subtitle;
  final _BaseForceArtKind art;
  final bool tight;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 44,
            fontWeight: FontWeight.w900,
            height: 1.04,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 20,
            height: 1.42,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 24),
          Wrap(spacing: 10, runSpacing: 10, children: actions),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Container(
            margin: EdgeInsets.only(bottom: tight ? 18 : 26),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0x00FFFFFF), Color(0xFFEAF5FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: tight ? 8 : 22),
                  child: titleBlock,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: tight ? 190 : 225,
                    height: tight ? 132 : 162,
                    child: _BaseForceHeroArt(kind: art),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          margin: EdgeInsets.only(bottom: tight ? 18 : 26),
          constraints: BoxConstraints(minHeight: tight ? 180 : 238),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0x00FFFFFF), Color(0xFFEAF5FF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Opacity(
                    opacity: .8,
                    child: CustomPaint(
                      size: const Size(240, 190),
                      painter: _NetworkGridPainter(),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: tight ? 0 : 10,
                right: 0,
                child: SizedBox(
                  width: tight ? 190 : 230,
                  height: tight ? 150 : 190,
                  child: _BaseForceHeroArt(kind: art),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(0, tight ? 8 : 26, 150, 10),
                child: titleBlock,
              ),
            ],
          ),
        );
      },
    );
  }
}

enum _BaseForceArtKind { stack, flashcards, notebook, cardSet }

class _BaseForceHeroArt extends StatelessWidget {
  const _BaseForceHeroArt({required this.kind});

  final _BaseForceArtKind kind;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BaseForceHeroArtPainter(kind));
  }
}

class _BaseForceHeroArtPainter extends CustomPainter {
  const _BaseForceHeroArtPainter(this.kind);

  final _BaseForceArtKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final shadow = Paint()
      ..color = AppColors.blue.withValues(alpha: .18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    final cyan = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF17CAD4), Color(0xFF1A8BFF)],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ).createShader(Offset.zero & size);
    final blue = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0B5FFF), Color(0xFF725AF9)],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ).createShader(Offset.zero & size);
    final white = Paint()..color = Colors.white;

    void slab(Offset center, double w, double h, Paint paint) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: w, height: h),
        const Radius.circular(18),
      );
      canvas.drawRRect(rect.shift(const Offset(0, 14)), shadow);
      canvas.drawRRect(rect, paint);
    }

    if (kind == _BaseForceArtKind.notebook) {
      final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .35,
          16,
          size.width * .42,
          size.height * .62,
        ),
        const Radius.circular(17),
      );
      canvas.drawRRect(body.shift(const Offset(0, 14)), shadow);
      canvas.drawRRect(body, blue);
      for (var i = 0; i < 4; i++) {
        canvas.drawLine(
          Offset(size.width * .45, 44 + i * 24),
          Offset(size.width * .69, 44 + i * 24),
          Paint()
            ..color = Colors.white.withValues(alpha: .92)
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 7,
        );
      }
      canvas.drawCircle(
        Offset(size.width * .72, size.height * .50),
        34,
        Paint()..color = const Color(0xFFE9F6FF),
      );
      canvas.drawCircle(Offset(size.width * .72, size.height * .50), 24, cyan);
      canvas.drawLine(
        Offset(size.width * .72, size.height * .50),
        Offset(size.width * .72, size.height * .40),
        white..strokeWidth = 5,
      );
      return;
    }

    if (kind == _BaseForceArtKind.flashcards ||
        kind == _BaseForceArtKind.cardSet) {
      final card = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .24,
          42,
          size.width * .56,
          size.height * .42,
        ),
        const Radius.circular(18),
      );
      canvas.drawRRect(card.shift(const Offset(-16, -14)), blue);
      canvas.drawRRect(card.shift(const Offset(18, 8)), cyan);
      canvas.drawRRect(card, Paint()..color = const Color(0xFFF5FBFF));
      canvas.drawLine(
        Offset(size.width * .42, 80),
        Offset(size.width * .63, 80),
        Paint()
          ..color = AppColors.sky
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 8,
      );
      canvas.drawLine(
        Offset(size.width * .42, 106),
        Offset(size.width * .68, 106),
        Paint()
          ..color = AppColors.sky.withValues(alpha: .75)
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 7,
      );
      _drawSpark(canvas, Offset(size.width * .50, 12), 24, AppColors.blue);
      return;
    }

    slab(Offset(size.width * .50, size.height * .72), 150, 58, cyan);
    slab(
      Offset(size.width * .52, size.height * .55),
      154,
      62,
      Paint()..color = const Color(0xFF28A7FF),
    );
    slab(Offset(size.width * .54, size.height * .38), 150, 70, blue);
    canvas.drawCircle(
      Offset(size.width * .54, size.height * .37),
      28,
      Paint()..color = Colors.white.withValues(alpha: .94),
    );
    canvas.drawCircle(
      Offset(size.width * .54, size.height * .37),
      13,
      Paint()..color = AppColors.blue.withValues(alpha: .65),
    );
    canvas.drawLine(
      Offset(size.width * .54, size.height * .07),
      Offset(size.width * .54, size.height * .37),
      Paint()
        ..color = Colors.white
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 5,
    );
    _drawSpark(canvas, Offset(size.width * .54, 12), 26, AppColors.blue);
  }

  void _drawSpark(Canvas canvas, Offset center, double size, Color color) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(center.dx, center.dy - size)
      ..quadraticBezierTo(
        center.dx + 4,
        center.dy - 4,
        center.dx + size,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx + 4,
        center.dy + 4,
        center.dx,
        center.dy + size,
      )
      ..quadraticBezierTo(
        center.dx - 4,
        center.dy + 4,
        center.dx - size,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx - 4,
        center.dy - 4,
        center.dx,
        center.dy - size,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BaseForceHeroArtPainter oldDelegate) =>
      oldDelegate.kind != kind;
}

class _NetworkGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: .85)
      ..strokeWidth = 1;
    final dot = Paint()..color = Colors.white.withValues(alpha: .95);
    final points = [
      Offset(size.width * .12, size.height * .62),
      Offset(size.width * .28, size.height * .38),
      Offset(size.width * .48, size.height * .50),
      Offset(size.width * .72, size.height * .28),
      Offset(size.width * .88, size.height * .52),
      Offset(size.width * .62, size.height * .78),
      Offset(size.width * .34, size.height * .72),
    ];
    for (var i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], line);
    }
    for (final point in points) {
      canvas.drawCircle(point, 3.5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BaseForceHome extends StatelessWidget {
  const _BaseForceHome({
    required this.data,
    required this.onSearch,
    required this.onOpenSources,
    required this.onOpenAll,
    required this.onOpenQueue,
    required this.onOpenFactory,
    required this.onOpenResult,
  });

  final DriveWorkspaceData data;
  final VoidCallback onSearch;
  final VoidCallback onOpenSources;
  final VoidCallback onOpenAll;
  final VoidCallback onOpenQueue;
  final ValueChanged<String> onOpenFactory;
  final VoidCallback onOpenResult;

  @override
  Widget build(BuildContext context) {
    return _BaseForcePage(
      title: 'BaseForce',
      subtitle: 'Kaynaklarını seç, üretim merkezlerinden\nbirini başlat.',
      onSearch: onSearch,
      actions: [
        _HeroAction(
          label: 'Drive’dan Seç',
          icon: Icons.change_history_rounded,
          onTap: onOpenSources,
        ),
        _HeroAction(
          label: 'Yeni Dosya Yükle',
          icon: Icons.cloud_upload_rounded,
          cyan: true,
          onTap: onOpenSources,
        ),
      ],
      children: [
        _SectionHeader(
          title: 'Üretim Merkezleri',
          action: 'Tümünü Gör',
          onTap: onOpenAll,
        ),
        _ResponsiveGrid(
          minItemWidth: 155,
          children: [
            _FactoryCard(
              kind: GeneratedKind.flashcard,
              title: 'Flashcard\nFabrikası',
              subtitle: 'Kaynaklarından akıllı flashcard setleri üretir.',
              buttonColor: AppColors.blue,
              onTap: () => onOpenFactory('flashcard'),
            ),
            _FactoryCard(
              kind: GeneratedKind.question,
              title: 'Soru\nFabrikası',
              subtitle: 'Konuya özel sorular oluşturur.',
              buttonColor: AppColors.green,
              onTap: () => onOpenFactory('question'),
            ),
            _FactoryCard(
              kind: GeneratedKind.summary,
              title: 'Sınav Sabahı\nÖzeti',
              subtitle: 'En kritik bilgileri özet haline getirir.',
              buttonColor: AppColors.purple,
              onTap: () => onOpenFactory('summary'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _ResponsiveGrid(
          minItemWidth: 155,
          children: [
            _FactoryCard(
              kind: GeneratedKind.algorithm,
              title: 'Akış Şeması &\nAlgoritma',
              subtitle: 'Karmaşık konuları şemalarla açıklar.',
              buttonColor: AppColors.orange,
              onTap: () => onOpenFactory('algorithm'),
            ),
            _FactoryCard(
              kind: GeneratedKind.table,
              title: 'Karşılaştırma\nTablosu',
              subtitle: 'Kavramları yan yana karşılaştırır.',
              buttonColor: AppColors.cyan,
              onTap: () => onOpenFactory('comparison'),
            ),
            _FactoryCard(
              kind: GeneratedKind.mindMap,
              title: 'Üretim\nKuyruğu',
              subtitle: 'Başlattığın işleri tek yerden izler.',
              buttonColor: AppColors.blue,
              onTap: onOpenQueue,
            ),
          ],
        ),
        _SectionHeader(
          title: 'Son Kaynaklar',
          action: 'Tümünü Gör',
          onTap: onOpenSources,
        ),
        _BasePanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final file in data.recentFiles.take(3))
                _RecentSourceRow(
                  source: _BFSource(
                    id: file.id,
                    name: file.title,
                    kind: file.kind,
                    size: file.sizeLabel,
                    pages: file.pageLabel,
                    subject: file.courseTitle,
                    time: 'Az önce',
                    warning: false,
                  ),
                  onTap: onOpenSources,
                ),
            ],
          ),
        ),
        _SectionHeader(
          title: 'Son Üretimler',
          action: 'Tümünü Gör',
          onTap: onOpenAll,
        ),
        _ResponsiveGrid(
          minItemWidth: 220,
          children: [
            for (final file in data.recentFiles)
              for (final gen in file.generated)
                _RecentGenerationCard(
                  kind: gen.kind,
                  title: gen.title,
                  value: gen.detail,
                  label: gen.kind.name,
                  source: file.title,
                  time: gen.updatedLabel,
                  onTap: onOpenResult,
                ),
          ],
        ),
      ],
    );
  }
}

class _SourcePickerScreen extends StatelessWidget {
  const _SourcePickerScreen({
    required this.data,
    required this.selectedSources,
    required this.onSearch,
    required this.onToggleSource,
    required this.onContinue,
    required this.onUpload,
    required this.onBack,
  });

  final DriveWorkspaceData data;
  final Set<String> selectedSources;
  final VoidCallback onSearch;
  final ValueChanged<String> onToggleSource;
  final VoidCallback onContinue;
  final VoidCallback onUpload;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return _BaseForcePage(
      title: 'Kaynak Seç',
      subtitle: 'Drive\u2019daki dosyalar\u0131n\u0131 se\xE7 veya yeni y\xFCkle.',
      onSearch: onSearch,
      onBack: onBack,
      heroTight: true,
      actions: [
        _HeroAction(
          label: 'Drive\u2019dan Se\xE7',
          icon: Icons.change_history_rounded,
          onTap: () => _showBaseForceToast(
            context,
            'Bu \xF6zellik hen\xFCz haz\u0131r de\u011Fil.',
          ),
        ),
        _HeroAction(
          label: 'Yeni Yükle',
          icon: Icons.cloud_upload_rounded,
          cyan: true,
          onTap: onUpload,
        ),
      ],
      children: [
        Row(
          children: [
            Expanded(
              child: _SearchBox(
                hint: 'Dosya adı veya konu ile ara...',
                onTap: onSearch,
              ),
            ),
            const SizedBox(width: 10),
            _FilterButton(
              onTap: () => _showBaseForceToast(
                context,
                'Bu \xF6zellik hen\xFCz haz\u0131r de\u011Fil.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: const [
            _SourceFilter(
              label: 'Tümü',
              selected: true,
              icon: Icons.folder_rounded,
            ),
            _SourceFilter(label: 'PDF', kind: DriveFileKind.pdf),
            _SourceFilter(label: 'PPTX', kind: DriveFileKind.pptx),
            _SourceFilter(label: 'DOCX', kind: DriveFileKind.docx),
            _SourceFilter(
              label: 'Kardiyoloji',
              icon: Icons.monitor_heart_rounded,
            ),
            _SourceFilter(
              label: 'Farmakoloji',
              icon: Icons.medication_liquid_rounded,
            ),
            _SourceFilter(
              label: 'Anatomi',
              icon: Icons.accessibility_new_rounded,
            ),
            _SourceFilter(label: 'Biyokimya', icon: Icons.science_rounded),
          ],
        ),
        _SectionHeader(
          title: 'Drive’daki Dosyalar',
          trailing: '${data.recentFiles.length} dosya',
        ),
        _BasePanel(
          padding: EdgeInsets.zero,
          child: data.recentFiles.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text(
                      'Drive\u2019da hen\u00FCz dosya yok. \u00D6nce Drive '
                      'ekran\u0131ndan bir dosya y\u00FCkleyin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 16,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (final file in data.recentFiles)
                      _SourceSelectRow(
                        source: _BFSource(
                          id: file.id,
                          name: file.title,
                          kind: file.kind,
                          size: file.sizeLabel,
                          pages: file.pageLabel,
                          subject: file.courseTitle,
                          time: 'Az önce',
                          warning: false,
                        ),
                        selected: selectedSources.contains(file.id),
                        onTap: () => onToggleSource(file.id),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 18),
        _UploadDropZone(onTap: onUpload),
        const SizedBox(height: 18),
        _SelectedSourcesTray(
          data: data,
          selectedSources: selectedSources,
          onRemove: onToggleSource,
          onContinue: onContinue,
        ),
      ],
    );
  }
}

class _FlashcardFactoryScreen extends StatelessWidget {
  const _FlashcardFactoryScreen({
    required this.data,
    required this.onSearch,
    required this.onBack,
    required this.onPickSources,
    required this.onGenerate,
    required this.onSavePreview,
    required this.cardStyle,
    required this.cardCount,
    required this.cardDifficulty,
    required this.extractKey,
    required this.addHints,
    required this.onStyleChanged,
    required this.onCountChanged,
    required this.onDifficultyChanged,
    required this.onExtractKeyChanged,
    required this.onAddHintsChanged,
  });

  final DriveWorkspaceData data;
  final VoidCallback onSearch;
  final VoidCallback onBack;
  final VoidCallback onPickSources;
  final VoidCallback onGenerate;
  final VoidCallback onSavePreview;
  final String cardStyle;
  final int cardCount;
  final String cardDifficulty;
  final bool extractKey;
  final bool addHints;
  final ValueChanged<String> onStyleChanged;
  final ValueChanged<int> onCountChanged;
  final ValueChanged<String> onDifficultyChanged;
  final ValueChanged<bool> onExtractKeyChanged;
  final ValueChanged<bool> onAddHintsChanged;

  @override
  Widget build(BuildContext context) {
    return _BaseForcePage(
      title: 'Flashcard Fabrikas\u0131',
      subtitle: 'Kaynaklar\u0131ndan ak\u0131ll\u0131 flashcard\u2019lar \xFCret.',
      onSearch: onSearch,
      onBack: onBack,
      art: _BaseForceArtKind.cardSet,
      children: [
        _TwoPane(
          left: Column(
            children: [
              _SourcesPanel(data: data, onPickSources: onPickSources),
              const SizedBox(height: 12),
              _BasePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _PanelTitle(
                      icon: Icons.settings_outlined,
                      title: 'Üretim Ayarları',
                    ),
                    const SizedBox(height: 18),
                    const _SettingLabel('Kart Stili'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _SegmentButton(
                            label: 'Klasik',
                            icon: Icons.credit_card_rounded,
                            selected: cardStyle == 'Klasik',
                            onTap: () => onStyleChanged('Klasik'),
                          ),
                        ),
                        Expanded(
                          child: _SegmentButton(
                            label: 'Cloze',
                            icon: Icons.more_horiz_rounded,
                            selected: cardStyle == 'Cloze',
                            onTap: () => onStyleChanged('Cloze'),
                          ),
                        ),
                        Expanded(
                          child: _SegmentButton(
                            label: 'H\u0131zl\u0131 Tekrar',
                            icon: Icons.sync_rounded,
                            selected: cardStyle == 'H\u0131zl\u0131 Tekrar',
                            onTap: () => onStyleChanged('H\u0131zl\u0131 Tekrar'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _StepperSetting(
                      label: 'Kart Say\u0131s\u0131',
                      value: '$cardCount',
                      onChanged: onCountChanged,
                    ),
                    const SizedBox(height: 18),
                    const _SettingLabel('Zorluk Seviyesi'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _DifficultyChip(
                            label: 'Kolay',
                            color: AppColors.green,
                            selected: cardDifficulty == 'Kolay',
                            onTap: () => onDifficultyChanged('Kolay'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _DifficultyChip(
                            label: 'Orta',
                            color: AppColors.orange,
                            selected: cardDifficulty == 'Orta',
                            onTap: () => onDifficultyChanged('Orta'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _DifficultyChip(
                            label: 'Zor',
                            color: AppColors.red,
                            selected: cardDifficulty == 'Zor',
                            onTap: () => onDifficultyChanged('Zor'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _ToggleLine(
                      label: '\xD6nemli kavramlar\u0131 \xE7\u0131kar',
                      initialValue: extractKey,
                      onChanged: onExtractKeyChanged,
                    ),
                    _ToggleLine(
                      label: '\u0130pu\xE7lar\u0131 ekle',
                      initialValue: addHints,
                      onChanged: onAddHintsChanged,
                    ),
                  ],
                ),
              ),
            ],
          ),
          right: _BasePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _PanelTitle(
                  icon: Icons.visibility_outlined,
                  title: 'Önizleme',
                ),
                const SizedBox(height: 22),
                const _SettingLabel('Ön Yüz'),
                const SizedBox(height: 10),
                _FlashCardFace(
                  text: 'Beta blokerler hangi\nfarmakolojik etkiyi\ngösterir?',
                  icon: Icons.style_outlined,
                  center: true,
                  onTap: onSavePreview,
                ),
                const SizedBox(height: 14),
                const Center(
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.selectedBlue,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.blue,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const _SettingLabel('Arka Yüz'),
                const SizedBox(height: 10),
                _FlashCardFace(
                  text:
                      'Beta blokerler, kalpteki beta-1 adrenerjik reseptörleri bloke ederek kalp hızını düşürür, miyokard kasılma gücünü azaltır.',
                  icon: Icons.auto_awesome_rounded,
                  onTap: onSavePreview,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const _ProductionSummary(
          items: [
            _SummaryItemData(
              Icons.style_rounded,
              '50',
              'Tahmini Kart',
              AppColors.blue,
            ),
            _SummaryItemData(
              Icons.menu_book_rounded,
              '8',
              'Tahmini Konu',
              AppColors.green,
            ),
            _SummaryItemData(
              Icons.schedule_rounded,
              '~8 dk',
              'Tahmini Süre',
              AppColors.purple,
            ),
            _SummaryItemData(
              Icons.auto_awesome_rounded,
              'AI Destekli',
              'Akıllı Üretim',
              AppColors.purple,
            ),
          ],
        ),
        const SizedBox(height: 14),
        PrimaryGradientButton(
          label: 'Flashcard Üret',
          icon: Icons.auto_awesome_rounded,
          height: 58,
          onTap: onGenerate,
        ),
      ],
    );
  }
}

class _QuestionFactoryScreen extends StatelessWidget {
  const _QuestionFactoryScreen({
    required this.data,
    required this.selectedDifficulty,
    required this.questionType,
    required this.questionCount,
    required this.addExplanation,
    required this.onSearch,
    required this.onBack,
    required this.onPickSources,
    required this.onDifficulty,
    required this.onTypeChanged,
    required this.onCountChanged,
    required this.onExplanationChanged,
    required this.onGenerate,
  });

  final DriveWorkspaceData data;
  final String selectedDifficulty;
  final String questionType;
  final int questionCount;
  final bool addExplanation;
  final VoidCallback onSearch;
  final VoidCallback onBack;
  final VoidCallback onPickSources;
  final ValueChanged<String> onDifficulty;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<int> onCountChanged;
  final ValueChanged<bool> onExplanationChanged;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return _BaseForcePage(
      title: 'Soru Fabrikas\u0131',
      subtitle:
          'Se\xE7ti\u011Finiz kaynaklardan, yapay zeka ile\n\xF6zelle\u015Ftirilmi\u015F sorular \xFCretin.',
      onSearch: onSearch,
      onBack: onBack,
      children: [
        _SelectedSourceChips(data: data, onPickSources: onPickSources),
        const SizedBox(height: 20),
        _BasePanel(
          child: Column(
            children: [
              const _SettingRowLabel(
                icon: Icons.list_rounded,
                label: 'Soru Tipi',
              ),
              _ResponsiveGrid(
                minItemWidth: 150,
                children: [
                  _SegmentButton(
                    label: '\xC7oktan Se\xE7meli',
                    selected: questionType == '\xC7oktan Se\xE7meli',
                    onTap: () => onTypeChanged('\xC7oktan Se\xE7meli'),
                  ),
                  _SegmentButton(
                    label: 'Klinik Vaka',
                    selected: questionType == 'Klinik Vaka',
                    onTap: () => onTypeChanged('Klinik Vaka'),
                  ),
                  _SegmentButton(
                    label: 'Do\u011Fru-Yanl\u0131\u015F',
                    selected: questionType == 'Do\u011Fru-Yanl\u0131\u015F',
                    onTap: () => onTypeChanged('Do\u011Fru-Yanl\u0131\u015F'),
                  ),
                ],
              ),
              const _ThinRule(),
              const _SettingRowLabel(
                icon: Icons.bar_chart_rounded,
                label: 'Zorluk Seviyesi',
              ),
              _ResponsiveGrid(
                minItemWidth: 120,
                children: [
                  for (final value in const ['Kolay', 'Orta', 'Zor', '\xC7ok Zor'])
                    _SegmentButton(
                      label: value,
                      selected: selectedDifficulty == value,
                      onTap: () => onDifficulty(value),
                    ),
                ],
              ),
              const _ThinRule(),
              _StepperSetting(
                label: 'Soru Say\u0131s\u0131',
                value: '$questionCount',
                onChanged: onCountChanged,
              ),
              const _ThinRule(),
              _ToggleLine(
                label: 'A\xE7\u0131klama Ekle',
                initialValue: addExplanation,
                onChanged: onExplanationChanged,
              ),
              const _ThinRule(),
              const Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _TagChip(label: 'Tan\u0131'),
                  _TagChip(label: 'Tedavi', color: AppColors.green),
                  _TagChip(label: 'Fizyoloji', color: AppColors.purple),
                  _TagChip(
                    label: 'Alan Ekle',
                    outlined: true,
                    icon: Icons.add_rounded,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _TwoPane(left: _QuestionPreview(), right: _ExplanationPreview()),
        const SizedBox(height: 18),
        const _ProductionSummary(
          items: [
            _SummaryItemData(
              Icons.description_outlined,
              '20',
              'Soru',
              AppColors.blue,
            ),
            _SummaryItemData(
              Icons.chat_bubble_outline_rounded,
              'Açıklamalı',
              'Üretim',
              AppColors.cyan,
            ),
            _SummaryItemData(
              Icons.bar_chart_rounded,
              'Orta',
              'Zorluk Seviyesi',
              AppColors.orange,
            ),
            _SummaryItemData(
              Icons.track_changes_rounded,
              'Tanı, Tedavi,\nFizyoloji',
              'Odak Alanları',
              AppColors.purple,
            ),
          ],
        ),
        const SizedBox(height: 14),
        PrimaryGradientButton(
          label: 'Soruları Üret',
          icon: Icons.auto_fix_high_rounded,
          height: 58,
          onTap: onGenerate,
        ),
      ],
    );
  }
}

class _SummaryFactoryScreen extends StatelessWidget {
  const _SummaryFactoryScreen({
    required this.data,
    required this.onSearch,
    required this.onBack,
    required this.onPickSources,
    required this.onGenerate,
    required this.summaryLength,
    required this.summaryFocus,
    required this.markTerms,
    required this.toTable,
    required this.checklist,
    required this.onLengthChanged,
    required this.onFocusChanged,
    required this.onMarkTermsChanged,
    required this.onToTableChanged,
    required this.onChecklistChanged,
  });

  final DriveWorkspaceData data;

  final VoidCallback onSearch;
  final VoidCallback onBack;
  final VoidCallback onPickSources;
  final VoidCallback onGenerate;
  final String summaryLength;
  final String summaryFocus;
  final bool markTerms;
  final bool toTable;
  final bool checklist;
  final ValueChanged<String> onLengthChanged;
  final ValueChanged<String> onFocusChanged;
  final ValueChanged<bool> onMarkTermsChanged;
  final ValueChanged<bool> onToTableChanged;
  final ValueChanged<bool> onChecklistChanged;

  @override
  Widget build(BuildContext context) {
    return _BaseForcePage(
      title: 'S\u0131nav Sabah\u0131 \xD6zeti',
      subtitle:
          'Se\xE7ti\u011Finiz kaynaklardan s\u0131nav\u0131n\u0131za \xF6zel,\nodakl\u0131 bir \xF6zet olu\u015Ftur.',
      onSearch: onSearch,
      onBack: onBack,
      art: _BaseForceArtKind.notebook,
      children: [
        _SelectedSourceChips(
          data: data,
          onPickSources: onPickSources,
          includeThird: true,
        ),
        const SizedBox(height: 18),
        _ResponsiveGrid(
          minItemWidth: 240,
          children: [
            _SummaryOptionPanel(
              selectedLength: summaryLength,
              onLengthChanged: onLengthChanged,
            ),
            _FocusOptionPanel(
              selectedFocus: summaryFocus,
              onFocusChanged: onFocusChanged,
            ),
            _HighlightOptionPanel(
              markTerms: markTerms,
              toTable: toTable,
              checklist: checklist,
              onMarkTermsChanged: onMarkTermsChanged,
              onToTableChanged: onToTableChanged,
              onChecklistChanged: onChecklistChanged,
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _SummaryPreviewCard(),
        const SizedBox(height: 18),
        const _ProductionSummary(
          items: [
            _SummaryItemData(
              Icons.description_rounded,
              '1 sayfa',
              'Tahmini uzunluk',
              AppColors.blue,
            ),
            _SummaryItemData(
              Icons.menu_book_rounded,
              '8 başlık',
              'Özet başlık sayısı',
              AppColors.purple,
            ),
            _SummaryItemData(
              Icons.layers_rounded,
              '3 kaynak',
              'Seçili kaynak sayısı',
              AppColors.cyan,
            ),
            _SummaryItemData(
              Icons.track_changes_rounded,
              'Sınav odaklı',
              'Seçilmiş odak modu',
              AppColors.green,
            ),
          ],
        ),
        const SizedBox(height: 14),
        PrimaryGradientButton(
          label: 'Özeti Oluştur',
          icon: Icons.auto_awesome_rounded,
          height: 58,
          onTap: onGenerate,
        ),
      ],
    );
  }
}

class _AlgorithmFactoryScreen extends StatelessWidget {
  const _AlgorithmFactoryScreen({
    required this.data,
    required this.onSearch,
    required this.onBack,
    required this.onPickSources,
    required this.onGenerate,
    required this.algorithmMode,
    required this.algorithmLayout,
    required this.algorithmDetail,
    required this.colorfulNodes,
    required this.clinicalNotes,
    required this.onModeChanged,
    required this.onLayoutChanged,
    required this.onDetailChanged,
    required this.onColorfulNodesChanged,
    required this.onClinicalNotesChanged,
  });

  final DriveWorkspaceData data;
  final VoidCallback onSearch;
  final VoidCallback onBack;
  final VoidCallback onPickSources;
  final VoidCallback onGenerate;
  final String algorithmMode;
  final String algorithmLayout;
  final String algorithmDetail;
  final bool colorfulNodes;
  final bool clinicalNotes;
  final ValueChanged<String> onModeChanged;
  final ValueChanged<String> onLayoutChanged;
  final ValueChanged<String> onDetailChanged;
  final ValueChanged<bool> onColorfulNodesChanged;
  final ValueChanged<bool> onClinicalNotesChanged;

  @override
  Widget build(BuildContext context) {
    return _BaseForcePage(
      title: 'Ak\u0131\u015F \u015Eemas\u0131 &\nAlgoritma',
      subtitle:
          'Klinik s\xFCre\xE7lerinizi g\xF6rsel ak\u0131\u015F \u015Femalar\u0131 ve\nalgoritmalar ile yap\u0131land\u0131r\u0131n.',
      onSearch: onSearch,
      onBack: onBack,
      children: [
        _SelectedSourceChips(data: data, onPickSources: onPickSources),
        const SizedBox(height: 14),
        _BasePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('\xC7\u0131kt\u0131 Ayarlar\u0131', style: _titleStyle),
              const SizedBox(height: 16),
              _SettingGridRow(
                label: '\xC7\u0131kt\u0131 Modu',
                children: [
                  _SegmentButton(
                    label: 'Tan\u0131 Algoritmas\u0131',
                    icon: Icons.account_tree_outlined,
                    selected: algorithmMode == 'Tan\u0131 Algoritmas\u0131',
                    onTap: () => onModeChanged('Tan\u0131 Algoritmas\u0131'),
                  ),
                  _SegmentButton(
                    label: 'Tedavi Ak\u0131\u015F\u0131',
                    icon: Icons.polyline_rounded,
                    selected: algorithmMode == 'Tedavi Ak\u0131\u015F\u0131',
                    onTap: () => onModeChanged('Tedavi Ak\u0131\u015F\u0131'),
                  ),
                  _SegmentButton(
                    label: 'Karar A\u011Fac\u0131',
                    icon: Icons.device_hub_rounded,
                    selected: algorithmMode == 'Karar A\u011Fac\u0131',
                    onTap: () => onModeChanged('Karar A\u011Fac\u0131'),
                  ),
                ],
              ),
              _SettingGridRow(
                label: 'Yerle\u015Fim Y\xF6n\xFC',
                children: [
                  _SegmentButton(
                    label: 'Dikey',
                    icon: Icons.tune_rounded,
                    selected: algorithmLayout == 'Dikey',
                    onTap: () => onLayoutChanged('Dikey'),
                  ),
                  _SegmentButton(
                    label: 'Yatay',
                    icon: Icons.view_week_outlined,
                    selected: algorithmLayout == 'Yatay',
                    onTap: () => onLayoutChanged('Yatay'),
                  ),
                ],
              ),
              _SettingGridRow(
                label: 'Detay Seviyesi',
                children: [
                  _SegmentButton(
                    label: 'Basit',
                    icon: Icons.adjust_rounded,
                    selected: algorithmDetail == 'Basit',
                    onTap: () => onDetailChanged('Basit'),
                  ),
                  _SegmentButton(
                    label: 'Orta',
                    icon: Icons.center_focus_strong_rounded,
                    selected: algorithmDetail == 'Orta',
                    onTap: () => onDetailChanged('Orta'),
                  ),
                  _SegmentButton(
                    label: 'Ayr\u0131nt\u0131l\u0131',
                    icon: Icons.format_list_bulleted_rounded,
                    selected: algorithmDetail == 'Ayr\u0131nt\u0131l\u0131',
                    onTap: () => onDetailChanged('Ayr\u0131nt\u0131l\u0131'),
                  ),
                ],
              ),
              _ToggleLine(
                label: 'Renkli D\xFC\u011F\xFCmler',
                initialValue: colorfulNodes,
                onChanged: onColorfulNodesChanged,
              ),
              _ToggleLine(
                label: 'Klinik Not Ekle',
                initialValue: clinicalNotes,
                onChanged: onClinicalNotesChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _FlowPreviewPanel(),
        const SizedBox(height: 18),
        const _ProductionSummary(
          items: [
            _SummaryItemData(
              Icons.account_tree_outlined,
              '1',
              'Algoritma Sayısı',
              AppColors.blue,
            ),
            _SummaryItemData(
              Icons.polyline_rounded,
              '18',
              'Tahmini Düğüm Sayısı',
              AppColors.green,
            ),
            _SummaryItemData(
              Icons.device_hub_rounded,
              'Tanı Algoritması',
              'Çıktı Modu',
              AppColors.purple,
            ),
          ],
        ),
        const SizedBox(height: 14),
        PrimaryGradientButton(
          label: 'Algoritmayı Oluştur',
          icon: Icons.auto_awesome_rounded,
          height: 58,
          onTap: onGenerate,
        ),
      ],
    );
  }
}

class _ComparisonFactoryScreen extends StatelessWidget {
  const _ComparisonFactoryScreen({
    required this.data,
    required this.onSearch,
    required this.onBack,
    required this.onPickSources,
    required this.onGenerate,
    required this.onOpenResult,
  });

  final DriveWorkspaceData data;
  final VoidCallback onSearch;
  final VoidCallback onBack;
  final VoidCallback onPickSources;
  final VoidCallback onGenerate;
  final VoidCallback onOpenResult;

  @override
  Widget build(BuildContext context) {
    return _BaseForcePage(
      title: 'Kar\u015F\u0131la\u015Ft\u0131rma Tablosu',
      subtitle:
          'Se\xE7ti\u011Finiz kaynaklar\u0131 ve konular\u0131 kar\u015F\u0131la\u015Ft\u0131r\u0131n, farklar\u0131 net \u015Fekilde g\xF6r\xFCn.',
      onSearch: onSearch,
      onBack: onBack,
      heroTight: true,
      children: [
        _BasePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Seçilen Kaynaklar (2)', style: _titleStyle),
              const SizedBox(height: 12),
              for (final file in data.recentFiles.take(2))
                _ComparisonSourceLine(
                  source: _BFSource(
                    id: file.id,
                    name: file.title,
                    kind: file.kind,
                    size: file.sizeLabel,
                    pages: file.pageLabel,
                    subject: file.courseTitle,
                    time: 'Az önce',
                    warning: false,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _BasePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Karşılaştırılacak Konular', style: _titleStyle),
              SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _TopicButton(label: 'Crohn', selected: true),
                  _TopicButton(label: 'Ülseratif Kolit', selected: true),
                  _TopicButton(label: 'STEMI'),
                  _TopicButton(label: 'NSTEMI'),
                  _TopicButton(label: 'Kalp Yetmezliği'),
                  _TopicButton(
                    label: '',
                    icon: Icons.keyboard_arrow_down_rounded,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const _TableSettingsPanel(),
        const SizedBox(height: 10),
        const _ComparisonPreviewTable(),
        const SizedBox(height: 18),
        const _ProductionSummary(
          items: [
            _SummaryItemData(
              Icons.menu_book_outlined,
              '2',
              'Konu',
              AppColors.green,
            ),
            _SummaryItemData(
              Icons.format_list_bulleted_rounded,
              '6',
              'Satır',
              AppColors.purple,
            ),
            _SummaryItemData(
              Icons.track_changes_rounded,
              'Fark Odaklı',
              'Vurgu Tercihi',
              AppColors.orange,
            ),
          ],
        ),
        const SizedBox(height: 14),
        PrimaryGradientButton(
          label: 'Tabloyu Oluştur',
          icon: Icons.table_chart_outlined,
          height: 58,
          onTap: onGenerate,
        ),
      ],
    );
  }
}

class _QueueScreen extends StatefulWidget {
  const _QueueScreen({
    required this.data,
    required this.onSearch,
    required this.onBack,
    required this.queueFilter,
    required this.onFilterChanged,
    required this.onOpenResult,
    required this.onRetry,
    required this.onStop,
  });

  final DriveWorkspaceData data;
  final VoidCallback onSearch;
  final VoidCallback onBack;
  final String queueFilter;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onOpenResult;
  final VoidCallback onRetry;
  final VoidCallback onStop;

  @override
  State<_QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<_QueueScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _BaseForcePage(
        title: '\xDcretim Kuyru\u011Fu',
        subtitle: 'Ba\u015Flat\u0131lan \xFCretimleri tek yerden takip et.',
        onSearch: widget.onSearch,
        onBack: widget.onBack,
        heroTight: true,
        children: const [
          SizedBox(height: 80),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    final allRows = <_QueueRow>[];
    for (final file in widget.data.recentFiles) {
      if (file.generated.isNotEmpty) {
        for (final gen in file.generated) {
          allRows.add(
            _QueueRow(
              source: _BFSource(
                id: file.id,
                name: file.title,
                kind: file.kind,
                size: file.sizeLabel,
                pages: file.pageLabel,
                subject: file.courseTitle,
                time: 'Az \xF6nce',
              ),
              title: gen.title,
              complete: true,
              failed: false,
              progress: 1,
              time: gen.updatedLabel,
              filterStatus: 'Tamamland\u0131',
              onAction: widget.onOpenResult,
            ),
          );
        }
      }
    }

    final filteredRows = widget.queueFilter == 'T\xFCm\xFC'
        ? allRows
        : allRows.where((r) => r.filterStatus == widget.queueFilter).toList();

    return _BaseForcePage(
      title: '\xDcretim Kuyru\u011Fu',
      subtitle: 'Ba\u015Flat\u0131lan \xFCretimleri tek yerden takip et.',
      onSearch: widget.onSearch,
      onBack: widget.onBack,
      heroTight: true,
      children: [
        const _ResponsiveGrid(
          minItemWidth: 230,
          children: [
            _QueueMetric(
              icon: Icons.play_circle_outline_rounded,
              title: 'Devam Eden',
              value: '2',
              subtitle: '\u0130\u015Fleniyor',
              color: AppColors.blue,
            ),
            _QueueMetric(
              icon: Icons.check_circle_rounded,
              title: 'Tamamland\u0131',
              value: '2',
              subtitle: 'Ba\u015Far\u0131yla bitti',
              color: AppColors.green,
            ),
            _QueueMetric(
              icon: Icons.error_rounded,
              title: 'Beklemede',
              value: '1',
              subtitle: 'S\u0131rada bekliyor',
              color: AppColors.orange,
            ),
          ],
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            _QueueFilter(
              label: 'T\xFCm\xFC',
              selected: widget.queueFilter == 'T\xFCm\xFC',
              onTap: () => widget.onFilterChanged('T\xFCm\xFC'),
            ),
            _QueueFilter(
              label: '\u0130\u015Fleniyor',
              dot: AppColors.blue,
              selected: widget.queueFilter == '\u0130\u015Fleniyor',
              onTap: () => widget.onFilterChanged('\u0130\u015Fleniyor'),
            ),
            _QueueFilter(
              label: 'Tamamland\u0131',
              dot: AppColors.green,
              selected: widget.queueFilter == 'Tamamland\u0131',
              onTap: () => widget.onFilterChanged('Tamamland\u0131'),
            ),
            _QueueFilter(
              label: 'Hata',
              dot: AppColors.red,
              selected: widget.queueFilter == 'Hata',
              onTap: () => widget.onFilterChanged('Hata'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        ...filteredRows,
      ],
    );
  }
}

class _FlashcardResultsScreen extends StatelessWidget {
  const _FlashcardResultsScreen({
    required this.onSearch,
    required this.onBack,
    required this.onSave,
    required this.onExport,
    required this.onRegenerate,
    required this.onEdit,
  });

  final VoidCallback onSearch;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final VoidCallback onExport;
  final VoidCallback onRegenerate;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return _BaseForcePage(
      title: 'Flashcard Sonu\xE7lar\u0131',
      subtitle: '\xDcretilen seti incele, d\xFCzenle ve\nkoleksiyonuna kaydet.',
      art: _BaseForceArtKind.flashcards,
      onSearch: onSearch,
      onBack: onBack,
      children: [
        _BasePanel(
          padding: const EdgeInsets.all(22),
          child: const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Bu i\xE7erik hen\xFCz olu\u015Fturulmad\u0131.\nBir \xFCretim fabrikas\u0131ndan i\xE7erik \xFCretip\ng\xF6r\xFCnt\xFClemek i\xE7in \u201C\xDCret\u201D butonuna bas\u0131n.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 17,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _SectionHeader(title: 'H\u0131zl\u0131 Aksiyonlar'),
        _ResponsiveGrid(
          minItemWidth: 165,
          children: [
            _QuickResultAction(
              icon: Icons.folder_special_outlined,
              label: 'Koleksiyona\nKaydet',
              onTap: onSave,
            ),
            _QuickResultAction(
              icon: Icons.upload_rounded,
              label: 'Dışa Aktar',
              color: AppColors.green,
              onTap: onExport,
            ),
            _QuickResultAction(
              icon: Icons.auto_awesome_rounded,
              label: 'Yeniden Üret',
              color: AppColors.purple,
              onTap: onRegenerate,
            ),
            _QuickResultAction(
              icon: Icons.edit_outlined,
              label: 'Düzenle',
              color: AppColors.orange,
              onTap: onEdit,
            ),
          ],
        ),
        const SizedBox(height: 16),
        PrimaryGradientButton(
          label: 'Koleksiyona Kaydet',
          icon: Icons.bookmark_border_rounded,
          height: 58,
          onTap: onSave,
        ),
      ],
    );
  }
}

class _AllGenerationsScreen extends StatelessWidget {
  const _AllGenerationsScreen({
    required this.data,
    required this.selectedFilter,
    required this.onSearch,
    required this.onBack,
    required this.onFilter,
    required this.onOpenResult,
    required this.onRegenerate,
    required this.onShare,
    required this.onClear,
  });

  final DriveWorkspaceData data;
  final String selectedFilter;
  final VoidCallback onSearch;
  final VoidCallback onBack;
  final ValueChanged<String> onFilter;
  final VoidCallback onOpenResult;
  final VoidCallback onRegenerate;
  final VoidCallback onShare;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final allGenerations = data.recentFiles
        .expand(
          (file) => file.generated.map(
            (gen) => _GenerationRowData(
              title: gen.title,
              source: file.title,
              kind: gen.kind.name,
              count: gen.detail,
              time: gen.updatedLabel,
            ),
          ),
        )
        .toList();

    final visible = selectedFilter == 'T\xFCm\xFC'
        ? allGenerations
        : allGenerations.where((row) => row.kind == selectedFilter).toList();

    return _BaseForcePage(
      title: 'T\xFCm \xDcretimler',
      subtitle:
          'Olu\u015Fturdu\u011Fun t\xFCm \xE7\u0131kt\u0131lar\u0131 d\xFCzenle, g\xF6r\xFCnt\xFCle\nve yeniden kullan.',
      onSearch: onSearch,
      onBack: onBack,
      heroTight: true,
      children: [
        _BasePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Bu Hafta Oluşturulanlar',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 18),
              _WeeklyStats(),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SearchBox(hint: 'Üretimlerde ara...', onTap: onSearch),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final filter in const [
              'Flashcard',
              'Soru',
              'Özet',
              'Algoritma',
              'Tablo',
            ]) ...[
              _MiniKindFilter(
                label: filter,
                selected: selectedFilter == filter,
                onTap: () => onFilter(filter),
              ),
            ],
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Tümünü Temizle'),
              style: TextButton.styleFrom(foregroundColor: AppColors.blue),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _showBaseForceToast(context, 'Bu özellik henüz hazır değil.'),
            child: const Text(
              'Sırala:  En Yeni ⌄',
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        for (final row in visible)
          _GenerationListRow(
            data: row,
            onOpen: onOpenResult,
            onShare: onShare,
            onRegenerate: onRegenerate,
          ),
      ],
    );
  }
}

const TextStyle _titleStyle = TextStyle(
  color: AppColors.navy,
  fontSize: 20,
  fontWeight: FontWeight.w900,
  height: 1.1,
);

class _BasePanel extends StatelessWidget {
  const _BasePanel({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 16,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: .055),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({required this.children, this.minItemWidth = 240});

  final List<Widget> children;
  final double minItemWidth;

  @override
  Widget build(BuildContext context) {
    const spacing = 12.0;
    const runSpacing = 12.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (!width.isFinite || children.isEmpty) {
          return Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1) SizedBox(height: runSpacing),
              ],
            ],
          );
        }
        final columns = math.max(
          1,
          math.min(children.length, width ~/ minItemWidth),
        );
        if (columns <= 1) {
          return Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1) SizedBox(height: runSpacing),
              ],
            ],
          );
        }
        final itemWidth = (width - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class _TwoPane extends StatelessWidget {
  const _TwoPane({
    required this.left,
    required this.right,
    this.breakpoint = 760,
    this.spacing = 12,
  });

  final Widget left;
  final Widget right;
  final double breakpoint;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            children: [
              left,
              SizedBox(height: spacing),
              right,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            SizedBox(width: spacing),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

void _showBaseForceToast(BuildContext context, String message) {
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

class _HeroAction extends StatelessWidget {
  const _HeroAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.cyan = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool cyan;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 27),
        label: Text(label, maxLines: 1),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: cyan ? AppColors.cyan : AppColors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.action,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? action;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            )
          else if (action != null)
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(foregroundColor: AppColors.blue),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    action!,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, size: 24),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RoundGeneratedIcon extends StatelessWidget {
  const _RoundGeneratedIcon({required this.kind, this.size = 62});

  final GeneratedKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = generatedColor(kind);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: .15)),
      ),
      child: Icon(generatedIcon(kind), color: color, size: size * .52),
    );
  }
}

class _FactoryCard extends StatelessWidget {
  const _FactoryCard({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.buttonColor,
    required this.onTap,
  });

  final GeneratedKind kind;
  final String title;
  final String subtitle;
  final Color buttonColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _BasePanel(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RoundGeneratedIcon(kind: kind),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 18,
              height: 1.14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: Text(
              subtitle,
              maxLines: 3,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12.5,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: const Text('Aç'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentSourceRow extends StatelessWidget {
  const _RecentSourceRow({required this.source, required this.onTap});

  final _BFSource source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            FileKindBadge(kind: source.kind, plain: true),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${source.size}  •  ${source.time}  •  ${source.subject}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            StatusPill(status: DriveItemStatus.completed, compact: true),
            const _MoreMenuButton(),
          ],
        ),
      ),
    );
  }
}

class _RecentGenerationCard extends StatelessWidget {
  const _RecentGenerationCard({
    required this.kind,
    required this.title,
    required this.value,
    required this.label,
    required this.source,
    required this.time,
    required this.onTap,
  });

  final GeneratedKind kind;
  final String title;
  final String value;
  final String label;
  final String source;
  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: _BasePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RoundGeneratedIcon(kind: kind),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: AppColors.navy, fontSize: 15),
            ),
            const SizedBox(height: 14),
            const Divider(color: AppColors.softLine),
            Row(
              children: [
                Expanded(
                  child: Text(
                    source,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  time,
                  style: const TextStyle(
                    color: AppColors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.hint, required this.onTap});

  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: AppColors.navy, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hint,
                style: const TextStyle(color: AppColors.softText, fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.filter_alt_outlined, size: 27),
        label: const Text('Filtrele'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy,
          side: const BorderSide(color: AppColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _SourceFilter extends StatelessWidget {
  const _SourceFilter({
    required this.label,
    this.selected = false,
    this.icon,
    this.kind,
  });

  final String label;
  final bool selected;
  final IconData? icon;
  final DriveFileKind? kind;

  @override
  Widget build(BuildContext context) {
    final color = kind == null
        ? AppColors.blue
        : FileKindBadge.kindColor(kind!);
    return InkWell(
      onTap: () => _showBaseForceToast(
        context,
        'Bu \xF6zellik hen\xFCz haz\u0131r de\u011Fil.',
      ),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? AppColors.selectedBlue : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.blue : AppColors.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (kind != null)
              FileKindBadge(kind: kind!, compact: true)
            else if (icon != null)
              Icon(icon, color: color, size: 24),
            if (kind != null || icon != null) const SizedBox(width: 9),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.blue : AppColors.navy,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceSelectRow extends StatelessWidget {
  const _SourceSelectRow({
    required this.source,
    required this.selected,
    required this.onTap,
  });

  final _BFSource source;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _CheckSquare(selected: selected),
            const SizedBox(width: 16),
            FileKindBadge(kind: source.kind, plain: false),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source.name,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${source.size}  •  ${source.pages}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            _SuitabilityPill(warning: source.warning),
            const SizedBox(width: 10),
            const _MoreMenuButton(),
          ],
        ),
      ),
    );
  }
}

class _CheckSquare extends StatelessWidget {
  const _CheckSquare({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: selected ? AppColors.blue : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: selected ? AppColors.blue : const Color(0xFFB8C5D8),
          width: 2,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
          : null,
    );
  }
}

class _SuitabilityPill extends StatelessWidget {
  const _SuitabilityPill({this.warning = false});

  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: warning ? const Color(0xFFFFF2D8) : AppColors.greenBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            warning ? Icons.error_rounded : Icons.check_circle_rounded,
            color: warning ? const Color(0xFFE69A00) : AppColors.green,
            size: 17,
          ),
          const SizedBox(width: 6),
          Text(
            warning ? 'Büyük Boyut' : 'Uygun',
            style: TextStyle(
              color: warning ? const Color(0xFFD28000) : AppColors.green,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadDropZone extends StatelessWidget {
  const _UploadDropZone({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 26),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.blue.withValues(alpha: .42),
            style: BorderStyle.solid,
          ),
        ),
        child: const Column(
          children: [
            Icon(Icons.cloud_upload_outlined, color: AppColors.blue, size: 34),
            SizedBox(height: 8),
            Text(
              'Yeni dosya yükle',
              style: TextStyle(
                color: AppColors.blue,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'PDF, PPTX, DOCX formatları desteklenir.',
              style: TextStyle(color: AppColors.muted, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedSourcesTray extends StatelessWidget {
  const _SelectedSourcesTray({
    required this.data,
    required this.selectedSources,
    required this.onRemove,
    required this.onContinue,
  });

  final DriveWorkspaceData data;
  final Set<String> selectedSources;
  final ValueChanged<String> onRemove;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final selected = data.recentFiles
        .where((file) => selectedSources.contains(file.id))
        .map(
          (file) => _BFSource(
            id: file.id,
            name: file.title,
            kind: file.kind,
            size: file.sizeLabel,
            pages: file.pageLabel,
            subject: file.courseTitle,
            time: 'Az önce',
            warning: false,
          ),
        )
        .toList();
    return _BasePanel(
      padding: const EdgeInsets.all(18),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.blue,
                child: Text(
                  '${selected.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'kaynak seçildi',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final source in selected)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _SelectedSourceChip(
                      source: source,
                      onRemove: () => onRemove(source.id),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton.icon(
              onPressed: selected.isEmpty ? null : onContinue,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Devam Et'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.line,
                padding: const EdgeInsets.symmetric(horizontal: 26),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedSourceChip extends StatelessWidget {
  const _SelectedSourceChip({required this.source, required this.onRemove});

  final _BFSource source;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          FileKindBadge(kind: source.kind, compact: true),
          const SizedBox(width: 8),
          Text(
            source.name,
            style: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.muted,
              size: 19,
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _SourcesPanel extends StatelessWidget {
  const _SourcesPanel({required this.data, required this.onPickSources});

  final DriveWorkspaceData data;
  final VoidCallback onPickSources;

  @override
  Widget build(BuildContext context) {
    return _BasePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle(
            icon: Icons.description_outlined,
            title: 'Kaynaklarınız',
          ),
          const SizedBox(height: 18),
          for (final file in data.recentFiles.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CompactSourceTile(
                source: _BFSource(
                  id: file.id,
                  name: file.title,
                  kind: file.kind,
                  size: file.sizeLabel,
                  pages: file.pageLabel,
                  subject: file.courseTitle,
                  time: 'Az önce',
                  warning: false,
                ),
                selected: true,
              ),
            ),
          InkWell(
            onTap: onPickSources,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.blue.withValues(alpha: .28),
                ),
              ),
              child: Row(
                children: const [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.selectedBlue,
                    child: Icon(
                      Icons.add_rounded,
                      color: AppColors.blue,
                      size: 34,
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dosya Ekle',
                          style: TextStyle(
                            color: AppColors.blue,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'PDF, PPTX, DOCX desteklenir',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedSourceChips extends StatelessWidget {
  const _SelectedSourceChips({
    required this.data,
    required this.onPickSources,
    this.includeThird = false,
  });

  final DriveWorkspaceData data;
  final VoidCallback onPickSources;
  final bool includeThird;

  @override
  Widget build(BuildContext context) {
    final sources = includeThird
        ? data.recentFiles.take(3)
        : data.recentFiles.take(2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Seçili Kaynaklar', style: _titleStyle),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final file in sources)
              _SourceChipCard(
                source: _BFSource(
                  id: file.id,
                  name: file.title,
                  kind: file.kind,
                  size: file.sizeLabel,
                  pages: file.pageLabel,
                  subject: file.courseTitle,
                  time: 'Az önce',
                  warning: false,
                ),
                onTap: onPickSources,
              ),
            _DashedAddButton(onTap: onPickSources),
          ],
        ),
      ],
    );
  }
}

class _CompactSourceTile extends StatelessWidget {
  const _CompactSourceTile({required this.source, this.selected = false});

  final _BFSource source;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          FileKindBadge(kind: source.kind),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  source.size,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          if (selected)
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.green,
              size: 25,
            )
          else
            const Icon(Icons.close_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _SourceChipCard extends StatelessWidget {
  const _SourceChipCard({required this.source, required this.onTap});

  final _BFSource source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          FileKindBadge(kind: source.kind, compact: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  source.size,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Kaynak seçimini düzenle',
            onPressed: onTap,
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.muted,
              size: 18,
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _DashedAddButton extends StatelessWidget {
  const _DashedAddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 150,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.blue.withValues(alpha: .45)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: AppColors.blue),
            SizedBox(width: 6),
            Text(
              'Kaynak Ekle',
              style: TextStyle(
                color: AppColors.blue,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
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
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.selectedBlue,
          child: Icon(icon, color: AppColors.blue, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _titleStyle,
          ),
        ),
      ],
    );
  }
}

class _SettingLabel extends StatelessWidget {
  const _SettingLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.navy,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () => _showBaseForceToast(context, 'Bu \xF6zellik hen\xFCz haz\u0131r de\u011Fil.'),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.selectedBlue : Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? AppColors.blue : AppColors.line,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: selected ? AppColors.blue : AppColors.muted,
                size: 20,
              ),
              const SizedBox(width: 7),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? AppColors.blue : AppColors.navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperSetting extends StatefulWidget {
  const _StepperSetting({
    required this.label,
    required this.value,
    this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<int>? onChanged;

  @override
  State<_StepperSetting> createState() => _StepperSettingState();
}

class _StepperSettingState extends State<_StepperSetting> {
  late int value;

  @override
  void initState() {
    super.initState();
    value = int.tryParse(widget.value) ?? 0;
  }

  @override
  void didUpdateWidget(covariant _StepperSetting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      final parsed = int.tryParse(widget.value);
      if (parsed != null && parsed != value) {
        value = parsed;
      }
    }
  }

  void _change(int delta) {
    final next = math.max(1, value + delta);
    setState(() => value = next);
    widget.onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _SettingLabel(widget.label)),
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _change(-1),
                icon: const Icon(Icons.remove_rounded, color: AppColors.muted),
                visualDensity: VisualDensity.compact,
              ),
              Container(width: 1, height: 42, color: AppColors.softLine),
              SizedBox(
                width: 54,
                child: Center(
                  child: Text(
                    '$value',
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              Container(width: 1, height: 42, color: AppColors.softLine),
              IconButton(
                onPressed: () => _change(1),
                icon: const Icon(Icons.add_rounded, color: AppColors.blue),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DifficultyChip extends StatefulWidget {
  const _DifficultyChip({
    required this.label,
    required this.color,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<_DifficultyChip> createState() => _DifficultyChipState();
}

class _DifficultyChipState extends State<_DifficultyChip> {
  late bool selected;

  @override
  void initState() {
    super.initState();
    selected = widget.selected;
  }

  @override
  void didUpdateWidget(covariant _DifficultyChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      selected = widget.selected;
    }
  }

  void _toggle() {
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _toggle,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected
                ? widget.color
                : widget.color.withValues(alpha: .18),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(radius: 5, backgroundColor: widget.color),
              const SizedBox(width: 7),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.color,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleLine extends StatefulWidget {
  const _ToggleLine({required this.label, this.initialValue = true, this.onChanged});

  final String label;
  final bool initialValue;
  final ValueChanged<bool>? onChanged;

  @override
  State<_ToggleLine> createState() => _ToggleLineState();
}

class _ToggleLineState extends State<_ToggleLine> {
  late bool enabled;

  @override
  void initState() {
    super.initState();
    enabled = widget.initialValue;
  }

  @override
  void didUpdateWidget(covariant _ToggleLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      enabled = widget.initialValue;
    }
  }

  void _toggle(bool value) {
    setState(() => enabled = value);
    widget.onChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.label,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Switch(
            value: enabled,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.blue,
            inactiveThumbColor: Colors.white,
            onChanged: (value) => _toggle(value),
          ),
        ],
      ),
    );
  }
}

class _FlashCardFace extends StatelessWidget {
  const _FlashCardFace({
    required this.text,
    required this.icon,
    required this.onTap,
    this.center = false,
  });

  final String text;
  final IconData icon;
  final VoidCallback onTap;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: center ? 210 : 250,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF4FAFF), Colors.white, Color(0xFFF7F3FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFAFC8FF)),
          boxShadow: [
            BoxShadow(
              color: AppColors.blue.withValues(alpha: .06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Align(
              alignment: center ? Alignment.center : Alignment.centerLeft,
              child: Text(
                text,
                textAlign: center ? TextAlign.center : TextAlign.left,
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: center ? 21 : 18,
                  fontWeight: center ? FontWeight.w900 : FontWeight.w500,
                  height: 1.38,
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Icon(
                icon,
                color: AppColors.blue.withValues(alpha: .22),
                size: 35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductionSummary extends StatelessWidget {
  const _ProductionSummary({required this.items});

  final List<_SummaryItemData> items;

  @override
  Widget build(BuildContext context) {
    return _BasePanel(
      child: _ResponsiveGrid(
        minItemWidth: 165,
        children: [for (final item in items) _SummaryStat(item: item)],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.item});

  final _SummaryItemData item;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: item.color.withValues(alpha: .11),
          child: Icon(item.icon, color: item.color, size: 27),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12.5,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryItemData {
  const _SummaryItemData(this.icon, this.value, this.label, this.color);

  final IconData icon;
  final String value;
  final String label;
  final Color color;
}

class _SettingRowLabel extends StatelessWidget {
  const _SettingRowLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.muted, size: 26),
          const SizedBox(width: 14),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThinRule extends StatelessWidget {
  const _ThinRule();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Divider(color: AppColors.softLine, height: 1),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    this.color = AppColors.blue,
    this.outlined = false,
    this.icon,
  });

  final String label;
  final Color color;
  final bool outlined;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showBaseForceToast(context, 'Bu özellik henüz hazır değil.'),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: outlined ? Colors.white : color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: outlined
                ? AppColors.blue.withValues(alpha: .35)
                : color.withValues(alpha: .12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: AppColors.blue, size: 18),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            if (!outlined) ...[
              const SizedBox(width: 8),
              Icon(Icons.close_rounded, color: color, size: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuestionPreview extends StatelessWidget {
  const _QuestionPreview();

  @override
  Widget build(BuildContext context) {
    return _BasePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Soru Önizleme', style: _titleStyle),
          SizedBox(height: 14),
          _QuestionLine(
            number: '1.',
            text:
                'Aşağıdakilerden hangisi ACE inhibitörlerinin etki mekanizmasıyla ilişkilidir?',
          ),
          SizedBox(height: 10),
          _AnswerOption(label: 'A) Renin salınımını artırırlar.'),
          _AnswerOption(
            label: 'B) Anjiyotensin II oluşumunu engellerler.',
            selected: true,
          ),
          _AnswerOption(label: 'C) Aldosteron reseptörlerini bloke ederler.'),
          _AnswerOption(label: 'D) Beta-1 adrenerjik reseptörleri uyarırlar.'),
          _AnswerOption(label: 'E) Anjiyotensinojeni karaciğerde yıkarlar.'),
        ],
      ),
    );
  }
}

class _QuestionLine extends StatelessWidget {
  const _QuestionLine({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.blue,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1.28,
            ),
          ),
        ),
      ],
    );
  }
}

class _AnswerOption extends StatelessWidget {
  const _AnswerOption({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? AppColors.selectedBlue : Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: selected ? AppColors.blue : AppColors.line),
      ),
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_off_rounded,
            color: selected ? AppColors.blue : AppColors.softText,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.navy, fontSize: 14.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExplanationPreview extends StatelessWidget {
  const _ExplanationPreview();

  @override
  Widget build(BuildContext context) {
    return _BasePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: Color(0xFFEFE7FF),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.purple,
                ),
              ),
              SizedBox(width: 12),
              Text('Açıklama Önizleme', style: _titleStyle),
            ],
          ),
          SizedBox(height: 30),
          Text(
            'ACE inhibitörleri, anjiyotensin dönüştürücü enzimi inhibe ederek anjiyotensin I’in anjiyotensin II’ye dönüşümünü engeller. Bu etki vazodilatasyon ve aldosteron salınımının azalmasına yol açar.',
            style: TextStyle(color: AppColors.navy, fontSize: 18, height: 1.55),
          ),
          SizedBox(height: 22),
          _TagChip(
            label: 'Kaynak: Farmakoloji Ders Notları.pdf',
            color: AppColors.purple,
          ),
        ],
      ),
    );
  }
}

class _SummaryOptionPanel extends StatelessWidget {
  const _SummaryOptionPanel({required this.selectedLength, required this.onLengthChanged});

  final String selectedLength;
  final ValueChanged<String> onLengthChanged;

  @override
  Widget build(BuildContext context) {
    return _BasePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle(icon: Icons.description_outlined, title: '\xD6zet Uzunlu\u011Fu'),
          const SizedBox(height: 16),
          _RadioOption(
            title: '1 sayfa',
            subtitle: 'Kompakt ve odakl\u0131',
            selected: selectedLength == '1 sayfa',
            onTap: () => onLengthChanged('1 sayfa'),
          ),
          _RadioOption(
            title: '3 sayfa',
            subtitle: 'Daha detayl\u0131 \xF6zet',
            selected: selectedLength == '3 sayfa',
            onTap: () => onLengthChanged('3 sayfa'),
          ),
          _RadioOption(
            title: 'Ultra k\u0131sa',
            subtitle: 'En k\u0131sa format',
            selected: selectedLength == 'Ultra k\u0131sa',
            onTap: () => onLengthChanged('Ultra k\u0131sa'),
          ),
        ],
      ),
    );
  }
}

class _FocusOptionPanel extends StatelessWidget {
  const _FocusOptionPanel({required this.selectedFocus, required this.onFocusChanged});

  final String selectedFocus;
  final ValueChanged<String> onFocusChanged;

  @override
  Widget build(BuildContext context) {
    return _BasePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle(icon: Icons.track_changes_rounded, title: 'Odak Modu'),
          const SizedBox(height: 16),
          _RadioOption(
            title: 'Y\xFCksek Olas\u0131l\u0131kl\u0131 Sorular',
            subtitle: '\xC7\u0131kma ihtimali y\xFCksek konular',
            selected: selectedFocus == 'Y\xFCksek Olas\u0131l\u0131kl\u0131 Sorular',
            onTap: () => onFocusChanged('Y\xFCksek Olas\u0131l\u0131kl\u0131 Sorular'),
          ),
          _RadioOption(
            title: 'Kritik Noktalar',
            subtitle: 'En \xF6nemli kavramlar',
            selected: selectedFocus == 'Kritik Noktalar',
            onTap: () => onFocusChanged('Kritik Noktalar'),
          ),
          _RadioOption(
            title: 'Hoca Vurgular\u0131',
            subtitle: '\xD6\u011Fretmenin vurgulad\u0131klar\u0131',
            selected: selectedFocus == 'Hoca Vurgular\u0131',
            onTap: () => onFocusChanged('Hoca Vurgular\u0131'),
          ),
        ],
      ),
    );
  }
}

class _HighlightOptionPanel extends StatelessWidget {
  const _HighlightOptionPanel({
    required this.markTerms,
    required this.toTable,
    required this.checklist,
    required this.onMarkTermsChanged,
    required this.onToTableChanged,
    required this.onChecklistChanged,
  });

  final bool markTerms;
  final bool toTable;
  final bool checklist;
  final ValueChanged<bool> onMarkTermsChanged;
  final ValueChanged<bool> onToTableChanged;
  final ValueChanged<bool> onChecklistChanged;

  @override
  Widget build(BuildContext context) {
    return _BasePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle(icon: Icons.edit_outlined, title: 'Vurgu Se\xE7enekleri'),
          const SizedBox(height: 22),
          _ToggleLine(
            label: 'Anahtar terimleri i\u015Faretle',
            initialValue: markTerms,
            onChanged: onMarkTermsChanged,
          ),
          const Divider(color: AppColors.softLine),
          _ToggleLine(
            label: 'Tabloya \xE7evir',
            initialValue: toTable,
            onChanged: onToTableChanged,
          ),
          const Divider(color: AppColors.softLine),
          _ToggleLine(
            label: 'Mini check-list ekle',
            initialValue: checklist,
            onChanged: onChecklistChanged,
          ),
        ],
      ),
    );
  }
}

class _RadioOption extends StatelessWidget {
  const _RadioOption({
    required this.title,
    required this.subtitle,
    this.selected = false,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.selectedBlue : Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: selected ? AppColors.blue : AppColors.line),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? AppColors.blue : AppColors.softText,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryPreviewCard extends StatelessWidget {
  const _SummaryPreviewCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Özet Önizleme', style: _titleStyle),
        const SizedBox(height: 10),
        _BasePanel(
          child: const _TwoPane(
            breakpoint: 700,
            spacing: 18,
            left: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Kardiyoloji - Temel Konular Özeti',
                        style: TextStyle(
                          color: AppColors.navy,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _TagChip(label: 'Sınav Odaklı', color: AppColors.blue),
                  ],
                ),
                SizedBox(height: 18),
                Text(
                  'Yüksek Olasılıklı Konular',
                  style: TextStyle(
                    color: AppColors.blue,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                _BulletText(text: 'Kalp debisi = Atım hacmi x Kalp hızı'),
                _BulletText(text: 'Preload artışı -> Atım hacmi artar'),
                _BulletText(text: 'Afterload artışı -> Atım hacmi azalır'),
                _BulletText(text: 'Sistol: Ventriküllerin kasılması'),
                _BulletText(
                  text: 'Diastol: Ventriküllerin gevşemesi ve dolması',
                ),
                SizedBox(height: 18),
                _CalloutBox(
                  title: 'Hoca Vurgusu',
                  text:
                      'Preload, kalbe dönen kan miktarını; afterload ise kalbin kanı pompalarken karşılaştığı direnci ifade eder.',
                ),
              ],
            ),
            right: Column(
              children: [_TinyTable(), SizedBox(height: 14), _ChecklistBox()],
            ),
          ),
        ),
      ],
    );
  }
}

class _BulletText extends StatelessWidget {
  const _BulletText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(color: AppColors.navy, fontSize: 17),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 15.5,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalloutBox extends StatelessWidget {
  const _CalloutBox({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.greenBg.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.green.withValues(alpha: .25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.green,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 14.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyTable extends StatelessWidget {
  const _TinyTable();

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['Parametre', 'Tanım'],
      ['Atım Hacmi', 'Her atımda pompalanan kan'],
      ['Kalp Debisi', 'Dakikadaki toplam kan'],
      ['Preload', 'Ventrikül doluş basıncı'],
      ['Afterload', 'Damar direnci'],
    ];
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          for (final row in rows)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.softLine)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row[0],
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row[1],
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ChecklistBox extends StatelessWidget {
  const _ChecklistBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFAFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.purple.withValues(alpha: .22)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mini Check-list',
            style: TextStyle(
              color: AppColors.purple,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          _CheckText(text: 'Frank-Starling yasasını anladım.'),
          _CheckText(text: 'Preload - Afterload ayrımını biliyorum.'),
          _CheckText(text: 'Sistol - Diyastol fazlarını hatırladım.'),
        ],
      ),
    );
  }
}

class _CheckText extends StatelessWidget {
  const _CheckText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.muted),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.navy, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingGridRow extends StatelessWidget {
  const _SettingGridRow({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    const labelStyle = TextStyle(
      color: AppColors.navy,
      fontSize: 15.5,
      fontWeight: FontWeight.w800,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 640) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: labelStyle),
                const SizedBox(height: 10),
                _ResponsiveGrid(minItemWidth: 145, children: children),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 190, child: Text(label, style: labelStyle)),
              Expanded(
                child: Row(
                  children: [
                    for (var index = 0; index < children.length; index++) ...[
                      Expanded(child: children[index]),
                      if (index != children.length - 1)
                        const SizedBox(width: 10),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FlowPreviewPanel extends StatelessWidget {
  const _FlowPreviewPanel();

  @override
  Widget build(BuildContext context) {
    return _BasePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Expanded(child: Text('Önizleme', style: _titleStyle)),
              _IconBox(icon: Icons.open_in_full_rounded),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 350,
            child: CustomPaint(
              painter: _FlowPreviewPainter(),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowPreviewPainter extends CustomPainter {
  const _FlowPreviewPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFF687DA0)
      ..strokeWidth = 2;
    final green = Paint()..color = const Color(0xFFEAFBF1);
    final orange = Paint()..color = const Color(0xFFFFF3E8);
    final purple = Paint()..color = const Color(0xFFF8F2FF);
    void box(Rect rect, Paint paint, Color stroke, String text, IconData icon) {
      final r = RRect.fromRectAndRadius(rect, const Radius.circular(8));
      canvas.drawRRect(r, paint);
      canvas.drawRRect(
        r,
        Paint()
          ..color = stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: rect.width - 16);
      tp.paint(
        canvas,
        Offset(
          rect.left + (rect.width - tp.width) / 2,
          rect.top + (rect.height - tp.height) / 2,
        ),
      );
    }

    void arrow(Offset a, Offset b) {
      canvas.drawLine(a, b, line);
      final angle = math.atan2(b.dy - a.dy, b.dx - a.dx);
      final p1 =
          b - Offset(math.cos(angle - .55) * 9, math.sin(angle - .55) * 9);
      final p2 =
          b - Offset(math.cos(angle + .55) * 9, math.sin(angle + .55) * 9);
      canvas.drawPath(
        Path()
          ..moveTo(b.dx, b.dy)
          ..lineTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..close(),
        line,
      );
    }

    final top = Rect.fromCenter(
      center: Offset(size.width / 2, 34),
      width: 230,
      height: 54,
    );
    box(
      top,
      Paint()..color = AppColors.selectedBlue,
      AppColors.blue,
      'Göğüs Ağrısı\n(Olası Kardiyak)',
      Icons.monitor_heart_outlined,
    );
    final diamondCenter = Offset(size.width / 2, 126);
    final diamond = Path()
      ..moveTo(diamondCenter.dx, diamondCenter.dy - 48)
      ..lineTo(diamondCenter.dx + 82, diamondCenter.dy)
      ..lineTo(diamondCenter.dx, diamondCenter.dy + 48)
      ..lineTo(diamondCenter.dx - 82, diamondCenter.dy)
      ..close();
    canvas.drawPath(diamond, purple);
    canvas.drawPath(
      diamond,
      Paint()
        ..color = AppColors.purple
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    final question = TextPainter(
      text: const TextSpan(
        text: 'ST Elevasyonu\nVar mı?',
        style: TextStyle(
          color: AppColors.navy,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 130);
    question.paint(
      canvas,
      Offset(
        diamondCenter.dx - question.width / 2,
        diamondCenter.dy - question.height / 2,
      ),
    );
    arrow(Offset(size.width / 2, 61), Offset(size.width / 2, 78));

    final leftX = size.width * .22;
    final rightX = size.width * .74;
    box(
      Rect.fromCenter(center: Offset(leftX, 184), width: 170, height: 48),
      green,
      AppColors.green,
      'STEMI',
      Icons.favorite_rounded,
    );
    box(
      Rect.fromCenter(center: Offset(leftX, 254), width: 170, height: 48),
      green,
      AppColors.green,
      'Acil Reperfüzyon\n(PPK / Primer PCI)',
      Icons.local_hospital_outlined,
    );
    box(
      Rect.fromCenter(center: Offset(leftX, 322), width: 170, height: 48),
      green,
      AppColors.green,
      'Koroner Yoğun Bakım\nve İzlem',
      Icons.bed_rounded,
    );
    box(
      Rect.fromCenter(center: Offset(rightX, 184), width: 190, height: 48),
      orange,
      AppColors.orange,
      'Yüksek Riskli\nNSTEMI / UA',
      Icons.warning_amber_rounded,
    );
    box(
      Rect.fromCenter(center: Offset(rightX, 254), width: 190, height: 48),
      orange,
      AppColors.orange,
      'Risk Skoru ve Tanısal\nDeğerlendirme',
      Icons.analytics_outlined,
    );
    box(
      Rect.fromCenter(center: Offset(rightX - 86, 324), width: 156, height: 48),
      Paint()..color = const Color(0xFFFFFAEC),
      const Color(0xFFDCA32E),
      'İnvaziv Strateji',
      Icons.timeline_rounded,
    );
    box(
      Rect.fromCenter(center: Offset(rightX + 86, 324), width: 156, height: 48),
      Paint()..color = const Color(0xFFFFFAEC),
      const Color(0xFFDCA32E),
      'İlaç Tedavisi ve\nYakın İzlem',
      Icons.medication_outlined,
    );
    arrow(Offset(diamondCenter.dx - 82, diamondCenter.dy), Offset(leftX, 160));
    arrow(Offset(diamondCenter.dx + 82, diamondCenter.dy), Offset(rightX, 160));
    arrow(Offset(leftX, 208), Offset(leftX, 230));
    arrow(Offset(leftX, 278), Offset(leftX, 298));
    arrow(Offset(rightX, 208), Offset(rightX, 230));
    arrow(Offset(rightX, 278), Offset(rightX - 86, 300));
    arrow(Offset(rightX, 278), Offset(rightX + 86, 300));
    final yes = TextPainter(
      text: const TextSpan(
        text: 'Evet',
        style: TextStyle(
          color: AppColors.green,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    yes.paint(canvas, Offset(size.width * .30, 130));
    final no = TextPainter(
      text: const TextSpan(
        text: 'Hayır',
        style: TextStyle(
          color: AppColors.red,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    no.paint(canvas, Offset(size.width * .64, 130));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Icon(icon, color: AppColors.navy, size: 22),
    );
  }
}

class _ComparisonSourceLine extends StatelessWidget {
  const _ComparisonSourceLine({required this.source});

  final _BFSource source;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.softLine)),
      ),
      child: Row(
        children: [
          FileKindBadge(kind: source.kind, compact: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.name,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  source.size,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Kaynağı kaldır',
            onPressed: () =>
                _showBaseForceToast(context, 'Bu özellik henüz hazır değil.'),
            icon: const Icon(Icons.close_rounded, color: AppColors.navy),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _TopicButton extends StatefulWidget {
  const _TopicButton({required this.label, this.selected = false, this.icon});

  final String label;
  final bool selected;
  final IconData? icon;

  @override
  State<_TopicButton> createState() => _TopicButtonState();
}

class _TopicButtonState extends State<_TopicButton> {
  late bool selected;

  @override
  void initState() {
    super.initState();
    selected = widget.selected;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (widget.label.isEmpty) {
          _showBaseForceToast(context, 'Bu özellik henüz hazır değil.');
          return;
        }
        setState(() => selected = !selected);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: selected ? AppColors.selectedBlue : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.blue : AppColors.line,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null)
              Icon(widget.icon, color: AppColors.navy)
            else
              Text(
                widget.label,
                style: TextStyle(
                  color: selected ? AppColors.blue : AppColors.navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            if (selected) ...[
              const SizedBox(width: 10),
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.blue,
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TableSettingsPanel extends StatelessWidget {
  const _TableSettingsPanel();

  @override
  Widget build(BuildContext context) {
    return _BasePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Tablo Ayarları', style: _titleStyle),
          SizedBox(height: 12),
          _ResponsiveGrid(
            minItemWidth: 210,
            children: [
              _DropdownBox(label: 'Sütun Stili', value: 'Konu Bazlı'),
              _DropdownBox(label: 'Özet Derinliği', value: 'Orta'),
              _DropdownBox(label: 'Vurgu Tercihi', value: 'Fark Odaklı'),
            ],
          ),
          SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppColors.blue, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Benzerlikler yeşil, farklılıklar kırmızı ile vurgulanacaktır.',
                  style: TextStyle(color: AppColors.muted, fontSize: 15),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DropdownBox extends StatelessWidget {
  const _DropdownBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showBaseForceToast(context, 'Bu özellik henüz hazır değil.'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonPreviewTable extends StatelessWidget {
  const _ComparisonPreviewTable();

  @override
  Widget build(BuildContext context) {
    const rows = [
      [
        'Crohn - Tanım',
        'Kronik, segmental inflamatuar barsak hastalığıdır.',
        'Kronik inflamatuar barsak hastalığıdır.',
        'Benzer',
      ],
      [
        'Crohn - Etiyoloji',
        'Genetik, immünolojik ve çevresel faktörler rol oynar.',
        'Multifaktöriyel; genetik ve immünolojik faktörler önemlidir.',
        'Benzer',
      ],
      [
        'Crohn - Klinik',
        'Karın ağrısı, ishal, kilo kaybı görülebilir.',
        'Kilo kaybı, karın ağrısı, ishal en sık bulgulardır.',
        'Benzer',
      ],
      [
        'Ülseratif Kolit - Klinik',
        'Hematokezya, tenesmus, ishal tipiktir.',
        'Kanlı ishal, tenesmus ve karın krampları görülebilir.',
        'Farklı',
      ],
    ];
    return _BasePanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Önizleme', style: _titleStyle),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final tableWidth = math.max(constraints.maxWidth, 720.0);
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Table(
                      border: TableBorder.all(color: AppColors.line),
                      columnWidths: const {
                        0: FlexColumnWidth(1.2),
                        1: FlexColumnWidth(1.65),
                        2: FlexColumnWidth(1.65),
                        3: FlexColumnWidth(.9),
                      },
                      children: [
                        const TableRow(
                          decoration: BoxDecoration(color: Color(0xFFF5FAFF)),
                          children: [
                            _TableCell(text: 'Konu', bold: true),
                            _TableCell(
                              text: 'Farmakoloji Ders Notları.pdf',
                              bold: true,
                            ),
                            _TableCell(
                              text: 'Kardiyovasküler Sistem.pptx',
                              bold: true,
                            ),
                            _TableCell(text: 'Fark / Benzerlik', bold: true),
                          ],
                        ),
                        for (final row in rows)
                          TableRow(
                            children: [
                              _TableCell(text: row[0]),
                              _TableCell(text: row[1]),
                              _TableCell(text: row[2]),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: _SimilarityPill(
                                  different: row[3] == 'Farklı',
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell({required this.text, this.bold = false});

  final String text;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.navy,
          fontSize: 12.5,
          height: 1.25,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _SimilarityPill extends StatelessWidget {
  const _SimilarityPill({required this.different});

  final bool different;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: different ? AppColors.redBg : AppColors.greenBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: different
              ? AppColors.red.withValues(alpha: .12)
              : AppColors.green.withValues(alpha: .12),
        ),
      ),
      child: Text(
        different ? 'Farklı' : 'Benzer',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: different ? AppColors.red : AppColors.green,
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _QueueMetric extends StatelessWidget {
  const _QueueMetric({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _BasePanel(
      child: Row(
        children: [
          CircleAvatar(
            radius: 31,
            backgroundColor: color.withValues(alpha: .11),
            child: Icon(icon, color: color, size: 36),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color == AppColors.orange ? AppColors.navy : color,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.muted, fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueFilter extends StatelessWidget {
  const _QueueFilter({
    required this.label,
    this.selected = false,
    this.dot,
    this.onTap,
  });

  final String label;
  final bool selected;
  final Color? dot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: selected ? AppColors.blue : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: selected ? AppColors.blue : AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[
            CircleAvatar(radius: 5, backgroundColor: dot),
            const SizedBox(width: 10),
          ],
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.navy,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.source,
    required this.title,
    required this.time,
    required this.onAction,
    this.progress,
    this.complete = false,
    this.failed = false,
    this.filterStatus = '',
  });

  final _BFSource source;
  final String title;
  final String time;
  final VoidCallback onAction;
  final double? progress;
  final bool complete;
  final bool failed;
  final String filterStatus;

  @override
  Widget build(BuildContext context) {
    final kind = failed
        ? GeneratedKind.algorithm
        : title.startsWith('Soru')
        ? GeneratedKind.question
        : title.startsWith('Sınav')
        ? GeneratedKind.summary
        : title.startsWith('Karşılaştırma')
        ? GeneratedKind.table
        : GeneratedKind.flashcard;

    final statusIcon = complete
        ? Icons.check_circle_rounded
        : failed
        ? Icons.error_rounded
        : Icons.schedule_rounded;
    final statusColor = complete
        ? AppColors.green
        : failed
        ? AppColors.red
        : AppColors.navy;
    final actionIcon = complete
        ? Icons.visibility_rounded
        : failed
        ? Icons.refresh_rounded
        : Icons.stop_rounded;
    final actionLabel = complete
        ? 'Gör'
        : failed
        ? 'Tekrar Dene'
        : 'Durdur';

    final fileInfo = Row(
      children: [
        FileKindBadge(kind: source.kind, large: true),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                source.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                '${source.size}  •  ${source.pages}',
                style: const TextStyle(color: AppColors.muted, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );

    final productionInfo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _RoundGeneratedIcon(kind: kind, size: 50),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        if (progress != null) ...[
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 9,
                    backgroundColor: AppColors.line,
                    valueColor: const AlwaysStoppedAnimation(AppColors.blue),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '%${(progress! * 100).round()}',
                style: const TextStyle(
                  color: AppColors.blue,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: StatusPill(
              status: failed
                  ? DriveItemStatus.failed
                  : DriveItemStatus.completed,
              compact: true,
            ),
          ),
      ],
    );

    final statusInfo = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(statusIcon, color: statusColor, size: 22),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            time,
            style: TextStyle(
              color: statusColor,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );

    final actionButton = OutlinedButton.icon(
      onPressed: onAction,
      icon: Icon(actionIcon),
      label: Text(actionLabel),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.blue,
        side: const BorderSide(color: AppColors.blue),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _BasePanel(
        padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 720) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  fileInfo,
                  const SizedBox(height: 14),
                  const Divider(color: AppColors.softLine),
                  const SizedBox(height: 12),
                  productionInfo,
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      statusInfo,
                      actionButton,
                      const _MoreMenuButton(),
                    ],
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(flex: 2, child: fileInfo),
                Container(width: 1, height: 62, color: AppColors.softLine),
                const SizedBox(width: 18),
                Expanded(flex: 2, child: productionInfo),
                Container(
                  width: 1,
                  height: 62,
                  margin: const EdgeInsets.symmetric(horizontal: 18),
                  color: AppColors.softLine,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Center(child: statusInfo),
                      const SizedBox(height: 12),
                      actionButton,
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const _MoreMenuButton(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _QuickResultAction extends StatelessWidget {
  const _QuickResultAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.blue,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 27),
        label: Text(label, textAlign: TextAlign.center, maxLines: 2),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          backgroundColor: color.withValues(alpha: .04),
          side: BorderSide(color: color.withValues(alpha: .18)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w900,
            height: 1.12,
          ),
        ),
      ),
    );
  }
}

class _WeeklyStats extends StatelessWidget {
  const _WeeklyStats();

  @override
  Widget build(BuildContext context) {
    const stats = [
      _StatDatum(GeneratedKind.flashcard, '48', 'Kart'),
      _StatDatum(GeneratedKind.question, '20', 'Soru'),
      _StatDatum(GeneratedKind.summary, '1', 'Özet'),
      _StatDatum(GeneratedKind.algorithm, '3', 'Algoritma'),
      _StatDatum(GeneratedKind.table, '2', 'Tablo'),
    ];
    return _ResponsiveGrid(
      minItemWidth: 135,
      children: [
        for (final stat in stats)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RoundGeneratedIcon(kind: stat.kind, size: 52),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stat.value,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      stat.label,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _StatDatum {
  const _StatDatum(this.kind, this.value, this.label);

  final GeneratedKind kind;
  final String value;
  final String label;
}

class _MiniKindFilter extends StatelessWidget {
  const _MiniKindFilter({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kind = _kindForTurkishLabel(label);
    final color = generatedColor(kind);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: .12) : Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? color.withValues(alpha: .24) : AppColors.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(generatedIcon(kind), color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenerationListRow extends StatelessWidget {
  const _GenerationListRow({
    required this.data,
    required this.onOpen,
    required this.onShare,
    required this.onRegenerate,
  });

  final _GenerationRowData data;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final kind = _kindForTurkishLabel(data.kind);
    final titleBlock = Row(
      children: [
        _RoundGeneratedIcon(kind: kind, size: 66),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.title,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Kaynak: ${data.source}',
                style: const TextStyle(color: AppColors.muted, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    color: AppColors.softText,
                    size: 17,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    data.time,
                    style: const TextStyle(
                      color: AppColors.softText,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
    final kindBlock = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _KindPill(label: data.kind, kind: kind),
        const SizedBox(height: 8),
        Text(
          data.count,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
    final actions = [
      _RowAction(icon: Icons.visibility_outlined, label: 'Gör', onTap: onOpen),
      _RowAction(icon: Icons.share_outlined, label: 'Paylaş', onTap: onShare),
      _RowAction(
        icon: Icons.refresh_rounded,
        label: 'Yeniden Üret',
        onTap: onRegenerate,
      ),
      const _MoreMenuButton(color: AppColors.navy),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _BasePanel(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 720) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleBlock,
                  const SizedBox(height: 14),
                  kindBlock,
                  const SizedBox(height: 14),
                  Wrap(spacing: 12, runSpacing: 10, children: actions),
                ],
              );
            }
            return Row(
              children: [
                Expanded(flex: 3, child: titleBlock),
                Expanded(child: kindBlock),
                Container(
                  width: 1,
                  height: 80,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: AppColors.line,
                ),
                ...actions,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _KindPill extends StatelessWidget {
  const _KindPill({required this.label, required this.kind});

  final String label;
  final GeneratedKind kind;

  @override
  Widget build(BuildContext context) {
    final color = generatedColor(kind);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(generatedIcon(kind), color: color, size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RowAction extends StatelessWidget {
  const _RowAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: AppColors.navy, size: 24),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreMenuButton extends StatelessWidget {
  const _MoreMenuButton({this.color = AppColors.muted});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Diğer işlemler',
      onPressed: () => _showBaseForceToast(context, 'Bu özellik henüz hazır değil.'),
      icon: Icon(Icons.more_vert_rounded, color: color),
      visualDensity: VisualDensity.compact,
    );
  }
}

GeneratedKind _kindForTurkishLabel(String label) {
  return switch (label) {
    'Soru' => GeneratedKind.question,
    'Özet' => GeneratedKind.summary,
    'Algoritma' => GeneratedKind.algorithm,
    'Tablo' => GeneratedKind.table,
    _ => GeneratedKind.flashcard,
  };
}

class _BFSource {
  const _BFSource({
    required this.id,
    required this.name,
    required this.kind,
    required this.size,
    required this.pages,
    required this.subject,
    required this.time,
    this.warning = false,
  });

  final String id;
  final String name;
  final DriveFileKind kind;
  final String size;
  final String pages;
  final String subject;
  final String time;
  final bool warning;
}

class _GenerationRowData {
  const _GenerationRowData({
    required this.title,
    required this.source,
    required this.kind,
    required this.count,
    required this.time,
  });

  final String title;
  final String source;
  final String kind;
  final String count;
  final String time;
}
