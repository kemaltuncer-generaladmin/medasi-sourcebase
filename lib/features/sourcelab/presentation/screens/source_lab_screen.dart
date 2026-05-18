import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' hide Color, Gradient, Image, TextStyle;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sourcebase_brand.dart';
import '../../../drive/data/drive_models.dart';
import '../../../drive/data/sourcebase_drive_api.dart';
import '../../../drive/presentation/widgets/drive_ui.dart';
import '../../../drive/presentation/widgets/sourcebase_bottom_nav.dart';

enum SourceLabView {
  home,
  examMorningBuilder,
  examMorningResult,
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

enum _ToolKind { examMorning, clinical, plan, podcast, infographic, mindMap }

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
  final SourceBaseDriveApi _api = const SourceBaseDriveApi();
  SourceLabView view = SourceLabView.home;
  late List<_LabSource> selectedSources;
  bool _isLoading = false;
  _LabGenerationResult? _labResult;
  String? _labError;

  @override
  void initState() {
    super.initState();
    selectedSources = const [];
  }

  String clinicalType = 'TUS tarzı vaka';
  String clinicalDifficulty = 'Orta';
  String clinicalLevel = 'Soru-cevaplı vaka';
  String clinicalBranch = 'Standart';
  double patientAge = 0;
  bool clinicalFeedback = true;

  String planGoal = '7 günlük plan';
  String planPriority = 'Aktif hatırlama';
  String planIntensity = 'Gün gün plan';
  int planDays = 7;
  String dailyDuration = '1 saat';
  String planQuality = 'Standart';
  bool includeReviews = true;

  String podcastVoice = '';
  String podcastDuration = '';
  String podcastFocus = '';
  double podcastPace = .5;
  bool includeMiniQuiz = true;
  bool podcastPlaying = false;
  double podcastPosition = 0;

  String infographicType = 'Klinik Akış';
  String infographicStyle = 'Akademik';
  String infographicDensity = 'Dengeli';
  String infographicQuality = 'Standart';

  String examSummaryMode = 'Sınav sabahı kritikler';
  String examLengthTarget = '7 dakikalık';
  String examQuality = 'Standart';
  final Set<String> examOutputFormats = {'Madde madde', 'Mini tablo'};

  String mapKind = 'Konu Haritası';
  String mapDepth = '3 seviye';
  String mapLook = 'Kartlı harita';
  String mapQuality = 'Standart';
  bool expandChildren = true;

  void _open(SourceLabView next) {
    setState(() => view = next);
  }

  void _back() {
    setState(() {
      view = switch (view) {
        SourceLabView.examMorningResult => SourceLabView.examMorningBuilder,
        SourceLabView.clinicalResult => SourceLabView.clinicalBuilder,
        SourceLabView.planResult => SourceLabView.planBuilder,
        SourceLabView.podcastResult => SourceLabView.podcastBuilder,
        SourceLabView.infographicResult => SourceLabView.infographicBuilder,
        SourceLabView.mindMapResult => SourceLabView.mindMapBuilder,
        _ => SourceLabView.home,
      };
    });
  }

  Future<void> _generate(SourceLabView resultView, _ToolKind tool) async {
    if (selectedSources.isEmpty) {
      _toast('Üretim için önce Drive’dan kaynak seçin.');
      _showSourcePicker();
      return;
    }
    final unavailable = selectedSources
        .where((source) => source.disabledReason != null)
        .map((source) => source.disabledReason!)
        .toSet()
        .join(' ');
    if (unavailable.isNotEmpty) {
      _toast(unavailable);
      return;
    }
    final file = _driveFileForSource(selectedSources.first);
    if (file == null || file.id.trim().isEmpty) {
      _toast('Seçilen kaynak Drive kaydıyla eşleşmiyor.');
      return;
    }
    if (file.status != DriveItemStatus.completed) {
      _toast('Seçilen kaynak henüz işlenmeye hazır değil.');
      return;
    }

    setState(() {
      _isLoading = true;
      _labError = null;
      _labResult = null;
      view = resultView;
    });

    final jobType = _sourceLabJobType(tool);
    if (jobType == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _labError =
            '${_sourceLabToolTitle(tool)} için backend job type henüz aktif değil. Üretim başlatılmadı.';
      });
      return;
    }

    try {
      final createResponse = await _api.createGenerationJob(
        fileId: file.id,
        jobType: jobType,
        sourceIds: selectedSources.map((source) => source.id).toList(),
        qualityTier: switch (tool) {
          _ToolKind.examMorning => _examQualityValue(examQuality),
          _ToolKind.infographic => _infographicQualityValue(infographicQuality),
          _ToolKind.mindMap => _mindMapQualityValue(mapQuality),
          _ToolKind.clinical => _sourceLabQualityValue(clinicalBranch),
          _ToolKind.plan => _sourceLabQualityValue(planQuality),
          _ => null,
        },
        options: switch (tool) {
          _ToolKind.examMorning => _examMorningPayloadOptions(
            mode: examSummaryMode,
            length: examLengthTarget,
            formats: examOutputFormats,
            quality: examQuality,
            source: selectedSources.first,
          ),
          _ToolKind.infographic => _infographicPayloadOptions(
            type: infographicType,
            style: infographicStyle,
            density: infographicDensity,
            quality: infographicQuality,
            source: selectedSources.first,
          ),
          _ToolKind.mindMap => _mindMapPayloadOptions(
            mapType: mapKind,
            depth: mapDepth,
            viewMode: mapLook,
            quality: mapQuality,
            source: selectedSources.first,
          ),
          _ToolKind.clinical => _clinicalPayloadOptions(
            scenarioType: clinicalType,
            difficulty: clinicalDifficulty,
            outputFormat: clinicalLevel,
            quality: clinicalBranch,
            source: selectedSources.first,
          ),
          _ToolKind.plan => _learningPlanPayloadOptions(
            goal: planGoal,
            dailyTime: dailyDuration,
            studyStyle: planPriority,
            outputFormat: planIntensity,
            quality: planQuality,
            source: selectedSources.first,
          ),
          _ => null,
        },
      );
      final data = createResponse['data'];
      final jobId = data is Map ? data['jobId']?.toString().trim() ?? '' : '';
      if (jobId.isEmpty) {
        throw StateError('AI üretim işi başlatılamadı.');
      }
      await _api.processGenerationJob(jobId);
      final content = await _pollLabContent(jobId);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _labResult = _LabGenerationResult(
          tool: tool,
          title: _sourceLabToolTitle(tool),
          sourceTitle: file.title,
          sourceCount: selectedSources.length,
          jobId: jobId,
          createdAtLabel: _sourceLabDateTimeLabel(DateTime.now()),
          mcCostLabel: _mcCostLabel(data),
          examSummaryMode: tool == _ToolKind.examMorning
              ? examSummaryMode
              : null,
          examLengthTarget: tool == _ToolKind.examMorning
              ? examLengthTarget
              : null,
          examOutputFormat: tool == _ToolKind.examMorning
              ? _examFormatLabel(examOutputFormats)
              : null,
          examQuality: tool == _ToolKind.examMorning ? examQuality : null,
          infographicType: tool == _ToolKind.infographic
              ? infographicType
              : null,
          infographicStyle: tool == _ToolKind.infographic
              ? infographicStyle
              : null,
          infographicDensity: tool == _ToolKind.infographic
              ? infographicDensity
              : null,
          infographicQuality: tool == _ToolKind.infographic
              ? infographicQuality
              : null,
          mindMapType: tool == _ToolKind.mindMap ? mapKind : null,
          mindMapDepth: tool == _ToolKind.mindMap ? mapDepth : null,
          mindMapViewMode: tool == _ToolKind.mindMap ? mapLook : null,
          mindMapQuality: tool == _ToolKind.mindMap ? mapQuality : null,
          content: content,
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _labError = _friendlyLabError(error, tool: tool);
      });
    }
  }

  Future<Object?> _pollLabContent(String jobId) async {
    const maxAttempts = 24;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final statusResponse = await _api.getJobStatus(jobId);
      final data = statusResponse['data'];
      final status = data is Map ? data['status']?.toString() ?? '' : '';
      if (status == 'completed') {
        final contentResponse = await _api.getGeneratedContent(jobId);
        final contentData = contentResponse['data'];
        return contentData is Map ? contentData['content'] : null;
      }
      if (status == 'failed') {
        final code = data is Map ? data['errorCode']?.toString() : null;
        final message = data is Map
            ? data['errorMessage']?.toString()
            : 'AI üretimi başarısız oldu.';
        throw StateError(
          message == null || message.trim().isEmpty
              ? 'AI üretimi başarısız oldu.'
              : [code, message].whereType<String>().join(': '),
        );
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    throw StateError('AI üretimi zaman aşımına uğradı. Lütfen tekrar deneyin.');
  }

  DriveFile? _driveFileForSource(_LabSource source) {
    for (final file in widget.data.recentFiles) {
      if (file.id == source.id) return file;
    }
    return null;
  }

  Future<void> _saveLabResult() async {
    final result = _labResult;
    if (result == null) {
      _toast('Kaydedilecek üretim sonucu yok.');
      return;
    }
    final kind = _sourceLabGeneratedKind(result.tool);
    if (kind == null) {
      _toast('${result.title} için kaydetme backend desteği bekleniyor.');
      return;
    }
    final file = selectedSources.isEmpty
        ? null
        : _driveFileForSource(selectedSources.first);
    if (file == null || file.id.trim().isEmpty) {
      _toast('Kaydetmek için geçerli Drive kaynağı bulunamadı.');
      return;
    }
    try {
      await _api.createGeneratedOutputByKind(
        fileId: file.id,
        kind: kind,
        itemCount: _sourceLabContentCount(result.content),
        jobId: result.jobId,
      );
      if (!mounted) return;
      _toast('Sonuç üretimler listesine kaydedildi.');
    } catch (error) {
      if (!mounted) return;
      _toast(_friendlyLabError(error, tool: result.tool));
    }
  }

  void _unsupportedExport() {
    _toast('Dışa aktarma/paylaşma entegrasyonu bu sürümde bağlı değil.');
  }

  Future<void> _copyLabResult() async {
    final result = _labResult;
    if (result == null) {
      _toast('Paylaşılacak üretim sonucu yok.');
      return;
    }
    await Clipboard.setData(
      ClipboardData(text: _plainTextForLabResult(result)),
    );
    if (!mounted) return;
    _toast('Sonuç metni panoya kopyalandı.');
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
      _ToolKind.examMorning => SourceLabView.examMorningBuilder,
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
    final selectedIds = selectedSources
        .where((source) => source.isSelectable)
        .map((source) => source.id)
        .toSet();
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
              if (!source.isSelectable) {
                _toast(source.disabledReason ?? 'Bu kaynak seçilemez.');
                return;
              }
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
                    if (pool.isEmpty)
                      const _LabPanel(
                        child: _LabEmptyState(
                          icon: Icons.folder_off_outlined,
                          title: 'Drive kaynağı yok',
                          message:
                              'SourceLab üretimi için önce Drive’a dosya yükleyin.',
                        ),
                      )
                    else
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
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemCount: pool.length,
                        ),
                      ),
                    const SizedBox(height: 18),
                    _PrimaryLabButton(
                      label: 'Seçimi Kullan',
                      icon: Icons.check_rounded,
                      onTap: selectedIds.isEmpty
                          ? null
                          : () {
                              if (selectedIds.isEmpty) {
                                _toast('En az bir kaynak seçin.');
                                return;
                              }
                              setState(() {
                                selectedSources = pool
                                    .where(
                                      (source) =>
                                          source.isSelectable &&
                                          selectedIds.contains(source.id),
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
                onContinue: () => _openTool(_ToolKind.examMorning),
                onToast: _toast,
              ),
              SourceLabView.examMorningBuilder => _ExamMorningBuilder(
                selectedSources: selectedSources,
                summaryMode: examSummaryMode,
                lengthTarget: examLengthTarget,
                outputFormats: examOutputFormats,
                quality: examQuality,
                onBack: _back,
                onSearch: widget.onSearch,
                onPickSources: _showSourcePicker,
                onRemoveSource: _removeSource,
                onSummaryMode: (value) =>
                    setState(() => examSummaryMode = value),
                onLengthTarget: (value) =>
                    setState(() => examLengthTarget = value),
                onToggleFormat: (value) {
                  setState(() {
                    if (examOutputFormats.contains(value)) {
                      if (examOutputFormats.length == 1) return;
                      examOutputFormats.remove(value);
                    } else {
                      examOutputFormats.add(value);
                    }
                  });
                },
                onQuality: (value) => setState(() => examQuality = value),
                onGenerate: () => _generate(
                  SourceLabView.examMorningResult,
                  _ToolKind.examMorning,
                ),
              ),
              SourceLabView.examMorningResult => _ExamMorningResult(
                loading: _isLoading,
                result: _labResult,
                error: _labError,
                onBack: _back,
                onSave: () {
                  _saveLabResult();
                },
                onCopy: _copyLabResult,
                onRegenerate: () => _open(SourceLabView.examMorningBuilder),
                onPickSources: _showSourcePicker,
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
                onDifficulty: (value) =>
                    setState(() => clinicalDifficulty = value),
                onLevel: (value) => setState(() => clinicalLevel = value),
                onBranch: (value) => setState(() => clinicalBranch = value),
                onAge: (value) => setState(() => patientAge = value),
                onFeedback: (value) => setState(() => clinicalFeedback = value),
                onGenerate: () =>
                    _generate(SourceLabView.clinicalResult, _ToolKind.clinical),
              ),
              SourceLabView.clinicalResult => _ClinicalScenarioResult(
                loading: _isLoading,
                result: _labResult,
                error: _labError,
                onBack: _back,
                onSearch: widget.onSearch,
                onSave: () {
                  _saveLabResult();
                },
                onExport: _copyLabResult,
                onRegenerate: () => _open(SourceLabView.clinicalBuilder),
                onComplete: _unsupportedExport,
              ),
              SourceLabView.planBuilder => _LearningPlanBuilder(
                selectedSources: selectedSources,
                goal: planGoal,
                priority: planPriority,
                intensity: planIntensity,
                days: planDays,
                dailyDuration: dailyDuration,
                quality: planQuality,
                includeReviews: includeReviews,
                onBack: _back,
                onSearch: widget.onSearch,
                onPickSources: _showSourcePicker,
                onGoal: (value) => setState(() {
                  planGoal = value;
                  planDays = _planDaysForGoal(value);
                }),
                onPriority: (value) => setState(() => planPriority = value),
                onIntensity: (value) => setState(() => planIntensity = value),
                onDaysChanged: (value) => setState(() => planDays = value),
                onDuration: (value) => setState(() => dailyDuration = value),
                onQuality: (value) => setState(() => planQuality = value),
                onReviews: (value) => setState(() => includeReviews = value),
                onGenerate: () =>
                    _generate(SourceLabView.planResult, _ToolKind.plan),
              ),
              SourceLabView.planResult => _LearningPlanResult(
                selectedSources: selectedSources,
                planDays: planDays,
                planGoal: planGoal,
                loading: _isLoading,
                result: _labResult,
                error: _labError,
                onBack: _back,
                onSave: () {
                  _saveLabResult();
                },
                onCalendar: _unsupportedExport,
                onExport: _copyLabResult,
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
                onGenerate: () =>
                    _generate(SourceLabView.podcastResult, _ToolKind.podcast),
              ),
              SourceLabView.podcastResult => _PodcastResult(
                playing: podcastPlaying,
                position: podcastPosition,
                loading: _isLoading,
                result: _labResult,
                error: _labError,
                onBack: _back,
                onTogglePlay: () => _toast(
                  'Ses dosyası üretilmedi; metinsel podcast scripti gösteriliyor.',
                ),
                onPosition: (value) => setState(() => podcastPosition = value),
                onSpeed: _unsupportedExport,
                onShare: _copyLabResult,
                onExport: _copyLabResult,
                onRegenerate: () => _open(SourceLabView.podcastBuilder),
                onSave: () {
                  _saveLabResult();
                },
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
                onVolume: _unsupportedExport,
              ),
              SourceLabView.infographicBuilder => _InfographicBuilder(
                selectedSources: selectedSources,
                type: infographicType,
                style: infographicStyle,
                density: infographicDensity,
                quality: infographicQuality,
                onBack: _back,
                onSearch: widget.onSearch,
                onPickSources: _showSourcePicker,
                onType: (value) => setState(() => infographicType = value),
                onStyle: (value) => setState(() => infographicStyle = value),
                onDensity: (value) =>
                    setState(() => infographicDensity = value),
                onQuality: (value) =>
                    setState(() => infographicQuality = value),
                onGenerate: () => _generate(
                  SourceLabView.infographicResult,
                  _ToolKind.infographic,
                ),
              ),
              SourceLabView.infographicResult => _InfographicResult(
                loading: _isLoading,
                result: _labResult,
                error: _labError,
                onBack: _back,
                onSearch: widget.onSearch,
                onSave: () {
                  _saveLabResult();
                },
                onPng: () => _toast('Görsel önizleme ekranda açık.'),
                onPdf: _unsupportedExport,
                onRegenerate: () => _open(SourceLabView.infographicBuilder),
              ),
              SourceLabView.mindMapBuilder => _MindMapBuilder(
                selectedSources: selectedSources,
                mapKind: mapKind,
                depth: mapDepth,
                look: mapLook,
                quality: mapQuality,
                expandChildren: expandChildren,
                onBack: _back,
                onSearch: widget.onSearch,
                onPickSources: _showSourcePicker,
                onRemoveSource: _removeSource,
                onMapKind: (value) => setState(() => mapKind = value),
                onDepth: (value) => setState(() => mapDepth = value),
                onLook: (value) => setState(() => mapLook = value),
                onQuality: (value) => setState(() => mapQuality = value),
                onExpandChildren: (value) =>
                    setState(() => expandChildren = value),
                onGenerate: () =>
                    _generate(SourceLabView.mindMapResult, _ToolKind.mindMap),
              ),
              SourceLabView.mindMapResult => _MindMapResult(
                loading: _isLoading,
                result: _labResult,
                error: _labError,
                onBack: _back,
                onSave: () {
                  _saveLabResult();
                },
                onExport: _copyLabResult,
                onRegenerate: () => _open(SourceLabView.mindMapBuilder),
              ),
            },
          ),
        ),
      ],
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
    required this.status,
    required this.disabledReason,
  });

  final String id;
  final String title;
  final DriveFileKind kind;
  final String size;
  final String detail;
  final String tag;
  final DriveItemStatus status;
  final String? disabledReason;

  bool get isSelectable => disabledReason == null;
}

