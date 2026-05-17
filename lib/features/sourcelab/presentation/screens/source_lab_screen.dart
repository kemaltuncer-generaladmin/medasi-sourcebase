import 'dart:math' as math;
import 'dart:ui' hide Color, Gradient, Image, TextStyle;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sourcebase_brand.dart';
import '../../../drive/data/drive_models.dart';
import '../../../drive/presentation/widgets/drive_ui.dart';
import '../../../drive/presentation/widgets/sourcebase_bottom_nav.dart';

enum SourceLabView {
  home,
  clinicalBuilder,
  clinicalResult,
  planBuilder,
  planResult,
  podcastBuilder,
  podcastResult,
  infographicBuilder,
  infographicResult,
  mindMapBuilder,
  mindMapResult,
}

enum _ToolKind { clinical, plan, podcast, infographic, mindMap }

enum _HeroArtKind { lab, clinical, plan, podcast, infographic, mindMap }

class SourceLabScreen extends StatefulWidget {
  const SourceLabScreen({
    required this.data,
    required this.onSearch,
    super.key,
  });

  final DriveWorkspaceData data;
  final VoidCallback onSearch;

  @override
  State<SourceLabScreen> createState() => _SourceLabScreenState();
}

class _SourceLabScreenState extends State<SourceLabScreen> {
  SourceLabView view = SourceLabView.home;
  late List<_LabSource> selectedSources;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    selectedSources = _sourcePool(widget.data);
  }

  String clinicalType = '';
  String clinicalDifficulty = '';
  String clinicalLevel = '';
  String clinicalBranch = '';
  double patientAge = 0;
  bool clinicalFeedback = true;

  String planGoal = '';
  String planPriority = '';
  String planIntensity = '';
  int planDays = 1;
  String dailyDuration = '';
  bool includeReviews = true;

  String podcastVoice = '';
  String podcastDuration = '';
  String podcastFocus = '';
  double podcastPace = .5;
  bool includeMiniQuiz = true;
  bool podcastPlaying = false;
  double podcastPosition = 0;

  String infographicStyle = 'Akademik';
  String infographicSize = 'Dikey';
  String infographicDensity = 'Orta';
  Color infographicAccent = AppColors.blue;
  bool showInfographicSources = true;

  String mapKind = 'Konu Bazlı';
  String mapDepth = 'Orta';
  String mapLook = 'Renkli';
  bool expandChildren = true;
  final Set<String> mapTopics = {
    'Patofizyoloji',
    'Klinik',
    'Tanı',
    'Tedavi',
    'Komplikasyonlar',
    'İlaçlar',
  };

  void _open(SourceLabView next) {
    setState(() => view = next);
  }

  void _back() {
    setState(() {
      view = switch (view) {
        SourceLabView.clinicalResult => SourceLabView.clinicalBuilder,
        SourceLabView.planResult => SourceLabView.planBuilder,
        SourceLabView.podcastResult => SourceLabView.podcastBuilder,
        SourceLabView.infographicResult => SourceLabView.infographicBuilder,
        SourceLabView.mindMapResult => SourceLabView.mindMapBuilder,
        _ => SourceLabView.home,
      };
    });
  }

  void _generate(SourceLabView resultView) {
    setState(() {
      _isLoading = true;
      view = resultView;
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1200),
        ),
      );
  }

  void _openTool(_ToolKind tool) {
    _open(switch (tool) {
      _ToolKind.clinical => SourceLabView.clinicalBuilder,
      _ToolKind.plan => SourceLabView.planBuilder,
      _ToolKind.podcast => SourceLabView.podcastBuilder,
      _ToolKind.infographic => SourceLabView.infographicBuilder,
      _ToolKind.mindMap => SourceLabView.mindMapBuilder,
    });
  }

  void _removeSource(String id) {
    if (selectedSources.length == 1) {
      _toast('En az bir kaynak seçili kalmalı.');
      return;
    }
    setState(() => selectedSources.removeWhere((source) => source.id == id));
  }

  void _showSourcePicker() {
    final pool = _sourcePool(widget.data);
    final selectedIds = selectedSources.map((source) => source.id).toSet();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            void toggle(_LabSource source) {
              modalSetState(() {
                if (selectedIds.contains(source.id)) {
                  if (selectedIds.length == 1) {
                    return;
                  }
                  selectedIds.remove(source.id);
                } else {
                  selectedIds.add(source.id);
                }
              });
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Drive Kaynakları',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'SourceLab araçlarında kullanılacak dosyaları seç.',
                      style: TextStyle(color: AppColors.muted, fontSize: 15),
                    ),
                    const SizedBox(height: 18),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemBuilder: (context, index) {
                          final source = pool[index];
                          final selected = selectedIds.contains(source.id);
                          return _SourcePickerRow(
                            source: source,
                            selected: selected,
                            onTap: () => toggle(source),
                          );
                        },
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemCount: pool.length,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _PrimaryLabButton(
                      label: 'Seçimi Kullan',
                      icon: Icons.check_rounded,
                      onTap: () {
                        setState(() {
                          selectedSources = pool
                              .where(
                                (source) => selectedIds.contains(source.id),
                              )
                              .toList();
                        });
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: KeyedSubtree(
            key: ValueKey(view),
            child: switch (view) {
          SourceLabView.home => _SourceLabHome(
            selectedSources: selectedSources,
            onSearch: widget.onSearch,
            onPickSources: _showSourcePicker,
            onOpenTool: _openTool,
            onContinue: () => _openTool(_ToolKind.clinical),
            onToast: _toast,
          ),
          SourceLabView.clinicalBuilder => _ClinicalScenarioBuilder(
            selectedSources: selectedSources,
            clinicalType: clinicalType,
            difficulty: clinicalDifficulty,
            level: clinicalLevel,
            branch: clinicalBranch,
            patientAge: patientAge,
            feedback: clinicalFeedback,
            onBack: _back,
            onSearch: widget.onSearch,
            onPickSources: _showSourcePicker,
            onRemoveSource: _removeSource,
            onClinicalType: (value) => setState(() => clinicalType = value),
            onDifficulty: (value) => setState(() => clinicalDifficulty = value),
            onLevel: (value) => setState(() => clinicalLevel = value),
            onBranch: (value) => setState(() => clinicalBranch = value),
            onAge: (value) => setState(() => patientAge = value),
            onFeedback: (value) => setState(() => clinicalFeedback = value),
            onGenerate: () => _generate(SourceLabView.clinicalResult),
          ),
          SourceLabView.clinicalResult => _ClinicalScenarioResult(
            onBack: _back,
            onSearch: widget.onSearch,
            onSave: () => _toast('Bu özellik henüz hazır değil.'),
            onExport: () => _toast('Bu özellik henüz hazır değil.'),
            onRegenerate: () => _open(SourceLabView.clinicalBuilder),
            onComplete: () => _toast('Bu özellik henüz hazır değil.'),
          ),
          SourceLabView.planBuilder => _LearningPlanBuilder(
            selectedSources: selectedSources,
            goal: planGoal,
            priority: planPriority,
            intensity: planIntensity,
            days: planDays,
            dailyDuration: dailyDuration,
            includeReviews: includeReviews,
            onBack: _back,
            onSearch: widget.onSearch,
            onPickSources: _showSourcePicker,
            onGoal: (value) => setState(() => planGoal = value),
            onPriority: (value) => setState(() => planPriority = value),
            onIntensity: (value) => setState(() => planIntensity = value),
            onDaysChanged: (value) => setState(() => planDays = value),
            onDuration: (value) => setState(() => dailyDuration = value),
            onReviews: (value) => setState(() => includeReviews = value),
            onGenerate: () => _generate(SourceLabView.planResult),
          ),
          SourceLabView.planResult => _LearningPlanResult(
            selectedSources: selectedSources,
            planDays: planDays,
            planGoal: planGoal,
            onBack: _back,
            onSave: () => _toast('Bu özellik henüz hazır değil.'),
            onCalendar: () => _toast('Bu özellik henüz hazır değil.'),
            onExport: () => _toast('Bu özellik henüz hazır değil.'),
            onRegenerate: () => _open(SourceLabView.planBuilder),
          ),
          SourceLabView.podcastBuilder => _PodcastBuilder(
            selectedSources: selectedSources,
            voice: podcastVoice,
            duration: podcastDuration,
            focus: podcastFocus,
            pace: podcastPace,
            includeMiniQuiz: includeMiniQuiz,
            onBack: _back,
            onSearch: widget.onSearch,
            onPickSources: _showSourcePicker,
            onRemoveSource: _removeSource,
            onVoice: (value) => setState(() => podcastVoice = value),
            onDuration: (value) => setState(() => podcastDuration = value),
            onFocus: (value) => setState(() => podcastFocus = value),
            onPace: (value) => setState(() => podcastPace = value),
            onMiniQuiz: (value) => setState(() => includeMiniQuiz = value),
            onGenerate: () => _generate(SourceLabView.podcastResult),
          ),
          SourceLabView.podcastResult => _PodcastResult(
            playing: podcastPlaying,
            position: podcastPosition,
            onBack: _back,
            onTogglePlay: () =>
                setState(() => podcastPlaying = !podcastPlaying),
            onPosition: (value) => setState(() => podcastPosition = value),
            onSpeed: () => _toast('Bu özellik henüz hazır değil.'),
            onShare: () => _toast('Bu özellik henüz hazır değil.'),
            onExport: () => _toast('Bu özellik henüz hazır değil.'),
            onRegenerate: () => _open(SourceLabView.podcastBuilder),
            onSave: () => _toast('Bu özellik henüz hazır değil.'),
            onSkipBack: () {
              setState(() {
                podcastPosition = math.max(0, podcastPosition - .08);
              });
            },
            onSkipForward: () {
              setState(() {
                podcastPosition = math.min(1, podcastPosition + .08);
              });
            },
            onVolume: () => _toast('Bu özellik henüz hazır değil.'),
          ),
          SourceLabView.infographicBuilder => _InfographicBuilder(
            selectedSources: selectedSources,
            style: infographicStyle,
            size: infographicSize,
            density: infographicDensity,
            accent: infographicAccent,
            showSources: showInfographicSources,
            onBack: _back,
            onSearch: widget.onSearch,
            onPickSources: _showSourcePicker,
            onStyle: (value) => setState(() => infographicStyle = value),
            onSize: (value) => setState(() => infographicSize = value),
            onDensity: (value) => setState(() => infographicDensity = value),
            onAccent: (value) => setState(() => infographicAccent = value),
            onShowSources: (value) =>
                setState(() => showInfographicSources = value),
            onGenerate: () => _generate(SourceLabView.infographicResult),
          ),
          SourceLabView.infographicResult => _InfographicResult(
            onBack: _back,
            onSearch: widget.onSearch,
            onSave: () => _toast('Bu özellik henüz hazır değil.'),
            onPng: () => _toast('Bu özellik henüz hazır değil.'),
            onPdf: () => _toast('Bu özellik henüz hazır değil.'),
            onRegenerate: () => _open(SourceLabView.infographicBuilder),
          ),
          SourceLabView.mindMapBuilder => _MindMapBuilder(
            selectedSources: selectedSources,
            mapKind: mapKind,
            depth: mapDepth,
            look: mapLook,
            topics: mapTopics,
            expandChildren: expandChildren,
            onBack: _back,
            onSearch: widget.onSearch,
            onPickSources: _showSourcePicker,
            onRemoveSource: _removeSource,
            onMapKind: (value) => setState(() => mapKind = value),
            onDepth: (value) => setState(() => mapDepth = value),
            onLook: (value) => setState(() => mapLook = value),
            onToggleTopic: (topic) {
              setState(() {
                if (mapTopics.contains(topic)) {
                  if (mapTopics.length == 1) {
                    return;
                  }
                  mapTopics.remove(topic);
                } else {
                  mapTopics.add(topic);
                }
              });
            },
            onExpandChildren: (value) => setState(() => expandChildren = value),
            onGenerate: () => _generate(SourceLabView.mindMapResult),
          ),
          SourceLabView.mindMapResult => _MindMapResult(
            onBack: _back,
            onSave: () => _toast('Bu özellik henüz hazır değil.'),
            onExport: () => _toast('Bu özellik henüz hazır değil.'),
            onRegenerate: () => _open(SourceLabView.mindMapBuilder),
          ),
            },
          ),
        ),
        if (_isLoading)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.page.withValues(alpha: .72),
              ),
              child: const Center(
                child: _LabLoadingCard(),
              ),
            ),
          ),
      ],
    );
  }
}

class _LabLoadingCard extends StatelessWidget {
  const _LabLoadingCard();

  @override
  Widget build(BuildContext context) {
    return _LabPanel(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      radius: 18,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          SizedBox(width: 14),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 220),
            child: Text(
              'SourceLab önizlemesi hazırlanıyor...',
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabSource {
  const _LabSource({
    required this.id,
    required this.title,
    required this.kind,
    required this.size,
    required this.detail,
    required this.tag,
  });

  final String id;
  final String title;
  final DriveFileKind kind;
  final String size;
  final String detail;
  final String tag;
}

List<_LabSource> _sourcePool(DriveWorkspaceData data) {
  final converted = <_LabSource>[];
  for (final file in data.recentFiles) {
    converted.add(
      _LabSource(
        id: 'drive-${file.id}',
        title: file.title,
        kind: file.kind,
        size: file.sizeLabel,
        detail: file.pageLabel,
        tag: file.tag ?? file.courseTitle,
      ),
    );
  }
  return converted;
}

void _showLabSnack(BuildContext context, String message) {
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

class _SourceLabHome extends StatelessWidget {
  const _SourceLabHome({
    required this.selectedSources,
    required this.onSearch,
    required this.onPickSources,
    required this.onOpenTool,
    required this.onContinue,
    required this.onToast,
  });

  final List<_LabSource> selectedSources;
  final VoidCallback onSearch;
  final VoidCallback onPickSources;
  final ValueChanged<_ToolKind> onOpenTool;
  final VoidCallback onContinue;
  final ValueChanged<String> onToast;

  @override
  Widget build(BuildContext context) {
    return _LabScroll(
      children: [
        _LabTopBar(onSearch: onSearch),
        _LabHero(
          title: 'SourceLab',
          subtitle:
              'Drive’dan gelen kaynaklar klinik öğrenme\nve kişisel çalışma araçlarına dönüştürülür.',
          art: _HeroArtKind.lab,
          chips: const [
            _MiniHeroChip(icon: Icons.verified_user_outlined, label: 'Güvenli'),
            _MiniHeroChip(icon: Icons.bolt_outlined, label: 'Hızlı'),
            _MiniHeroChip(icon: Icons.auto_awesome_outlined, label: 'Akıllı'),
          ],
        ),
        _HomeContinuePanel(
          sources: selectedSources,
          onPickSources: onPickSources,
          onContinue: onContinue,
        ),
        _SectionHeader(
          title: 'Hızlı Başlat',
          action: 'Tüm araçları gör',
          onTap: () => onToast('Tüm SourceLab araçları bu ekranda hazır.'),
        ),
        _ToolGrid(onOpenTool: onOpenTool),
        _SectionHeader(
          title: 'Son Kaynaklar',
          action: 'Tümünü gör',
          onTap: onPickSources,
        ),
        _LabPanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < selectedSources.length; i++)
                _RecentSourceRow(
                  source: selectedSources[i],
                  trailing: 'Şimdi',
                  onTap: onPickSources,
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _ResponsiveSplit(
          children: [
            _SmartSuggestionsPanel(onOpenTool: onOpenTool, onToast: onToast),
            _RecentActivitiesPanel(onOpenTool: onOpenTool),
          ],
        ),
      ],
    );
  }
}

class _HomeContinuePanel extends StatelessWidget {
  const _HomeContinuePanel({
    required this.sources,
    required this.onPickSources,
    required this.onContinue,
  });

  final List<_LabSource> sources;
  final VoidCallback onPickSources;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return _LabPanel(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final title = Row(
                children: [
                  const Icon(
                    Icons.change_history_rounded,
                    color: AppColors.blue,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Drive’dan Devam Et',
                          style: TextStyle(
                            color: AppColors.navy,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Drive’ınızdan seçtiğiniz ${sources.length} kaynak',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final button = _PrimaryLabButton(
                label: 'Devam Et',
                icon: Icons.arrow_forward_rounded,
                onTap: onContinue,
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [title, const SizedBox(height: 16), button],
                );
              }

              return Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 18),
                  SizedBox(width: 190, child: button),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          _SourceGrid(
            sources: sources,
            allowRemove: false,
            onRemove: (_) {},
            onMenu: onPickSources,
          ),
        ],
      ),
    );
  }
}

class _ToolGrid extends StatelessWidget {
  const _ToolGrid({required this.onOpenTool});

  final ValueChanged<_ToolKind> onOpenTool;

  @override
  Widget build(BuildContext context) {
    final tools = [
      _ToolSpec(
        _ToolKind.clinical,
        Icons.medical_services_outlined,
        'Klinik Senaryo',
        'Kaynaklarınızı klinik\nvaka senaryolarına\ndönüştürün.',
        AppColors.purple,
      ),
      _ToolSpec(
        _ToolKind.plan,
        Icons.fact_check_outlined,
        'Öğrenme Planı',
        'Kişiselleştirilmiş\nöğrenme planları\noluşturun.',
        AppColors.green,
      ),
      _ToolSpec(
        _ToolKind.podcast,
        Icons.keyboard_voice_outlined,
        'Podcast Özeti',
        'Kaynaklarınızı\npodcast formatında\nözetleyin.',
        const Color(0xFF8C5BFF),
      ),
      _ToolSpec(
        _ToolKind.infographic,
        Icons.insert_chart_outlined_rounded,
        'İnfografik',
        'Önemli bilgileri\ngörsel infografiklere\ndönüştürün.',
        AppColors.cyan,
      ),
      _ToolSpec(
        _ToolKind.mindMap,
        Icons.hub_outlined,
        'Zihin Haritası',
        'Kavramları zihin\nharitası ile ilişkilendirin\nve organize edin.',
        AppColors.blue,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 5
            : constraints.maxWidth >= 640
            ? 3
            : 2;
        final gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tool in tools)
              SizedBox(
                width: width,
                child: _ToolCard(
                  spec: tool,
                  onTap: () => onOpenTool(tool.kind),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ToolSpec {
  const _ToolSpec(this.kind, this.icon, this.title, this.subtitle, this.color);

  final _ToolKind kind;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.spec, required this.onTap});

  final _ToolSpec spec;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _LabPanel(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
      radius: 16,
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: spec.color.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(spec.icon, color: spec.color, size: 34),
          ),
          const SizedBox(height: 15),
          Text(
            spec.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 18,
              height: 1.08,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            spec.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              height: 1.23,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 13),
          _SmallActionButton(label: 'Başlat', onTap: onTap),
        ],
      ),
    );
  }
}

class _SmartSuggestionsPanel extends StatelessWidget {
  const _SmartSuggestionsPanel({
    required this.onOpenTool,
    required this.onToast,
  });

  final ValueChanged<_ToolKind> onOpenTool;
  final ValueChanged<String> onToast;

  @override
  Widget build(BuildContext context) {
    return _LabPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InlineHeader(
            icon: Icons.auto_awesome_outlined,
            title: 'Akıllı Öneriler',
            action: 'Tümünü gör',
            onAction: () => onToast('Öneriler güncellendi.'),
          ),
          _SuggestionRow(
            icon: Icons.psychology_outlined,
            color: AppColors.cyan,
            text:
                'Yüklediğin kaynaklardan istediğin konuda özetler çıkarabilirsin.',
            onTap: () => onOpenTool(_ToolKind.infographic),
          ),
          _SuggestionRow(
            icon: Icons.medical_services_outlined,
            color: AppColors.purple,
            text:
                'Kardiyovasküler Sistem.pptx ile klinik senaryo oluşturmayı deneyin.',
            onTap: () => onOpenTool(_ToolKind.clinical),
          ),
          _SuggestionRow(
            icon: Icons.keyboard_voice_outlined,
            color: AppColors.blue,
            text:
                'Ders notlarını podcast formatında dinleyebilirsin.',
            onTap: () => onOpenTool(_ToolKind.podcast),
          ),
        ],
      ),
    );
  }
}

class _RecentActivitiesPanel extends StatelessWidget {
  const _RecentActivitiesPanel({required this.onOpenTool});

  final ValueChanged<_ToolKind> onOpenTool;

  @override
  Widget build(BuildContext context) {
    return _LabPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InlineHeader(
            icon: Icons.history_rounded,
            title: 'Son Etkinlikler',
            action: 'Tümünü gör',
            onAction: () => onOpenTool(_ToolKind.plan),
          ),
          _ActivityRow(
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.green,
            title: 'Öğrenme planınız güncellendi',
            subtitle: 'Yeni özellikler eklendi',
            time: '2 saat önce',
            onTap: () => onOpenTool(_ToolKind.plan),
          ),
          _ActivityRow(
            icon: Icons.keyboard_voice_outlined,
            color: AppColors.purple,
            title: 'Podcast özeti oluşturuldu',
            subtitle: 'Kardiyovasküler Sistem.pptx',
            time: '5 saat önce',
            onTap: () => onOpenTool(_ToolKind.podcast),
          ),
          _ActivityRow(
            icon: Icons.insert_chart_outlined_rounded,
            color: AppColors.blue,
            title: 'İnfografik oluşturuldu',
            subtitle: 'Yeni kaynak yüklendi',
            time: '1 gün önce',
            onTap: () => onOpenTool(_ToolKind.infographic),
          ),
          _ActivityRow(
            icon: Icons.star_border_rounded,
            color: AppColors.orange,
            title: 'Klinik senaryo taslağı kaydedildi',
            subtitle: 'Akut MI - Vaka Senaryosu',
            time: '1 gün önce',
            onTap: () => onOpenTool(_ToolKind.clinical),
          ),
        ],
      ),
    );
  }
}

class _ClinicalScenarioBuilder extends StatelessWidget {
  const _ClinicalScenarioBuilder({
    required this.selectedSources,
    required this.clinicalType,
    required this.difficulty,
    required this.level,
    required this.branch,
    required this.patientAge,
    required this.feedback,
    required this.onBack,
    required this.onSearch,
    required this.onPickSources,
    required this.onRemoveSource,
    required this.onClinicalType,
    required this.onDifficulty,
    required this.onLevel,
    required this.onBranch,
    required this.onAge,
    required this.onFeedback,
    required this.onGenerate,
  });

  final List<_LabSource> selectedSources;
  final String clinicalType;
  final String difficulty;
  final String level;
  final String branch;
  final double patientAge;
  final bool feedback;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback onPickSources;
  final ValueChanged<String> onRemoveSource;
  final ValueChanged<String> onClinicalType;
  final ValueChanged<String> onDifficulty;
  final ValueChanged<String> onLevel;
  final ValueChanged<String> onBranch;
  final ValueChanged<double> onAge;
  final ValueChanged<bool> onFeedback;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return _LabScroll(
      children: [
        _LabTopBar(onBack: onBack, onSearch: onSearch),
        _LabHero(
          title: 'Klinik Senaryo',
          subtitle:
              'Drive’dan seçtiğin kaynakları hasta\nsenaryolarına dönüştür.',
          art: _HeroArtKind.clinical,
        ),
        _StepPanel(
          number: 1,
          title: 'Seçili Kaynaklar',
          trailing: _DriveAddButton(onTap: onPickSources),
          child: Column(
            children: [
              _SourceList(
                sources: selectedSources,
                onRemove: onRemoveSource,
                onReorder: () =>
                    _showLabSnack(context, 'Kaynak sırası güncellendi.'),
              ),
              const SizedBox(height: 12),
              _DashedAddRow(
                label: 'Başka kaynak eklemek için Drive’dan seç',
                onTap: onPickSources,
              ),
            ],
          ),
        ),
        _StepPanel(
          number: 2,
          title: 'Senaryo Ayarları',
          child: LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth > 700;
              final left = Column(
                children: [
                  _SettingRow(
                    label: 'Senaryo Türü',
                    child: _SegmentedOptions(
                      values: const ['Acil', 'Poliklinik', 'Yataklı Servis'],
                      selected: clinicalType,
                      onSelected: onClinicalType,
                    ),
                  ),
                  _SettingRow(
                    label: 'Öğrenci Seviyesi',
                    child: _SegmentedOptions(
                      values: const ['Dönem 3', 'Dönem 4', 'İntörn'],
                      selected: level,
                      onSelected: onLevel,
                    ),
                  ),
                  _SettingRow(
                    label: 'Hasta Yaşı',
                    child: _LabeledSlider(
                      value: patientAge,
                      min: 16,
                      max: 90,
                      label: '${patientAge.round()} yaş',
                      leftLabel: '16',
                      rightLabel: '90+',
                      onChanged: onAge,
                    ),
                  ),
                ],
              );
              final right = Column(
                children: [
                  _SettingRow(
                    label: 'Zorluk',
                    child: _SegmentedOptions(
                      values: const ['Kolay', 'Orta', 'Zor'],
                      selected: difficulty,
                      onSelected: onDifficulty,
                    ),
                  ),
                  _SettingRow(
                    label: 'Branş',
                    child: _SelectBox(
                      icon: Icons.favorite_border_rounded,
                      label: branch,
                      onTap: () => onBranch(
                        branch == 'Kategori 1' ? 'Kategori 2' : 'Kategori 1',
                      ),
                    ),
                  ),
                  _SwitchSetting(
                    title: 'Açıklamalı Geri Bildirim',
                    subtitle: 'Senaryonun sonunda detaylı geri bildirim ver.',
                    value: feedback,
                    onChanged: onFeedback,
                  ),
                ],
              );
              if (!twoColumns) {
                return Column(
                  children: [left, const SizedBox(height: 12), right],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: left),
                  const SizedBox(width: 28),
                  Expanded(child: right),
                ],
              );
            },
          ),
        ),
        _StepPanel(
          number: 3,
          title: 'Odak Alanları',
          child: _FocusChips(
            labels: const [
              'Tanı',
              'Tetkik',
              'Tedavi',
              'Ayırıcı Tanı',
              'Komplikasyonlar',
            ],
            selectedLabels: const {'Tanı', 'Tetkik', 'Tedavi', 'Ayırıcı Tanı'},
            onTap: (label) =>
                _showLabSnack(context, '$label odağı güncellendi.'),
          ),
        ),
        _StepPanel(
          number: 4,
          title: 'Önizleme',
          trailing: const _InfoPill(label: 'Tahmini süre: 12-15 dk'),
          child: const _ResponsiveSplit(
            breakpoint: 720,
            children: [
              SizedBox(width: 140, height: 140, child: _PatientAvatar()),
              _PreviewTextBlock(
                title: '58 yaş erkek hasta, göğüs ağrısı...',
                body:
                    'Eforla artan göğüs ağrısı ve nefes darlığı şikayetiyle acil servise başvuran hastada akut koroner sendrom ön tanısı değerlendirilecek.',
              ),
              _LearningGoalsPreview(),
            ],
          ),
        ),
        _SummaryActionBar(
          icon: Icons.description_outlined,
          title: 'Özet',
          detail:
              '${selectedSources.length} kaynak  •  $clinicalType senaryo  •  $difficulty zorluk  •  $level  •  $branch  •  ${patientAge.round()} yaş',
          buttonLabel: 'Senaryoyu Oluştur',
          onTap: onGenerate,
        ),
      ],
    );
  }
}