class _LabGenerationResult {
  const _LabGenerationResult({
    required this.tool,
    required this.title,
    required this.sourceTitle,
    required this.sourceCount,
    required this.jobId,
    required this.createdAtLabel,
    required this.mcCostLabel,
    required this.content,
    this.examSummaryMode,
    this.examLengthTarget,
    this.examOutputFormat,
    this.examQuality,
    this.infographicType,
    this.infographicStyle,
    this.infographicDensity,
    this.infographicQuality,
    this.mindMapType,
    this.mindMapDepth,
    this.mindMapViewMode,
    this.mindMapQuality,
  });

  final _ToolKind tool;
  final String title;
  final String sourceTitle;
  final int sourceCount;
  final String jobId;
  final String createdAtLabel;
  final String mcCostLabel;
  final Object? content;
  final String? examSummaryMode;
  final String? examLengthTarget;
  final String? examOutputFormat;
  final String? examQuality;
  final String? infographicType;
  final String? infographicStyle;
  final String? infographicDensity;
  final String? infographicQuality;
  final String? mindMapType;
  final String? mindMapDepth;
  final String? mindMapViewMode;
  final String? mindMapQuality;
}

List<_LabSource> _sourcePool(DriveWorkspaceData data) {
  final converted = <_LabSource>[];
  for (final file in _allDriveFiles(data)) {
    converted.add(
      _LabSource(
        id: file.id,
        title: file.title,
        kind: file.kind,
        size: file.sizeLabel,
        detail: file.pageLabel,
        tag: file.tag ?? file.courseTitle,
        status: file.status,
        disabledReason: _sourceDisabledReason(file),
      ),
    );
  }
  return converted;
}

List<DriveFile> _allDriveFiles(DriveWorkspaceData data) {
  final files = <DriveFile>[];
  final seen = <String>{};
  for (final course in data.courses) {
    for (final section in course.sections) {
      for (final file in section.files) {
        if (seen.add(file.id)) files.add(file);
      }
    }
  }
  for (final file in data.recentFiles) {
    if (seen.add(file.id)) files.add(file);
  }
  return files;
}

String? _sourceDisabledReason(DriveFile file) {
  if (file.status == DriveItemStatus.processing) {
    return 'Kaynak işleniyor; hazır olunca seçilebilir.';
  }
  if (file.status == DriveItemStatus.uploading) {
    return 'Yükleme devam ediyor; tamamlanınca seçilebilir.';
  }
  if (file.status == DriveItemStatus.failed) {
    return 'Bu kaynak işlenemediği için seçilemez.';
  }
  if (file.status == DriveItemStatus.draft) {
    return 'Taslak kaynaklar üretimde kullanılamaz.';
  }
  if (_isZeroSizeLabel(file.sizeLabel)) {
    return '0 KB kaynaklar üretimde kullanılamaz.';
  }
  return null;
}

bool _isZeroSizeLabel(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized.isEmpty ||
      normalized == '-' ||
      normalized == '0 kb' ||
      normalized == '0 b' ||
      normalized.startsWith('0.0 ');
}

Map<String, dynamic> _infographicPayloadOptions({
  required String type,
  required String style,
  required String density,
  required String quality,
  required _LabSource source,
}) {
  final typeValue = _infographicTypeValue(type);
  final styleValue = _infographicStyleValue(style);
  final densityValue = _infographicDensityValue(density);
  final qualityValue = _infographicQualityValue(quality);
  return {
    'infographic_type': typeValue,
    'visual_style': styleValue,
    'density': densityValue,
    'quality_tier': qualityValue,
    'imageQuality': qualityValue == 'economy' ? 'draft' : qualityValue,
    'tier': qualityValue == 'premium' ? 'premium' : 'standard',
    'style': styleValue,
    'mode': typeValue == 'exam_morning' ? 'exam-morning' : 'structured',
    'clinical':
        styleValue == 'clinical' ||
        typeValue == 'clinical_flow' ||
        typeValue == 'diagnosis_treatment_algorithm',
    'premium': qualityValue == 'premium',
    'short': densityValue == 'short',
    'complex': densityValue == 'detailed',
    'source_size_tier': _sourceSizeTierFromLabel(source.size),
  };
}

Map<String, dynamic> _mindMapPayloadOptions({
  required String mapType,
  required String depth,
  required String viewMode,
  required String quality,
  required _LabSource source,
}) {
  final typeValue = _mindMapTypeValue(mapType);
  final depthValue = _mindMapDepthValue(depth);
  final viewValue = _mindMapViewModeValue(viewMode);
  final qualityValue = _mindMapQualityValue(quality);
  return {
    'map_type': typeValue,
    'depth': depthValue,
    'view_mode': viewValue,
    'quality_tier': qualityValue,
    'mode': 'structured',
    'clinical':
        typeValue == 'clinical_approach' || typeValue == 'diagnosis_treatment',
    'premium': qualityValue == 'premium',
    'complex': depthValue == 'detailed' || depthValue == 'exam_focused',
    'source_size_tier': _sourceSizeTierFromLabel(source.size),
  };
}

Map<String, dynamic> _examMorningPayloadOptions({
  required String mode,
  required String length,
  required Set<String> formats,
  required String quality,
  required _LabSource source,
}) {
  final qualityValue = _examQualityValue(quality);
  final formatValues = formats.map(_examFormatValue).toList()..sort();
  final outputFormat = formatValues.isEmpty
      ? 'bullet_points'
      : formatValues.join('+');
  return {
    'summary_mode': _examSummaryModeValue(mode),
    'length_target': _examLengthValue(length),
    'output_format': outputFormat,
    'output_formats': formatValues,
    'quality_tier': qualityValue,
    'mode': 'exam-morning',
    'structured': true,
    'clinical': mode == 'Klinik ipuçları' || mode == 'TUS tarzı yüksek verim',
    'premium': qualityValue == 'premium',
    'short': length == '3 dakikalık' || length == '7 dakikalık',
    'complex': length == 'Detaylı son tekrar',
    'source_size_tier': _sourceSizeTierFromLabel(source.size),
  };
}

Map<String, dynamic> _clinicalPayloadOptions({
  required String scenarioType,
  required String difficulty,
  required String outputFormat,
  required String quality,
  required _LabSource source,
}) {
  final difficultyValue = _clinicalDifficultyValue(difficulty);
  final qualityValue = _sourceLabQualityValue(quality);
  return {
    'scenario_type': _clinicalScenarioTypeValue(scenarioType),
    'difficulty': difficultyValue,
    'output_format': _clinicalOutputFormatValue(outputFormat),
    'quality_tier': qualityValue,
    'mode': 'structured',
    'clinical': true,
    'hard': difficultyValue == 'hard' || difficultyValue == 'expert',
    'premium': qualityValue == 'premium',
    'source_size_tier': _sourceSizeTierFromLabel(source.size),
  };
}

Map<String, dynamic> _learningPlanPayloadOptions({
  required String goal,
  required String dailyTime,
  required String studyStyle,
  required String outputFormat,
  required String quality,
  required _LabSource source,
}) {
  final qualityValue = _sourceLabQualityValue(quality);
  return {
    'plan_goal': _planGoalValue(goal),
    'daily_time': _dailyTimeValue(dailyTime),
    'study_style': _studyStyleValue(studyStyle),
    'output_format': _planOutputFormatValue(outputFormat),
    'quality_tier': qualityValue,
    'mode': 'structured',
    'personalized': true,
    'premium': qualityValue == 'premium',
    'source_size_tier': _sourceSizeTierFromLabel(source.size),
  };
}

String _clinicalScenarioTypeValue(String value) {
  return switch (value) {
    'Klinik karar senaryosu' => 'clinical_decision',
    'Acil yaklaşım vakası' => 'emergency_approach',
    'Tanı koydurucu vaka' => 'diagnostic_case',
    'Tedavi seçimi vakası' => 'treatment_choice',
    'Temel bilimden kliniğe vaka' => 'basic_to_clinical',
    _ => 'tus_case',
  };
}

String _clinicalDifficultyValue(String value) {
  return switch (value) {
    'Kolay' => 'easy',
    'Zor' => 'hard',
    'Uzmanlık seviyesi' => 'expert',
    _ => 'medium',
  };
}

String _clinicalOutputFormatValue(String value) {
  return switch (value) {
    '3 kısa vaka' => 'three_short_cases',
    'Soru-cevaplı vaka' => 'qa_case',
    'Açıklamalı vaka' => 'explained_case',
    'Adım adım klinik akıl yürütme' => 'stepwise_reasoning',
    _ => 'single_case',
  };
}

String _planGoalValue(String value) {
  return switch (value) {
    'Hızlı tekrar planı' => 'quick_review',
    '14 günlük plan' => '14_day',
    '30 günlük plan' => '30_day',
    'Sınav tarihi odaklı plan' => 'exam_date_backplanning',
    'Zayıf konu kapatma planı' => 'weak_topic_closure',
    _ => '7_day',
  };
}

String _dailyTimeValue(String value) {
  return switch (value) {
    '30 dk' => '30_min',
    '2 saat' => '2_hours',
    '4 saat' => '4_hours',
    'Özel süre' => 'custom',
    _ => '1_hour',
  };
}

String _studyStyleValue(String value) {
  return switch (value) {
    'Soru çözerek öğrenme' => 'question_based',
    'Flashcard destekli' => 'flashcard_supported',
    'Klinik bağlantılı' => 'clinical_linked',
    'Temel bilim bağlantılı' => 'basic_science_linked',
    'Dengeli' => 'balanced',
    _ => 'active_recall',
  };
}

String _planOutputFormatValue(String value) {
  return switch (value) {
    'Haftalık yol haritası' => 'weekly_roadmap',
    'Checklist' => 'checklist',
    'Takvim + tekrar döngüsü' => 'calendar_review_cycle',
    'Pomodoro blokları' => 'pomodoro_blocks',
    _ => 'day_by_day',
  };
}

int _planDaysForGoal(String value) {
  return switch (value) {
    'Hızlı tekrar planı' => 3,
    '14 günlük plan' => 14,
    '30 günlük plan' => 30,
    'Sınav tarihi odaklı plan' => 21,
    'Zayıf konu kapatma planı' => 10,
    _ => 7,
  };
}

String _sourceLabQualityValue(String value) {
  return switch (value) {
    'Ekonomik' => 'economy',
    'Premium' => 'premium',
    _ => 'standard',
  };
}

String _examSummaryModeValue(String value) {
  return switch (value) {
    'Hızlı tekrar' => 'quick_review',
    'Sınav sabahı kritikler' => 'exam_morning_critical',
    'En çok karıştırılanlar' => 'commonly_confused',
    'Klinik ipuçları' => 'clinical_tips',
    'Temel bilim mekanizması' => 'basic_science_mechanism',
    'TUS tarzı yüksek verim' => 'tus_high_yield',
    _ => 'exam_morning_critical',
  };
}

String _examLengthValue(String value) {
  return switch (value) {
    '3 dakikalık' => '3_min',
    '7 dakikalık' => '7_min',
    '15 dakikalık' => '15_min',
    'Detaylı son tekrar' => 'detailed_final_review',
    _ => '7_min',
  };
}

String _examFormatValue(String value) {
  return switch (value) {
    'Madde madde' => 'bullet_points',
    'Mini tablo' => 'mini_table',
    'Klinik ipucu kartları' => 'clinical_tip_cards',
    'Soru-cevap' => 'qa',
    'Algoritmik akış' => 'algorithm_flow',
    _ => 'bullet_points',
  };
}

String _examQualityValue(String value) {
  return switch (value) {
    'Ekonomik' => 'economy',
    'Premium' => 'premium',
    _ => 'standard',
  };
}

String _examFormatLabel(Set<String> formats) {
  if (formats.isEmpty) return 'Madde madde';
  return formats.join(' + ');
}

String _infographicTypeValue(String value) {
  return switch (value) {
    'Klinik Akış' => 'clinical_flow',
    'Mekanizma Haritası' => 'mechanism_map',
    'Sınav Sabahı Özeti' => 'exam_morning',
    'Karşılaştırma Panosu' => 'comparison_board',
    'Tanı-Tedavi Algoritması' => 'diagnosis_treatment_algorithm',
    'Temel Bilim Mekanizması' => 'basic_science_mechanism',
    'TUS Yüksek Verim Posteri' => 'tus_high_yield_poster',
    _ => 'clinical_flow',
  };
}

String _infographicStyleValue(String value) {
  return switch (value) {
    'Akademik' => 'academic',
    'Klinik' => 'clinical',
    'Minimal' => 'minimal',
    'Poster' => 'poster',
    'Premium' => 'premium',
    'Açık tema' => 'light_theme',
    'Koyu tema' => 'dark_theme',
    _ => 'academic',
  };
}

String _infographicDensityValue(String value) {
  return switch (value) {
    'Kısa' => 'short',
    'Dengeli' => 'balanced',
    'Detaylı' => 'detailed',
    _ => 'balanced',
  };
}

String _infographicQualityValue(String value) {
  return switch (value) {
    'Ekonomik' => 'economy',
    'Premium' => 'premium',
    _ => 'standard',
  };
}

String _mindMapTypeValue(String value) {
  return switch (value) {
    'Klinik Yaklaşım Haritası' => 'clinical_approach',
    'Mekanizma Haritası' => 'mechanism',
    'Temel Bilim Haritası' => 'basic_science',
    'Tanı-Tedavi Haritası' => 'diagnosis_treatment',
    'Sınav Tekrar Haritası' => 'exam_review',
    _ => 'topic_map',
  };
}

String _mindMapDepthValue(String value) {
  return switch (value) {
    '2 seviye' => '2_levels',
    'Detaylı' => 'detailed',
    'Sınav odaklı' => 'exam_focused',
    _ => '3_levels',
  };
}

String _mindMapViewModeValue(String value) {
  return switch (value) {
    'Merkezden dallanan' => 'radial',
    'Hiyerarşik ağaç' => 'tree',
    'Mobil kompakt' => 'mobile_compact',
    'Geniş ekran' => 'wide',
    _ => 'card_map',
  };
}

String _mindMapQualityValue(String value) {
  return switch (value) {
    'Ekonomik' => 'economy',
    'Premium' => 'premium',
    _ => 'standard',
  };
}

String _sourceSizeTierFromLabel(String value) {
  final normalized = value.toLowerCase().replaceAll(',', '.');
  final number =
      double.tryParse(
        RegExp(r'([0-9]+(?:\.[0-9]+)?)').firstMatch(normalized)?.group(1) ?? '',
      ) ??
      0;
  if (normalized.contains('kb')) return number < 300 ? 'tiny' : 'short';
  if (normalized.contains('gb')) return 'huge';
  if (number >= 50) return 'huge';
  if (number >= 15) return 'large';
  if (number >= 3) return 'medium';
  return 'short';
}

String? _sourceLabJobType(_ToolKind tool) {
  return switch (tool) {
    _ToolKind.examMorning => 'exam_morning_summary',
    _ToolKind.podcast => 'podcast',
    _ToolKind.infographic => 'infographic',
    _ToolKind.clinical => 'clinical_scenario',
    _ToolKind.plan => 'learning_plan',
    _ToolKind.mindMap => 'mind_map',
  };
}

String? _sourceLabGeneratedKind(_ToolKind tool) {
  return switch (tool) {
    _ToolKind.examMorning => 'exam_morning_summary',
    _ToolKind.podcast => 'podcast_summary',
    _ToolKind.infographic => GeneratedKind.infographic.name,
    _ToolKind.clinical => 'clinical_scenario',
    _ToolKind.plan => 'learning_plan',
    _ToolKind.mindMap => 'mind_map',
  };
}

int _sourceLabContentCount(Object? content) {
  if (content is List) return content.length;
  if (content is Map) {
    for (final key in const [
      'must_know',
      'mutlaka_bil',
      'commonly_confused',
      'clinical_tus_tips',
      'self_check',
      'segments',
      'chapters',
      'steps',
      'days',
      'nodes',
      'questions',
      'rows',
      'bulletPoints',
      'sections',
    ]) {
      final value = content[key];
      if (value is List) return value.length;
    }
  }
  return content == null ? 0 : 1;
}

String _plainTextForLabResult(_LabGenerationResult result) {
  return [
    result.title,
    'Kaynak: ${result.sourceTitle}',
    '',
    _plainTextLabValue(result.content),
  ].join('\n');
}

String _sourceLabDateTimeLabel(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.'
      '${local.month.toString().padLeft(2, '0')}.${local.year} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String _mcCostLabel(Object? data) {
  if (data is! Map) {
    return 'Ücret üretim sırasında güvenli şekilde hesaplanır.';
  }
  final value = data['final_mc_cost'] ?? data['reserved_mc'];
  if (value is num && value > 0) {
    return '${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)} MC rezerve edildi';
  }
  return 'Ücret üretim sırasında güvenli şekilde hesaplanır.';
}

String _plainTextLabValue(Object? value) {
  if (value == null) return 'Sonuç içeriği boş.';
  if (value is String) {
    final text = value.trim();
    return text.isEmpty ? 'Sonuç içeriği boş.' : text;
  }
  if (value is List) {
    if (value.isEmpty) return 'Sonuç içeriği boş.';
    return value
        .asMap()
        .entries
        .map((entry) => '${entry.key + 1}. ${_plainTextLabValue(entry.value)}')
        .join('\n\n');
  }
  if (value is Map) {
    if (value.isEmpty) return 'Sonuç içeriği boş.';
    return value.entries
        .map((entry) {
          final key = entry.key.toString();
          return '$key: ${_plainTextLabValue(entry.value)}';
        })
        .join('\n');
  }
  final text = value.toString().trim();
  return text.isEmpty ? 'Sonuç içeriği boş.' : text;
}

String _sourceLabToolTitle(_ToolKind tool) {
  return switch (tool) {
    _ToolKind.examMorning => 'Sınav Sabahı Özeti',
    _ToolKind.clinical => 'Klinik Senaryo',
    _ToolKind.plan => 'Öğrenme Planı',
    _ToolKind.podcast => 'Podcast Özeti',
    _ToolKind.infographic => 'İnfografik',
    _ToolKind.mindMap => 'Zihin Haritası',
  };
}

String _friendlyLabError(Object error, {_ToolKind? tool}) {
  final text = error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '')
      .replaceFirst('FunctionException', '')
      .trim();
  if (text.contains('SourceBase Supabase client is not configured')) {
    return 'Oturum bağlantısı hazır değil. Lütfen tekrar giriş yapın.';
  }
  if (tool == _ToolKind.examMorning &&
      (text.contains('VERTEX_AUTH_FAILED') ||
          text.contains('VERTEX_NOT_CONFIGURED') ||
          text.contains('JOB_CREATE_FAILED') ||
          text.contains('AI_FAILED') ||
          text.contains('UPSTREAM') ||
          text.contains('CONFIG_ERROR'))) {
    return 'Sınav Sabahı Özeti şu anda tamamlanamadı. Kaynağın güvende; harcanan MC varsa iade edilir.';
  }
  if ((tool == _ToolKind.clinical || tool == _ToolKind.plan) &&
      (text.contains('VERTEX_AUTH_FAILED') ||
          text.contains('VERTEX_NOT_CONFIGURED') ||
          text.contains('JOB_CREATE_FAILED') ||
          text.contains('AI_FAILED') ||
          text.contains('UPSTREAM') ||
          text.contains('CONFIG_ERROR'))) {
    final label = tool == _ToolKind.clinical
        ? 'Klinik Senaryo'
        : 'Öğrenme Planı';
    return '$label şu anda tamamlanamadı. Kaynağın güvende; harcanan MC varsa iade edilir.';
  }
  if (tool == _ToolKind.mindMap &&
      (text.contains('VERTEX_AUTH_FAILED') ||
          text.contains('VERTEX_NOT_CONFIGURED') ||
          text.contains('JOB_CREATE_FAILED') ||
          text.contains('AI_FAILED') ||
          text.contains('UPSTREAM') ||
          text.contains('CONFIG_ERROR'))) {
    return 'Zihin haritası şu anda tamamlanamadı. Kaynağın güvende; harcanan MC varsa iade edilir.';
  }
  if (tool == _ToolKind.infographic &&
      text.contains('IMAGE_PROVIDER_NOT_CONFIGURED')) {
    return 'İnfografik üretimi şu anda tamamlanamadı. Kaynağın güvende; harcanan MC varsa iade edilir.';
  }
  if (tool == _ToolKind.infographic && text.contains('JOB_CREATE_FAILED')) {
    return 'İnfografik üretim işi şu anda başlatılamadı. Kaynağın güvende; harcanan MC varsa iade edilir.';
  }
  if (_isRawLabProviderError(text)) {
    return '${_sourceLabToolTitle(tool ?? _ToolKind.examMorning)} şu anda tamamlanamadı. Kaynağın güvende; harcanan MC varsa iade edilir.';
  }
  if (text.contains('VERTEX_AUTH_FAILED') ||
      text.contains('VERTEX_NOT_CONFIGURED') ||
      text.contains('IMAGE_AUTH_FAILED')) {
    return 'AI üretim sağlayıcısı şu anda doğrulanamadı. Kaynağın güvende; harcanan MC varsa iade edilir.';
  }
  if (text.contains('INSUFFICIENT_MC')) {
    return 'Bu üretim için MedasiCoin bakiyen yetersiz. Bakiyeni artırıp tekrar deneyebilirsin.';
  }
  if (text.contains('IMAGE_UPSTREAM_ERROR') ||
      text.contains('IMAGE_GENERATION_FAILED') ||
      text.contains('IMAGE_EMPTY')) {
    return 'İnfografik görseli şu anda tamamlanamadı. Kaynağın güvende; harcanan MC varsa iade edilir.';
  }
  return text.isEmpty
      ? 'AI üretimi tamamlanamadı. Lütfen tekrar deneyin.'
      : text;
}

bool _isRawLabProviderError(String text) {
  final normalized = text.toUpperCase();
  return normalized.contains('VERTEX_') ||
      normalized.contains('OPENAI_') ||
      normalized.contains('ANTHROPIC_') ||
      normalized.contains('IMAGE_') ||
      normalized.contains('UPSTREAM') ||
      normalized.contains('PROVIDER') ||
      normalized.contains('AI_FAILED') ||
      normalized.contains('EMPTY_AI_OUTPUT') ||
      normalized.contains('STACK') ||
      normalized.contains('UNDEFINED') ||
      normalized.contains('NULL') ||
      normalized.contains('{') ||
      normalized.contains('}');
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

class _LabEmptyState extends StatelessWidget {
  const _LabEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.selectedBlue,
            child: Icon(icon, color: AppColors.blue),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
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
          tight: true,
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
          child: selectedSources.isEmpty
              ? const _LabEmptyState(
                  icon: Icons.folder_open_outlined,
                  title: 'Kaynak seçilmedi',
                  message:
                      'SourceLab araçlarını kullanmak için Drive’dan en az bir kaynak seçin.',
                )
              : Column(
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
    final compact = MediaQuery.sizeOf(context).width < 420;
    return _LabPanel(
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 22,
        compact ? 16 : 22,
        compact ? 16 : 22,
        compact ? 16 : 20,
      ),
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
                            fontSize: 22,
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
                label: sources.isEmpty ? 'Kaynak Seç' : 'Devam Et',
                icon: sources.isEmpty
                    ? Icons.folder_open_rounded
                    : Icons.arrow_forward_rounded,
                onTap: sources.isEmpty ? onPickSources : onContinue,
                height: compact ? 54 : 60,
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
          if (sources.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SourceGrid(
              sources: sources,
              allowRemove: false,
              onRemove: (_) {},
              onMenu: onPickSources,
            ),
          ],
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
        _ToolKind.examMorning,
        Icons.alarm_on_outlined,
        'Sınav Sabahı Özeti',
        'Son tekrar için kısa,\nyüksek verimli sınav\nözeti çıkarın.',
        AppColors.orange,
      ),
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
        final columns = constraints.maxWidth > 760 ? 3 : 2;
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
    final compact = MediaQuery.sizeOf(context).width < 420;
    return _LabPanel(
      padding: EdgeInsets.fromLTRB(12, compact ? 14 : 18, 12, 12),
      radius: 16,
      child: Column(
        children: [
          Container(
            width: compact ? 48 : 58,
            height: compact ? 48 : 58,
            decoration: BoxDecoration(
              color: spec.color.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(spec.icon, color: spec.color, size: compact ? 28 : 34),
          ),
          SizedBox(height: compact ? 10 : 15),
          Text(
            spec.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              color: AppColors.navy,
              fontSize: compact ? 16 : 18,
              height: 1.08,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: compact ? 7 : 9),
          Text(
            spec.subtitle,
            textAlign: TextAlign.center,
            maxLines: compact ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: compact ? 12 : 13,
              height: 1.23,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: compact ? 9 : 13),
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
            icon: Icons.alarm_on_outlined,
            color: AppColors.cyan,
            text:
                'Sınav sabahı için kritik bilgileri kısa bir son tekrar formatına dönüştür.',
            onTap: () => onOpenTool(_ToolKind.examMorning),
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
            text: 'Ders notlarını podcast formatında dinleyebilirsin.',
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
    final hasSources = selectedSources.isNotEmpty;
    final blockedReasons = selectedSources
        .where((source) => source.disabledReason != null)
        .map((source) => source.disabledReason!)
        .toSet()
        .toList();
    final canGenerate = hasSources && blockedReasons.isEmpty;
    return _LabScroll(
      children: [
        _LabTopBar(onBack: onBack, onSearch: onSearch),
        _CompactToolHero(
          title: 'Klinik Senaryo',
          subtitle: 'Kaynağından vaka temelli klinik düşünme senaryoları üret.',
          icon: Icons.monitor_heart_outlined,
          selectedCount: selectedSources.length,
          hasSources: hasSources,
          onPickSources: onPickSources,
        ),
        _StepPanel(
          number: 1,
          title: 'Kaynak Seçimi',
          trailing: _SmallActionButton(
            label: hasSources ? 'Kaynak Değiştir' : 'Drive’dan kaynak seç',
            icon: Icons.folder_open_rounded,
            onTap: onPickSources,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!hasSources)
                const _LabEmptyState(
                  icon: Icons.folder_open_outlined,
                  title: 'Kaynak seçilmedi',
                  message:
                      'Hazır/Tamamlandı durumda ve boyutu 0 KB olmayan bir Drive kaynağı seçin.',
                )
              else
                _SourceGrid(
                  sources: selectedSources,
                  allowRemove: true,
                  onRemove: onRemoveSource,
                  onMenu: onPickSources,
                ),
              for (final reason in blockedReasons) ...[
                const SizedBox(height: 12),
                _LabNotice(text: reason),
              ],
            ],
          ),
        ),
        _StepPanel(
          number: 2,
          title: 'Senaryo Tipi',
          child: _InfographicOptionGrid(
            values: const [
              'TUS tarzı vaka',
              'Klinik karar senaryosu',
              'Acil yaklaşım vakası',
              'Tanı koydurucu vaka',
              'Tedavi seçimi vakası',
              'Temel bilimden kliniğe vaka',
            ],
            selected: clinicalType,
            onSelected: onClinicalType,
          ),
        ),
        _StepPanel(
          number: 3,
          title: 'Zorluk ve Format',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SegmentedOptions(
                values: const ['Kolay', 'Orta', 'Zor', 'Uzmanlık seviyesi'],
                selected: difficulty,
                onSelected: onDifficulty,
              ),
              const SizedBox(height: 16),
              _InfographicOptionGrid(
                values: const [
                  'Tek vaka',
                  '3 kısa vaka',
                  'Soru-cevaplı vaka',
                  'Açıklamalı vaka',
                  'Adım adım klinik akıl yürütme',
                ],
                selected: level,
                onSelected: onLevel,
              ),
            ],
          ),
        ),
        _StepPanel(
          number: 4,
          title: 'Kalite ve MC',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SegmentedOptions(
                values: const ['Ekonomik', 'Standart', 'Premium'],
                selected: branch,
                onSelected: onBranch,
              ),
              const SizedBox(height: 12),
              _LabNotice(
                text: branch == 'Premium'
                    ? 'Premium kalite daha derin klinik akıl yürütme hedefler ve daha yüksek MC tüketebilir. Kesin ücret backend tarafından üretim sırasında hesaplanır.'
                    : 'MC tutarı üretim sırasında güvenli şekilde backend tarafından hesaplanır.',
              ),
            ],
          ),
        ),
        _StepPanel(
          number: 5,
          title: 'Klinik İçerik Kapsamı',
          child: _FocusChips(
            labels: const [
              'Hasta bilgisi',
              'Başvuru şikayeti',
              'Öykü',
              'Fizik muayene',
              'Laboratuvar/görüntüleme',
              'Klinik karar',
              'Tanı-tedavi tartışması',
              'Sınav ipuçları',
            ],
            selectedLabels: const {
              'Hasta bilgisi',
              'Başvuru şikayeti',
              'Öykü',
              'Fizik muayene',
              'Laboratuvar/görüntüleme',
              'Klinik karar',
              'Tanı',
              'Sınav ipuçları',
            },
            onTap: (label) =>
                _showLabSnack(context, '$label odağı güncellendi.'),
          ),
        ),
        _SummaryActionBar(
          icon: Icons.description_outlined,
          title: 'Özet',
          detail:
              '${selectedSources.length} kaynak  •  $clinicalType  •  $difficulty  •  $level  •  $branch',
          buttonLabel: 'Klinik senaryo üret',
          subtitle: canGenerate
              ? null
              : hasSources
              ? 'Hazır olmayan kaynak var'
              : 'Önce kaynak seç',
          onTap: canGenerate ? onGenerate : null,
        ),
      ],
    );
  }
}

class _ClinicalScenarioResult extends StatelessWidget {
  const _ClinicalScenarioResult({
    required this.loading,
    required this.result,
    required this.error,
    required this.onBack,
    required this.onSearch,
    required this.onSave,
    required this.onExport,
    required this.onRegenerate,
    required this.onComplete,
  });