class _ClinicalScenarioResult extends StatelessWidget {
  const _ClinicalScenarioResult({
    required this.onBack,
    required this.onSearch,
    required this.onSave,
    required this.onExport,
    required this.onRegenerate,
    required this.onComplete,
  });

  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback onSave;
  final VoidCallback onExport;
  final VoidCallback onRegenerate;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return _LabScroll(
      children: [
        _LabTopBar(onBack: onBack, onSearch: onSearch),
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 18),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final titleBlock = const _TitleBlock(
                title: 'Klinik Senaryo',
                subtitle:
                    'Vaka üzerinden ilerle, karar ver ve geri bildirim al.',
              );
              final pill = _InfoPill(
                label: 'Klinik Senaryo',
                icon: Icons.monitor_heart_outlined,
                tint: AppColors.purple,
              );
              if (constraints.maxWidth < 560) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [titleBlock, const SizedBox(height: 14), pill],
                );
              }
              return Row(
                children: [
                  Expanded(child: titleBlock),
                  pill,
                ],
              );
            },
          ),
        ),
        const _PatientVitalsPanel(),
        const _ClinicalStepper(),
        _LabPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _QuestionTitle('Bu bölüm henüz hazır değil.'),
              const SizedBox(height: 18),
              for (final answer in const [
                ('A.', 'Bu bölüm henüz hazır değil.', false),
                ('B.', 'Bu bölüm henüz hazır değil.', false),
                ('C.', 'Bu bölüm henüz hazır değil.', false),
                ('D.', 'Bu bölüm henüz hazır değil.', false),
              ])
                _AnswerRow(
                  prefix: answer.$1,
                  label: answer.$2,
                  selected: answer.$3,
                ),
              const SizedBox(height: 18),
              const _ClinicalFeedbackPanel(),
              const SizedBox(height: 18),
              const _LearningPointsStrip(),
              const SizedBox(height: 18),
              const _ClinicalScorePanel(),
              const SizedBox(height: 20),
              _ResponsiveActions(
                children: [
                  _SecondaryLabButton(
                    label: 'Kaydet',
                    icon: Icons.bookmark_border_rounded,
                    onTap: onSave,
                  ),
                  _SecondaryLabButton(
                    label: 'PDF Olarak Dışa Aktar',
                    icon: Icons.picture_as_pdf_outlined,
                    iconColor: AppColors.red,
                    onTap: onExport,
                  ),
                  _SecondaryLabButton(
                    label: 'Yeniden Üret',
                    icon: Icons.refresh_rounded,
                    onTap: onRegenerate,
                  ),
                  _PrimaryLabButton(
                    label: 'Senaryoyu Tamamla',
                    icon: Icons.arrow_forward_rounded,
                    onTap: onComplete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LearningPlanBuilder extends StatelessWidget {
  const _LearningPlanBuilder({
    required this.selectedSources,
    required this.goal,
    required this.priority,
    required this.intensity,
    required this.days,
    required this.dailyDuration,
    required this.includeReviews,
    required this.onBack,
    required this.onSearch,
    required this.onPickSources,
    required this.onGoal,
    required this.onPriority,
    required this.onIntensity,
    required this.onDaysChanged,
    required this.onDuration,
    required this.onReviews,
    required this.onGenerate,
  });

  final List<_LabSource> selectedSources;
  final String goal;
  final String priority;
  final String intensity;
  final int days;
  final String dailyDuration;
  final bool includeReviews;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback onPickSources;
  final ValueChanged<String> onGoal;
  final ValueChanged<String> onPriority;
  final ValueChanged<String> onIntensity;
  final ValueChanged<int> onDaysChanged;
  final ValueChanged<String> onDuration;
  final ValueChanged<bool> onReviews;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return _LabScroll(
      children: [
        _LabTopBar(onBack: onBack, onSearch: onSearch),
        _LabHero(
          title: 'Öğrenme Planı',
          subtitle:
              'Kaynaklarına, hedeflerine ve sürene göre\nkişisel çalışma planı oluştur.',
          art: _HeroArtKind.plan,
          chips: const [
            _MiniHeroChip(
              icon: Icons.verified_user_outlined,
              label: 'Kişiselleştirilmiş',
            ),
            _MiniHeroChip(icon: Icons.bolt_outlined, label: 'Akıllı Planlama'),
            _MiniHeroChip(
              icon: Icons.analytics_outlined,
              label: 'Veriye Dayalı',
            ),
          ],
        ),
        _StepPanel(
          number: 1,
          title: 'Seçili Kaynaklar',
          trailing: _DriveAddButton(onTap: onPickSources),
          child: _SourceGrid(
            sources: selectedSources,
            allowRemove: false,
            onRemove: (_) {},
            onMenu: onPickSources,
          ),
        ),
        _StepPanel(
          number: 2,
          title: 'Plan Ayarları',
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final topFields = [
                _SettingRow(
                  label: 'Hedef',
                  child: _SegmentedOptions(
                    values: const ['TUS', 'Komite', 'Final'],
                    selected: goal,
                    onSelected: onGoal,
                    icons: const [
                      Icons.medical_services_outlined,
                      Icons.psychology_alt_outlined,
                      Icons.school_outlined,
                    ],
                  ),
                ),
                _SettingRow(
                  label: 'Gün Sayısı',
                  child: _StepperBox(value: days, onChanged: onDaysChanged),
                ),
                _SettingRow(
                  label: 'Günlük Süre',
                  child: _DropdownLike(
                    icon: Icons.schedule_rounded,
                    label: dailyDuration,
                    onTap: () => onDuration(
                      dailyDuration == '2 saat' ? '3 saat' : '2 saat',
                    ),
                  ),
                ),
              ];
              final priorityFields = [
                _SettingRow(
                  label: 'Öncelik Modu',
                  child: _SegmentedOptions(
                    values: const ['Zayıf Konular', 'Karma', 'Hızlı Tekrar'],
                    selected: priority,
                    onSelected: onPriority,
                    icons: const [
                      Icons.track_changes_rounded,
                      Icons.shuffle_rounded,
                      Icons.flash_on_outlined,
                    ],
                  ),
                ),
                _SettingRow(
                  label: 'Çalışma Yoğunluğu',
                  child: _SegmentedOptions(
                    values: const ['Düşük', 'Orta', 'Yüksek'],
                    selected: intensity,
                    onSelected: onIntensity,
                    icons: const [
                      Icons.eco_outlined,
                      Icons.show_chart_rounded,
                      Icons.local_fire_department_outlined,
                    ],
                  ),
                ),
              ];

              List<Widget> rowFor(List<Widget> children) {
                if (compact) {
                  return [
                    for (var i = 0; i < children.length; i++) ...[
                      children[i],
                      if (i != children.length - 1) const SizedBox(height: 4),
                    ],
                  ];
                }
                return [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < children.length; i++) ...[
                        Expanded(child: children[i]),
                        if (i != children.length - 1) const SizedBox(width: 22),
                      ],
                    ],
                  ),
                ];
              }

              return Column(
                children: [
                  ...rowFor(topFields),
                  if (!compact) const SizedBox(height: 2),
                  ...rowFor(priorityFields),
                  _SwitchSetting(
                    title: 'Tekrar Seansları Ekle',
                    subtitle:
                        'Planına spaced repetition tekrar seansları otomatik olarak eklensin.',
                    value: includeReviews,
                    onChanged: onReviews,
                  ),
                ],
              );
            },
          ),
        ),
        _StepPanel(
          number: 3,
          title: 'Odak Konular',
          child: _FocusChips(
            labels: const ['Bu bölüm hazırlanıyor'],
            selectedLabels: const {},
            onTap: (_) {},
          ),
        ),
        _StepPanel(
          number: 4,
          title: 'Plan Önizleme',
          trailing: _SmallActionButton(
            label: 'Tümünü Gör',
            onTap: () => _showLabSnack(context, '7 günlük önizleme açıldı.'),
          ),
          child: const _PlanPreviewCards(),
        ),
        _PlanSummaryBar(
          days: days,
          duration: dailyDuration,
          focus: 5,
          reviews: includeReviews,
          onGenerate: onGenerate,
        ),
      ],
    );
  }
}

class _LearningPlanResult extends StatelessWidget {
  const _LearningPlanResult({
    required this.selectedSources,
    required this.planDays,
    required this.planGoal,
    required this.onBack,
    required this.onSave,
    required this.onCalendar,
    required this.onExport,
    required this.onRegenerate,
  });

  final List<_LabSource> selectedSources;
  final int planDays;
  final String planGoal;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final VoidCallback onCalendar;
  final VoidCallback onExport;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    return _LabScroll(
      children: [
        _ResultHeader(
          topTitle: 'Öğrenme Planı Sonucu',
          title: 'Öğrenme Planın',
          subtitle: '$planDays günlük kişiselleştirilmiş planın hazır.',
          chip: '$planGoal Odaklı',
          onBack: onBack,
          trailing: Icons.ios_share_rounded,
          onTrailing: onExport,
          art: _HeroArtKind.plan,
        ),
        _LabPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Planına Genel Bakış',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              _ResponsiveSplit(
                breakpoint: 760,
                children: [
                  _MetricCard(
                    icon: Icons.calendar_month_outlined,
                    title: 'Toplam Gün',
                    value: '$planDays gün',
                    color: AppColors.purple,
                  ),
                  const _MetricCard(
                    icon: Icons.schedule_rounded,
                    title: 'Toplam Çalışma Süresi',
                    value: '—',
                    color: AppColors.blue,
                  ),
                  const _MetricCard(
                    icon: Icons.view_agenda_outlined,
                    title: 'Toplam Oturum',
                    value: '—',
                    color: AppColors.green,
                  ),
                  _MetricCard(
                    icon: Icons.folder_outlined,
                    title: 'Seçilen Kaynak',
                    value: '${selectedSources.length} kaynak',
                    color: AppColors.orange,
                  ),
                ],
              ),
            ],
          ),
        ),
        const _PlanTimelinePanel(),
        const _ResponsiveSplit(
          children: [_TodayGoalCard(), _WeaknessAlertCard()],
        ),
        const _PlanAnalysisPanel(),
        _ResponsiveActions(
          children: [
            _SecondaryLabButton(
              label: 'Takvime Ekle',
              icon: Icons.calendar_today_outlined,
              onTap: onCalendar,
            ),
            _SecondaryLabButton(
              label: 'PDF Dışa Aktar',
              icon: Icons.picture_as_pdf_outlined,
              iconColor: AppColors.red,
              onTap: onExport,
            ),
            _SecondaryLabButton(
              label: 'Yeniden Planla',
              icon: Icons.refresh_rounded,
              onTap: onRegenerate,
            ),
          ],
        ),
        _PrimaryLabButton(
          label: 'Planı Kaydet',
          icon: Icons.bookmark_border_rounded,
          onTap: onSave,
          height: 72,
        ),
      ],
    );
  }
}

class _PodcastBuilder extends StatelessWidget {
  const _PodcastBuilder({
    required this.selectedSources,
    required this.voice,
    required this.duration,
    required this.focus,
    required this.pace,
    required this.includeMiniQuiz,
    required this.onBack,
    required this.onSearch,
    required this.onPickSources,
    required this.onRemoveSource,
    required this.onVoice,
    required this.onDuration,
    required this.onFocus,
    required this.onPace,
    required this.onMiniQuiz,
    required this.onGenerate,
  });

  final List<_LabSource> selectedSources;
  final String voice;
  final String duration;
  final String focus;
  final double pace;
  final bool includeMiniQuiz;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback onPickSources;
  final ValueChanged<String> onRemoveSource;
  final ValueChanged<String> onVoice;
  final ValueChanged<String> onDuration;
  final ValueChanged<String> onFocus;
  final ValueChanged<double> onPace;
  final ValueChanged<bool> onMiniQuiz;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return _LabScroll(
      children: [
        _LabTopBar(onBack: onBack, onSearch: onSearch),
        _LabHero(
          title: 'Podcast Özeti',
          subtitle:
              'Kaynaklarını dinlenebilir, akıcı ve\nsınav odaklı ses özetlerine dönüştür.',
          art: _HeroArtKind.podcast,
          chips: const [
            _MiniHeroChip(icon: Icons.waves_rounded, label: 'Akıcı'),
            _MiniHeroChip(icon: Icons.control_camera_rounded, label: 'Odaklı'),
            _MiniHeroChip(
              icon: Icons.star_border_rounded,
              label: 'Sınav Odaklı',
            ),
          ],
        ),
        _LabPanel(
          child: Column(
            children: [
              _PanelTitleRow(
                icon: Icons.folder_outlined,
                title: 'Seçili Kaynaklar',
                trailing: _DriveAddButton(onTap: onPickSources),
              ),
              const SizedBox(height: 12),
              _SourceList(
                sources: selectedSources,
                onRemove: onRemoveSource,
                onReorder: () =>
                    _showLabSnack(context, 'Kaynak sırası güncellendi.'),
              ),
            ],
          ),
        ),
        _LabPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PanelTitleRow(
                icon: Icons.auto_awesome_outlined,
                title: 'Ses ve İçerik Ayarları',
              ),
              _SettingRow(
                icon: Icons.mic_none_rounded,
                label: 'Ses Stili',
                child: _SegmentedOptions(
                  values: const ['Akademik', 'Samimi', 'Hızlı Anlatım'],
                  selected: voice,
                  onSelected: onVoice,
                  icons: const [
                    Icons.school_outlined,
                    Icons.sentiment_satisfied_alt_outlined,
                    Icons.flash_on_outlined,
                  ],
                ),
              ),
              _SettingRow(
                icon: Icons.schedule_rounded,
                label: 'Süre',
                child: _SegmentedOptions(
                  values: const ['5 dk', '10 dk', '15 dk'],
                  selected: duration,
                  onSelected: onDuration,
                ),
              ),
              _SettingRow(
                icon: Icons.ads_click_rounded,
                label: 'Odak',
                child: _SegmentedOptions(
                  values: const [
                    'Genel Özet',
                    'Kritik Noktalar',
                    'Yüksek Olasılıklı Sorular',
                  ],
                  selected: focus,
                  onSelected: onFocus,
                ),
              ),
              _SettingRow(
                icon: Icons.speed_rounded,
                label: 'Anlatım Hızı',
                child: _RangeLine(
                  value: pace,
                  leftLabel: 'Yavaş',
                  rightLabel: 'Hızlı',
                  onChanged: onPace,
                ),
              ),
              _SwitchSetting(
                icon: Icons.quiz_outlined,
                title: 'Mini Quiz Ekle',
                subtitle: 'Podcast sonunda kısa quiz ekle.',
                value: includeMiniQuiz,
                onChanged: onMiniQuiz,
              ),
            ],
          ),
        ),
        _LabPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PanelTitleRow(
                icon: Icons.visibility_outlined,
                title: 'Bölüm Önizleme',
                trailing: InkWell(
                  onTap: () =>
                      _showLabSnack(context, 'Önizleme sesi oynatılıyor.'),
                  child: const _InfoPill(
                    label: 'Önizlemeyi Dinle',
                    icon: Icons.play_arrow_rounded,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const _PodcastPreviewFlow(),
            ],
          ),
        ),
        const _PodcastStructurePanel(),
        _PrimaryLabButton(
          label: 'Podcast Oluştur',
          subtitle: 'Tahmini süre: ~10 dk',
          icon: Icons.auto_awesome_rounded,
          onTap: onGenerate,
          height: 76,
        ),
      ],
    );
  }
}

class _PodcastResult extends StatelessWidget {
  const _PodcastResult({
    required this.playing,
    required this.position,
    required this.onBack,
    required this.onTogglePlay,
    required this.onPosition,
    required this.onSpeed,
    required this.onShare,
    required this.onExport,
    required this.onRegenerate,
    required this.onSave,
    required this.onSkipBack,
    required this.onSkipForward,
    required this.onVolume,
  });

  final bool playing;
  final double position;
  final VoidCallback onBack;
  final VoidCallback onTogglePlay;
  final ValueChanged<double> onPosition;
  final VoidCallback onSpeed;
  final VoidCallback onShare;
  final VoidCallback onExport;
  final VoidCallback onRegenerate;
  final VoidCallback onSave;
  final VoidCallback onSkipBack;
  final VoidCallback onSkipForward;
  final VoidCallback onVolume;

  @override
  Widget build(BuildContext context) {
    return _LabScroll(
      children: [
        _MinimalTopBar(
          title: 'Podcast Özeti',
          subtitle: 'Oluşturulan ses özetini dinle, bölümlere atla ve kaydet.',
          onBack: onBack,
        ),
        _LabPanel(
          child: const _ResponsiveSplit(
            breakpoint: 620,
            children: [
              SizedBox(width: 168, height: 168, child: _PodcastCoverArt()),
              _PodcastResultMeta(),
            ],
          ),
        ),
        _LabPanel(
          padding: const EdgeInsets.fromLTRB(34, 32, 34, 28),
          child: Column(
            children: [
              SizedBox(height: 108, child: _Waveform(progress: position)),
              Slider(
                value: position,
                onChanged: onPosition,
                activeColor: AppColors.purple,
                inactiveColor: AppColors.line,
              ),
              Row(
                children: [
                  const Text(
                    '00:00',
                    style: TextStyle(color: AppColors.muted, fontSize: 18),
                  ),
                  const Spacer(),
                  const Text(
                    '00:00',
                    style: TextStyle(color: AppColors.muted, fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.spaceAround,
                spacing: 16,
                runSpacing: 16,
                children: [
                  _ControlButton(label: '1.0x', onTap: onSpeed),
                  _CircleControl(
                    icon: Icons.replay_10_rounded,
                    onTap: onSkipBack,
                  ),
                  _PlayButton(playing: playing, onTap: onTogglePlay),
                  _CircleControl(
                    icon: Icons.forward_10_rounded,
                    onTap: onSkipForward,
                  ),
                  _VolumeControl(onTap: onVolume),
                ],
              ),
            ],
          ),
        ),
        const _ResponsiveSplit(
          breakpoint: 760,
          gap: 24,
          children: [_PodcastChaptersPanel(), _PodcastNotesPanel()],
        ),
        _ResponsiveActions(
          children: [
            _SecondaryLabButton(
              label: 'Paylaş',
              icon: Icons.share_outlined,
              onTap: onShare,
              height: 64,
            ),
            _SecondaryLabButton(
              label: 'MP3 Dışa Aktar',
              icon: Icons.file_download_outlined,
              onTap: onExport,
              height: 64,
            ),
            _SecondaryLabButton(
              label: 'Yeniden Üret',
              icon: Icons.refresh_rounded,
              onTap: onRegenerate,
              height: 64,
            ),
          ],
        ),
        _PrimaryLabButton(
          label: 'Podcasti Kaydet',
          icon: Icons.bookmark_border_rounded,
          onTap: onSave,
          height: 76,
        ),
      ],
    );
  }
}

class _InfographicBuilder extends StatelessWidget {
  const _InfographicBuilder({
    required this.selectedSources,
    required this.style,
    required this.size,
    required this.density,
    required this.accent,
    required this.showSources,
    required this.onBack,
    required this.onSearch,
    required this.onPickSources,
    required this.onStyle,
    required this.onSize,
    required this.onDensity,
    required this.onAccent,
    required this.onShowSources,
    required this.onGenerate,
  });

  final List<_LabSource> selectedSources;
  final String style;
  final String size;
  final String density;
  final Color accent;
  final bool showSources;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback onPickSources;
  final ValueChanged<String> onStyle;
  final ValueChanged<String> onSize;
  final ValueChanged<String> onDensity;
  final ValueChanged<Color> onAccent;
  final ValueChanged<bool> onShowSources;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return _LabScroll(
      children: [
        _LabTopBar(onBack: onBack, onSearch: onSearch),
        _LabHero(
          title: 'İnfografik',
          subtitle:
              'Kaynaklarını anlaşılır, görsel ve\npaylaşılabilir bilgi kartlarına dönüştür.',
          art: _HeroArtKind.infographic,
        ),
        _StepPanel(
          number: 1,
          title: 'Seçili Kaynaklar',
          trailing: _SmallActionButton(
            label: 'Kaynak Ekle',
            icon: Icons.add_rounded,
            onTap: onPickSources,
          ),
          child: _SourceGrid(
            sources: selectedSources,
            allowRemove: false,
            onRemove: (_) {},
            onMenu: onPickSources,
          ),
        ),
        _StepPanel(
          number: 2,
          title: 'İnfografik Ayarları',
          child: Column(
            children: [
              _SettingRow(
                icon: Icons.palette_outlined,
                label: 'Stil',
                child: _SegmentedOptions(
                  values: const ['Temiz', 'Akademik', 'Sosyal Medya'],
                  selected: style,
                  onSelected: onStyle,
                ),
              ),
              _SettingRow(
                icon: Icons.crop_rounded,
                label: 'Boyut',
                child: _SegmentedOptions(
                  values: const ['Dikey', 'Kare', 'Yatay'],
                  selected: size,
                  onSelected: onSize,
                ),
              ),
              _SettingRow(
                icon: Icons.notes_rounded,
                label: 'İçerik Yoğunluğu',
                child: _SegmentedOptions(
                  values: const ['Az', 'Orta', 'Yoğun'],
                  selected: density,
                  onSelected: onDensity,
                ),
              ),
              _SettingRow(
                icon: Icons.water_drop_outlined,
                label: 'Vurgu Rengi',
                child: _ColorDots(selected: accent, onSelected: onAccent),
              ),
              _SwitchSetting(
                icon: Icons.format_quote_rounded,
                title: 'Kaynak Göster',
                value: showSources,
                onChanged: onShowSources,
              ),
            ],
          ),
        ),
        _StepPanel(
          number: 3,
          title: 'İnfografik Bölümleri',
          child: Column(
            children: [
              _FocusChips(
                labels: const [
                  'Tanım',
                  'Klinik Bulgular',
                  'Ayırıcı Tanı',
                  'Tedavi',
                  'Komplikasyonlar',
                ],
                selectedLabels: const {
                  'Tanım',
                  'Klinik Bulgular',
                  'Ayırıcı Tanı',
                  'Tedavi',
                  'Komplikasyonlar',
                },
                onTap: (label) =>
                    _showLabSnack(context, '$label odağı güncellendi.'),
              ),
              const SizedBox(height: 14),
              _SmallActionButton(
                label: 'Bölüm Ekle',
                icon: Icons.add_rounded,
                onTap: () =>
                    _showLabSnack(context, 'Yeni infografik bölümü eklendi.'),
              ),
            ],
          ),
        ),
        _StepPanel(
          number: 4,
          title: 'Önizleme Yerleşimi',
          child: const _InfographicLayoutPreview(),
        ),
        _PrimaryLabButton(
          label: 'İnfografiği Oluştur',
          icon: Icons.auto_awesome_rounded,
          onTap: onGenerate,
          height: 72,
        ),
      ],
    );
  }
}

class _InfographicResult extends StatelessWidget {
  const _InfographicResult({
    required this.onBack,
    required this.onSearch,
    required this.onSave,
    required this.onPng,
    required this.onPdf,
    required this.onRegenerate,
  });

  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback onSave;
  final VoidCallback onPng;
  final VoidCallback onPdf;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    return _LabScroll(
      children: [
        _LabTopBar(onBack: onBack, onSearch: onSearch),
        const Padding(
          padding: EdgeInsets.only(bottom: 24),
          child: _TitleBlock(
            title: 'İnfografik',
            subtitle: 'Hazırlanan infografiği incele, düzenle ve paylaş.',
          ),
        ),
        _LabPanel(
          child: const _ResponsiveSplit(
            breakpoint: 620,
            children: [
              SizedBox(width: 132, height: 184, child: _HeartCoverCard()),
              _InfographicMetaBlock(),
            ],
          ),
        ),
        _LabPanel(
          padding: const EdgeInsets.all(18),
          child: const AspectRatio(
            aspectRatio: 1.36,
            child: _InfographicPoster(),
          ),
        ),
        const _ResponsiveSplit(
          breakpoint: 620,
          children: [
            _InfoStatPanel(
              icon: Icons.bookmark_border_rounded,
              title: 'BÖLÜM SAYISI',
              value: '—',
            ),
            _InfoStatPanel(
              icon: Icons.palette_outlined,
              title: 'GÖRSEL STİL',
              value: '—',
            ),
          ],
        ),
        _ResponsiveActions(
          children: [
            _SecondaryLabButton(
              label: 'Koleksiyona Kaydet',
              icon: Icons.bookmark_border_rounded,
              onTap: onSave,
              height: 64,
            ),
            _SecondaryLabButton(
              label: 'PNG Dışa Aktar',
              icon: Icons.image_outlined,
              onTap: onPng,
              height: 64,
            ),
            _SecondaryLabButton(
              label: 'PDF Dışa Aktar',
              icon: Icons.picture_as_pdf_outlined,
              iconColor: AppColors.red,
              onTap: onPdf,
              height: 64,
            ),
            _SecondaryLabButton(
              label: 'Yeniden Üret',
              icon: Icons.auto_awesome_rounded,
              onTap: onRegenerate,
              height: 64,
            ),
          ],
        ),
        _PrimaryLabButton(
          label: 'İnfografiği Kaydet',
          icon: Icons.file_download_outlined,
          onTap: onSave,
          height: 72,
        ),
      ],
    );
  }
}

class _MindMapBuilder extends StatelessWidget {
  const _MindMapBuilder({
    required this.selectedSources,
    required this.mapKind,
    required this.depth,
    required this.look,
    required this.topics,
    required this.expandChildren,
    required this.onBack,
    required this.onSearch,
    required this.onPickSources,
    required this.onRemoveSource,
    required this.onMapKind,
    required this.onDepth,
    required this.onLook,
    required this.onToggleTopic,
    required this.onExpandChildren,
    required this.onGenerate,
  });

  final List<_LabSource> selectedSources;
  final String mapKind;
  final String depth;
  final String look;
  final Set<String> topics;
  final bool expandChildren;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback onPickSources;
  final ValueChanged<String> onRemoveSource;
  final ValueChanged<String> onMapKind;
  final ValueChanged<String> onDepth;
  final ValueChanged<String> onLook;
  final ValueChanged<String> onToggleTopic;
  final ValueChanged<bool> onExpandChildren;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return _LabScroll(
      children: [
        _LabTopBar(onBack: onBack, onSearch: onSearch, showMore: true),
        _LabHero(
          title: 'Zihin Haritası',
          subtitle:
              'Kavramları düğümler halinde gör,\nilişkileri keşfet ve öğrenmeyi\norganize et.',
          art: _HeroArtKind.mindMap,
          tight: true,
        ),
        _StepPanel(
          number: 1,
          title: 'Seçili Kaynaklar',
          child: Column(
            children: [
              _SourceGrid(
                sources: selectedSources,
                allowRemove: true,
                onRemove: onRemoveSource,
                onMenu: onPickSources,
              ),
              const SizedBox(height: 14),
              _DashedAddRow(
                label: 'Drive’dan daha fazla kaynak ekle',
                onTap: onPickSources,
              ),
            ],
          ),
        ),
        _StepPanel(
          number: 2,
          title: 'Harita Ayarları',
          child: Column(
            children: [
              _SettingRow(
                label: 'Harita Türü',
                helper: true,
                child: _SegmentedOptions(
                  values: const ['Genel', 'Tanı Ağacı', 'Konu Bazlı'],
                  selected: mapKind,
                  onSelected: onMapKind,
                ),
              ),
              _SettingRow(
                label: 'Derinlik',
                helper: true,
                child: _SegmentedOptions(
                  values: const ['Temel', 'Orta', 'Derin'],
                  selected: depth,
                  onSelected: onDepth,
                ),
              ),
              _SettingRow(
                label: 'Görünüm',
                helper: true,
                child: _SegmentedOptions(
                  values: const ['Renkli', 'Sade'],
                  selected: look,
                  onSelected: onLook,
                ),
              ),
              _SettingRow(
                label: 'Merkez Konu',
                helper: true,
                child: const _InputLike(text: 'Konu başlığı girin'),
              ),
              _SwitchSetting(
                title: 'Alt Düğümleri Açık Başlat',
                value: expandChildren,
                onChanged: onExpandChildren,
              ),
            ],
          ),
        ),
        _StepPanel(
          number: 3,
          title: 'Dahil Edilecek Başlıklar',
          child: _TopicWrap(
            labels: topics.toList(),
            selected: topics,
            onTap: onToggleTopic,
          ),
        ),
        _StepPanel(
          number: 4,
          title: 'Önizleme',
          trailing: IconButton(
            onPressed: () =>
                _showLabSnack(context, 'Harita önizlemesi genişletildi.'),
            icon: const Icon(Icons.open_in_full_rounded),
          ),
          child: const SizedBox(height: 260, child: _MindMapPreview()),
        ),
        _PrimaryLabButton(
          label: 'Haritayı Oluştur',
          icon: Icons.auto_awesome_rounded,
          onTap: onGenerate,
          height: 76,
        ),
      ],
    );
  }
}

class _MindMapResult extends StatelessWidget {
  const _MindMapResult({
    required this.onBack,
    required this.onSave,
    required this.onExport,
    required this.onRegenerate,
  });

  final VoidCallback onBack;
  final VoidCallback onSave;
  final VoidCallback onExport;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    return _LabScroll(
      children: [
        _MinimalTopBar(
          title: 'Zihin Haritası',
          subtitle: 'Kavram ağını incele, genişlet ve koleksiyona kaydet.',
          onBack: onBack,
        ),
        _LabPanel(
          padding: const EdgeInsets.all(18),
          child: const SizedBox(
            height: 520,
            child: _MindMapPreview(expanded: true),
          ),
        ),
        _ResponsiveActions(
          children: [
            _SecondaryLabButton(
              label: 'Haritayı Dışa Aktar',
              icon: Icons.file_download_outlined,
              onTap: onExport,
              height: 64,
            ),
            _SecondaryLabButton(
              label: 'Yeniden Üret',
              icon: Icons.refresh_rounded,
              onTap: onRegenerate,
              height: 64,
            ),
          ],
        ),
        _PrimaryLabButton(
          label: 'Haritayı Kaydet',
          icon: Icons.bookmark_border_rounded,
          onTap: onSave,
          height: 74,
        ),
      ],
    );
  }
}