  final bool loading;
  final _LabGenerationResult? result;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback onSave;
  final VoidCallback onExport;
  final VoidCallback onRegenerate;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    if (loading || result != null || error != null) {
      return _SourceLabGeneratedResult(
        title: 'Klinik Senaryo',
        tool: _ToolKind.clinical,
        loading: loading,
        result: result,
        error: error,
        onBack: onBack,
        onSave: onSave,
        onExport: onExport,
        onRegenerate: onRegenerate,
        saveLabel: 'Koleksiyona ekle',
        exportLabel: 'Kopyala',
        loadingSteps: const [
          'Kaynak analiz ediliyor',
          'Klinik bulgular çıkarılıyor',
          'Vaka kurgusu hazırlanıyor',
          'Soru ve açıklamalar oluşturuluyor',
        ],
      );
    }
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
    required this.quality,
    required this.includeReviews,
    required this.onBack,
    required this.onSearch,
    required this.onPickSources,
    required this.onGoal,
    required this.onPriority,
    required this.onIntensity,
    required this.onDaysChanged,
    required this.onDuration,
    required this.onQuality,
    required this.onReviews,
    required this.onGenerate,
  });

  final List<_LabSource> selectedSources;
  final String goal;
  final String priority;
  final String intensity;
  final int days;
  final String dailyDuration;
  final String quality;
  final bool includeReviews;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback onPickSources;
  final ValueChanged<String> onGoal;
  final ValueChanged<String> onPriority;
  final ValueChanged<String> onIntensity;
  final ValueChanged<int> onDaysChanged;
  final ValueChanged<String> onDuration;
  final ValueChanged<String> onQuality;
  final ValueChanged<bool> onReviews;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final hasSources = selectedSources.isNotEmpty;
    final blockedReasons = selectedSources
        .where((source) => source.disabledReason != null)
        .map((source) => source.disabledReason!)
        .toSet()
        .toList();
    final canGenerate = hasSources && blockedReasons.isEmpty;
    return _LabScroll(
      children: [
        _LabTopBar(onBack: onBack, onSearch: onSearch),
        _CompactToolHero(
          title: 'Öğrenme Planı',
          subtitle:
              'Kaynağını günlük hedeflere, tekrar döngülerine ve çalışma planına dönüştür.',
          icon: Icons.event_note_outlined,
          selectedCount: selectedSources.length,
          hasSources: hasSources,
          onPickSources: onPickSources,
        ),
        _StepPanel(
          number: 1,
          title: 'Kaynak Seçimi',
          trailing: _SmallActionButton(
            label: hasSources ? 'Kaynak Değiştir' : 'Drive’dan kaynak seç',
            icon: Icons.folder_open_rounded,
            onTap: onPickSources,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!hasSources)
                const _LabEmptyState(
                  icon: Icons.folder_open_outlined,
                  title: 'Kaynak seçilmedi',
                  message:
                      'Hazır/Tamamlandı durumda ve boyutu 0 KB olmayan bir Drive kaynağı seçin.',
                )
              else
                _SourceGrid(
                  sources: selectedSources,
                  allowRemove: false,
                  onRemove: (_) {},
                  onMenu: onPickSources,
                ),
              for (final reason in blockedReasons) ...[
                const SizedBox(height: 12),
                _LabNotice(text: reason),
              ],
            ],
          ),
        ),
        _StepPanel(
          number: 2,
          title: 'Plan Hedefi',
          child: _InfographicOptionGrid(
            values: const [
              'Hızlı tekrar planı',
              '7 günlük plan',
              '14 günlük plan',
              '30 günlük plan',
              'Sınav tarihi odaklı plan',
              'Zayıf konu kapatma planı',
            ],
            selected: goal,
            onSelected: onGoal,
          ),
        ),
        _StepPanel(
          number: 3,
          title: 'Günlük Süre ve Çalışma Stili',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SegmentedOptions(
                values: const [
                  '30 dk',
                  '1 saat',
                  '2 saat',
                  '4 saat',
                  'Özel süre',
                ],
                selected: dailyDuration,
                onSelected: onDuration,
              ),
              const SizedBox(height: 16),
              _InfographicOptionGrid(
                values: const [
                  'Aktif hatırlama',
                  'Soru çözerek öğrenme',
                  'Flashcard destekli',
                  'Klinik bağlantılı',
                  'Temel bilim bağlantılı',
                  'Dengeli',
                ],
                selected: priority,
                onSelected: onPriority,
              ),
            ],
          ),
        ),
        _StepPanel(
          number: 4,
          title: 'Çıktı Formatı',
          child: _InfographicOptionGrid(
            values: const [
              'Gün gün plan',
              'Haftalık yol haritası',
              'Checklist',
              'Takvim + tekrar döngüsü',
              'Pomodoro blokları',
            ],
            selected: intensity,
            onSelected: onIntensity,
          ),
        ),
        _StepPanel(
          number: 5,
          title: 'Kalite ve Tekrar Döngüsü',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SegmentedOptions(
                values: const ['Ekonomik', 'Standart', 'Premium'],
                selected: quality,
                onSelected: onQuality,
              ),
              const SizedBox(height: 12),
              _LabNotice(
                text: quality == 'Premium'
                    ? 'Premium kalite daha kişiselleştirilmiş planlama hedefler ve daha yüksek MC tüketebilir. Kesin ücret backend tarafından üretim sırasında hesaplanır.'
                    : 'MC tutarı üretim sırasında güvenli şekilde backend tarafından hesaplanır.',
              ),
              const SizedBox(height: 14),
              _SwitchSetting(
                title: 'Tekrar Seansları Ekle',
                subtitle:
                    'Planına spaced repetition tekrar seansları otomatik olarak eklensin.',
                value: includeReviews,
                onChanged: onReviews,
              ),
            ],
          ),
        ),
        _PlanSummaryBar(
          days: _planDaysForGoal(goal),
          duration: dailyDuration,
          focus: 5,
          reviews: includeReviews,
          quality: quality,
          canGenerate: canGenerate,
          blockedSubtitle: canGenerate
              ? null
              : hasSources
              ? 'Hazır olmayan kaynak var'
              : 'Önce kaynak seç',
          onGenerate: canGenerate ? onGenerate : null,
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
    required this.loading,
    required this.result,
    required this.error,
    required this.onBack,
    required this.onSave,
    required this.onCalendar,
    required this.onExport,
    required this.onRegenerate,
  });

  final List<_LabSource> selectedSources;
  final int planDays;
  final String planGoal;
  final bool loading;
  final _LabGenerationResult? result;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final VoidCallback onCalendar;
  final VoidCallback onExport;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    if (loading || result != null || error != null) {
      return _SourceLabGeneratedResult(
        title: 'Öğrenme Planı',
        tool: _ToolKind.plan,
        loading: loading,
        result: result,
        error: error,
        onBack: onBack,
        onSave: onSave,
        onExport: onExport,
        onRegenerate: onRegenerate,
        saveLabel: 'Koleksiyona ekle',
        exportLabel: 'Kopyala',
        loadingSteps: const [
          'Kaynak bölümlere ayrılıyor',
          'Öncelikler belirleniyor',
          'Tekrar döngüsü kuruluyor',
          'Çalışma planı hazırlanıyor',
        ],
      );
    }
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
    required this.loading,
    required this.result,
    required this.error,
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
  final bool loading;
  final _LabGenerationResult? result;
  final String? error;
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
    if (loading || result != null || error != null) {
      return _SourceLabGeneratedResult(
        title: 'Podcast Özeti',
        tool: _ToolKind.podcast,
        loading: loading,
        result: result,
        error: error,
        onBack: onBack,
        onSave: onSave,
        onExport: onExport,
        onRegenerate: onRegenerate,
        audioNotice:
            'Backend metinsel podcast scripti döndürüyor; gerçek ses dosyası/oynatıcı entegrasyonu bağlı değil.',
      );
    }
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

class _InfographicHero extends StatelessWidget {
  const _InfographicHero({
    required this.selectedCount,
    required this.hasSources,
    required this.onPickSources,
  });

  final int selectedCount;
  final bool hasSources;
  final VoidCallback onPickSources;

  @override
  Widget build(BuildContext context) {
    return _LabPanel(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      radius: 18,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'İnfografik',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 34,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Kaynağından klinik akış, mekanizma ve sınav odaklı görsel özet üret.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 16,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _MiniHeroChip(
                    icon: Icons.source_outlined,
                    label: '$selectedCount kaynak seçili',
                  ),
                  const _MiniHeroChip(
                    icon: Icons.medical_information_outlined,
                    label: 'Klinik odak',
                  ),
                  const _MiniHeroChip(
                    icon: Icons.high_quality_outlined,
                    label: 'Görsel çıktı',
                  ),
                ],
              ),
            ],
          );
          final cta = _SmallActionButton(
            label: hasSources ? 'Kaynakları yönet' : 'Drive’dan kaynak seç',
            icon: Icons.folder_open_rounded,
            onTap: onPickSources,
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                copy,
                const SizedBox(height: 16),
                Align(alignment: Alignment.centerLeft, child: cta),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: copy),
              const SizedBox(width: 20),
              SizedBox(width: 210, child: cta),
            ],
          );
        },
      ),
    );
  }
}

class _MindMapHero extends StatelessWidget {
  const _MindMapHero({
    required this.selectedCount,
    required this.hasSources,
    required this.onPickSources,
  });

  final int selectedCount;
  final bool hasSources;
  final VoidCallback onPickSources;

  @override
  Widget build(BuildContext context) {
    return _LabPanel(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      radius: 18,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Zihin Haritası',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 34,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Kaynağındaki kavramları merkez-dal-alt dal ilişkisiyle öğrenilebilir haritaya dönüştür.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 16,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _MiniHeroChip(
                    icon: Icons.source_outlined,
                    label: '$selectedCount kaynak seçili',
                  ),
                  const _MiniHeroChip(
                    icon: Icons.hub_outlined,
                    label: 'Merkez-dal yapı',
                  ),
                  const _MiniHeroChip(
                    icon: Icons.medical_information_outlined,
                    label: 'Klinik/TUS ipucu',
                  ),
                ],
              ),
            ],
          );
          final cta = _SmallActionButton(
            label: hasSources ? 'Kaynakları yönet' : 'Drive’dan kaynak seç',
            icon: Icons.folder_open_rounded,
            onTap: onPickSources,
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                copy,
                const SizedBox(height: 16),
                Align(alignment: Alignment.centerLeft, child: cta),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: copy),
              const SizedBox(width: 20),
              SizedBox(width: 210, child: cta),
            ],
          );
        },
      ),
    );
  }
}

class _InfographicOptionGrid extends StatelessWidget {
  const _InfographicOptionGrid({
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 680 ? 3 : 2;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final value in values)
              SizedBox(
                width: width,
                child: _InfographicOptionCard(
                  label: value,
                  selected: value == selected,
                  onTap: () => onSelected(value),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _InfographicOptionCard extends StatelessWidget {
  const _InfographicOptionCard({
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF5FF) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.blue : AppColors.line),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.blue : AppColors.softText,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 14.5,
                  height: 1.12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamMorningBuilder extends StatelessWidget {
  const _ExamMorningBuilder({
    required this.selectedSources,
    required this.summaryMode,
    required this.lengthTarget,
    required this.outputFormats,
    required this.quality,
    required this.onBack,
    required this.onSearch,
    required this.onPickSources,
    required this.onRemoveSource,
    required this.onSummaryMode,
    required this.onLengthTarget,
    required this.onToggleFormat,
    required this.onQuality,
    required this.onGenerate,
  });

  final List<_LabSource> selectedSources;
  final String summaryMode;
  final String lengthTarget;
  final Set<String> outputFormats;
  final String quality;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback onPickSources;
  final ValueChanged<String> onRemoveSource;
  final ValueChanged<String> onSummaryMode;
  final ValueChanged<String> onLengthTarget;
  final ValueChanged<String> onToggleFormat;
  final ValueChanged<String> onQuality;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final hasSources = selectedSources.isNotEmpty;
    final blockedReasons = selectedSources
        .where((source) => source.disabledReason != null)
        .map((source) => source.disabledReason!)
        .toSet()
        .toList();
    final canGenerate = hasSources && blockedReasons.isEmpty;
    return _LabScroll(
      children: [
        _LabTopBar(onBack: onBack, onSearch: onSearch),
        _ExamMorningHero(
          selectedCount: selectedSources.length,
          hasSources: hasSources,
          onPickSources: onPickSources,
        ),
        _StepPanel(
          number: 1,
          title: 'Kaynak Seçimi',
          trailing: _SmallActionButton(
            label: hasSources ? 'Kaynak Değiştir' : 'Drive’dan kaynak seç',
            icon: Icons.folder_open_rounded,
            onTap: onPickSources,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!hasSources)
                const _LabEmptyState(
                  icon: Icons.folder_open_outlined,
                  title: 'Kaynak seçilmedi',
                  message:
                      'Hazır ve boyutu 0 KB olmayan bir Drive kaynağı seçerek son tekrar özetini başlatın.',
                )
              else
                _SourceGrid(
                  sources: selectedSources,
                  allowRemove: true,
                  onRemove: onRemoveSource,
                  onMenu: onPickSources,
                ),
              for (final reason in blockedReasons) ...[
                const SizedBox(height: 12),
                _LabNotice(text: reason),
              ],
            ],
          ),
        ),
        _StepPanel(
          number: 2,
          title: 'Özet Tipi',
          child: _InfographicOptionGrid(
            values: const [
              'Hızlı tekrar',
              'Sınav sabahı kritikler',
              'En çok karıştırılanlar',
              'Klinik ipuçları',
              'Temel bilim mekanizması',
              'TUS tarzı yüksek verim',
            ],
            selected: summaryMode,
            onSelected: onSummaryMode,
          ),
        ),
        _StepPanel(
          number: 3,
          title: 'Uzunluk ve Format',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SegmentedOptions(
                values: const [
                  '3 dakikalık',
                  '7 dakikalık',
                  '15 dakikalık',
                  'Detaylı son tekrar',
                ],
                selected: lengthTarget,
                onSelected: onLengthTarget,
              ),
              const SizedBox(height: 16),
              _ExamFormatGrid(
                selected: outputFormats,
                onToggle: onToggleFormat,
              ),
            ],
          ),
        ),
        _StepPanel(
          number: 4,
          title: 'Kalite ve MC',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SegmentedOptions(
                values: const ['Ekonomik', 'Standart', 'Premium'],
                selected: quality,
                onSelected: onQuality,
              ),
              const SizedBox(height: 12),
              _LabNotice(
                text: quality == 'Premium'
                    ? 'Premium kalite daha derin ayrıştırma hedefler ve daha yüksek MC tüketebilir. MC tutarı üretim sırasında güvenli şekilde hesaplanır.'
                    : 'MC tutarı üretim sırasında güvenli şekilde hesaplanır.',
              ),
            ],
          ),
        ),
        _PrimaryLabButton(
          label: 'Sınav Sabahı Özeti üret',
          icon: Icons.alarm_on_rounded,
          onTap: canGenerate ? onGenerate : null,
          subtitle: canGenerate
              ? null
              : hasSources
              ? 'Hazır olmayan kaynak var'
              : 'Önce kaynak seç',
          height: 76,
        ),
      ],
    );
  }
}

class _ExamMorningHero extends StatelessWidget {
  const _ExamMorningHero({
    required this.selectedCount,
    required this.hasSources,
    required this.onPickSources,
  });

  final int selectedCount;
  final bool hasSources;
  final VoidCallback onPickSources;

  @override
  Widget build(BuildContext context) {
    return _LabPanel(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sınav Sabahı Özeti',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 30,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Kaynağından son tekrar için yüksek verimli, kısa ve sınav odaklı özet çıkar.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 16,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _MiniHeroChip(
                    icon: Icons.library_books_outlined,
                    label: '$selectedCount kaynak',
                  ),
                  const _MiniHeroChip(
                    icon: Icons.bolt_outlined,
                    label: '5-10 dk tekrar',
                  ),
                  const _MiniHeroChip(
                    icon: Icons.medical_information_outlined,
                    label: 'Klinik ipucu',
                  ),
                ],
              ),
            ],
          );
          final action = _SmallActionButton(
            label: hasSources ? 'Kaynakları yönet' : 'Drive’dan kaynak seç',
            icon: Icons.folder_open_rounded,
            onTap: onPickSources,
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [copy, const SizedBox(height: 16), action],
            );
          }
          return Row(
            children: [
              Expanded(child: copy),
              const SizedBox(width: 18),
              SizedBox(width: 230, child: action),
            ],
          );
        },
      ),
    );
  }
}