class _LabScroll extends StatelessWidget {
  const _LabScroll({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width < 420 ? 16.0 : 26.0;
    final isMobile = width < 600;
    final topPadding = MediaQuery.viewPaddingOf(context).top + 12;
    final bottomPadding = isMobile
        ? SourceBaseBottomNav.contentBottomPadding(context)
        : 48.0;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 940),
        child: ListView(
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            topPadding,
            horizontalPadding,
            bottomPadding,
          ),
          children: [
            for (final child in children) ...[
              child,
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _LabTopBar extends StatelessWidget {
  const _LabTopBar({
    required this.onSearch,
    this.onBack,
    this.showMore = false,
  });

  final VoidCallback onSearch;
  final VoidCallback? onBack;
  final bool showMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final brand = Row(
            children: const [
              Flexible(child: SourceBaseBrand(compact: true)),
              _HeaderDivider(),
              Text(
                'SourceLab',
                style: TextStyle(
                  color: AppColors.blue,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ],
          );
          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RoundButton(
                icon: Icons.search_rounded,
                label: 'Ara',
                onTap: onSearch,
              ),
              const SizedBox(width: 10),
              _NotificationButton(
                onTap: () => _showLabSnack(context, 'Bildirim merkezi açıldı.'),
              ),
              if (showMore) ...[
                const SizedBox(width: 10),
                _RoundButton(
                  icon: Icons.more_horiz_rounded,
                  label: 'Diğer işlemler',
                  onTap: () =>
                      _showLabSnack(context, 'Sayfa seçenekleri açıldı.'),
                ),
              ],
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (onBack != null)
                      _RoundButton(
                        icon: Icons.arrow_back_rounded,
                        label: 'Geri dön',
                        onTap: onBack!,
                      ),
                    if (onBack != null) const SizedBox(width: 12),
                    Expanded(child: brand),
                  ],
                ),
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            );
          }

          return Row(
            children: [
              if (onBack case final onBack?) ...[
                _RoundButton(
                  icon: Icons.arrow_back_rounded,
                  label: 'Geri dön',
                  onTap: onBack,
                ),
                const SizedBox(width: 18),
              ],
              Expanded(child: brand),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _ResponsiveSplit extends StatelessWidget {
  const _ResponsiveSplit({
    required this.children,
    this.gap = 14,
    this.breakpoint = 680,
  });

  final List<Widget> children;
  final double gap;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) SizedBox(height: gap),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i != children.length - 1) SizedBox(width: gap),
            ],
          ],
        );
      },
    );
  }
}

class _ResponsiveActions extends StatelessWidget {
  const _ResponsiveActions({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    const gap = 12.0;
    const breakpoint = 620.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) SizedBox(height: gap),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i != children.length - 1) SizedBox(width: gap),
            ],
          ],
        );
      },
    );
  }
}

class _MinimalTopBar extends StatelessWidget {
  const _MinimalTopBar({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _RoundButton(
                    icon: Icons.arrow_back_rounded,
                    label: 'Geri dön',
                    onTap: onBack,
                  ),
                  const Spacer(),
                  _RoundButton(
                    icon: Icons.more_horiz_rounded,
                    label: 'Diğer işlemler',
                    onTap: () =>
                        _showLabSnack(context, 'Sayfa seçenekleri açıldı.'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _TitleBlock(title: title, subtitle: subtitle),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RoundButton(
              icon: Icons.arrow_back_rounded,
              label: 'Geri dön',
              onTap: onBack,
            ),
            const SizedBox(width: 34),
            Expanded(
              child: _TitleBlock(title: title, subtitle: subtitle),
            ),
            _RoundButton(
              icon: Icons.more_horiz_rounded,
              label: 'Diğer işlemler',
              onTap: () => _showLabSnack(context, 'Sayfa seçenekleri açıldı.'),
            ),
          ],
        );
      },
    );
  }
}

class _LabHero extends StatelessWidget {
  const _LabHero({
    required this.title,
    required this.subtitle,
    required this.art,
    this.chips = const [],
    this.tight = false,
  });

  final String title;
  final String subtitle;
  final _HeroArtKind art;
  final List<Widget> chips;
  final bool tight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final artWidth = compact
            ? math.min(constraints.maxWidth, 300.0)
            : (tight ? 360.0 : 430.0);
        final artHeight = compact ? 214.0 : (tight ? 210.0 : 260.0);

        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GradientTitle(title),
            const SizedBox(height: 14),
            Text(
              subtitle,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: compact ? 17 : 21,
                height: 1.34,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 20),
              Wrap(spacing: 10, runSpacing: 10, children: chips),
            ],
          ],
        );

        if (compact) {
          return Container(
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
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: artWidth,
                    height: artHeight,
                    child: ClipRect(child: _HeroArt(kind: art)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 18),
                  child: copy,
                ),
              ],
            ),
          );
        }

        return Container(
          constraints: BoxConstraints(minHeight: tight ? 210 : 260),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0x00FFFFFF), Color(0xFFEAF5FF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: 0,
                top: 0,
                child: SizedBox(
                  width: artWidth,
                  height: artHeight,
                  child: _HeroArt(kind: art),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(6, tight ? 36 : 58, artWidth, 18),
                child: copy,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GradientTitle extends StatelessWidget {
  const _GradientTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final fontSize = width < 390
        ? 38.0
        : width < 620
        ? 46.0
        : 58.0;
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFF1711BC), AppColors.blue, AppColors.cyan],
        stops: [.0, .58, 1],
      ).createShader(bounds),
      child: Text(
        text,
        maxLines: 2,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 58,
          fontWeight: FontWeight.w900,
          height: 1.02,
          letterSpacing: 0,
        ).copyWith(fontSize: fontSize),
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final titleSize = width < 420
        ? 30.0
        : width < 620
        ? 34.0
        : 40.0;
    final subtitleSize = width < 420 ? 16.0 : 20.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.navy,
            fontSize: titleSize,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            color: AppColors.muted,
            fontSize: subtitleSize,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _StepPanel extends StatelessWidget {
  const _StepPanel({
    required this.number,
    required this.title,
    required this.child,
    this.trailing,
  });

  final int number;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return _LabPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 460;
              final heading = Row(
                children: [
                  _StepNumber(number),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              );

              if (trailing == null) {
                return heading;
              }
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    heading,
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerLeft, child: trailing),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: heading),
                  const SizedBox(width: 12),
                  trailing!,
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _StepNumber extends StatelessWidget {
  const _StepNumber(this.number);

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.primaryGradient,
      ),
      child: Text(
        '$number',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _LabPanel extends StatelessWidget {
  const _LabPanel({
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.radius = 22,
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
        border: Border.all(color: AppColors.line.withValues(alpha: .86)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B3D84).withValues(alpha: .07),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SourceGrid extends StatelessWidget {
  const _SourceGrid({
    required this.sources,
    required this.allowRemove,
    required this.onRemove,
    required this.onMenu,
  });

  final List<_LabSource> sources;
  final bool allowRemove;
  final ValueChanged<String> onRemove;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 640 ? 3 : 1;
        const gap = 14.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final source in sources)
              SizedBox(
                width: width,
                child: _SourceCard(
                  source: source,
                  allowRemove: allowRemove,
                  onRemove: () => onRemove(source.id),
                  onMenu: onMenu,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.source,
    required this.allowRemove,
    required this.onRemove,
    required this.onMenu,
  });

  final _LabSource source;
  final bool allowRemove;
  final VoidCallback onRemove;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          FileKindBadge(kind: source.kind, compact: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  source.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 14.5,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${source.size}  •  ${source.detail}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: allowRemove ? onRemove : onMenu,
            icon: Icon(
              allowRemove ? Icons.close_rounded : Icons.more_vert_rounded,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceList extends StatelessWidget {
  const _SourceList({
    required this.sources,
    required this.onRemove,
    required this.onReorder,
  });

  final List<_LabSource> sources;
  final ValueChanged<String> onRemove;
  final VoidCallback onReorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          for (var i = 0; i < sources.length; i++) ...[
            _SourceListRow(
              source: sources[i],
              onRemove: () => onRemove(sources[i].id),
              onReorder: onReorder,
            ),
            if (i != sources.length - 1)
              const Divider(height: 1, color: AppColors.softLine),
          ],
        ],
      ),
    );
  }
}

class _SourceListRow extends StatelessWidget {
  const _SourceListRow({
    required this.source,
    required this.onRemove,
    required this.onReorder,
  });

  final _LabSource source;
  final VoidCallback onRemove;
  final VoidCallback onReorder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 74,
      child: Row(
        children: [
          const SizedBox(width: 14),
          FileKindBadge(kind: source.kind, compact: true),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.title.replaceAll('\n', ' '),
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
                  '${source.size}  •  ${source.detail}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onReorder,
            icon: const Icon(
              Icons.drag_indicator_rounded,
              color: AppColors.muted,
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, color: AppColors.muted),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _RecentSourceRow extends StatelessWidget {
  const _RecentSourceRow({
    required this.source,
    required this.trailing,
    required this.onTap,
  });

  final _LabSource source;
  final String trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;
            final titleBlock = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.title.replaceAll('\n', ' '),
                  maxLines: compact ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${source.size}  •  ${source.detail}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            );

            if (compact) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FileKindBadge(kind: source.kind, compact: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleBlock,
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _TagPill(label: source.tag),
                            Text(
                              trailing,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.more_vert_rounded, color: AppColors.muted),
                ],
              );
            }

            return Row(
              children: [
                FileKindBadge(kind: source.kind, compact: true),
                const SizedBox(width: 14),
                Expanded(child: titleBlock),
                _TagPill(label: source.tag),
                const SizedBox(width: 16),
                Text(trailing, style: const TextStyle(color: AppColors.muted)),
                const SizedBox(width: 10),
                const Icon(
                  Icons.schedule_rounded,
                  color: AppColors.muted,
                  size: 20,
                ),
                const SizedBox(width: 10),
                const Icon(Icons.more_vert_rounded, color: AppColors.muted),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SourcePickerRow extends StatelessWidget {
  const _SourcePickerRow({
    required this.source,
    required this.selected,
    required this.onTap,
  });

  final _LabSource source;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.selectedBlue : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.blue : AppColors.line),
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
                    source.title.replaceAll('\n', ' '),
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${source.size}  •  ${source.detail}  •  ${source.tag}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? AppColors.blue : AppColors.softText,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderDivider extends StatelessWidget {
  const _HeaderDivider();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 1,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        color: const Color(0xFFC9D5EA),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
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
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.line),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: .06),
                  blurRadius: 15,
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

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _RoundButton(
          icon: Icons.notifications_none_rounded,
          label: 'Bildirimler',
          onTap: onTap,
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action, this.onTap});

  final String title;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(foregroundColor: AppColors.blue),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    action!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniHeroChip extends StatelessWidget {
  const _MiniHeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.blue, size: 19),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroArt extends StatelessWidget {
  const _HeroArt({required this.kind});

  final _HeroArtKind kind;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _HeroArtPainter(kind));
  }
}

class _HeroArtPainter extends CustomPainter {
  const _HeroArtPainter(this.kind);

  final _HeroArtKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final shadow = Paint()
      ..color = AppColors.blue.withValues(alpha: .18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    final line = Paint()
      ..color = AppColors.blue.withValues(alpha: .22)
      ..strokeWidth = 1.7
      ..style = PaintingStyle.stroke;
    final blue = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF0D6BFF), Color(0xFF6B5CFF)],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ).createShader(Offset.zero & size);
    final cyan = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF12D2D6), Color(0xFF2C80FF)],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ).createShader(Offset.zero & size);
    final soft = Paint()..color = const Color(0xFFEAF4FF);
    final white = Paint()..color = Colors.white;

    final orbit = Path()
      ..moveTo(size.width * .04, size.height * .55)
      ..cubicTo(
        size.width * .28,
        size.height * .1,
        size.width * .62,
        size.height * .08,
        size.width * .94,
        size.height * .32,
      );
    canvas.drawPath(orbit, line);
    for (final dot in [
      Offset(size.width * .12, size.height * .44),
      Offset(size.width * .42, size.height * .18),
      Offset(size.width * .82, size.height * .28),
      Offset(size.width * .92, size.height * .58),
    ]) {
      canvas.drawCircle(
        dot,
        4,
        Paint()..color = AppColors.blue.withValues(alpha: .55),
      );
    }

    void card(Rect rect, {Paint? fill}) {
      final r = RRect.fromRectAndRadius(rect, const Radius.circular(18));
      canvas.drawRRect(r.shift(const Offset(0, 14)), shadow);
      canvas.drawRRect(r, fill ?? white);
      canvas.drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.line,
      );
    }

    if (kind == _HeroArtKind.podcast) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * .53, size.height * .57, 170, 92),
          const Radius.circular(22),
        ),
        Paint()..color = const Color(0xFFECEBFF),
      );
      _drawMic(canvas, Offset(size.width * .47, size.height * .38), 95);
      for (var i = 0; i < 22; i++) {
        final x = size.width * .58 + i * 7;
        final h = 16 + (math.sin(i * .8).abs() * 32);
        canvas.drawLine(
          Offset(x, size.height * .66 - h / 2),
          Offset(x, size.height * .66 + h / 2),
          Paint()
            ..color = i < 16 ? AppColors.purple : AppColors.line
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round,
        );
      }
      _fileStack(canvas, size, Offset(size.width * .68, size.height * .18));
      return;
    }

    if (kind == _HeroArtKind.clinical) {
      _drawStethoscope(canvas, size);
      _fileStack(canvas, size, Offset(size.width * .62, size.height * .18));
      canvas.drawLine(
        Offset(size.width * .04, size.height * .56),
        Offset(size.width * .32, size.height * .56),
        Paint()
          ..color = AppColors.blue.withValues(alpha: .18)
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round,
      );
      return;
    }

    if (kind == _HeroArtKind.plan) {
      card(Rect.fromLTWH(size.width * .26, size.height * .16, 210, 130));
      for (var i = 0; i < 5; i++) {
        for (var j = 0; j < 3; j++) {
          card(
            Rect.fromLTWH(
              size.width * .31 + i * 31,
              size.height * .31 + j * 28,
              22,
              18,
            ),
            fill: Paint()
              ..color = i == j || i == j + 2
                  ? AppColors.selectedBlue
                  : Colors.white,
          );
        }
      }
      canvas.drawCircle(Offset(size.width * .28, size.height * .67), 44, soft);
      canvas.drawCircle(
        Offset(size.width * .28, size.height * .67),
        32,
        Paint()..color = Colors.white,
      );
      canvas.drawLine(
        Offset(size.width * .28, size.height * .67),
        Offset(size.width * .28, size.height * .49),
        Paint()
          ..color = AppColors.blue
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
      return;
    }

    if (kind == _HeroArtKind.infographic) {
      card(Rect.fromLTWH(size.width * .42, size.height * .08, 190, 220));
      card(Rect.fromLTWH(size.width * .17, size.height * .35, 132, 136));
      card(Rect.fromLTWH(size.width * .62, size.height * .46, 160, 112));
      for (var i = 0; i < 5; i++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              size.width * .49 + i * 22,
              size.height * .45 - i * 18,
              14,
              78 + i * 18,
            ),
            const Radius.circular(5),
          ),
          Paint()..color = i.isEven ? AppColors.blue : AppColors.cyan,
        );
      }
      canvas.drawCircle(Offset(size.width * .28, size.height * .55), 48, cyan);
      canvas.drawCircle(
        Offset(size.width * .28, size.height * .55),
        24,
        Paint()..color = Colors.white,
      );
      return;
    }

    if (kind == _HeroArtKind.mindMap) {
      final center = Offset(size.width * .50, size.height * .48);
      final nodes = [
        Offset(size.width * .24, size.height * .25),
        Offset(size.width * .74, size.height * .22),
        Offset(size.width * .76, size.height * .58),
        Offset(size.width * .34, size.height * .72),
        Offset(size.width * .18, size.height * .56),
      ];
      for (final node in nodes) {
        canvas.drawLine(center, node, line..strokeWidth = 2);
      }
      canvas.drawCircle(center, 42, blue);
      _drawIcon(canvas, center, Icons.psychology_outlined, Colors.white, 31);
      for (var i = 0; i < nodes.length; i++) {
        canvas.drawCircle(
          nodes[i],
          30,
          Paint()..color = _topicColor(i).withValues(alpha: .14),
        );
        canvas.drawCircle(
          nodes[i],
          22,
          Paint()..color = Colors.white.withValues(alpha: .92),
        );
      }
      return;
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .32, size.height * .22, 108, 172),
        const Radius.circular(18),
      ),
      cyan,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .42, size.height * .26, 92, 130),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFF0F3A91),
    );
    canvas.drawLine(
      Offset(size.width * .48, size.height * .13),
      Offset(size.width * .48, size.height * .23),
      Paint()
        ..color = AppColors.blue
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
    _fileStack(canvas, size, Offset(size.width * .62, size.height * .25));
  }

  void _fileStack(Canvas canvas, Size size, Offset origin) {
    final labels = [
      (DriveFileKind.pdf, AppColors.red),
      (DriveFileKind.pptx, AppColors.orange),
      (DriveFileKind.docx, AppColors.blue),
    ];
    for (var i = 0; i < 3; i++) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(origin.dx + i * 14, origin.dy + i * 50, 136, 66),
        const Radius.circular(14),
      );
      canvas.drawRRect(
        rect,
        Paint()..color = Colors.white.withValues(alpha: .94),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = AppColors.line
          ..strokeWidth = 1.2,
      );
      final badge = RRect.fromRectAndRadius(
        Rect.fromLTWH(origin.dx + 14 + i * 14, origin.dy + 16 + i * 50, 44, 28),
        const Radius.circular(7),
      );
      canvas.drawRRect(badge, Paint()..color = labels[i].$2);
    }
  }

  void _drawMic(Canvas canvas, Offset center, double size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: size * .56, height: size),
        Radius.circular(size * .28),
      ),
      Paint()..color = const Color(0xFF5D5CFF),
    );
    canvas.drawLine(
      Offset(center.dx, center.dy + size * .5),
      Offset(center.dx, center.dy + size * .92),
      Paint()
        ..color = AppColors.deepBlue
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(center.dx - size * .38, center.dy + size * .92),
      Offset(center.dx + size * .38, center.dy + size * .92),
      Paint()
        ..color = AppColors.deepBlue
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawStethoscope(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.blue
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * .28, size.height * .16)
      ..cubicTo(
        size.width * .18,
        size.height * .36,
        size.width * .26,
        size.height * .58,
        size.width * .42,
        size.height * .52,
      )
      ..cubicTo(
        size.width * .58,
        size.height * .46,
        size.width * .49,
        size.height * .18,
        size.width * .64,
        size.height * .14,
      );
    canvas.drawPath(path, paint);
    canvas.drawCircle(Offset(size.width * .52, size.height * .56), 28, paint);
  }

  void _drawIcon(
    Canvas canvas,
    Offset center,
    IconData icon,
    Color color,
    double size,
  ) {
    final builder =
        ParagraphBuilder(
            ParagraphStyle(textAlign: TextAlign.center, fontSize: size),
          )
          ..pushStyle(
            TextStyle(color: color, fontFamily: icon.fontFamily).getTextStyle(),
          )
          ..addText(String.fromCharCode(icon.codePoint));
    final paragraph = builder.build()
      ..layout(ParagraphConstraints(width: size + 4));
    canvas.drawParagraph(
      paragraph,
      Offset(center.dx - size / 2 - 2, center.dy - size / 2 - 2),
    );
  }

  Color _topicColor(int index) {
    return [
      AppColors.green,
      AppColors.purple,
      AppColors.orange,
      AppColors.cyan,
      AppColors.blue,
    ][index % 5];
  }

  @override
  bool shouldRepaint(covariant _HeroArtPainter oldDelegate) =>
      oldDelegate.kind != kind;
}