class _ExamFormatGrid extends StatelessWidget {
  const _ExamFormatGrid({required this.selected, required this.onToggle});

  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    const values = [
      'Madde madde',
      'Mini tablo',
      'Klinik ipucu kartları',
      'Soru-cevap',
      'Algoritmik akış',
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 680 ? 3 : 2;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final value in values)
              SizedBox(
                width: width,
                child: _ExamFormatCard(
                  label: value,
                  selected: selected.contains(value),
                  onTap: () => onToggle(value),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ExamFormatCard extends StatelessWidget {
  const _ExamFormatCard({
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF5FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.blue : AppColors.line),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? AppColors.blue : AppColors.softText,
              size: 20,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamMorningResult extends StatelessWidget {
  const _ExamMorningResult({
    required this.loading,
    required this.result,
    required this.error,
    required this.onBack,
    required this.onSave,
    required this.onCopy,
    required this.onRegenerate,
    required this.onPickSources,
  });

  final bool loading;
  final _LabGenerationResult? result;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final VoidCallback onCopy;
  final VoidCallback onRegenerate;
  final VoidCallback onPickSources;

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    return _LabScroll(
      children: [
        _MinimalTopBar(
          title: 'Sınav Sabahı Özeti',
          subtitle: loading
              ? 'Kaynak taranıyor ve yüksek verimli tekrar hazırlanıyor.'
              : result == null
              ? 'Son tekrar özeti tamamlanamadı.'
              : '${result.sourceTitle} kaynağından oluşturuldu.',
          onBack: onBack,
        ),
        _LabPanel(
          child: loading
              ? const _ExamLoadingState()
              : error != null
              ? _LabEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Üretim tamamlanamadı',
                  message: error!,
                )
              : result == null
              ? const _LabEmptyState(
                  icon: Icons.warning_amber_rounded,
                  title: 'Boş sonuç',
                  message:
                      'Backend tamamlandı ancak gösterilecek sınav özeti dönmedi.',
                )
              : _ExamMorningContent(result: result),
        ),
        if (result != null && error == null && !loading)
          _ResponsiveActions(
            children: [
              _SecondaryLabButton(
                label: 'Koleksiyona ekle',
                icon: Icons.bookmark_border_rounded,
                onTap: onSave,
                height: 64,
              ),
              _SecondaryLabButton(
                label: 'Yeniden üret',
                icon: Icons.refresh_rounded,
                onTap: onRegenerate,
                height: 64,
              ),
              _SecondaryLabButton(
                label: 'Kopyala/Paylaş',
                icon: Icons.ios_share_rounded,
                onTap: onCopy,
                height: 64,
              ),
              _SecondaryLabButton(
                label: 'Kaynağa dön',
                icon: Icons.folder_open_rounded,
                onTap: onPickSources,
                height: 64,
              ),
            ],
          )
        else if (!loading)
          _PrimaryLabButton(
            label: 'Yeniden üret',
            icon: Icons.refresh_rounded,
            onTap: onRegenerate,
          ),
      ],
    );
  }
}

class _ExamLoadingState extends StatelessWidget {
  const _ExamLoadingState();

  @override
  Widget build(BuildContext context) {
    const messages = [
      'Kaynak taranıyor',
      'Yüksek verimli bilgiler seçiliyor',
      'Karıştırılan noktalar ayrıştırılıyor',
      'Sınav sabahı formatı hazırlanıyor',
      'Son özet oluşturuluyor',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          const CircularProgressIndicator(color: AppColors.blue),
          const SizedBox(height: 20),
          for (var i = 0; i < messages.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: i == 0
                        ? AppColors.blue
                        : AppColors.selectedBlue,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: i == 0 ? Colors.white : AppColors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      messages[i],
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
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

class _ExamMorningContent extends StatelessWidget {
  const _ExamMorningContent({required this.result});

  final _LabGenerationResult result;

  @override
  Widget build(BuildContext context) {
    final content = result.content;
    final map = content is Map ? content : const {};
    final title = _examText(map['title']) ?? result.title;
    final table = _examValueFor(map, const [
      'mini_table',
      'miniTable',
      'table',
    ]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 26,
            height: 1.08,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _TagPill(label: 'Kaynak: ${result.sourceTitle}'),
            _TagPill(label: result.createdAtLabel),
            _TagPill(label: result.examSummaryMode ?? 'Sınav sabahı'),
            _TagPill(label: result.examLengthTarget ?? '7 dakikalık'),
            _TagPill(label: result.examOutputFormat ?? 'Madde madde'),
            _TagPill(label: result.examQuality ?? 'Standart'),
          ],
        ),
        const SizedBox(height: 12),
        _LabNotice(text: result.mcCostLabel),
        const SizedBox(height: 18),
        _ExamSection(
          title: 'Bölüm 1: Mutlaka bil',
          icon: Icons.priority_high_rounded,
          values: _examListFor(map, const [
            'must_know',
            'mutlaka_bil',
            'high_yield',
            'key_points',
            'bulletPoints',
          ]),
        ),
        _ExamSection(
          title: 'Bölüm 2: En çok karıştırılanlar',
          icon: Icons.compare_arrows_rounded,
          values: _examListFor(map, const [
            'commonly_confused',
            'confusions',
            'pitfalls',
          ]),
        ),
        _ExamSection(
          title: 'Bölüm 3: Klinik/TUS ipuçları',
          icon: Icons.medical_information_outlined,
          values: _examListFor(map, const [
            'clinical_tus_tips',
            'clinical_tips',
            'tus_tips',
            'red_flags',
          ]),
        ),
        _ExamMiniTable(value: table),
        _ExamSection(
          title: 'Bölüm 4: Mini algoritmalar',
          icon: Icons.account_tree_outlined,
          values: _examListFor(map, const [
            'algorithm_flow',
            'algorithms',
            'flows',
            'mini_algorithms',
          ]),
        ),
        _ExamSection(
          title: 'Bölüm 5: Kendini yokla',
          icon: Icons.quiz_outlined,
          values: _examListFor(map, const [
            'self_check',
            'quick_qa',
            'questions',
            'qa',
          ]),
        ),
        if (map.isEmpty) _LabGeneratedContent(content: content),
      ],
    );
  }
}

class _ExamSection extends StatelessWidget {
  const _ExamSection({
    required this.title,
    required this.icon,
    required this.values,
  });

  final String title;
  final IconData icon;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.blue, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final value in values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: CircleAvatar(
                      radius: 3,
                      backgroundColor: AppColors.blue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _LabGeneratedText(text: value)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ExamMiniTable extends StatelessWidget {
  const _ExamMiniTable({required this.value});

  final Object? value;

  @override
  Widget build(BuildContext context) {
    final rows = _examTableRows(value);
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.table_chart_outlined, color: AppColors.blue, size: 22),
              SizedBox(width: 10),
              Text(
                'Bölüm 4: Mini tablo veya akış',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final row in rows)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FBFF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                row,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 14.5,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfographicBuilder extends StatelessWidget {
  const _InfographicBuilder({
    required this.selectedSources,
    required this.type,
    required this.style,
    required this.density,
    required this.quality,
    required this.onBack,
    required this.onSearch,
    required this.onPickSources,
    required this.onType,
    required this.onStyle,
    required this.onDensity,
    required this.onQuality,
    required this.onGenerate,
  });

  final List<_LabSource> selectedSources;
  final String type;
  final String style;
  final String density;
  final String quality;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback onPickSources;
  final ValueChanged<String> onType;
  final ValueChanged<String> onStyle;
  final ValueChanged<String> onDensity;
  final ValueChanged<String> onQuality;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final hasSources = selectedSources.isNotEmpty;
    final blockedReasons = selectedSources
        .where((source) => source.disabledReason != null)
        .map((source) => source.disabledReason!)
        .toSet()
        .toList();
    final canGenerate = hasSources && blockedReasons.isEmpty;
    return _LabScroll(
      children: [
        _LabTopBar(onBack: onBack, onSearch: onSearch),
        _InfographicHero(
          selectedCount: selectedSources.length,
          hasSources: hasSources,
          onPickSources: onPickSources,
        ),
        _StepPanel(
          number: 1,
          title: 'Kaynak Seçimi',
          trailing: _SmallActionButton(
            label: hasSources ? 'Kaynak Değiştir' : 'Drive’dan Seç',
            icon: Icons.folder_open_rounded,
            onTap: onPickSources,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!hasSources)
                const _LabEmptyState(
                  icon: Icons.folder_open_outlined,
                  title: 'Kaynak seçilmedi',
                  message:
                      'Hazır ve boyutu 0 KB olmayan bir Drive kaynağı seçerek infografik üretimini başlatın.',
                )
              else
                _SourceGrid(
                  sources: selectedSources,
                  allowRemove: false,
                  onRemove: (_) {},
                  onMenu: onPickSources,
                ),
              for (final reason in blockedReasons) ...[
                const SizedBox(height: 12),
                _LabNotice(text: reason),
              ],
            ],
          ),
        ),
        _StepPanel(
          number: 2,
          title: 'İnfografik Türü',
          child: _InfographicOptionGrid(
            values: const [
              'Klinik Akış',
              'Mekanizma Haritası',
              'Sınav Sabahı Özeti',
              'Karşılaştırma Panosu',
              'Tanı-Tedavi Algoritması',
              'Temel Bilim Mekanizması',
              'TUS Yüksek Verim Posteri',
            ],
            selected: type,
            onSelected: onType,
          ),
        ),
        _StepPanel(
          number: 3,
          title: 'Görsel Stil ve Yoğunluk',
          child: Column(
            children: [
              _SettingRow(
                icon: Icons.palette_outlined,
                label: 'Görsel Stil',
                child: _SegmentedOptions(
                  values: const [
                    'Akademik',
                    'Klinik',
                    'Minimal',
                    'Poster',
                    'Premium',
                    'Açık tema',
                    'Koyu tema',
                  ],
                  selected: style,
                  onSelected: onStyle,
                ),
              ),
              _SettingRow(
                icon: Icons.notes_rounded,
                label: 'Yoğunluk',
                child: _SegmentedOptions(
                  values: const ['Kısa', 'Dengeli', 'Detaylı'],
                  selected: density,
                  onSelected: onDensity,
                ),
              ),
            ],
          ),
        ),
        _StepPanel(
          number: 4,
          title: 'Kalite ve MC',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SettingRow(
                icon: Icons.high_quality_outlined,
                label: 'Kalite',
                child: _SegmentedOptions(
                  values: const ['Ekonomik', 'Standart', 'Premium'],
                  selected: quality,
                  onSelected: onQuality,
                ),
              ),
              _LabNotice(
                text: quality == 'Premium'
                    ? 'Premium kalite daha yüksek görsel kalite hedefler ve standart üretime göre daha fazla MC tüketebilir. MC tutarı üretim sırasında güvenli şekilde hesaplanır.'
                    : 'MC tutarı üretim sırasında güvenli şekilde hesaplanır.',
              ),
            ],
          ),
        ),
        _StepPanel(
          number: 5,
          title: 'Akademik Görsel Çatı',
          child: const _InfographicLayoutPreview(),
        ),
        _PrimaryLabButton(
          label: 'İnfografik üret',
          icon: Icons.auto_awesome_rounded,
          onTap: canGenerate ? onGenerate : null,
          subtitle: canGenerate
              ? null
              : hasSources
              ? 'Hazır olmayan kaynak var'
              : 'Önce kaynak seç',
          height: 72,
        ),
      ],
    );
  }
}

class _InfographicResult extends StatelessWidget {
  const _InfographicResult({
    required this.loading,
    required this.result,
    required this.error,
    required this.onBack,
    required this.onSearch,
    required this.onSave,
    required this.onPng,
    required this.onPdf,
    required this.onRegenerate,
  });

  final bool loading;
  final _LabGenerationResult? result;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback onSave;
  final VoidCallback onPng;
  final VoidCallback onPdf;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    if (loading || result != null || error != null) {
      return _InfographicGeneratedResult(
        loading: loading,
        result: result,
        error: error,
        onBack: onBack,
        onSave: onSave,
        onView: onPng,
        onShare: onPdf,
        onRegenerate: onRegenerate,
      );
    }
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
    required this.quality,
    required this.expandChildren,
    required this.onBack,
    required this.onSearch,
    required this.onPickSources,
    required this.onRemoveSource,
    required this.onMapKind,
    required this.onDepth,
    required this.onLook,
    required this.onQuality,
    required this.onExpandChildren,
    required this.onGenerate,
  });

  final List<_LabSource> selectedSources;
  final String mapKind;
  final String depth;
  final String look;
  final String quality;
  final bool expandChildren;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback onPickSources;
  final ValueChanged<String> onRemoveSource;
  final ValueChanged<String> onMapKind;
  final ValueChanged<String> onDepth;
  final ValueChanged<String> onLook;
  final ValueChanged<String> onQuality;
  final ValueChanged<bool> onExpandChildren;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final hasSources = selectedSources.isNotEmpty;
    final blockedReasons = selectedSources
        .where((source) => source.disabledReason != null)
        .map((source) => source.disabledReason!)
        .toSet()
        .toList();
    final canGenerate = hasSources && blockedReasons.isEmpty;
    return _LabScroll(
      children: [
        _LabTopBar(onBack: onBack, onSearch: onSearch, showMore: true),
        _MindMapHero(
          selectedCount: selectedSources.length,
          hasSources: hasSources,
          onPickSources: onPickSources,
        ),
        _StepPanel(
          number: 1,
          title: 'Kaynak Seçimi',
          trailing: _SmallActionButton(
            label: hasSources ? 'Kaynak Değiştir' : 'Drive’dan kaynak seç',
            icon: Icons.folder_open_rounded,
            onTap: onPickSources,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!hasSources)
                const _LabEmptyState(
                  icon: Icons.folder_open_outlined,
                  title: 'Kaynak seçilmedi',
                  message:
                      'Hazır ve boyutu 0 KB olmayan bir Drive kaynağı seçerek zihin haritası üretimini başlatın.',
                )
              else
                _SourceGrid(
                  sources: selectedSources,
                  allowRemove: true,
                  onRemove: onRemoveSource,
                  onMenu: onPickSources,
                ),
              if (hasSources) ...[
                const SizedBox(height: 14),
                _DashedAddRow(
                  label: 'Drive’dan kaynak seç',
                  onTap: onPickSources,
                ),
              ],
              for (final reason in blockedReasons) ...[
                const SizedBox(height: 12),
                _LabNotice(text: reason),
              ],
            ],
          ),
        ),
        _StepPanel(
          number: 2,
          title: 'Harita Tipi',
          child: _InfographicOptionGrid(
            values: const [
              'Konu Haritası',
              'Klinik Yaklaşım Haritası',
              'Mekanizma Haritası',
              'Temel Bilim Haritası',
              'Tanı-Tedavi Haritası',
              'Sınav Tekrar Haritası',
            ],
            selected: mapKind,
            onSelected: onMapKind,
          ),
        ),
        _StepPanel(
          number: 3,
          title: 'Derinlik ve Görünüm',
          child: Column(
            children: [
              _SettingRow(
                icon: Icons.account_tree_outlined,
                label: 'Derinlik',
                helper: true,
                child: _SegmentedOptions(
                  values: const [
                    '2 seviye',
                    '3 seviye',
                    'Detaylı',
                    'Sınav odaklı',
                  ],
                  selected: depth,
                  onSelected: onDepth,
                ),
              ),
              _SettingRow(
                icon: Icons.view_quilt_outlined,
                label: 'Görünüm',
                child: _InfographicOptionGrid(
                  values: const [
                    'Merkezden dallanan',
                    'Hiyerarşik ağaç',
                    'Kartlı harita',
                    'Mobil kompakt',
                    'Geniş ekran',
                  ],
                  selected: look,
                  onSelected: onLook,
                ),
              ),
              _SwitchSetting(
                icon: Icons.unfold_more_rounded,
                title: 'Alt dalları açık başlat',
                subtitle: 'Mobilde kartlı hiyerarşi korunur.',
                value: expandChildren,
                onChanged: onExpandChildren,
              ),
            ],
          ),
        ),
        _StepPanel(
          number: 4,
          title: 'Kalite ve MC',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SegmentedOptions(
                values: const ['Ekonomik', 'Standart', 'Premium'],
                selected: quality,
                onSelected: onQuality,
              ),
              const SizedBox(height: 12),
              _LabNotice(
                text: quality == 'Premium'
                    ? 'Premium kalite daha derin ilişki çıkarımı hedefler ve daha yüksek MC tüketebilir. MC tutarı üretim sırasında güvenli şekilde hesaplanır.'
                    : 'MC tutarı üretim sırasında güvenli şekilde hesaplanır.',
              ),
            ],
          ),
        ),
        _StepPanel(
          number: 5,
          title: 'Önizleme',
          child: const SizedBox(height: 260, child: _MindMapPreview()),
        ),
        _PrimaryLabButton(
          label: 'Zihin haritası üret',
          icon: Icons.auto_awesome_rounded,
          onTap: canGenerate ? onGenerate : null,
          subtitle: canGenerate
              ? null
              : hasSources
              ? 'Hazır olmayan kaynak var'
              : 'Önce kaynak seç',
          height: 76,
        ),
      ],
    );
  }
}