class _PrimaryLabButton extends StatelessWidget {
  const _PrimaryLabButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.height = 60,
  });

  final String label;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.blue.withValues(alpha: .23),
              blurRadius: 18,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 25),
                const SizedBox(width: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 22)),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
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

class _SecondaryLabButton extends StatelessWidget {
  const _SecondaryLabButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.iconColor = AppColors.blue,
    this.height = 56,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy,
          side: const BorderSide(color: AppColors.line),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 10),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  const _SmallActionButton({
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.blue,
        side: const BorderSide(color: AppColors.line),
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 7)],
          Text(label),
          const SizedBox(width: 7),
          const Icon(Icons.arrow_forward_rounded, size: 18),
        ],
      ),
    );
  }
}

class _DriveAddButton extends StatelessWidget {
  const _DriveAddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SmallActionButton(
      label: 'Drive’dan Ekle',
      icon: Icons.change_history_rounded,
      onTap: onTap,
    );
  }
}

class _DashedAddRow extends StatelessWidget {
  const _DashedAddRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line, style: BorderStyle.solid),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded, color: AppColors.blue, size: 26),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.blue,
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

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      'Farmakoloji' => AppColors.red,
      'Kardiyoloji' => AppColors.red,
      'Biyokimya' => AppColors.blue,
      _ => AppColors.purple,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InlineHeader extends StatelessWidget {
  const _InlineHeader({
    required this.icon,
    required this.title,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.blue, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              child: Text(
                action!,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.icon,
    required this.color,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 14,
                  height: 1.34,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
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
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              time,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelTitleRow extends StatelessWidget {
  const _PanelTitleRow({
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 440;
        final heading = Row(
          children: [
            Icon(icon, color: AppColors.blue, size: 25),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
        if (trailing == null) {
          return heading;
        }
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [heading, const SizedBox(height: 10), trailing!],
          );
        }
        return Row(
          children: [
            Expanded(child: heading),
            const SizedBox(width: 12),
            trailing!,
          ],
        );
      },
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.label,
    required this.child,
    this.icon,
    this.helper = false,
  });

  final String label;
  final Widget child;
  final IconData? icon;
  final bool helper;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final labelWidget = Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppColors.blue, size: 26),
                const SizedBox(width: 14),
              ],
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (helper) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.softText,
                  size: 19,
                ),
              ],
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelWidget, const SizedBox(height: 10), child],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 260, child: labelWidget),
              const SizedBox(width: 16),
              Expanded(child: child),
            ],
          );
        },
      ),
    );
  }
}