class _MindMapResult extends StatelessWidget {
  const _MindMapResult({
    required this.loading,
    required this.result,
    required this.error,
    required this.onBack,
    required this.onSave,
    required this.onExport,
    required this.onRegenerate,
  });

  final bool loading;
  final _LabGenerationResult? result;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final VoidCallback onExport;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    if (loading || result != null || error != null) {
      return _MindMapGeneratedResult(
        loading: loading,
        result: result,
        error: error,
        onBack: onBack,
        onSave: onSave,
        onExport: onExport,
        onRegenerate: onRegenerate,
      );
    }
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

class _MindMapGeneratedResult extends StatelessWidget {
  const _MindMapGeneratedResult({
    required this.loading,
    required this.result,
    required this.error,
    required this.onBack,
    required this.onSave,
    required this.onExport,
    required this.onRegenerate,
  });

  final bool loading;
  final _LabGenerationResult? result;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final VoidCallback onExport;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final value = result;
    return _LabScroll(
      children: [
        _MinimalTopBar(
          title: 'Zihin Haritası',
          subtitle: loading
              ? 'Kavram haritası üretim kuyruğu işleniyor.'
              : value == null
              ? 'Zihin haritası tamamlanamadı.'
              : '${value.sourceTitle} kaynağından hiyerarşik harita.',
          onBack: onBack,
        ),
        _LabPanel(
          child: loading
              ? const _MindMapLoadingState()
              : error != null
              ? _LabEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Zihin haritası tamamlanamadı',
                  message: error!,
                )
              : value == null
              ? const _LabEmptyState(
                  icon: Icons.warning_amber_rounded,
                  title: 'Boş sonuç',
                  message:
                      'Backend tamamlandı ancak gösterilecek zihin haritası dönmedi.',
                )
              : _MindMapResultBody(result: value),
        ),
        if (value != null && error == null && !loading)
          _ResponsiveActions(
            children: [
              _SecondaryLabButton(
                label: 'Koleksiyona ekle',
                icon: Icons.bookmark_border_rounded,
                onTap: onSave,
              ),
              _SecondaryLabButton(
                label: 'Yeniden üret',
                icon: Icons.refresh_rounded,
                onTap: onRegenerate,
              ),
              _SecondaryLabButton(
                label: 'Kopyala/Paylaş',
                icon: Icons.ios_share_rounded,
                onTap: onExport,
              ),
              _SecondaryLabButton(
                label: 'Kaynağa dön',
                icon: Icons.folder_open_rounded,
                onTap: onBack,
              ),
            ],
          )
        else if (!loading)
          _PrimaryLabButton(
            label: 'Yeniden üret',
            icon: Icons.refresh_rounded,
            onTap: onRegenerate,
          ),
      ],
    );
  }
}

class _MindMapLoadingState extends StatelessWidget {
  const _MindMapLoadingState();

  @override
  Widget build(BuildContext context) {
    const stages = [
      'Kaynak analiz ediliyor',
      'Ana kavramlar çıkarılıyor',
      'Bağlantılar kuruluyor',
      'Harita yapısı hazırlanıyor',
      'Zihin haritası oluşturuluyor',
    ];
    return _LabLoadingState(steps: stages);
  }
}

class _MindMapResultBody extends StatelessWidget {
  const _MindMapResultBody({required this.result});

  final _LabGenerationResult result;

  @override
  Widget build(BuildContext context) {
    final map = _mindMapFromContent(result.content);
    if (map == null) {
      return const _LabEmptyState(
        icon: Icons.account_tree_outlined,
        title: 'Harita yapısı bulunamadı',
        message:
            'Backend tamamlandı ancak merkez konu ve dallar ayrıştırılamadı.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GeneratedTitleBlock(
          icon: Icons.hub_outlined,
          title: map.title,
          subtitle: '${result.sourceTitle} kaynağından yapılandırıldı.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _TagPill(label: 'Kaynak: ${result.sourceTitle}'),
            _TagPill(label: result.createdAtLabel),
            _TagPill(label: result.mindMapType ?? 'Konu Haritası'),
            _TagPill(label: result.mindMapDepth ?? '3 seviye'),
            _TagPill(label: result.mindMapViewMode ?? 'Kartlı harita'),
            _TagPill(label: result.mindMapQuality ?? 'Standart'),
          ],
        ),
        const SizedBox(height: 12),
        _LabNotice(text: result.mcCostLabel),
        const SizedBox(height: 16),
        _MindMapHierarchy(data: map),
      ],
    );
  }
}

class _MindMapHierarchy extends StatelessWidget {
  const _MindMapHierarchy({required this.data});

  final _MindMapData data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        final branchCards = [
          for (var i = 0; i < data.branches.length; i++)
            SizedBox(
              width: compact ? double.infinity : 260,
              child: _MindMapBranchCard(branch: data.branches[i], index: i),
            ),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MindMapCentralCard(label: data.centralTopic),
            const SizedBox(height: 14),
            if (compact)
              Column(
                children: [
                  for (var i = 0; i < branchCards.length; i++) ...[
                    branchCards[i],
                    if (i != branchCards.length - 1) const SizedBox(height: 12),
                  ],
                ],
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < branchCards.length; i++) ...[
                      branchCards[i],
                      if (i != branchCards.length - 1)
                        const SizedBox(width: 12),
                    ],
                  ],
                ),
              ),
            if (data.links.isNotEmpty) ...[
              const SizedBox(height: 14),
              _GeneratedSectionCard(
                icon: Icons.link_rounded,
                title: 'Kritik Bağlantılar',
                child: _GeneratedBulletList(values: data.links),
              ),
            ],
            if (data.tips.isNotEmpty)
              _GeneratedSectionCard(
                icon: Icons.lightbulb_outline_rounded,
                title: 'Klinik/TUS İpuçları',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tip in data.tips)
                      _TagPill(
                        label: tip.length > 42
                            ? '${tip.substring(0, 42)}...'
                            : tip,
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MindMapCentralCard extends StatelessWidget {
  const _MindMapCentralCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.blue.withValues(alpha: .35)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white,
            child: Icon(Icons.radio_button_checked, color: AppColors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 20,
                height: 1.15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MindMapBranchCard extends StatelessWidget {
  const _MindMapBranchCard({required this.branch, required this.index});

  final _MindMapBranch branch;
  final int index;

  @override
  Widget build(BuildContext context) {
    final color = [
      AppColors.blue,
      AppColors.green,
      AppColors.purple,
      AppColors.orange,
      AppColors.red,
    ][index % 5];
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .28)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: color.withValues(alpha: .12),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  branch.label,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 16,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (branch.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final tag in branch.tags) _TagPill(label: tag)],
            ),
          ],
          const SizedBox(height: 12),
          if (branch.children.isEmpty)
            const _GeneratedText('Alt dal bilgisi dönmedi.')
          else
            for (final child in branch.children)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Icon(Icons.circle, size: 6, color: color),
                    ),
                    const SizedBox(width: 9),
                    Expanded(child: _GeneratedText(child)),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _InfographicGeneratedResult extends StatelessWidget {
  const _InfographicGeneratedResult({
    required this.loading,
    required this.result,
    required this.error,
    required this.onBack,
    required this.onSave,
    required this.onView,
    required this.onShare,
    required this.onRegenerate,
  });

  final bool loading;
  final _LabGenerationResult? result;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final VoidCallback onView;
  final VoidCallback onShare;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final value = result;
    final image = value == null
        ? null
        : _infographicImageFromContent(value.content);
    return _LabScroll(
      children: [
        _MinimalTopBar(
          title: 'İnfografik',
          subtitle: loading
              ? 'Görsel üretim kuyruğu işleniyor.'
              : value == null
              ? 'İnfografik üretimi tamamlanamadı.'
              : '${value.sourceTitle} kaynağından klinik görsel özet.',
          onBack: onBack,
        ),
        _LabPanel(
          child: loading
              ? const _InfographicLoadingState()
              : error != null
              ? _LabEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'İnfografik üretimi tamamlanamadı',
                  message: error!,
                )
              : value == null
              ? const _LabEmptyState(
                  icon: Icons.warning_amber_rounded,
                  title: 'Boş sonuç',
                  message:
                      'Backend tamamlandı ancak gösterilecek görsel dönmedi.',
                )
              : _InfographicResultBody(result: value, image: image),
        ),
        if (value != null && error == null && !loading)
          _ResponsiveActions(
            children: [
              _SecondaryLabButton(
                label: 'Görüntüle',
                icon: Icons.open_in_full_rounded,
                onTap: onView,
              ),
              _SecondaryLabButton(
                label: 'Kaydet',
                icon: Icons.bookmark_border_rounded,
                onTap: onSave,
              ),
              _SecondaryLabButton(
                label: 'Yeniden üret',
                icon: Icons.refresh_rounded,
                onTap: onRegenerate,
              ),
              _SecondaryLabButton(
                label: 'İndir / paylaş',
                icon: Icons.ios_share_rounded,
                onTap: onShare,
              ),
            ],
          )
        else if (!loading)
          _PrimaryLabButton(
            label: 'Yeniden üret',
            icon: Icons.refresh_rounded,
            onTap: onRegenerate,
          ),
      ],
    );
  }
}

class _InfographicLoadingState extends StatelessWidget {
  const _InfographicLoadingState();

  @override
  Widget build(BuildContext context) {
    const stages = [
      'Kaynak analiz ediliyor',
      'Görsel yapı kuruluyor',
      'İnfografik oluşturuluyor',
      'Sonuç hazırlanıyor',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          const CircularProgressIndicator(color: AppColors.blue),
          const SizedBox(height: 18),
          for (var i = 0; i < stages.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == stages.length - 1 ? 0 : 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: i == 0
                        ? AppColors.selectedBlue
                        : const Color(0xFFF3F6FB),
                    child: Icon(
                      i == 0 ? Icons.sync_rounded : Icons.more_horiz_rounded,
                      size: 16,
                      color: i == 0 ? AppColors.blue : AppColors.muted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    stages[i],
                    style: TextStyle(
                      color: i == 0 ? AppColors.navy : AppColors.muted,
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

class _InfographicResultBody extends StatelessWidget {
  const _InfographicResultBody({required this.result, required this.image});

  final _LabGenerationResult result;
  final _InfographicImage? image;

  @override
  Widget build(BuildContext context) {
    final contentTitle = _infographicTitle(result.content);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          contentTitle.isEmpty ? result.title : contentTitle,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 14),
        _InfographicMetaGrid(result: result, image: image),
        const SizedBox(height: 18),
        AspectRatio(
          aspectRatio: 2 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FBFF),
                border: Border.all(color: AppColors.line),
              ),
              child: image == null
                  ? const _LabEmptyState(
                      icon: Icons.image_not_supported_outlined,
                      title: 'Görsel çıktı bulunamadı',
                      message:
                          'İş tamamlandı ancak backend image URL veya data URL döndürmedi.',
                    )
                  : _InfographicImageView(image: image!),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfographicMetaGrid extends StatelessWidget {
  const _InfographicMetaGrid({required this.result, required this.image});

  final _LabGenerationResult result;
  final _InfographicImage? image;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Kaynak', result.sourceTitle),
      ('Oluşturma', result.createdAtLabel),
      (
        'Stil / kalite',
        '${result.infographicStyle ?? '-'} / ${result.infographicQuality ?? '-'}',
      ),
      (
        'Tür / yoğunluk',
        '${result.infographicType ?? '-'} / ${result.infographicDensity ?? '-'}',
      ),
      ('Kaynak sayısı', '${result.sourceCount}'),
      ('MC', result.mcCostLabel),
      ('Image', image == null ? 'Yok' : image!.label),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final item in items)
          Container(
            width: MediaQuery.sizeOf(context).width < 520
                ? double.infinity
                : 190,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FBFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.$1,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.$2,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 13,
                    height: 1.18,
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

class _InfographicImageView extends StatelessWidget {
  const _InfographicImageView({required this.image});

  final _InfographicImage image;

  @override
  Widget build(BuildContext context) {
    if (image.bytes != null) {
      return Image.memory(image.bytes!, fit: BoxFit.contain);
    }
    return Image.network(
      image.url!,
      fit: BoxFit.contain,
      errorBuilder: (context, _, _) => const _LabEmptyState(
        icon: Icons.broken_image_outlined,
        title: 'Görsel yüklenemedi',
        message: 'Image URL alındı ancak görsel render edilemedi.',
      ),
    );
  }
}

class _InfographicImage {
  const _InfographicImage({this.url, this.bytes, required this.label});

  final String? url;
  final Uint8List? bytes;
  final String label;
}

class _MindMapData {
  const _MindMapData({
    required this.title,
    required this.centralTopic,
    required this.branches,
    required this.links,
    required this.tips,
  });

  final String title;
  final String centralTopic;
  final List<_MindMapBranch> branches;
  final List<String> links;
  final List<String> tips;
}

class _MindMapBranch {
  const _MindMapBranch({
    required this.label,
    required this.children,
    required this.tags,
  });

  final String label;
  final List<String> children;
  final List<String> tags;
}

_InfographicImage? _infographicImageFromContent(Object? content) {
  if (content is! Map) return null;
  final image = content['image'];
  final imageMap = image is Map ? image : const {};
  final dataUrl = _firstText([
    imageMap['dataUrl'],
    imageMap['data_url'],
    content['dataUrl'],
    content['data_url'],
  ]);
  if (dataUrl.startsWith('data:image')) {
    final comma = dataUrl.indexOf(',');
    if (comma > 0) {
      try {
        final bytes = base64Decode(dataUrl.substring(comma + 1));
        return _InfographicImage(bytes: bytes, label: 'dataUrl');
      } catch (_) {
        return null;
      }
    }
  }
  final url = _firstText([
    imageMap['storageUrl'],
    imageMap['storage_url'],
    imageMap['url'],
    content['storageUrl'],
    content['storage_url'],
    content['imageUrl'],
    content['image_url'],
    content['url'],
  ]);
  if (url.startsWith('http')) {
    return _InfographicImage(url: url, label: 'URL');
  }
  return null;
}

String _infographicTitle(Object? content) {
  if (content is! Map) return '';
  return content['title']?.toString().trim() ?? '';
}

_MindMapData? _mindMapFromContent(Object? content) {
  final value = _decodeStructuredContent(content);
  if (value is Map) return _mindMapFromMap(value);
  if (value is List) {
    final branches = _mindMapBranchesFrom(value);
    if (branches.isEmpty) return null;
    return _MindMapData(
      title: 'Zihin Haritası',
      centralTopic: branches.first.label,
      branches: branches,
      links: const [],
      tips: const [],
    );
  }
  if (content is String) return _mindMapFromMarkdown(content);
  return null;
}

Object? _decodeStructuredContent(Object? content) {
  if (content is! String) return content;
  final text = content.trim();
  if (text.isEmpty) return null;
  final jsonMatch =
      RegExp(
        r'```json\s*([\s\S]*?)\s*```',
        caseSensitive: false,
      ).firstMatch(text) ??
      RegExp(r'```\s*([\s\S]*?)\s*```').firstMatch(text);
  final candidate = jsonMatch?.group(1)?.trim() ?? text;
  final firstObject = candidate.indexOf('{');
  final firstArray = candidate.indexOf('[');
  final starts = [
    firstObject,
    firstArray,
  ].where((index) => index >= 0).toList();
  if (starts.isEmpty) return content;
  final start = starts.reduce(math.min);
  final end = math.max(candidate.lastIndexOf('}'), candidate.lastIndexOf(']'));
  if (end <= start) return content;
  try {
    return jsonDecode(candidate.substring(start, end + 1));
  } catch (_) {
    return content;
  }
}

_MindMapData? _mindMapFromMap(Map<dynamic, dynamic> map) {
  final title =
      _labTextFor(map, const ['title', 'mapTitle', 'map_title', 'baslik']) ??
      'Zihin Haritası';
  final centralTopic =
      _labTextFor(map, const [
        'centralTopic',
        'central_topic',
        'center',
        'root',
        'topic',
        'merkez',
      ]) ??
      title;
  final branchSource = _labValueFor(map, const [
    'branches',
    'mainBranches',
    'main_branches',
    'children',
    'nodes',
    'tree',
  ]);
  final branches = _mindMapBranchesFrom(branchSource);
  if (branches.isEmpty) return null;
  return _MindMapData(
    title: title,
    centralTopic: centralTopic,
    branches: branches,
    links: _labListFor(
      _labValueFor(map, const [
        'criticalConnections',
        'critical_connections',
        'connections',
        'relationships',
        'edges',
      ]),
    ),
    tips: _labListFor(
      _labValueFor(map, const [
        'clinicalTusTips',
        'clinical_tus_tips',
        'clinicalTips',
        'tusTips',
        'tips',
        'high_yield',
      ]),
    ),
  );
}

List<_MindMapBranch> _mindMapBranchesFrom(Object? value) {
  if (value is Map) {
    final nested = _labValueFor(value, const [
      'branches',
      'children',
      'nodes',
      'items',
    ]);
    if (nested != null && nested != value) return _mindMapBranchesFrom(nested);
    return value.entries
        .map(
          (entry) => _MindMapBranch(
            label: _humanizeLabLabel(entry.key.toString()),
            children: _mindMapChildLabels(entry.value),
            tags: const [],
          ),
        )
        .where((branch) => branch.label.trim().isNotEmpty)
        .toList();
  }
  if (value is! List) return const [];
  return value
      .map(_mindMapBranchFromItem)
      .whereType<_MindMapBranch>()
      .where((branch) => branch.label.trim().isNotEmpty)
      .toList();
}

_MindMapBranch? _mindMapBranchFromItem(Object? item) {
  if (item is Map) {
    final label = _labTextFor(item, const [
      'label',
      'title',
      'name',
      'topic',
      'heading',
      'branch',
    ]);
    if (label == null) return null;
    final childSource = _labValueFor(item, const [
      'children',
      'subBranches',
      'sub_branches',
      'subtopics',
      'items',
      'nodes',
      'bullets',
    ]);
    return _MindMapBranch(
      label: label,
      children: _mindMapChildLabels(childSource),
      tags: _labListFor(_labValueFor(item, const ['tags', 'labels', 'group'])),
    );
  }
  final text = _labText(item);
  if (text == null || text.isEmpty) return null;
  return _MindMapBranch(label: text, children: const [], tags: const []);
}

List<String> _mindMapChildLabels(Object? value) {
  if (value == null) return const [];
  if (value is List) {
    return value
        .map((item) {
          if (item is Map) {
            final label = _labTextFor(item, const [
              'label',
              'title',
              'name',
              'topic',
              'heading',
            ]);
            final children = _mindMapChildLabels(
              _labValueFor(item, const [
                'children',
                'subBranches',
                'sub_branches',
                'subtopics',
                'items',
                'nodes',
              ]),
            );
            if (label == null) return children.join(' / ');
            if (children.isEmpty) return label;
            return '$label: ${children.join(' / ')}';
          }
          return _labText(item) ?? '';
        })
        .where((text) => text.trim().isNotEmpty)
        .toList();
  }
  return _labListFor(value);
}

_MindMapData? _mindMapFromMarkdown(String content) {
  final lines = content
      .split('\n')
      .map((line) => line.trimRight())
      .where((line) => line.trim().isNotEmpty)
      .toList();
  if (lines.isEmpty) return null;
  final title = lines.first.replaceFirst(RegExp(r'^#+\s*'), '').trim();
  final branches = <_MindMapBranch>[];
  String? current;
  final children = <String>[];
  void flush() {
    final label = current?.trim() ?? '';
    if (label.isEmpty) return;
    branches.add(
      _MindMapBranch(
        label: label,
        children: List<String>.from(children),
        tags: const [],
      ),
    );
    children.clear();
  }

  for (final line in lines.skip(1)) {
    final trimmed = line.trim();
    final level = line.length - line.trimLeft().length;
    final cleaned = trimmed
        .replaceFirst(RegExp(r'^[-*]\s*'), '')
        .replaceFirst(RegExp(r'^#+\s*'), '')
        .trim();
    if (cleaned.isEmpty) continue;
    if (trimmed.startsWith('#') || level <= 1) {
      flush();
      current = cleaned;
    } else {
      children.add(cleaned);
    }
  }
  flush();
  if (branches.isEmpty) return null;
  return _MindMapData(
    title: title.isEmpty ? 'Zihin Haritası' : title,
    centralTopic: title.isEmpty ? branches.first.label : title,
    branches: branches,
    links: const [],
    tips: const [],
  );
}

String _firstText(List<Object?> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return '';
}

class _SourceLabGeneratedResult extends StatelessWidget {
  const _SourceLabGeneratedResult({
    required this.title,
    required this.tool,
    required this.loading,
    required this.result,
    required this.error,
    required this.onBack,
    required this.onSave,
    required this.onExport,
    required this.onRegenerate,
    this.saveLabel = 'Kaydet',
    this.exportLabel = 'Dışa Aktar',
    this.loadingSteps = const [],
    this.audioNotice,
  });

  final String title;
  final _ToolKind tool;
  final bool loading;
  final _LabGenerationResult? result;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final VoidCallback onExport;
  final VoidCallback onRegenerate;
  final String saveLabel;
  final String exportLabel;
  final List<String> loadingSteps;
  final String? audioNotice;

  @override
  Widget build(BuildContext context) {
    return _LabScroll(
      children: [
        _MinimalTopBar(
          title: title,
          subtitle: loading
              ? '${_sourceLabToolTitle(tool)} üretim kuyruğu işleniyor.'
              : result == null
              ? 'Üretim tamamlanamadı.'
              : '${result!.sourceTitle} kaynağından oluşturuldu.',
          onBack: onBack,
        ),
        _LabPanel(
          child: loading
              ? _LabLoadingState(steps: loadingSteps)
              : error != null
              ? _LabEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Üretim başlatılamadı',
                  message: error!,
                )
              : result == null
              ? const _LabEmptyState(
                  icon: Icons.warning_amber_rounded,
                  title: 'Boş sonuç',
                  message:
                      'Backend tamamlandı ancak gösterilecek içerik dönmedi.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (audioNotice != null) ...[
                      _LabNotice(text: audioNotice!),
                      const SizedBox(height: 14),
                    ],
                    switch (result!.tool) {
                      _ToolKind.clinical => _ClinicalGeneratedContent(
                        result: result!,
                      ),
                      _ToolKind.plan => _LearningPlanGeneratedContent(
                        result: result!,
                      ),
                      _ => _LabGeneratedContent(content: result!.content),
                    },
                  ],
                ),
        ),
        if (result != null && error == null && !loading)
          _ResponsiveActions(
            children: [
              _SecondaryLabButton(
                label: saveLabel,
                icon: Icons.bookmark_border_rounded,
                onTap: onSave,
              ),
              _SecondaryLabButton(
                label: exportLabel,
                icon: Icons.file_download_outlined,
                onTap: onExport,
              ),
              _SecondaryLabButton(
                label: 'Yeniden Üret',
                icon: Icons.refresh_rounded,
                onTap: onRegenerate,
              ),
            ],
          )
        else if (!loading)
          _PrimaryLabButton(
            label: 'Yeniden Üret',
            icon: Icons.refresh_rounded,
            onTap: onRegenerate,
          ),
      ],
    );
  }
}

class _LabLoadingState extends StatelessWidget {
  const _LabLoadingState({this.steps = const []});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          const CircularProgressIndicator(color: AppColors.blue),
          const SizedBox(height: 16),
          const Text(
            'AI üretimi devam ediyor. Bu ekran tamamlanınca otomatik güncellenecek.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (steps.isNotEmpty) ...[
            const SizedBox(height: 18),
            for (final step in steps)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppColors.blue,
                      size: 19,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        step,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _LabNotice extends StatelessWidget {
  const _LabNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFDCA8)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF9A5A00),
          height: 1.35,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LabGeneratedContent extends StatelessWidget {
  const _LabGeneratedContent({required this.content});

  final Object? content;

  @override
  Widget build(BuildContext context) {
    final value = content;
    if (value == null ||
        (value is String && value.trim().isEmpty) ||
        (value is List && value.isEmpty) ||
        (value is Map && value.isEmpty)) {
      return const _LabEmptyState(
        icon: Icons.warning_amber_rounded,
        title: 'Boş içerik döndü',
        message: 'AI işi tamamlandı ancak görüntülenecek içerik bulunamadı.',
      );
    }
    if (value is List) {
      return Column(
        children: [
          for (var i = 0; i < value.length; i++)
            _LabGeneratedItem(index: i + 1, value: value[i]),
        ],
      );
    }
    if (value is Map) {
      final title = value['title']?.toString().trim() ?? '';
      final list = _labPreferredList(value);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Text(
              title,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (list != null && list.isNotEmpty)
            for (var i = 0; i < list.length; i++)
              _LabGeneratedItem(index: i + 1, value: list[i])
          else
            for (final entry in value.entries)
              _LabGeneratedPair(
                label: entry.key.toString(),
                value: entry.value,
              ),
        ],
      );
    }
    return _LabGeneratedText(text: value.toString());
  }
}

class _ClinicalGeneratedContent extends StatelessWidget {
  const _ClinicalGeneratedContent({required this.result});

  final _LabGenerationResult result;

  @override
  Widget build(BuildContext context) {
    final content = result.content;
    if (content is! Map) return _LabGeneratedContent(content: content);
    final title =
        _labTextFor(content, const ['title', 'vaka_basligi']) ?? result.title;
    final question = _labFirstMapFor(content, const ['questions', 'sorular']);
    final answerText = [
      _labTextFor(question, const ['answer', 'yanit', 'cevap']),
      _labTextFor(question, const ['explanation', 'aciklama']),
    ].whereType<String>().where((item) => item.isNotEmpty).join('\n\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GeneratedTitleBlock(
          icon: Icons.monitor_heart_outlined,
          title: title,
          subtitle: '${result.sourceTitle} kaynağından yapılandırıldı.',
        ),
        const SizedBox(height: 14),
        _GeneratedSectionCard(
          icon: Icons.badge_outlined,
          title: 'Hasta Bilgisi',
          child: _GeneratedText(
            _labTextFor(content, const [
                  'patientInfo',
                  'patient_info',
                  'hasta_bilgisi',
                ]) ??
                'Backend çıktısında hasta bilgisi alanı boş döndü.',
          ),
        ),
        _GeneratedSectionCard(
          icon: Icons.local_hospital_outlined,
          title: 'Başvuru',
          child: _GeneratedText(
            _labTextFor(content, const [
                  'chiefComplaint',
                  'chief_complaint',
                  'presentation',
                  'basvuru',
                  'caseStem',
                ]) ??
                'Backend çıktısında başvuru alanı boş döndü.',
          ),
        ),
        _GeneratedSectionCard(
          icon: Icons.history_edu_outlined,
          title: 'Öykü',
          child: _GeneratedText(
            _labTextFor(content, const ['history', 'oyku', 'caseStem']) ??
                'Backend çıktısında öykü alanı boş döndü.',
          ),
        ),
        _GeneratedSectionCard(
          icon: Icons.health_and_safety_outlined,
          title: 'Fizik Muayene',
          child: _GeneratedBulletList(
            values: _labListFor(
              _labValueFor(content, const [
                'physicalExam',
                'physical_exam',
                'muayene',
                'findings',
              ]),
            ),
          ),
        ),
        _GeneratedSectionCard(
          icon: Icons.biotech_outlined,
          title: 'Laboratuvar / Görüntüleme',
          child: _GeneratedBulletList(
            values: _labListFor(
              _labValueFor(content, const [
                'labsImaging',
                'labs_imaging',
                'lab_imaging',
                'investigations',
                'laboratuvar_goruntuleme',
              ]),
            ),
          ),
        ),
        _GeneratedSectionCard(
          icon: Icons.alt_route_rounded,
          title: 'Klinik Karar Noktası',
          child: _GeneratedText(
            _labTextFor(content, const [
                  'decisionPoint',
                  'decision_point',
                  'clinical_decision',
                  'karar_noktasi',
                ]) ??
                'Backend çıktısında karar noktası alanı boş döndü.',
          ),
        ),
        _GeneratedSectionCard(
          icon: Icons.help_outline_rounded,
          title: 'Klinik Soru / Yorum',
          child: _GeneratedText(
            _labTextFor(question, const ['question', 'soru']) ??
                'Backend çıktısında klinik soru alanı boş döndü.',
          ),
        ),
        _GeneratedSectionCard(
          icon: Icons.fact_check_outlined,
          title: 'Yanıt ve Açıklama',
          child: _GeneratedText(
            answerText.isEmpty
                ? 'Backend çıktısında yanıt/açıklama alanı boş döndü.'
                : answerText,
          ),
        ),
        _GeneratedSectionCard(
          icon: Icons.school_outlined,
          title: 'Öğrenme Hedefi',
          child: _GeneratedBulletList(
            values: _labListFor(
              _labValueFor(content, const [
                'learningObjective',
                'learning_objective',
                'learningObjectives',
                'learning_objectives',
                'teachingPoints',
                'ogrenme_hedefi',
              ]),
            ),
          ),
        ),
        _GeneratedSectionCard(
          icon: Icons.lightbulb_outline_rounded,
          title: 'Sınavda Yakala İpuçları',
          child: _GeneratedBulletList(
            values: _labListFor(
              _labValueFor(content, const [
                'examTips',
                'exam_tips',
                'tusTips',
                'tus_tips',
                'sinav_ipuclari',
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

class _LearningPlanGeneratedContent extends StatelessWidget {
  const _LearningPlanGeneratedContent({required this.result});

  final _LabGenerationResult result;

  @override
  Widget build(BuildContext context) {
    final content = result.content;
    if (content is! Map) return _LabGeneratedContent(content: content);
    final title =
        _labTextFor(content, const ['title', 'plan_title']) ?? result.title;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GeneratedTitleBlock(
          icon: Icons.event_note_outlined,
          title: title,
          subtitle: '${result.sourceTitle} kaynağından çalışma planı.',
        ),
        const SizedBox(height: 14),
        _GeneratedSectionCard(
          icon: Icons.source_outlined,
          title: 'Kaynak Adı',
          child: _GeneratedText(result.sourceTitle),
        ),
        _GeneratedSectionCard(
          icon: Icons.date_range_outlined,
          title: 'Plan Süresi',
          child: _GeneratedText(
            _labTextFor(content, const [
                  'duration',
                  'planDuration',
                  'plan_duration',
                  'sure',
                ]) ??
                'Backend çıktısında plan süresi alanı boş döndü.',
          ),
        ),
        _GeneratedSectionCard(
          icon: Icons.flag_outlined,
          title: 'Günlük Hedefler',
          child: _GeneratedBulletList(
            values: _labListFor(
              _labValueFor(content, const [
                'dailyGoals',
                'daily_goals',
                'gunluk_hedefler',
                'sessions',
              ]),
            ),
          ),
        ),
        _GeneratedSectionCard(
          icon: Icons.checklist_rounded,
          title: 'Checklist',
          child: _GeneratedBulletList(
            values: _labListFor(
              _labValueFor(content, const [
                'checklist',
                'objectives',
                'hedefler',
              ]),
            ),
          ),
        ),
        _GeneratedSectionCard(
          icon: Icons.sync_rounded,
          title: 'Tekrar Günleri',
          child: _GeneratedBulletList(
            values: _labListFor(
              _labValueFor(content, const [
                'reviewDays',
                'review_days',
                'reviewCycle',
                'checkpoints',
                'tekrar_gunleri',
              ]),
            ),
          ),
        ),
        _GeneratedSectionCard(
          icon: Icons.quiz_outlined,
          title: 'Soru / Flashcard Önerileri',
          child: _GeneratedBulletList(
            values: _labListFor(
              _labValueFor(content, const [
                'questionFlashcardSuggestions',
                'question_flashcard_suggestions',
                'recommendations',
                'oneriler',
              ]),
            ),
          ),
        ),
        _GeneratedSectionCard(
          icon: Icons.priority_high_rounded,
          title: 'Zayıf Nokta ve Önceliklendirme',
          child: _GeneratedBulletList(
            values: _labListFor(
              _labValueFor(content, const [
                'weakPoints',
                'weak_points',
                'priorities',
                'zayif_noktalar',
              ]),
            ),
          ),
        ),
        _GeneratedSectionCard(
          icon: Icons.play_circle_outline_rounded,
          title: 'Bugün Başla',
          child: _GeneratedBulletList(
            values: _labListFor(
              _labValueFor(content, const [
                'startToday',
                'start_today',
                'today',
                'bugun_basla',
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

class _GeneratedTitleBlock extends StatelessWidget {
  const _GeneratedTitleBlock({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.blue.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.blue),
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
                  fontSize: 22,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 14.5,
                  height: 1.3,
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

class _GeneratedSectionCard extends StatelessWidget {
  const _GeneratedSectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.blue, size: 21),
              const SizedBox(width: 9),
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
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _GeneratedText extends StatelessWidget {
  const _GeneratedText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.trim().isEmpty ? '-' : text.trim(),
      softWrap: true,
      style: const TextStyle(
        color: AppColors.navy,
        fontSize: 15,
        height: 1.45,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _GeneratedBulletList extends StatelessWidget {
  const _GeneratedBulletList({required this.values});

  final List<String> values;

  @override
  Widget build(BuildContext context) {
    final items = values.isEmpty
        ? const ['Backend çıktısında bu alan boş döndü.']
        : values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 7),
                  child: Icon(Icons.circle, color: AppColors.blue, size: 6),
                ),
                const SizedBox(width: 9),
                Expanded(child: _GeneratedText(item)),
              ],
            ),
          ),
      ],
    );
  }
}

Object? _labValueFor(Map<dynamic, dynamic>? content, List<String> keys) {
  if (content == null) return null;
  for (final key in keys) {
    if (content.containsKey(key)) return content[key];
  }
  final normalizedKeys = keys.map(_normalizeLabKey).toSet();
  for (final entry in content.entries) {
    if (normalizedKeys.contains(_normalizeLabKey(entry.key.toString()))) {
      return entry.value;
    }
  }
  return null;
}

String? _labTextFor(Map<dynamic, dynamic>? content, List<String> keys) {
  final text = _labText(_labValueFor(content, keys));
  return text == null || text.trim().isEmpty ? null : text.trim();
}

Map<dynamic, dynamic>? _labFirstMapFor(
  Map<dynamic, dynamic> content,
  List<String> keys,
) {
  final value = _labValueFor(content, keys);
  if (value is List) {
    for (final item in value) {
      if (item is Map) return item;
    }
  }
  if (value is Map) return value;
  return null;
}

List<String> _labListFor(Object? value) {
  if (value == null) return const [];
  if (value is List) {
    return value
        .map(_labText)
        .whereType<String>()
        .where((text) => text.trim().isNotEmpty)
        .toList();
  }
  if (value is Map) {
    return value.entries
        .map((entry) {
          final text = _labText(entry.value);
          if (text == null || text.trim().isEmpty) return null;
          return '${_humanizeLabLabel(entry.key.toString())}: $text';
        })
        .whereType<String>()
        .toList();
  }
  final text = _labText(value);
  if (text == null || text.trim().isEmpty) return const [];
  return text
      .split(RegExp(r'\n+|•\s*'))
      .map((item) => item.replaceFirst(RegExp(r'^[-*]\s*'), '').trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

String? _labText(Object? value) {
  if (value == null) return null;
  if (value is String) return value.trim();
  if (value is num || value is bool) return value.toString();
  if (value is List) {
    return value.map(_labText).whereType<String>().join(' / ');
  }
  if (value is Map) {
    return value.entries
        .map((entry) {
          final text = _labText(entry.value);
          if (text == null || text.isEmpty) return null;
          return '${_humanizeLabLabel(entry.key.toString())}: $text';
        })
        .whereType<String>()
        .join(' | ');
  }
  return value.toString().trim();
}

String _normalizeLabKey(String value) {
  return value
      .toLowerCase()
      .replaceAll('_', '')
      .replaceAll('-', '')
      .replaceAll(' ', '');
}

List<Object?>? _labPreferredList(Map<dynamic, dynamic> content) {
  for (final key in const [
    'segments',
    'chapters',
    'steps',
    'days',
    'nodes',
    'questions',
    'rows',
    'bulletPoints',
    'sections',
  ]) {
    final value = content[key];
    if (value is List) return value.cast<Object?>();
  }
  return null;
}

Object? _examValueFor(Map<dynamic, dynamic> content, List<String> keys) {
  for (final key in keys) {
    final value = content[key];
    if (value != null) return value;
  }
  return null;
}

List<String> _examListFor(Map<dynamic, dynamic> content, List<String> keys) {
  return _examStringList(_examValueFor(content, keys));
}

List<String> _examStringList(Object? value) {
  if (value == null) return const [];
  if (value is List) {
    return value
        .map(_examText)
        .whereType<String>()
        .where((text) => text.trim().isNotEmpty)
        .toList();
  }
  if (value is Map) {
    return value.entries
        .map((entry) {
          final label = _humanizeLabLabel(entry.key.toString());
          final text = _examText(entry.value);
          if (text == null || text.trim().isEmpty) return null;
          return '$label: $text';
        })
        .whereType<String>()
        .toList();
  }
  final text = _examText(value);
  if (text == null || text.isEmpty) return const [];
  return text
      .split(RegExp(r'\n+|•\s*'))
      .map((item) => item.replaceFirst(RegExp(r'^[-*]\s*'), '').trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

String? _examText(Object? value) {
  if (value == null) return null;
  if (value is String) return value.trim();
  if (value is num || value is bool) return value.toString();
  if (value is List) {
    return value.map(_examText).whereType<String>().join(' / ');
  }
  if (value is Map) {
    final question = value['question'] ?? value['soru'];
    final answer = value['answer'] ?? value['cevap'];
    if (question != null || answer != null) {
      return [
        if (question != null) 'Soru: ${_examText(question)}',
        if (answer != null) 'Cevap: ${_examText(answer)}',
      ].join(' ');
    }
    return value.entries
        .map((entry) {
          final text = _examText(entry.value);
          if (text == null || text.isEmpty) return null;
          return '${_humanizeLabLabel(entry.key.toString())}: $text';
        })
        .whereType<String>()
        .join(' | ');
  }
  return value.toString().trim();
}

List<String> _examTableRows(Object? value) {
  if (value == null) return const [];
  if (value is List) return _examStringList(value);
  if (value is Map) {
    final rows = value['rows'];
    if (rows is List) {
      return rows.map(_examText).whereType<String>().toList();
    }
    return _examStringList(value);
  }
  return _examStringList(value);
}

String _humanizeLabLabel(String value) {
  final spaced = value
      .replaceAll('_', ' ')
      .replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'),
        (match) => '${match.group(1)} ${match.group(2)}',
      )
      .trim();
  if (spaced.isEmpty) return value;
  return spaced[0].toUpperCase() + spaced.substring(1);
}

class _LabGeneratedItem extends StatelessWidget {
  const _LabGeneratedItem({required this.index, required this.value});

  final int index;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.selectedBlue,
            child: Text(
              '$index',
              style: const TextStyle(
                color: AppColors.blue,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _LabGeneratedValue(value: value)),
        ],
      ),
    );
  }
}

class _LabGeneratedPair extends StatelessWidget {
  const _LabGeneratedPair({required this.label, required this.value});

  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.blue,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          _LabGeneratedValue(value: value),
        ],
      ),
    );
  }
}

class _LabGeneratedValue extends StatelessWidget {
  const _LabGeneratedValue({required this.value});

  final Object? value;

  @override
  Widget build(BuildContext context) {
    if (value is Map) {
      final map = value as Map;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in map.entries)
            _LabGeneratedPair(label: entry.key.toString(), value: entry.value),
        ],
      );
    }
    if (value is List) {
      final list = value as List;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _LabGeneratedValue(value: item),
            ),
        ],
      );
    }
    return _LabGeneratedText(text: value?.toString() ?? '-');
  }
}

class _LabGeneratedText extends StatelessWidget {
  const _LabGeneratedText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.trim().isEmpty ? '-' : text,
      softWrap: true,
      style: const TextStyle(
        color: AppColors.navy,
        fontSize: 15,
        height: 1.45,
        fontWeight: FontWeight.w600,
      ),
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
        ? SourceBaseBottomNav.scrollEndPadding(context)
        : 48.0;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 940),
        child: ListView(
          physics: const BouncingScrollPhysics(),
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
            if (isMobile) const WorkspaceBottomNavGuard(),
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
            ? (tight
                  ? math.min(constraints.maxWidth, 172.0)
                  : math.min(constraints.maxWidth, 250.0))
            : (tight ? 360.0 : 430.0);
        final artHeight = compact
            ? (tight ? 96.0 : 170.0)
            : (tight ? 210.0 : 260.0);

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
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                  child: copy,
                ),
                if (!tight)
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: artWidth,
                      height: artHeight,
                      child: ClipRect(child: _HeroArt(kind: art)),
                    ),
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
    final disabled = !source.isSelectable;
    return Container(
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: disabled ? const Color(0xFFF4F7FB) : Colors.white,
        border: Border.all(
          color: disabled ? AppColors.softLine : AppColors.line,
        ),
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
                if (disabled) ...[
                  const SizedBox(height: 5),
                  Text(
                    source.disabledReason!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
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
    final disabled = !source.isSelectable;
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: disabled
              ? const Color(0xFFF4F7FB)
              : selected
              ? AppColors.selectedBlue
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: disabled
                ? AppColors.softLine
                : selected
                ? AppColors.blue
                : AppColors.line,
          ),
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
                  if (disabled) ...[
                    const SizedBox(height: 6),
                    Text(
                      source.disabledReason!,
                      style: const TextStyle(
                        color: AppColors.red,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              disabled
                  ? Icons.block_rounded
                  : selected
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              color: disabled
                  ? AppColors.muted
                  : selected
                  ? AppColors.blue
                  : AppColors.softText,
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
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled
              ? AppColors.primaryGradient
              : const LinearGradient(
                  colors: [Color(0xFFCAD4E4), Color(0xFFB8C4D6)],
                ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: (enabled ? AppColors.blue : AppColors.muted).withValues(
                alpha: .18,
              ),
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
    if (values.length > 4) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth > 680 ? 4 : 2;
          const gap = 8.0;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (var i = 0; i < values.length; i++)
                SizedBox(
                  width: width,
                  child: _SegmentButton(
                    label: values[i],
                    icon: icons != null && i < icons!.length ? icons![i] : null,
                    selected: values[i] == selected,
                    onTap: () => onSelected(values[i]),
                  ),
                ),
            ],
          );
        },
      );
    }
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

class _SummaryActionBar extends StatelessWidget {
  const _SummaryActionBar({
    required this.icon,
    required this.title,
    required this.detail,
    required this.buttonLabel,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String buttonLabel;
  final VoidCallback? onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return _LabPanel(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final leading = Row(
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final button = _PrimaryLabButton(
            label: buttonLabel,
            icon: Icons.auto_awesome_rounded,
            onTap: onTap,
            subtitle: subtitle,
          );
          if (constraints.maxWidth < 640) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [leading, const SizedBox(height: 14), button],
            );
          }
          return Row(
            children: [
              Expanded(child: leading),
              const SizedBox(width: 18),
              SizedBox(width: 250, child: button),
            ],
          );
        },
      ),
    );
  }
}

class _CompactToolHero extends StatelessWidget {
  const _CompactToolHero({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selectedCount,
    required this.hasSources,
    required this.onPickSources,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final int selectedCount;
  final bool hasSources;
  final VoidCallback onPickSources;

  @override
  Widget build(BuildContext context) {
    return _LabPanel(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      radius: 18,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final copy = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.blue),
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
                        fontSize: 30,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 16,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _MiniHeroChip(
                          icon: Icons.library_books_outlined,
                          label: '$selectedCount kaynak seçili',
                        ),
                        const _MiniHeroChip(
                          icon: Icons.verified_outlined,
                          label: 'Kaynak temelli',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
          final action = _SmallActionButton(
            label: hasSources ? 'Kaynakları yönet' : 'Drive’dan kaynak seç',
            icon: Icons.folder_open_rounded,
            onTap: onPickSources,
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [copy, const SizedBox(height: 16), action],
            );
          }
          return Row(
            children: [
              Expanded(child: copy),
              const SizedBox(width: 18),
              SizedBox(width: 230, child: action),
            ],
          );
        },
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

class _PlanSummaryBar extends StatelessWidget {
  const _PlanSummaryBar({
    required this.days,
    required this.duration,
    required this.focus,
    required this.reviews,
    required this.quality,
    required this.canGenerate,
    required this.blockedSubtitle,
    required this.onGenerate,
  });

  final int days;
  final String duration;
  final int focus;
  final bool reviews;
  final String quality;
  final bool canGenerate;
  final String? blockedSubtitle;
  final VoidCallback? onGenerate;

  @override
  Widget build(BuildContext context) {
    return _LabPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final metrics = [
            _SummaryMetric(
              icon: Icons.menu_book_outlined,
              title: 'Plan Süresi',
              value: '$days',
              detail: 'gün',
            ),
            _SummaryMetric(
              icon: Icons.schedule_rounded,
              title: 'Günlük Süre',
              value: duration,
              detail: 'hedef',
            ),
            _SummaryMetric(
              icon: Icons.track_changes_rounded,
              title: 'Ana Odak',
              value: '$focus',
              detail: 'bölüm',
            ),
            _SummaryMetric(
              icon: Icons.sync_rounded,
              title: 'Kalite',
              value: quality,
              detail: reviews ? 'Tekrar eklenecek' : 'Tekrar kapalı',
            ),
          ];
          final button = _PrimaryLabButton(
            label: 'Öğrenme planı oluştur',
            icon: Icons.auto_awesome_rounded,
            onTap: onGenerate,
            subtitle: canGenerate ? null : blockedSubtitle,
          );
          if (constraints.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final metric in metrics) ...[
                  metric,
                  const SizedBox(height: 10),
                ],
                button,
              ],
            );
          }
          return Row(
            children: [
              for (var i = 0; i < metrics.length; i++) ...[
                Expanded(child: metrics[i]),
                if (i != metrics.length - 1) const _VerticalDividerLite(),
              ],
              const SizedBox(width: 24),
              SizedBox(width: 240, child: button),
            ],
          );
        },
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
      ('1', 'Bölüm 1', 'İçerik hazırlanıyor', '—'),
      ('2', 'Bölüm 2', 'İçerik hazırlanıyor', '—'),
      ('3', 'Bölüm 3', 'İçerik hazırlanıyor', '—'),
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
                  TextSpan(text: 'Konu Başlığı\nBu bölüm henüz hazır değil.'),
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
        _LegendRow(
          label: 'Kategori 1',
          value: 'İçerik hazırlanıyor',
          color: AppColors.blue,
        ),
        _LegendRow(
          label: 'Kategori 2',
          value: 'İçerik hazırlanıyor',
          color: AppColors.green,
        ),
        _LegendRow(
          label: 'Kategori 3',
          value: 'İçerik hazırlanıyor',
          color: AppColors.purple,
        ),
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
            onAction: () =>
                _showLabSnack(context, 'Bu bölüm henüz hazır değil.'),
          ),
          for (final note in const [
            ('Not başlığı yükleniyor...', 'İçerik açıklaması hazırlanıyor.'),
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
            style: TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w900,
            ),
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