class _SegmentedOptions extends StatelessWidget {
  const _SegmentedOptions({
    required this.values,
    required this.selected,
    required this.onSelected,
    this.icons,
  });

  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;
  final List<IconData>? icons;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < values.length; i++) ...[
          Expanded(
            child: _SegmentButton(
              label: values[i],
              icon: icons != null && i < icons!.length ? icons![i] : null,
              selected: values[i] == selected,
              onTap: () => onSelected(values[i]),
            ),
          ),
          if (i != values.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.selectedBlue : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.blue : AppColors.line,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  color: selected ? AppColors.blue : AppColors.muted,
                  size: 18,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.blue : AppColors.muted,
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchSetting extends StatelessWidget {
  const _SwitchSetting({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.softLine),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.blue, size: 25),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.blue,
          ),
        ],
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.leftLabel,
    required this.rightLabel,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final String label;
  final String leftLabel;
  final String rightLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
          activeColor: AppColors.blue,
          inactiveColor: AppColors.line,
        ),
        Row(
          children: [
            Text(
              leftLabel,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const Spacer(),
            Text(
              rightLabel,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}

class _RangeLine extends StatelessWidget {
  const _RangeLine({
    required this.value,
    required this.leftLabel,
    required this.rightLabel,
    required this.onChanged,
  });

  final double value;
  final String leftLabel;
  final String rightLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Slider(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.purple,
          inactiveColor: AppColors.line,
        ),
        Row(
          children: [
            Text(
              leftLabel,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const Spacer(),
            Text(
              rightLabel,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}

class _SelectBox extends StatelessWidget {
  const _SelectBox({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _DropdownLike(icon: icon, label: label, onTap: onTap);
  }
}

class _DropdownLike extends StatelessWidget {
  const _DropdownLike({
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
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.blue, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
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

class _InputLike extends StatelessWidget {
  const _InputLike({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Icon(Icons.close_rounded, color: AppColors.muted, size: 20),
        ],
      ),
    );
  }
}

class _StepperBox extends StatelessWidget {
  const _StepperBox({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => onChanged(math.max(1, value - 1)),
            icon: const Icon(Icons.remove_rounded),
          ),
          Expanded(
            child: Center(
              child: Text(
                '$value',
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () => onChanged(value + 1),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _FocusChips extends StatelessWidget {
  const _FocusChips({
    required this.labels,
    required this.selectedLabels,
    required this.onTap,
  });

  final List<String> labels;
  final Set<String> selectedLabels;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final label in labels)
          _FocusChip(
            label: label,
            selected: selectedLabels.contains(label),
            onTap: () => onTap(label),
          ),
      ],
    );
  }
}

class _FocusChip extends StatelessWidget {
  const _FocusChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF0EEFF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFFCFC8FF) : AppColors.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.blue : AppColors.navy,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check_rounded, color: AppColors.blue, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopicWrap extends StatelessWidget {
  const _TopicWrap({
    required this.labels,
    required this.selected,
    required this.onTap,
  });

  final List<String> labels;
  final Set<String> selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 12,
      children: [
        for (final label in labels)
          _FocusChip(
            label: label,
            selected: selected.contains(label),
            onTap: () => onTap(label),
          ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, this.icon, this.tint = AppColors.blue});

  final String label;
  final IconData? icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tint.withValues(alpha: .18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: tint, size: 21),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(
              color: tint == AppColors.blue ? AppColors.blue : tint,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorDots extends StatelessWidget {
  const _ColorDots({required this.selected, required this.onSelected});

  final Color selected;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    const colors = [
      AppColors.blue,
      AppColors.cyan,
      AppColors.purple,
      Color(0xFFFF3F7D),
      AppColors.orange,
      AppColors.green,
      Color(0xFF8492AE),
    ];
    return Row(
      children: [
        for (final color in colors)
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: InkWell(
              onTap: () => onSelected(color),
              customBorder: const CircleBorder(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected == color ? AppColors.blue : Colors.white,
                    width: selected == color ? 4 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: .18),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: selected == color
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 18,
                      )
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

class _PatientAvatar extends StatelessWidget {
  const _PatientAvatar();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _PatientAvatarPainter());
  }
}

class _PatientAvatarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      center,
      size.width * .45,
      Paint()..color = AppColors.selectedBlue,
    );
    canvas.drawCircle(
      Offset(center.dx, center.dy - 24),
      26,
      Paint()..color = const Color(0xFFD7E2F8),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + 38),
          width: 82,
          height: 56,
        ),
        const Radius.circular(22),
      ),
      Paint()..color = const Color(0xFF4D78C8),
    );
    canvas.drawCircle(
      Offset(center.dx - 18, center.dy - 32),
      4,
      Paint()..color = AppColors.navy,
    );
    canvas.drawCircle(
      Offset(center.dx + 18, center.dy - 32),
      4,
      Paint()..color = AppColors.navy,
    );
    canvas.drawLine(
      Offset(center.dx - 18, center.dy - 2),
      Offset(center.dx + 18, center.dy - 2),
      Paint()
        ..color = AppColors.red
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PreviewTextBlock extends StatelessWidget {
  const _PreviewTextBlock({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          body,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 15,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _LearningGoalsPreview extends StatelessWidget {
  const _LearningGoalsPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Olası Öğrenme Hedefleri',
            style: TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          for (final goal in const [
            'Tanı yaklaşımını uygulama',
            'Uygun tetkik ve tedavi planlama',
            'Ayırıcı tanıda klinik karar verme',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_rounded,
                    color: AppColors.green,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      goal,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const Text(
            'Tümünü göster',
            style: TextStyle(
              color: AppColors.blue,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryActionBar extends StatelessWidget {
  const _SummaryActionBar({
    required this.icon,
    required this.title,
    required this.detail,
    required this.buttonLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String buttonLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _LabPanel(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.blue),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 14),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 250,
            child: _PrimaryLabButton(
              label: buttonLabel,
              icon: Icons.auto_awesome_rounded,
              onTap: onTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionTitle extends StatelessWidget {
  const _QuestionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFF0EEFF),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.help_outline_rounded,
            color: AppColors.purple,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _AnswerRow extends StatelessWidget {
  const _AnswerRow({
    required this.prefix,
    required this.label,
    required this.selected,
  });

  final String prefix;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: selected ? AppColors.selectedBlue : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppColors.blue : AppColors.line,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_off_rounded,
            color: selected ? AppColors.blue : AppColors.softText,
          ),
          const SizedBox(width: 18),
          Text(
            '$prefix  $label',
            style: TextStyle(
              color: selected ? AppColors.blue : AppColors.navy,
              fontSize: 16,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (selected)
            const Icon(Icons.check_circle_rounded, color: AppColors.blue),
        ],
      ),
    );
  }
}

class _PatientVitalsPanel extends StatelessWidget {
  const _PatientVitalsPanel();

  @override
  Widget build(BuildContext context) {
    return _LabPanel(
      child: Row(
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: const BoxDecoration(
              color: Color(0xFFF0EDFF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: AppColors.purple,
              size: 58,
            ),
          ),
          const SizedBox(width: 22),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '58 yaş  •  Erkek',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Klinik tablo ve\nbaşvuru şikayetleri.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 16,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          for (final vital in const [
            (Icons.favorite_border_rounded, '—', 'nabız/dk', AppColors.muted),
            (Icons.water_drop_outlined, '—', 'mmHg', AppColors.muted),
            (Icons.air_outlined, '—', 'sol/dk', AppColors.muted),
            (Icons.opacity_rounded, '—', 'SpO₂', AppColors.muted),
            (Icons.thermostat_outlined, '—', 'Ateş', AppColors.muted),
          ])
            Expanded(
              child: Container(
                height: 76,
                margin: const EdgeInsets.only(left: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.softLine),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(vital.$1, color: vital.$4, size: 21),
                    const SizedBox(height: 3),
                    Text(
                      vital.$2,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      vital.$3,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
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

class _ClinicalStepper extends StatelessWidget {
  const _ClinicalStepper();

  @override
  Widget build(BuildContext context) {
    final steps = [
      (Icons.description_outlined, 'Başvuru', true),
      (Icons.medical_services_outlined, 'Fizik Muayene', false),
      (Icons.science_outlined, 'Tetkikler', false),
      (Icons.my_location_rounded, 'Tanı', false),
      (Icons.medical_services_outlined, 'Tedavi Planı', false),
    ];
    return _LabPanel(
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            Expanded(
              child: Column(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: steps[i].$3 ? AppColors.blue : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: steps[i].$3 ? AppColors.blue : AppColors.line,
                      ),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: steps[i].$3 ? Colors.white : AppColors.muted,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Icon(
                    steps[i].$1,
                    color: steps[i].$3 ? AppColors.blue : AppColors.muted,
                    size: 30,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    steps[i].$2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: steps[i].$3 ? AppColors.blue : AppColors.muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            if (i != steps.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 54),
                  color: i == 0 ? AppColors.blue : AppColors.line,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ClinicalFeedbackPanel extends StatelessWidget {
  const _ClinicalFeedbackPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEFFFF8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.green.withValues(alpha: .25)),
      ),
      child: Row(
        children: const [
          Icon(Icons.check_circle_rounded, color: AppColors.green, size: 46),
          SizedBox(width: 16),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Klinik Geri Bildirim\n',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
                  ),
                  TextSpan(
                    text:
                        'Tanı kriterlerini inceleyerek en uygun yaklaşımı belirleyin.',
                  ),
                ],
              ),
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 15,
                height: 1.45,
              ),
            ),
          ),
          SizedBox(width: 140, height: 70, child: _EkgMiniChart()),
        ],
      ),
    );
  }
}

class _EkgMiniChart extends StatelessWidget {
  const _EkgMiniChart();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _EkgMiniChartPainter());
  }
}

class _EkgMiniChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.green
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(0, size.height * .55);
    for (var i = 0; i < 10; i++) {
      final x = i * size.width / 10;
      path
        ..lineTo(x + 8, size.height * .55)
        ..lineTo(x + 13, size.height * .25)
        ..lineTo(x + 19, size.height * .75)
        ..lineTo(x + 28, size.height * .55);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LearningPointsStrip extends StatelessWidget {
  const _LearningPointsStrip();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InlineHeader(
          icon: Icons.school_outlined,
          title: 'Öğrenme Noktaları',
          action: 'Tümünü gör',
          onAction: () => _showLabSnack(context, 'Bu bölüm henüz hazır değil.'),
        ),
        Wrap(
          spacing: 14,
          runSpacing: 10,
          children: const [
            _InfoPill(
              label: 'Kavram 1',
              icon: Icons.lightbulb_outline_rounded,
              tint: AppColors.purple,
            ),
            _InfoPill(
              label: 'Kavram 2',
              icon: Icons.lightbulb_outline_rounded,
              tint: AppColors.blue,
            ),
            _InfoPill(
              label: 'Kavram 3',
              icon: Icons.lightbulb_outline_rounded,
              tint: AppColors.green,
            ),
          ],
        ),
      ],
    );
  }
}

class _ClinicalScorePanel extends StatelessWidget {
  const _ClinicalScorePanel();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _ScoreBox(
            icon: Icons.emoji_events_outlined,
            title: 'Başarı',
            value: '—',
            subtitle: 'Karar oranı',
            color: AppColors.green,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _ScoreBox(
            icon: Icons.star_border_rounded,
            title: 'Karar Puanı',
            value: '92 /100',
            subtitle: 'Toplam puan',
            color: AppColors.blue,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _ScoreBox(
            icon: Icons.account_tree_outlined,
            title: 'Klinik Akış',
            value: '5 / 5',
            subtitle: 'Adım tamamlama',
            color: AppColors.purple,
          ),
        ),
      ],
    );
  }
}

class _ScoreBox extends StatelessWidget {
  const _ScoreBox({
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.softLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 36,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _PlanPreviewCards extends StatelessWidget {
  const _PlanPreviewCards();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 1; i <= 3; i++) ...[
          Expanded(child: _PlanPreviewCard(day: i)),
          if (i != 3) const SizedBox(width: 18),
        ],
        const SizedBox(width: 18),
        Expanded(
          child: Container(
            height: 170,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            child: const Text(
              'Devam eden günler\nplanına göre\noluşturulacak.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanPreviewCard extends StatelessWidget {
  const _PlanPreviewCard({required this.day});

  final int day;

  @override
  Widget build(BuildContext context) {
    final lines = const [
        'İçerik hazırlanıyor',
        'İçerik hazırlanıyor',
        'İçerik hazırlanıyor',
      ];
    return Container(
      height: 170,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: day == 1 ? const Color(0xFFF4FFFC) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Gün $day',
                style: TextStyle(
                  color: day == 1 ? AppColors.green : AppColors.purple,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              const Icon(Icons.menu_book_outlined, color: AppColors.blue),
            ],
          ),
          const SizedBox(height: 14),
          for (final line in lines)
            Text(
              '- $line',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 12.5,
                height: 1.55,
              ),
            ),
          const Spacer(),
          const Text(
            'Tahmini 6 görev  •  2 saat',
            style: TextStyle(
              color: AppColors.green,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanSummaryBar extends StatelessWidget {
  const _PlanSummaryBar({
    required this.days,
    required this.duration,
    required this.focus,
    required this.reviews,
    required this.onGenerate,
  });

  final int days;
  final String duration;
  final int focus;
  final bool reviews;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return _LabPanel(
      child: Row(
        children: [
          _SummaryMetric(
            icon: Icons.menu_book_outlined,
            title: 'Tahmini Görev',
            value: '${days * 6}',
            detail: 'görev',
          ),
          const _VerticalDividerLite(),
          _SummaryMetric(
            icon: Icons.schedule_rounded,
            title: 'Toplam Süre',
            value: '${days * 2}',
            detail: 'saat',
          ),
          const _VerticalDividerLite(),
          _SummaryMetric(
            icon: Icons.track_changes_rounded,
            title: 'Ana Odak',
            value: '$focus',
            detail: 'konu',
          ),
          const _VerticalDividerLite(),
          _SummaryMetric(
            icon: Icons.sync_rounded,
            title: 'Tekrar Seansları',
            value: reviews ? 'Eklenecek' : 'Kapalı',
            detail: 'Spaced Repetition',
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: 210,
            child: _PrimaryLabButton(
              label: 'Planı Oluştur',
              icon: Icons.auto_awesome_rounded,
              onTap: onGenerate,
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
    required this.title,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: AppColors.blue, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  detail,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalDividerLite extends StatelessWidget {
  const _VerticalDividerLite();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 52, color: AppColors.softLine);
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({
    required this.topTitle,
    required this.title,
    required this.subtitle,
    required this.chip,
    required this.onBack,
    required this.trailing,
    required this.onTrailing,
    required this.art,
  });

  final String topTitle;
  final String title;
  final String subtitle;
  final String chip;
  final VoidCallback onBack;
  final IconData trailing;
  final VoidCallback onTrailing;
  final _HeroArtKind art;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        final backBtn = _RoundButton(
          icon: Icons.arrow_back_rounded,
          label: 'Geri dön',
          onTap: onBack,
        );
        final trailBtn = _RoundButton(
          icon: trailing,
          label: 'Sayfa işlemi',
          onTap: onTrailing,
        );
        final artWidget = SizedBox(
          width: 170,
          height: 160,
          child: _HeroArt(kind: art),
        );
        final textBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              topTitle,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 34),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 42,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.muted, fontSize: 18),
            ),
            const SizedBox(height: 14),
            _InfoPill(
              label: chip,
              icon: Icons.track_changes_rounded,
              tint: AppColors.purple,
            ),
          ],
        );

        if (compact) {
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [backBtn, trailBtn],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    artWidget,
                    const SizedBox(width: 16),
                    Expanded(child: textBlock),
                  ],
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              backBtn,
              const SizedBox(width: 16),
              artWidget,
              const SizedBox(width: 20),
              Expanded(child: textBlock),
              const SizedBox(width: 16),
              trailBtn,
            ],
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
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

class _PlanTimelinePanel extends StatelessWidget {
  const _PlanTimelinePanel();

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        '1',
        'Bölüm 1',
        'İçerik hazırlanıyor',
        '—',
      ),
      (
        '2',
        'Bölüm 2',
        'İçerik hazırlanıyor',
        '—',
      ),
      (
        '3',
        'Bölüm 3',
        'İçerik hazırlanıyor',
        '—',
      ),
    ];
    return _LabPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 76,
                    child: Text(
                      'Gün\n${item.$1}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                  ),
                  Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: AppColors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 22),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$2,
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.$3,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '3 oturum',
                          style: TextStyle(
                            color: AppColors.navy,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _InfoPill(
                    label: 'Video',
                    icon: Icons.video_library_outlined,
                    tint: AppColors.blue,
                  ),
                  const SizedBox(width: 8),
                  const _InfoPill(
                    label: 'Özet',
                    icon: Icons.refresh_rounded,
                    tint: AppColors.green,
                  ),
                  const SizedBox(width: 8),
                  const _InfoPill(
                    label: 'Soru',
                    icon: Icons.auto_awesome_rounded,
                    tint: AppColors.purple,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    item.$4,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
          const Divider(height: 1, color: AppColors.softLine),
          TextButton(
            onPressed: () =>
                _showLabSnack(context, '7 günlük plan listesi açıldı.'),
            child: const Text(
              'Tüm 7 günü gör',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayGoalCard extends StatelessWidget {
  const _TodayGoalCard();

  @override
  Widget build(BuildContext context) {
    return _LabPanel(
      child: Row(
        children: const [
          Icon(Icons.track_changes_rounded, color: AppColors.blue, size: 76),
          SizedBox(width: 18),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Bugünün Hedefi\n',
                    style: TextStyle(
                      color: AppColors.blue,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  TextSpan(
                    text: '—  •  —\n',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(
                    text:
                        'Konu Başlığı\nBu bölüm henüz hazır değil.',
                  ),
                ],
              ),
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 15,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeaknessAlertCard extends StatelessWidget {
  const _WeaknessAlertCard();

  @override
  Widget build(BuildContext context) {
    return _LabPanel(
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.redBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_rounded,
              color: AppColors.red,
              size: 42,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Zayıf Nokta Uyarısı',
                  style: TextStyle(
                    color: AppColors.red,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Daha fazla kaynak yükleyerek planını zenginleştirebilirsin.',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                _SmallActionButton(
                  label: 'Detayları Gör',
                  onTap: () =>
                      _showLabSnack(context, 'Zayıf nokta detayları açıldı.'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanAnalysisPanel extends StatelessWidget {
  const _PlanAnalysisPanel();

  @override
  Widget build(BuildContext context) {
    return _LabPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Plan Analizi',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const SizedBox(width: 148, height: 110, child: _DonutChart()),
              const SizedBox(width: 18),
              const Expanded(child: _LegendList()),
              Container(width: 1, height: 110, color: AppColors.softLine),
              const SizedBox(width: 34),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _ProgressLine(
                      label: 'Konu 1',
                      value: .34,
                      color: AppColors.blue,
                    ),
                    _ProgressLine(
                      label: 'Konu 2',
                      value: .33,
                      color: AppColors.green,
                    ),
                    _ProgressLine(
                      label: 'Konu 3',
                      value: .33,
                      color: AppColors.purple,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutChart extends StatelessWidget {
  const _DonutChart();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _DonutChartPainter());
  }
}

class _DonutChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: 44,
    );
    var start = -math.pi / 2;
    for (final item in const [
      (.43, AppColors.blue),
      (.29, AppColors.green),
      (.28, AppColors.purple),
    ]) {
      canvas.drawArc(
        rect,
        start,
        math.pi * 2 * item.$1,
        false,
        Paint()
          ..color = item.$2
          ..strokeWidth = 18
          ..style = PaintingStyle.stroke,
      );
      start += math.pi * 2 * item.$1;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LegendList extends StatelessWidget {
  const _LegendList();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        _LegendRow(label: 'Kategori 1', value: 'İçerik hazırlanıyor', color: AppColors.blue),
        _LegendRow(label: 'Kategori 2', value: 'İçerik hazırlanıyor', color: AppColors.green),
        _LegendRow(label: 'Kategori 3', value: 'İçerik hazırlanıyor', color: AppColors.purple),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(label, style: const TextStyle(color: AppColors.muted)),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 118,
            child: Text(label, style: const TextStyle(color: AppColors.muted)),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              borderRadius: BorderRadius.circular(99),
              backgroundColor: AppColors.softLine,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '%${(value * 100).round()}',
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _PodcastPreviewFlow extends StatelessWidget {
  const _PodcastPreviewFlow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _PodcastPreviewCard(
            title: 'Giriş',
            time: '00:00 - 00:45',
            color: AppColors.purple,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Icon(Icons.arrow_forward_rounded, color: AppColors.blue),
        ),
        Expanded(
          child: _PodcastPreviewCard(
            title: 'Ana Başlıklar',
            time: '00:45 - 09:00',
            color: AppColors.blue,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Icon(Icons.arrow_forward_rounded, color: AppColors.cyan),
        ),
        Expanded(
          child: _PodcastPreviewCard(
            title: 'Kapanış',
            time: '09:00 - 10:00',
            color: AppColors.green,
          ),
        ),
      ],
    );
  }
}

class _PodcastPreviewCard extends StatelessWidget {
  const _PodcastPreviewCard({
    required this.title,
    required this.time,
    required this.color,
  });

  final String title;
  final String time;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.play_circle_outline_rounded,
              color: color,
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  time,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Konuya giriş ve öğrenme hedefleri',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PodcastStructurePanel extends StatelessWidget {
  const _PodcastStructurePanel();

  @override
  Widget build(BuildContext context) {
    return _LabPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitleRow(
            icon: Icons.extension_outlined,
            title: 'Podcast Yapısı',
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Expanded(
                child: _StructureItem(
                  icon: Icons.mic_none_rounded,
                  title: 'Açılış',
                  detail: '~45 sn',
                  color: AppColors.purple,
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              Expanded(
                child: _StructureItem(
                  icon: Icons.menu_book_outlined,
                  title: 'Konu Özeti',
                  detail: '~6-7 dk',
                  color: AppColors.blue,
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              Expanded(
                child: _StructureItem(
                  icon: Icons.track_changes_rounded,
                  title: 'Kritik Noktalar',
                  detail: '~2-3 dk',
                  color: AppColors.green,
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              Expanded(
                child: _StructureItem(
                  icon: Icons.quiz_outlined,
                  title: 'Mini Quiz',
                  detail: '~1-2 dk',
                  color: AppColors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StructureItem extends StatelessWidget {
  const _StructureItem({
    required this.icon,
    required this.title,
    required this.detail,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: .16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  detail,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PodcastCoverArt extends StatelessWidget {
  const _PodcastCoverArt();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE9DFFF), Color(0xFFC8C2FF)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Icon(
        Icons.keyboard_voice_rounded,
        color: AppColors.purple,
        size: 100,
      ),
    );
  }
}

class _PodcastResultMeta extends StatelessWidget {
  const _PodcastResultMeta();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Text(
          'İçerik Başlığı - Podcast Özeti',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 20),
        Wrap(
          spacing: 18,
          runSpacing: 10,
          children: [
            _InfoPill(
              label: '10:24',
              icon: Icons.schedule_rounded,
              tint: AppColors.muted,
            ),
            _InfoPill(
              label: '3 kaynak',
              icon: Icons.groups_outlined,
              tint: AppColors.muted,
            ),
            _InfoPill(label: '10 dk', tint: AppColors.purple),
            _InfoPill(
              label: 'Kritik Noktalar',
              icon: Icons.star_border_rounded,
              tint: AppColors.orange,
            ),
            _InfoPill(
              label: 'Mini Quiz',
              icon: Icons.help_outline_rounded,
              tint: AppColors.blue,
            ),
          ],
        ),
      ],
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _WaveformPainter(progress));
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 84; i++) {
      final x = i * size.width / 83;
      final normalized = math.sin(i * .55).abs();
      final height = 14 + normalized * 70;
      final active = i / 83 <= progress;
      canvas.drawLine(
        Offset(x, size.height / 2 - height / 2),
        Offset(x, size.height / 2 + height / 2),
        Paint()
          ..color = active ? AppColors.purple : AppColors.line
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        fixedSize: const Size(78, 58),
        foregroundColor: AppColors.blue,
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _CircleControl extends StatelessWidget {
  const _CircleControl({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: AppColors.navy, size: 48),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playing, required this.onTap});

  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 108,
        height: 108,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [AppColors.blue, AppColors.purple]),
        ),
        child: Icon(
          playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 62,
        ),
      ),
    );
  }
}

class _VolumeControl extends StatelessWidget {
  const _VolumeControl({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ControlButton(label: '', onTap: onTap),
        const SizedBox(height: 6),
        SizedBox(
          width: 72,
          child: LinearProgressIndicator(
            value: .72,
            minHeight: 5,
            borderRadius: BorderRadius.circular(99),
            backgroundColor: AppColors.line,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.purple),
          ),
        ),
      ],
    );
  }
}

class _PodcastChaptersPanel extends StatelessWidget {
  const _PodcastChaptersPanel();

  @override
  Widget build(BuildContext context) {
    final chapters = [
      ('1', 'Giriş', '00:00'),
      ('2', 'Bölüm 1', '00:00'),
      ('3', 'Bölüm 2', '00:00'),
    ];
    return _LabPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Bölümler',
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          for (final item in chapters)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.softLine)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: item.$1 == '1'
                          ? const Color(0xFFE8E3FF)
                          : const Color(0xFFF1EDFF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      item.$1,
                      style: const TextStyle(
                        color: AppColors.blue,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      item.$2,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    item.$3,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 16,
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

class _PodcastNotesPanel extends StatelessWidget {
  const _PodcastNotesPanel();

  @override
  Widget build(BuildContext context) {
    return _LabPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InlineHeader(
            icon: Icons.notes_rounded,
            title: 'Notlar',
            action: 'Kritik Noktalar',
            onAction: () => _showLabSnack(context, 'Bu bölüm henüz hazır değil.'),
          ),
          for (final note in const [
            (
              'Not başlığı yükleniyor...',
              'İçerik açıklaması hazırlanıyor.',
            ),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 7),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFC34D),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${note.$1}\n',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppColors.navy,
                            ),
                          ),
                          TextSpan(text: note.$2),
                        ],
                      ),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          TextButton(
            onPressed: () =>
                _showLabSnack(context, 'Podcast notlarının tamamı açıldı.'),
            child: const Text(
              'Tüm notları gör  →',
              style: TextStyle(
                color: AppColors.blue,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfographicLayoutPreview extends StatelessWidget {
  const _InfographicLayoutPreview();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 210,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            child: const _WireframePoster(),
          ),
        ),
        const SizedBox(width: 28),
        Container(
          width: 84,
          height: 120,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.selectedBlue,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.phone_iphone_rounded, color: AppColors.navy, size: 34),
              SizedBox(height: 10),
              Text(
                'Dikey\nFormat',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WireframePoster extends StatelessWidget {
  const _WireframePoster();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 180, height: 12, decoration: _wireDeco()),
        const SizedBox(height: 10),
        Container(width: 145, height: 8, decoration: _wireDeco()),
        const SizedBox(height: 20),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _wireBox('Tanım')),
              const SizedBox(width: 16),
              Expanded(child: _wireBox('Klinik Bulgular')),
              const SizedBox(width: 16),
              Expanded(child: _wireBox('Tedavi')),
            ],
          ),
        ),
      ],
    );
  }

  BoxDecoration _wireDeco() => BoxDecoration(
    color: const Color(0xFFD4DFF2),
    borderRadius: BorderRadius.circular(99),
  );

  Widget _wireBox(String title) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.selectedBlue,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          Container(height: 8, decoration: _wireDeco()),
          const SizedBox(height: 8),
          Container(height: 8, decoration: _wireDeco()),
          const SizedBox(height: 8),
          Container(width: 80, height: 8, decoration: _wireDeco()),
        ],
      ),
    );
  }
}

class _HeartCoverCard extends StatelessWidget {
  const _HeartCoverCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.favorite_rounded, color: AppColors.red, size: 80),
          SizedBox(height: 8),
          Text(
            'KONU\nBAŞLIĞI',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _InfographicMetaBlock extends StatelessWidget {
  const _InfographicMetaBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Text(
          'İçerik Başlığı - İnfografik',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            _InfoPill(label: 'Akademik', icon: Icons.school_outlined),
            _InfoPill(label: 'Dikey', icon: Icons.phone_iphone_rounded),
            _InfoPill(label: '1 sayfa', icon: Icons.description_outlined),
          ],
        ),
        SizedBox(height: 14),
        Text(
          'Kaynak: Yüklenen Dosyalar',
          style: TextStyle(color: AppColors.muted, fontSize: 15),
        ),
        SizedBox(height: 6),
        Text(
          'Oluşturulma: 12.07.2025  •  10:42',
          style: TextStyle(color: AppColors.muted, fontSize: 15),
        ),
        SizedBox(height: 6),
        Text(
          'Oluşturan: SourceLab AI',
          style: TextStyle(color: AppColors.muted, fontSize: 15),
        ),
      ],
    );
  }
}

class _InfographicPoster extends StatelessWidget {
  const _InfographicPoster();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF06224E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF041737), width: 5),
      ),
      child: Column(
        children: [
          const Text(
            'KONU BAŞLIĞI',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Alt Başlık veya Açıklama',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  flex: 3,
                  child: Row(
                    children: const [
                      Expanded(
                        child: _PosterBox(
                          title: 'BAŞLIK 1',
                          lines: [
                            'İçerik maddesi 1',
                            'İçerik maddesi 2',
                            'İçerik maddesi 3',
                          ],
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _PosterBox(
                          title: 'BAŞLIK 2',
                          lines: [
                            'İçerik maddesi 1',
                            'İçerik maddesi 2',
                            'İçerik maddesi 3',
                          ],
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _PosterBox(
                          title: 'BULGULAR',
                          lines: [
                            'ST elevasyonu',
                            'ST depresyonu',
                            'T dalga inversiyonu',
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const _PosterStrip(
                  title: 'TROPONİN',
                  subtitle:
                      'Yükselme: 3-6 saat  |  Pik: 12-24 saat  |  Normalleşme: 7-14 gün',
                ),
                const SizedBox(height: 10),
                const _TreatmentSteps(),
                const SizedBox(height: 10),
                const _WarningStrip(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PosterBox extends StatelessWidget {
  const _PosterBox({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                '• $line',
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 12.5,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PosterStrip extends StatelessWidget {
  const _PosterStrip({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.bloodtype_outlined, color: AppColors.red, size: 34),
          const SizedBox(width: 16),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TreatmentSteps extends StatelessWidget {
  const _TreatmentSteps();

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('1', Icons.monitor_heart_outlined, 'Hızlı Değerlendirme'),
      ('2', Icons.medication_outlined, 'İlk İlaçlar'),
      ('3', Icons.vaccines_outlined, 'Revaskülarizasyon'),
      ('4', Icons.favorite_outline_rounded, 'İzlem ve Koruma'),
    ];
    return Container(
      height: 112,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (final step in steps)
            Expanded(
              child: Column(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.selectedBlue,
                    child: Icon(step.$2, color: AppColors.blue),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    step.$3,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
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

class _WarningStrip extends StatelessWidget {
  const _WarningStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEFEF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.red, size: 40),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'DİKKAT EDİLMESİ GEREKENLER\nZaman hayatidir. Ağrı atipik olabilir. Yüksek riskli hastalar yakın izlem ve erken invaziv stratejiden yarar görür.',
              style: TextStyle(
                color: AppColors.red,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoStatPanel extends StatelessWidget {
  const _InfoStatPanel({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return _LabPanel(
      child: Row(
        children: [
          Icon(icon, color: AppColors.blue, size: 34),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MindMapPreview extends StatelessWidget {
  const _MindMapPreview({this.expanded = false});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _MindMapPreviewPainter(expanded));
  }
}

class _MindMapPreviewPainter extends CustomPainter {
  const _MindMapPreviewPainter(this.expanded);

  final bool expanded;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final branches = [
      (
        'Bölüm 1',
        Offset(size.width * .24, size.height * .24),
        AppColors.green,
        ['Madde 1', 'Madde 2'],
      ),
      (
        'Bölüm 2',
        Offset(size.width * .22, size.height * .52),
        AppColors.blue,
        ['Madde 1', 'Madde 2'],
      ),
      (
        'Bölüm 3',
        Offset(size.width * .30, size.height * .76),
        AppColors.purple,
        ['Madde 1', 'Madde 2'],
      ),
      (
        'Bölüm 4',
        Offset(size.width * .72, size.height * .30),
        AppColors.orange,
        ['Madde 1', 'Madde 2'],
      ),
    ];
    final line = Paint()
      ..color = const Color(0xFFB7C5E6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final branch in branches) {
      canvas.drawLine(center, branch.$2, line);
      _drawNode(canvas, branch.$2, branch.$1, branch.$3, large: true);
      for (var i = 0; i < branch.$4.length; i++) {
        final side = branch.$2.dx < center.dx ? -1 : 1;
        final child = Offset(
          branch.$2.dx + side * 122,
          branch.$2.dy + (i - 1) * 34,
        );
        canvas.drawLine(branch.$2, child, line);
        _drawNode(canvas, child, branch.$4[i], branch.$3, large: false);
      }
    }
    _drawNode(
      canvas,
      center,
      'Akut Koroner\nSendrom',
      AppColors.purple,
      large: true,
      central: true,
    );
  }

  void _drawNode(
    Canvas canvas,
    Offset center,
    String label,
    Color color, {
    required bool large,
    bool central = false,
  }) {
    final width = central ? 176.0 : (large ? 126.0 : 112.0);
    final height = central ? 68.0 : (large ? 46.0 : 30.0);
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: width, height: height),
      Radius.circular(large ? 18 : 9),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = color.withValues(alpha: central ? .2 : .14),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = color.withValues(alpha: .38),
    );
    final builder =
        ParagraphBuilder(
            ParagraphStyle(
              textAlign: TextAlign.center,
              fontSize: large ? 14 : 10,
            ),
          )
          ..pushStyle(
            TextStyle(
              color: central ? AppColors.blue : color,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ).getTextStyle(),
          )
          ..addText(label);
    final paragraph = builder.build()
      ..layout(ParagraphConstraints(width: width - 12));
    canvas.drawParagraph(
      paragraph,
      Offset(center.dx - (width - 12) / 2, center.dy - paragraph.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _MindMapPreviewPainter oldDelegate) =>
      oldDelegate.expanded != expanded;
}
