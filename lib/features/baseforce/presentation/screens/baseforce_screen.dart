// ignore_for_file: unused_element, unused_element_parameter

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design_system/components/sourcebase_card.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sourcebase_brand.dart';
import '../../../drive/data/drive_models.dart';
import '../../../drive/data/sourcebase_drive_api.dart';
import '../../../drive/presentation/widgets/drive_ui.dart';
import '../../../drive/presentation/widgets/premium_workspace_components.dart';
import '../../../drive/presentation/widgets/sourcebase_bottom_nav.dart';
import '../../../generated_outputs/presentation/widgets/generated_output_readers.dart';

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
  final SourceBaseDriveApi _api = const SourceBaseDriveApi();
  BaseForceView view = BaseForceView.home;
  late final Set<String> selectedSources;
  final List<_BaseForceJobState> _jobs = [];
  _GenerationResult? _latestResult;
  bool _latestResultSaved = false;
  String? _latestResultSaveError;

  @override
  void initState() {
    super.initState();
    selectedSources = <String>{};
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
  String algorithmLayout = 'Evet/Hayır dallanması';
  String algorithmDetail = 'Dengeli';
  String algorithmQuality = 'Standart';
  bool algorithmColorfulNodes = true;
  bool algorithmClinicalNotes = true;

  String comparisonType = 'Hastalık Karşılaştırması';
  String comparisonFormat = 'Ayırt ettiren ipucu tablosu';
  String comparisonDetail = 'Dengeli';
  String comparisonQuality = 'Standart';

  String queueFilter = 'Tümü';

  void _open(BaseForceView next) {
    setState(() => view = next);
  }

  void _backToHome() {
    setState(() => view = BaseForceView.home);
  }

  BaseForceView _factoryViewForKind(GeneratedKind kind) {
    return switch (kind) {
      GeneratedKind.question => BaseForceView.questionFactory,
      GeneratedKind.summary => BaseForceView.summaryFactory,
      GeneratedKind.algorithm => BaseForceView.algorithmFactory,
      GeneratedKind.comparison ||
      GeneratedKind.table => BaseForceView.comparisonFactory,
      _ => BaseForceView.flashcardFactory,
    };
  }

  void _openResult(_GenerationResult result) {
    setState(() {
      _latestResult = result;
      _latestResultSaved = result.sourceFileId == null;
      _latestResultSaveError = null;
      view = BaseForceView.flashcardResults;
    });
  }

  void _retryGeneration(_BaseForceJobState job) {
    setState(() {
      selectedSources
        ..clear()
        ..add(job.source.id);
      selectedFactory = switch (job.kind) {
        GeneratedKind.question => 'question',
        GeneratedKind.summary => 'summary',
        GeneratedKind.algorithm => 'algorithm',
        GeneratedKind.comparison || GeneratedKind.table => 'comparison',
        _ => 'flashcard',
      };
    });
    _startGeneration(job.kind);
  }

  void _openStoredGeneration(_GenerationRowData row) {
    _openResult(
      _GenerationResult(
        kind: _kindForTurkishLabel(row.kind),
        title: row.title,
        sourceTitle: row.source,
        content:
            'Bu üretim kaydı koleksiyonda görünüyor; ham sonuç içeriği bu ekranda yeniden çekilemiyor.',
      ),
    );
  }

  void _regenerateStoredGeneration(_GenerationRowData row) {
    _open(_factoryViewForKind(_kindForTurkishLabel(row.kind)));
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

  Future<void> _copyLatestResult() async {
    final result = _latestResult;
    if (result == null) {
      _toast('Paylaşılacak üretim sonucu yok.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: _plainTextForResult(result)));
    if (!mounted) return;
    _toast('Sonuç metni panoya kopyalandı.');
  }

  Future<void> _copyStoredGeneration(_GenerationRowData row) async {
    final text = [
      row.title,
      'Tür: ${row.kind}',
      'Kaynak: ${row.source}',
      'Detay: ${row.count}',
      'Zaman: ${row.time}',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _toast('Üretim bilgisi panoya kopyalandı.');
  }

  Future<void> _cancelJob(_BaseForceJobState job) async {
    final jobId = job.jobId?.trim() ?? '';
    if (jobId.isEmpty) {
      _toast(
        'Bu üretim henüz backend job id almadı; birkaç saniye sonra tekrar deneyin.',
      );
      return;
    }
    try {
      await _api.cancelJob(jobId);
      if (!mounted) return;
      setState(() {
        _updateJobValue(
          job.localId,
          status: _JobUiStatus.failed,
          errorMessage: 'Üretim durduruldu.',
          progress: 1,
        );
      });
      _toast('Üretim durduruldu.');
    } catch (error) {
      if (!mounted) return;
      _toast(_friendlyBaseForceError(error));
    }
  }

  Future<void> _saveLatestResult() async {
    final result = _latestResult;
    if (result == null) {
      _toast('Kaydedilecek üretim sonucu yok.');
      return;
    }
    if (_latestResultSaved) {
      _toast('Sonuç üretimler listesinde kayıtlı.');
      return;
    }
    if (result.sourceFileId == null) {
      _toast('Bu üretim kaydı zaten koleksiyon listesinde görünüyor.');
      return;
    }
    final retryingAfterError = _latestResultSaveError != null;
    try {
      await _api.createGeneratedOutputByKind(
        fileId: result.sourceFileId!,
        kind: _baseForceOutputKind(result.kind),
        itemCount: _baseForceContentCount(result.content),
        jobId: result.jobId,
      );
      if (!mounted) return;
      setState(() {
        _latestResultSaved = true;
        _latestResultSaveError = null;
      });
      _toast(
        retryingAfterError
            ? 'Kayıt yeniden denendi ve üretimler listesine eklendi.'
            : 'Sonuç üretimler listesine kaydedildi.',
      );
    } catch (error) {
      if (!mounted) return;
      final message = _friendlyBaseForceError(error);
      setState(() => _latestResultSaveError = message);
      _toast('Sonuç görüntülendi, kayıt oluşturulamadı: $message');
    }
  }

  DriveFile? _selectedFile() {
    final readyFiles = _selectedReadyFiles();
    return readyFiles.isEmpty ? null : readyFiles.first;
  }

  List<DriveFile> _selectedReadyFiles() {
    for (final file in widget.data.recentFiles) {
      if (selectedSources.contains(file.id) && !_isBaseForceReadySource(file)) {
        selectedSources.remove(file.id);
      }
    }
    return widget.data.recentFiles
        .where(
          (file) =>
              selectedSources.contains(file.id) &&
              _isBaseForceReadySource(file),
        )
        .toList();
  }

  DriveFile? _fileById(String id) {
    for (final file in widget.data.recentFiles) {
      if (file.id == id) return file;
    }
    return null;
  }

  void _toggleSourceForGeneration(String id) {
    final file = _fileById(id);
    if (file == null) return;
    if (!_isBaseForceReadySource(file)) {
      setState(() => selectedSources.remove(id));
      _toast(_baseForceSourceBlockedMessage(file));
      return;
    }
    setState(() {
      if (selectedSources.contains(id)) {
        selectedSources.remove(id);
      } else {
        selectedSources.add(id);
      }
    });
  }

  int? _generationCount(GeneratedKind kind) {
    if (kind == GeneratedKind.flashcard) {
      return flashcardCount.clamp(1, 100);
    }
    if (kind == GeneratedKind.question) {
      return questionCount.clamp(1, 100);
    }
    return _baseForceCount(kind);
  }

  String? _qualityTierFor(GeneratedKind kind) {
    if (kind == GeneratedKind.algorithm) {
      return _algorithmQualityValue(algorithmQuality);
    }
    if (kind == GeneratedKind.comparison || kind == GeneratedKind.table) {
      return _comparisonQualityValue(comparisonQuality);
    }
    if (kind == GeneratedKind.summary) return 'standard';
    final difficulty = switch (kind) {
      GeneratedKind.flashcard => flashcardDifficulty,
      GeneratedKind.question => selectedQuestionDifficulty,
      _ => '',
    };
    return switch (difficulty) {
      'Kolay' => 'economy',
      'Zor' || 'Çok Zor' => 'premium',
      '' => null,
      _ => 'standard',
    };
  }

  Map<String, dynamic>? _generationOptionsFor(GeneratedKind kind) {
    if (kind == GeneratedKind.algorithm) {
      final source = _selectedFile();
      return {
        'algorithm_type': _algorithmTypeValue(algorithmMode),
        'output_format': _algorithmFormatValue(algorithmLayout),
        'detail_level': _algorithmDetailValue(algorithmDetail),
        'quality_tier': _algorithmQualityValue(algorithmQuality),
        'source_size_tier': source == null
            ? null
            : _baseForceSourceSizeTier(source.sizeLabel),
        'clinical_notes': algorithmClinicalNotes,
        'colorful_nodes': algorithmColorfulNodes,
        'structured': true,
      };
    }
    if (kind == GeneratedKind.comparison || kind == GeneratedKind.table) {
      final source = _selectedFile();
      return {
        'comparison_type': _comparisonTypeValue(comparisonType),
        'table_format': _comparisonFormatValue(comparisonFormat),
        'detail_level': _comparisonDetailValue(comparisonDetail),
        'quality_tier': _comparisonQualityValue(comparisonQuality),
        'source_size_tier': source == null
            ? null
            : _baseForceSourceSizeTier(source.sizeLabel),
        'structured': true,
        'clinical': true,
      };
    }
    if (kind == GeneratedKind.summary) {
      return {
        'summary_mode': _summaryModeValue(summaryFocus),
        'length_target': _summaryLengthValue(summaryLength),
        'output_format': summaryToTable
            ? 'exam_morning_table_checklist'
            : 'exam_morning_brief',
        'quality_tier': 'standard',
        'mark_terms': summaryMarkTerms,
        'checklist': summaryChecklist,
        'structured': true,
        'clinical': true,
      };
    }
    if (kind == GeneratedKind.flashcard) {
      return {
        'card_style': _flashcardStyleValue(flashcardStyle),
        'difficulty': _difficultyValue(flashcardDifficulty),
        'extract_key_concepts': flashcardExtractKey,
        'add_hints': flashcardAddHints,
        'structured': true,
      };
    }
    if (kind != GeneratedKind.question) return null;
    final clinical = questionType == 'Klinik Vaka';
    final hard =
        selectedQuestionDifficulty == 'Zor' ||
        selectedQuestionDifficulty == 'Çok Zor';
    final mode = switch (questionType) {
      'Klinik Vaka' => 'clinical_case',
      'Doğru-Yanlış' => 'true_false',
      _ => 'multiple_choice',
    };
    return {
      'question_type': mode,
      'mode': mode,
      'style': clinical ? 'clinical' : 'exam',
      'difficulty': hard
          ? 'hard'
          : _difficultyValue(selectedQuestionDifficulty),
      'clinical': clinical,
      'hard': hard,
      'explanations': questionAddExplanation,
      'structured': true,
    };
  }

  Future<void> _startGeneration(GeneratedKind kind) async {
    final file = _selectedFile();
    if (file == null) {
      _toast(
        selectedSources.isEmpty
            ? 'Üretim için önce Drive’dan hazır bir kaynak seçin.'
            : 'Seçili kaynak üretime hazır değil. Hazır ve 0 KB olmayan bir PDF seçin.',
      );
      _open(BaseForceView.sourcePicker);
      return;
    }
    if (!_isBaseForceReadySource(file)) {
      _toast(_baseForceSourceBlockedMessage(file));
      return;
    }

    final jobType = _baseForceJobType(kind);
    final readySourceIds = _selectedReadyFiles()
        .map((file) => file.id)
        .toList();
    final job = _BaseForceJobState(
      localId: DateTime.now().microsecondsSinceEpoch.toString(),
      kind: kind,
      source: file,
      title: _baseForceTitle(kind),
    );
    setState(() {
      _jobs.insert(0, job);
      view = BaseForceView.queue;
    });

    try {
      final createResponse = await _api.createGenerationJob(
        fileId: file.id,
        jobType: jobType,
        sourceIds: readySourceIds.isEmpty ? [file.id] : readySourceIds,
        count: _generationCount(kind),
        qualityTier: _qualityTierFor(kind),
        options: _generationOptionsFor(kind),
      );
      final data = createResponse['data'];
      final jobId = data is Map ? data['jobId']?.toString().trim() ?? '' : '';
      if (jobId.isEmpty) {
        throw StateError('AI üretim işi başlatılamadı.');
      }
      _updateJob(job.localId, jobId: jobId, status: _JobUiStatus.running);
      await _api.processGenerationJob(jobId);
      final content = await _pollGeneratedContent(job.localId, jobId, kind);
      final result = _GenerationResult(
        kind: kind,
        title: _baseForceTitle(kind),
        sourceTitle: file.title,
        sourceFileId: file.id,
        jobId: jobId,
        createdAtLabel: _baseForceDateTimeLabel(DateTime.now()),
        mcCostLabel: _baseForceMcCostLabel(data),
        algorithmType: kind == GeneratedKind.algorithm ? algorithmMode : null,
        outputFormat: kind == GeneratedKind.algorithm ? algorithmLayout : null,
        detailLevel: kind == GeneratedKind.algorithm ? algorithmDetail : null,
        qualityTier: kind == GeneratedKind.algorithm ? algorithmQuality : null,
        comparisonType:
            kind == GeneratedKind.comparison || kind == GeneratedKind.table
            ? comparisonType
            : null,
        tableFormat:
            kind == GeneratedKind.comparison || kind == GeneratedKind.table
            ? comparisonFormat
            : null,
        comparisonDetail:
            kind == GeneratedKind.comparison || kind == GeneratedKind.table
            ? comparisonDetail
            : null,
        comparisonQuality:
            kind == GeneratedKind.comparison || kind == GeneratedKind.table
            ? comparisonQuality
            : null,
        content: content,
      );
      if (!mounted) return;
      setState(() {
        _latestResult = result;
        _latestResultSaved = true;
        _latestResultSaveError = null;
        _updateJobValue(
          job.localId,
          status: _JobUiStatus.completed,
          result: result,
          progress: 1,
        );
        view = BaseForceView.flashcardResults;
      });
    } catch (error) {
      if (!mounted) return;
      final message = _friendlyBaseForceError(error, kind: kind);
      setState(() {
        _updateJobValue(
          job.localId,
          status: _JobUiStatus.failed,
          errorMessage: message,
          progress: 1,
        );
      });
      _toast(message);
    }
  }

  Future<Object?> _pollGeneratedContent(
    String localId,
    String jobId,
    GeneratedKind kind,
  ) async {
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
            : 'Çıktı oluşturulamadı.';
        throw StateError(
          message == null || message.trim().isEmpty
              ? 'Çıktı oluşturulamadı.'
              : [code, message].whereType<String>().join(': '),
        );
      }
      if (mounted) {
        _updateJob(
          localId,
          status: attempt == 0 ? _JobUiStatus.pending : _JobUiStatus.running,
          progress: (attempt + 1) / maxAttempts,
        );
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    throw StateError(
      'Çıktı hazırlanması zaman aşımına uğradı. Kuyruktan tekrar deneyebilirsin.',
    );
  }

  void _updateJob(
    String localId, {
    String? jobId,
    _JobUiStatus? status,
    double? progress,
  }) {
    if (!mounted) return;
    setState(() {
      _updateJobValue(
        localId,
        jobId: jobId,
        status: status,
        progress: progress,
      );
    });
  }

  void _updateJobValue(
    String localId, {
    String? jobId,
    _JobUiStatus? status,
    _GenerationResult? result,
    String? errorMessage,
    double? progress,
  }) {
    final index = _jobs.indexWhere((item) => item.localId == localId);
    if (index == -1) return;
    _jobs[index] = _jobs[index].copyWith(
      jobId: jobId,
      status: status,
      result: result,
      errorMessage: errorMessage,
      progress: progress,
    );
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
            onToggleSource: _toggleSourceForGeneration,
            onContinue: () => _open(switch (selectedFactory) {
              'question' => BaseForceView.questionFactory,
              'summary' => BaseForceView.summaryFactory,
              'algorithm' => BaseForceView.algorithmFactory,
              'comparison' => BaseForceView.comparisonFactory,
              _ => BaseForceView.flashcardFactory,
            }),
          ),
          BaseForceView.flashcardFactory => _FlashcardFactoryScreen(
            data: widget.data,
            selectedSources: selectedSources,
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
            onDifficultyChanged: (v) => setState(() => flashcardDifficulty = v),
            onExtractKeyChanged: (v) => setState(() => flashcardExtractKey = v),
            onAddHintsChanged: (v) => setState(() => flashcardAddHints = v),
            onGenerate: () => _startGeneration(GeneratedKind.flashcard),
          ),
          BaseForceView.questionFactory => _QuestionFactoryScreen(
            data: widget.data,
            selectedSources: selectedSources,
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
            onGenerate: () => _startGeneration(GeneratedKind.question),
          ),
          BaseForceView.summaryFactory => _SummaryFactoryScreen(
            data: widget.data,
            selectedSources: selectedSources,
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
            onMarkTermsChanged: (v) => setState(() => summaryMarkTerms = v),
            onToTableChanged: (v) => setState(() => summaryToTable = v),
            onChecklistChanged: (v) => setState(() => summaryChecklist = v),
            onGenerate: () => _startGeneration(GeneratedKind.summary),
          ),
          BaseForceView.algorithmFactory => _AlgorithmFactoryScreen(
            data: widget.data,
            selectedSources: selectedSources,
            onSearch: widget.onSearch,
            onBack: _backToHome,
            onPickSources: () => _open(BaseForceView.sourcePicker),
            algorithmMode: algorithmMode,
            algorithmLayout: algorithmLayout,
            algorithmDetail: algorithmDetail,
            algorithmQuality: algorithmQuality,
            colorfulNodes: algorithmColorfulNodes,
            clinicalNotes: algorithmClinicalNotes,
            onModeChanged: (v) => setState(() => algorithmMode = v),
            onLayoutChanged: (v) => setState(() => algorithmLayout = v),
            onDetailChanged: (v) => setState(() => algorithmDetail = v),
            onQualityChanged: (v) => setState(() => algorithmQuality = v),
            onColorfulNodesChanged: (v) =>
                setState(() => algorithmColorfulNodes = v),
            onClinicalNotesChanged: (v) =>
                setState(() => algorithmClinicalNotes = v),
            onGenerate: () => _startGeneration(GeneratedKind.algorithm),
          ),
          BaseForceView.comparisonFactory => _ComparisonFactoryScreen(
            data: widget.data,
            selectedSources: selectedSources,
            onSearch: widget.onSearch,
            onBack: _backToHome,
            onPickSources: () => _open(BaseForceView.sourcePicker),
            comparisonType: comparisonType,
            tableFormat: comparisonFormat,
            detailLevel: comparisonDetail,
            qualityTier: comparisonQuality,
            onComparisonTypeChanged: (v) => setState(() => comparisonType = v),
            onTableFormatChanged: (v) => setState(() => comparisonFormat = v),
            onDetailLevelChanged: (v) => setState(() => comparisonDetail = v),
            onQualityTierChanged: (v) => setState(() => comparisonQuality = v),
            onGenerate: () => _startGeneration(GeneratedKind.comparison),
            onOpenResult: () => _open(BaseForceView.flashcardResults),
          ),
          BaseForceView.queue => _QueueScreen(
            data: widget.data,
            jobs: _jobs,
            onSearch: widget.onSearch,
            onBack: _backToHome,
            queueFilter: queueFilter,
            onFilterChanged: (v) => setState(() => queueFilter = v),
            onOpenResult: _openResult,
            onRetryJob: _retryGeneration,
            onCancelJob: _cancelJob,
          ),
          BaseForceView.flashcardResults => _FlashcardResultsScreen(
            result: _latestResult,
            saveError: _latestResultSaveError,
            onSearch: widget.onSearch,
            onBack: _backToHome,
            onSave: () {
              _saveLatestResult();
            },
            onExport: _copyLatestResult,
            onRegenerate: () => _open(
              _factoryViewForKind(
                _latestResult?.kind ?? GeneratedKind.flashcard,
              ),
            ),
          ),
          BaseForceView.allGenerations => _AllGenerationsScreen(
            data: widget.data,
            jobs: _jobs,
            selectedFilter: selectedFilter,
            onSearch: widget.onSearch,
            onBack: _backToHome,
            onFilter: (filter) => setState(() => selectedFilter = filter),
            onOpenResult: _openStoredGeneration,
            onRegenerate: _regenerateStoredGeneration,
            onShare: _copyStoredGeneration,
            onClear: () => setState(() => selectedFilter = 'Tümü'),
          ),
        },
      ),
    );
  }
}

enum _JobUiStatus { pending, running, completed, failed }

class _BaseForceJobState {
  const _BaseForceJobState({
    required this.localId,
    required this.kind,
    required this.source,
    required this.title,
    this.jobId,
    this.status = _JobUiStatus.pending,
    this.progress = 0,
    this.result,
    this.errorMessage,
  });

  final String localId;
  final String? jobId;
  final GeneratedKind kind;
  final DriveFile source;
  final String title;
  final _JobUiStatus status;
  final double progress;
  final _GenerationResult? result;
  final String? errorMessage;

  _BaseForceJobState copyWith({
    String? jobId,
    _JobUiStatus? status,
    double? progress,
    _GenerationResult? result,
    String? errorMessage,
  }) {
    return _BaseForceJobState(
      localId: localId,
      jobId: jobId ?? this.jobId,
      kind: kind,
      source: source,
      title: title,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class _GenerationResult {
  const _GenerationResult({
    required this.kind,
    required this.title,
    required this.sourceTitle,
    required this.content,
    this.sourceFileId,
    this.jobId,
    this.createdAtLabel,
    this.mcCostLabel,
    this.algorithmType,
    this.outputFormat,
    this.detailLevel,
    this.qualityTier,
    this.comparisonType,
    this.tableFormat,
    this.comparisonDetail,
    this.comparisonQuality,
  });

  final GeneratedKind kind;
  final String title;
  final String sourceTitle;
  final String? sourceFileId;
  final String? jobId;
  final String? createdAtLabel;
  final String? mcCostLabel;
  final String? algorithmType;
  final String? outputFormat;
  final String? detailLevel;
  final String? qualityTier;
  final String? comparisonType;
  final String? tableFormat;
  final String? comparisonDetail;
  final String? comparisonQuality;
  final Object? content;
}

String _baseForceJobType(GeneratedKind kind) {
  return switch (kind) {
    GeneratedKind.flashcard => 'flashcard',
    GeneratedKind.question => 'quiz',
    GeneratedKind.summary => 'exam_morning_summary',
    GeneratedKind.algorithm => 'algorithm',
    GeneratedKind.comparison || GeneratedKind.table => 'comparison',
    GeneratedKind.podcast => 'podcast',
    GeneratedKind.infographic => 'infographic',
    GeneratedKind.mindMap => 'mind_map',
  };
}

String _baseForceOutputKind(GeneratedKind kind) {
  return switch (kind) {
    GeneratedKind.question => 'question',
    GeneratedKind.summary => 'exam_morning_summary',
    GeneratedKind.table => 'comparison',
    GeneratedKind.mindMap => 'mind_map',
    _ => kind.name,
  };
}

bool _isBaseForceReadySource(DriveFile file) {
  return file.id.trim().isNotEmpty && driveFileUsableForGeneration(file);
}

bool _isZeroSizeLabel(String label) {
  final normalized = label.trim().toLowerCase().replaceAll(',', '.');
  if (normalized.isEmpty) return true;
  if (normalized == '0' || normalized == '0 b' || normalized == '0 byte') {
    return true;
  }
  final match = RegExp(
    r'^([0-9]+(?:\.[0-9]+)?)\s*([a-zçğıöşü]*)$',
  ).firstMatch(normalized);
  if (match == null) return false;
  final value = double.tryParse(match.group(1) ?? '');
  return value != null && value <= 0;
}

String _baseForceSourceBlockedMessage(DriveFile file) {
  return '${file.title}: ${_baseForceSourceBlockedReason(file)}';
}

String _baseForceSourceBlockedReason(DriveFile file) {
  if (file.id.trim().isEmpty) return 'Kaynak kimliği eksik.';
  if (_isZeroSizeLabel(file.sizeLabel)) {
    return 'Eksik yükleme: Dosya yükleme tamamlanmamış.';
  }
  return switch (file.status) {
    DriveItemStatus.completed => 'Hazır değil: Bu kaynakla çıktı üretilemez.',
    DriveItemStatus.processing => 'İşleniyor: Hazır olduğunda kullanılabilir.',
    DriveItemStatus.uploading =>
      'Yükleniyor: Dosya aktarımı tamamlanınca kullanılabilir.',
    DriveItemStatus.failed => driveFriendlyStatusDescription(file),
    DriveItemStatus.draft => 'Eksik yükleme: Dosya yükleme tamamlanmamış.',
  };
}

String _baseForceReadyLabel(DriveFile file) {
  if (_isBaseForceReadySource(file)) return 'Kullanıma hazır';
  if (_isZeroSizeLabel(file.sizeLabel)) return 'Eksik yükleme';
  return driveStatusLabel(file.status);
}

_BFSource _bfSourceFromFile(DriveFile file, {String time = 'Az önce'}) {
  final ready = _isBaseForceReadySource(file);
  return _BFSource(
    id: file.id,
    name: file.title,
    kind: file.kind,
    size: file.sizeLabel,
    pages: file.pageLabel,
    subject: file.courseTitle,
    time: time,
    status: file.status,
    enabled: ready,
    suitabilityLabel: _baseForceReadyLabel(file),
    blockedReason: ready ? null : _baseForceSourceBlockedReason(file),
  );
}

int? _baseForceCount(GeneratedKind kind) {
  return switch (kind) {
    GeneratedKind.flashcard => 20,
    GeneratedKind.question => 10,
    _ => null,
  };
}

String _baseForceTitle(GeneratedKind kind) {
  return switch (kind) {
    GeneratedKind.flashcard => 'Flashcard Seti',
    GeneratedKind.question => 'Soru Seti',
    GeneratedKind.summary => 'Sınav Sabahı Özeti',
    GeneratedKind.algorithm => 'Algoritma',
    GeneratedKind.comparison || GeneratedKind.table => 'Karşılaştırma',
    GeneratedKind.podcast => 'Podcast',
    GeneratedKind.infographic => 'İnfografik',
    GeneratedKind.mindMap => 'Zihin Haritası',
  };
}

String _baseForceKindLabel(GeneratedKind kind) {
  return switch (kind) {
    GeneratedKind.flashcard => 'Flashcard',
    GeneratedKind.question => 'Soru',
    GeneratedKind.summary => 'Sınav Sabahı Özeti',
    GeneratedKind.algorithm => 'Algoritma',
    GeneratedKind.comparison || GeneratedKind.table => 'Tablo',
    GeneratedKind.podcast => 'Podcast',
    GeneratedKind.infographic => 'İnfografik',
    GeneratedKind.mindMap => 'Zihin Haritası',
  };
}

String _flashcardStyleValue(String label) {
  return switch (label) {
    'Cloze' => 'cloze',
    'Hızlı Tekrar' => 'rapid_review',
    _ => 'classic',
  };
}

String _summaryLengthValue(String label) {
  return switch (label) {
    '3 sayfa' => 'three_pages',
    'Ultra kısa' => 'ultra_brief',
    _ => 'one_page',
  };
}

String _summaryModeValue(String label) {
  return switch (label) {
    'Kritik Noktalar' => 'critical_points',
    'Hoca Vurguları' => 'teacher_emphasis',
    _ => 'high_yield_questions',
  };
}

String _difficultyValue(String label) {
  return switch (label) {
    'Kolay' => 'easy',
    'Zor' || 'Çok Zor' => 'hard',
    _ => 'medium',
  };
}

int _baseForceContentCount(Object? content) {
  if (content is List) return content.length;
  if (content is Map) {
    for (final key in const [
      'cards',
      'questions',
      'bulletPoints',
      'steps',
      'rows',
      'segments',
    ]) {
      final value = content[key];
      if (value is List) return value.length;
    }
  }
  return content == null ? 0 : 1;
}

String _algorithmTypeValue(String label) {
  return switch (label) {
    'Tedavi Algoritması' => 'treatment_algorithm',
    'Klinik Karar Ağacı' => 'clinical_decision_tree',
    'Patofizyoloji Mekanizma Akışı' => 'pathophysiology_mechanism_flow',
    'Laboratuvar Yorumlama Akışı' => 'lab_interpretation_flow',
    'TUS Soru Çözüm Akışı' => 'tus_question_solving_flow',
    'Acil Yaklaşım Algoritması' => 'emergency_approach_algorithm',
    _ => 'diagnostic_algorithm',
  };
}

String _algorithmFormatValue(String label) {
  return switch (label) {
    'Karar ağacı' => 'decision_tree',
    'Basamaklı algoritma' => 'stepwise_algorithm',
    'Evet/Hayır dallanması' => 'yes_no_branching',
    'Mekanizma zinciri' => 'mechanism_chain',
    'Tablo + akış' => 'table_plus_flow',
    _ => 'flowchart',
  };
}

String _algorithmDetailValue(String label) {
  return switch (label) {
    'Kısa' => 'brief',
    'Detaylı' => 'detailed',
    'Klinik odaklı' => 'clinical_focused',
    'Sınav odaklı' => 'exam_focused',
    _ => 'balanced',
  };
}

String _algorithmQualityValue(String label) {
  return switch (label) {
    'Ekonomik' => 'economy',
    'Premium' => 'premium',
    _ => 'standard',
  };
}

String _comparisonTypeValue(String label) {
  return switch (label) {
    'İlaç Karşılaştırması' => 'drug_comparison',
    'Mekanizma Karşılaştırması' => 'mechanism_comparison',
    'Klinik Bulgu Karşılaştırması' => 'clinical_finding_comparison',
    'Tanı-Tedavi Karşılaştırması' => 'diagnosis_treatment_comparison',
    'Temel Bilim Karşılaştırması' => 'basic_science_comparison',
    'TUS’ta Karıştırılanlar' => 'tus_confusables',
    _ => 'disease_comparison',
  };
}

String _comparisonFormatValue(String label) {
  return switch (label) {
    'Sütun bazlı ayrım' => 'column_based',
    '“Ayırt ettiren ipucu” tablosu' => 'distinguishing_clue_table',
    'Tanı / Tetkik / Tedavi matrisi' => 'diagnosis_test_treatment_matrix',
    'Artı-eksi karşılaştırması' => 'plus_minus_comparison',
    'Mini özet + tablo' => 'mini_summary_plus_table',
    _ => 'classic_table',
  };
}

String _comparisonDetailValue(String label) {
  return switch (label) {
    'Kısa' => 'brief',
    'Detaylı' => 'detailed',
    'Klinik odaklı' => 'clinical_focused',
    'Sınav odaklı' => 'exam_focused',
    _ => 'balanced',
  };
}

String _comparisonQualityValue(String label) {
  return switch (label) {
    'Ekonomik' => 'economy',
    'Premium' => 'premium',
    _ => 'standard',
  };
}

String _baseForceSourceSizeTier(String label) {
  final normalized = label.trim().toLowerCase().replaceAll(',', '.');
  final match = RegExp(r'([0-9]+(?:\.[0-9]+)?)').firstMatch(normalized);
  final value = double.tryParse(match?.group(1) ?? '');
  if (value == null) return 'unknown';
  if (normalized.contains('gb')) return 'large';
  if (normalized.contains('mb')) {
    if (value >= 25) return 'large';
    if (value >= 5) return 'medium';
    return 'small';
  }
  if (normalized.contains('kb')) {
    if (value >= 5000) return 'medium';
    return 'small';
  }
  return value > 0 ? 'small' : 'empty';
}

String _baseForceDateTimeLabel(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.'
      '${local.month.toString().padLeft(2, '0')}.${local.year} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String _baseForceMcCostLabel(Object? data) {
  if (data is! Map) {
    return 'MC tutarı üretim sırasında güvenli şekilde hesaplanır.';
  }
  final value = data['final_mc_cost'] ?? data['reserved_mc'];
  if (value is num && value > 0) {
    return '${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)} MC rezerve edildi';
  }
  return 'MC tutarı üretim sırasında güvenli şekilde hesaplanır.';
}

String _plainTextForResult(_GenerationResult result) {
  return [
    result.title,
    'Kaynak: ${result.sourceTitle}',
    'Tür: ${_baseForceKindLabel(result.kind)}',
    '',
    _plainTextValue(result.content),
  ].join('\n');
}

String _plainTextValue(Object? value) {
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
        .map((entry) => '${entry.key + 1}. ${_plainTextValue(entry.value)}')
        .join('\n\n');
  }
  if (value is Map) {
    if (value.isEmpty) return 'Sonuç içeriği boş.';
    return value.entries
        .map((entry) {
          final key = entry.key.toString();
          return '$key: ${_plainTextValue(entry.value)}';
        })
        .join('\n');
  }
  final text = value.toString().trim();
  return text.isEmpty ? 'Sonuç içeriği boş.' : text;
}

String _friendlyBaseForceError(Object error, {GeneratedKind? kind}) {
  final raw = error.toString();
  final text = raw
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '')
      .replaceFirst('FunctionException', '')
      .replaceFirst('FunctionsException', '')
      .trim();
  final isAlgorithm = kind == GeneratedKind.algorithm;
  final isComparison =
      kind == GeneratedKind.comparison || kind == GeneratedKind.table;
  const algorithmFallback =
      'Algoritma şu anda tamamlanamadı. Kaynağın güvende; harcanan MC varsa iade edilir.';
  const comparisonFallback =
      'Karşılaştırma tablosu şu anda tamamlanamadı. Kaynağın güvende; harcanan MC varsa iade edilir.';
  if (text.isEmpty) {
    return 'Çıktı oluşturulamadı. Kaynağı veya ayarları kontrol edip tekrar deneyebilirsin.';
  }
  if (text.contains('SourceBase Supabase client is not configured')) {
    return 'Oturum süren dolmuş olabilir. Tekrar giriş yaparak devam edebilirsin.';
  }
  final lowerText = text.toLowerCase();
  if (lowerText.contains('network') ||
      lowerText.contains('failed to fetch') ||
      lowerText.contains('socket') ||
      lowerText.contains('connection')) {
    return 'Bağlantı kurulamadı. İnternet bağlantını kontrol edip tekrar dene.';
  }
  if (lowerText.contains('unauthorized') ||
      lowerText.contains('jwt') ||
      lowerText.contains('401')) {
    return 'Oturum süren dolmuş olabilir. Tekrar giriş yaparak devam edebilirsin.';
  }
  if (text.contains('INSUFFICIENT_MC') ||
      text.toLowerCase().contains('yetersiz medasicoin')) {
    return 'MC bakiyen bu üretim için yeterli değil.';
  }
  if (text.contains('SOURCE_TEXT_REQUIRED')) {
    return 'Bu kaynakta üretim için okunabilir içerik yok. Metin içeren hazır bir PDF veya PPTX seç.';
  }
  if (text.contains('VERTEX_AUTH_FAILED') ||
      text.contains('VERTEX_UPSTREAM_ERROR') ||
      text.contains('MODEL_NOT_FOUND') ||
      text.contains('JOB_CREATE_FAILED') ||
      text.contains('BACKGROUND_JOB_FAILED')) {
    if (isAlgorithm) return algorithmFallback;
    if (isComparison) return comparisonFallback;
    return 'Çıktı şu anda hazırlanamadı. Kaynağı veya ayarları kontrol edip tekrar deneyebilirsin.';
  }
  if (_looksLikeTechnicalBaseForceError(text)) {
    if (isAlgorithm) return algorithmFallback;
    if (isComparison) return comparisonFallback;
    return 'Çıktı oluşturulamadı. Kaynağı veya ayarları kontrol edip tekrar deneyebilirsin.';
  }
  if (isAlgorithm && text.toLowerCase().contains('ai üretimi başarısız')) {
    return algorithmFallback;
  }
  if (isComparison && text.toLowerCase().contains('ai üretimi başarısız')) {
    return comparisonFallback;
  }
  return text;
}

bool _looksLikeTechnicalBaseForceError(String text) {
  final lower = text.toLowerCase();
  return lower.contains('stack trace') ||
      lower.contains(' at ') ||
      lower.contains('null') ||
      lower.contains('undefined') ||
      lower.contains('typeerror') ||
      lower.contains('referenceerror') ||
      lower.contains('syntaxerror') ||
      lower.contains('edge function') ||
      lower.contains('internal server error') ||
      lower.contains('failed to fetch') ||
      RegExp(r'\b[A-Z0-9_]{4,}_FAILED\b').hasMatch(text);
}

String _baseForceProgressLabel(
  GeneratedKind kind,
  _JobUiStatus status,
  double progress,
) {
  if (status == _JobUiStatus.pending) return 'İşlem sıraya alındı';
  if (kind == GeneratedKind.comparison || kind == GeneratedKind.table) {
    if (status == _JobUiStatus.completed) return 'Karşılaştırma hazır';
    if (status == _JobUiStatus.failed) return 'Karşılaştırma tamamlanamadı';
    final stage = (progress * 5).floor().clamp(0, 4);
    return const [
      'Kaynak analiz ediliyor',
      'Benzer kavramlar ayrıştırılıyor',
      'Ayırt ettiren noktalar çıkarılıyor',
      'Tablo yapısı hazırlanıyor',
      'Karşılaştırma tamamlanıyor',
    ][stage];
  }
  if (kind != GeneratedKind.algorithm) return _jobStatusLabel(status);
  if (status == _JobUiStatus.completed) return 'Algoritma hazır';
  if (status == _JobUiStatus.failed) return 'Algoritma tamamlanamadı';
  final stage = (progress * 5).floor().clamp(0, 4);
  return const [
    'Kaynak analiz ediliyor',
    'Karar noktaları çıkarılıyor',
    'Dallanma yapısı kuruluyor',
    'Klinik akış düzenleniyor',
    'Algoritma hazırlanıyor',
  ][stage];
}

String _jobStatusLabel(_JobUiStatus status) {
  return switch (status) {
    _JobUiStatus.pending => 'İşlem sıraya alındı',
    _JobUiStatus.running => 'Çıktı hazırlanıyor',
    _JobUiStatus.completed => 'Çıktı hazır',
    _JobUiStatus.failed => 'Çıktı oluşturulamadı',
  };
}

String _resultPreviewText(Object? content) {
  if (content == null) return 'Önizleme henüz hazır değil.';
  final raw = switch (content) {
    final String text => text,
    _ => content.toString(),
  };
  final cleaned = raw
      .replaceAll(RegExp(r'[#>*`_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (cleaned.isEmpty) return 'Önizleme henüz hazır değil.';
  if (cleaned.length <= 180) return cleaned;
  return '${cleaned.substring(0, 177).trimRight()}...';
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
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 600;
    final horizontalPadding = width < 600
        ? 16.0
        : width < 1024
        ? 24.0
        : 32.0;
    final topPadding = MediaQuery.viewPaddingOf(context).top + 12;
    final bottomPadding = isMobile
        ? SourceBaseBottomNav.scrollEndPadding(context)
        : 48.0;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
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
            _BaseForceTopBar(onSearch: onSearch, onBack: onBack),
            _BaseForceHero(
              title: title,
              subtitle: subtitle,
              art: art,
              tight: heroTight,
              actions: actions,
            ),
            ...children,
            if (isMobile) const WorkspaceBottomNavGuard(),
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
                    if (onBack != null) ...[
                      backButton,
                      const SizedBox(width: 6),
                    ],
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: AppColors.navy,
                fontSize: compact ? 32 : 44,
                fontWeight: FontWeight.w900,
                height: 1.04,
                letterSpacing: 0,
              ),
            ),
            SizedBox(height: compact ? 10 : 14),
            Text(
              subtitle,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: compact ? 16 : 20,
                height: compact ? 1.22 : 1.42,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (actions.isNotEmpty) ...[
              SizedBox(height: compact ? 12 : 24),
              Wrap(spacing: 10, runSpacing: 10, children: actions),
            ],
          ],
        );
        if (constraints.maxWidth < 620) {
          return Container(
            margin: EdgeInsets.only(bottom: tight ? 12 : 18),
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
                  padding: EdgeInsets.only(top: tight ? 4 : 12),
                  child: titleBlock,
                ),
                if (!tight)
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 176,
                      height: 104,
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
    final readyFiles = data.recentFiles.where(_isBaseForceReadySource).toList();
    final latestGenerations = [
      for (final file in data.recentFiles)
        for (final gen in file.generated.take(1)) (file, gen),
    ].take(3).toList();
    return _BaseForcePage(
      title: 'BaseForce',
      subtitle: 'Kaynaklarından sınav odaklı çalışma çıktıları üret.',
      onSearch: onSearch,
      heroTight: true,
      actions: [
        _HeroAction(
          label: 'Kaynak seç',
          icon: Icons.change_history_rounded,
          onTap: onOpenSources,
        ),
      ],
      children: [
        PremiumHeroCard(
          eyebrow: 'Üretim merkezi',
          title: 'BaseForce',
          description: readyFiles.isEmpty
              ? 'Önce bir kaynak seç. Hazır PDF ve PPTX dosyalarından üretim yapabilirsin.'
              : 'Seçtiğin kaynaklardan flashcard, soru, özet ve tablo üretimini tek merkezden yönet.',
          tint: AppColors.blue,
          anchorIcon: Icons.auto_awesome_mosaic_rounded,
          anchorLabel: readyFiles.isEmpty ? 'Kaynak seç' : 'Üretime hazır',
          metrics: [
            MetricPillData(
              label: 'Seçili kaynak',
              value: readyFiles.isEmpty ? '0' : '${readyFiles.length}',
              tint: AppColors.green,
              icon: Icons.check_circle_rounded,
            ),
            MetricPillData(
              label: 'Üretim türü',
              value: '5',
              tint: AppColors.purple,
              icon: Icons.grid_view_rounded,
            ),
            MetricPillData(
              label: 'Kalan MC',
              value: 'Takip et',
              tint: AppColors.orange,
              icon: Icons.toll_rounded,
            ),
          ],
          actions: [
            SBPrimaryButton(
              label: 'Kaynak seç',
              icon: Icons.change_history_rounded,
              onPressed: onOpenSources,
              size: SBButtonSize.small,
              fullWidth: false,
            ),
            SBSecondaryButton(
              label: 'Üretim kuyruğu',
              icon: Icons.schedule_rounded,
              onPressed: onOpenQueue,
              size: SBButtonSize.small,
              fullWidth: false,
            ),
          ],
        ),
        _SectionHeader(
          title: 'Üretim Merkezleri',
          action: 'Tümünü Gör',
          onTap: onOpenAll,
        ),
        _ResponsiveGrid(
          minItemWidth: 250,
          children: [
            DenseFeatureCard(
              icon: Icons.style_outlined,
              title: 'Flashcard Factory',
              description:
                  'Kaynağından tekrar kartları hazırlayıp aktif hatırlama düzeni kur.',
              tags: const ['Kart', 'Tekrar', 'Sınav'],
              primaryMetric: 'Flashcard seti',
              secondaryMetric: 'Tahmini 10-30 MC',
              trailingNote: readyFiles.isEmpty
                  ? 'Üretim için önce hazır kaynak seç.'
                  : 'Son kullanılan kaynaklarla hızlıca devam edebilirsin.',
              tint: AppColors.blue,
              ctaLabel: 'Başlat',
              onTap: () => onOpenFactory('flashcard'),
            ),
            DenseFeatureCard(
              icon: Icons.quiz_outlined,
              title: 'Soru Fabrikası',
              description:
                  'Kaynağındaki kritik noktaları soru formatına dönüştür.',
              tags: const ['MCQ', 'Açıklama', 'Hazır kaynak'],
              primaryMetric: 'Sınav sorusu',
              secondaryMetric: 'Tahmini 12-24 MC',
              trailingNote:
                  'Konu sonu tekrar ve deneme öncesi kullanım için uygun.',
              tint: AppColors.green,
              ctaLabel: 'Başlat',
              onTap: () => onOpenFactory('question'),
            ),
            DenseFeatureCard(
              icon: Icons.summarize_outlined,
              title: 'Sınav Sabahı Özeti',
              description:
                  'Yoğun tekrar için kısa, temiz ve sınav odaklı özetler çıkar.',
              tags: const ['Özet', 'Kritik nokta', 'Son tekrar'],
              primaryMetric: 'Kısa özet',
              secondaryMetric: 'Tahmini 8-18 MC',
              trailingNote: 'Sınav öncesi hızlı tarama için ideal.',
              tint: AppColors.purple,
              ctaLabel: 'Başlat',
              onTap: () => onOpenFactory('summary'),
            ),
            DenseFeatureCard(
              icon: Icons.account_tree_outlined,
              title: 'Akış Şeması / Algoritma',
              description:
                  'Tanı ve yönetim akışlarını karar adımlarıyla düzenle.',
              tags: const ['Algoritma', 'Karar', 'Akış'],
              primaryMetric: 'Adım adım şema',
              secondaryMetric: 'Tahmini 10-20 MC',
              trailingNote:
                  'Ayırıcı tanı ve yönetim basamakları için güçlü bir çıktı.',
              tint: AppColors.orange,
              ctaLabel: 'Başlat',
              onTap: () => onOpenFactory('algorithm'),
            ),
            DenseFeatureCard(
              icon: Icons.table_chart_outlined,
              title: 'Karşılaştırma Tablosu',
              description:
                  'Benzer konuları tek tabloda ayırt ettiren farklarla sun.',
              tags: const ['Tablo', 'Ayırt et', 'Karşılaştır'],
              primaryMetric: 'Karşılaştırma',
              secondaryMetric: 'Tahmini 10-18 MC',
              trailingNote:
                  'Benzer hastalık ve kavramları yan yana görmek için uygun.',
              tint: AppColors.cyan,
              ctaLabel: 'Başlat',
              onTap: () => onOpenFactory('comparison'),
            ),
            DenseFeatureCard(
              icon: Icons.schedule_rounded,
              title: 'Üretim Kuyruğu',
              description:
                  'Hazırlanan çıktıları ve işlem durumlarını tek listeden izle.',
              tags: const ['Kuyruk', 'Durum', 'Takip'],
              primaryMetric: 'Aktif işler',
              secondaryMetric:
                  '${data.recentFiles.where((file) => file.status == DriveItemStatus.processing).length} izleniyor',
              trailingNote:
                  'İşlenmekte olan kaynaklar tamamlandığında üretime devam edebilirsin.',
              tint: AppColors.blue,
              ctaLabel: 'Aç',
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
          child: readyFiles.isEmpty
              ? PremiumEmptyState(
                  icon: Icons.drive_folder_upload_outlined,
                  title: 'Henüz üretime hazır kaynak yok',
                  message:
                      'BaseForce çıktısı üretmek için önce Drive’a metin içeren PDF veya PPTX yükle.',
                  badges: const ['PDF', 'PPTX', 'Hazır kaynak'],
                  actionLabel: 'Kaynak seç',
                  onAction: onOpenSources,
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      for (final file in readyFiles.take(3)) ...[
                        SourcePreviewCard(
                          file: file,
                          ctaLabel: 'Kaynaktan üret',
                          onTap: onOpenSources,
                        ),
                        if (file != readyFiles.take(3).last)
                          const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
        ),
        _SectionHeader(
          title: 'Son Üretimler',
          action: 'Tümünü Gör',
          onTap: onOpenAll,
        ),
        if (latestGenerations.isEmpty)
          _BasePanel(
            child: PremiumEmptyState(
              icon: Icons.auto_awesome_rounded,
              title: 'Henüz üretim yok',
              message:
                  'Bir kaynak seçip üretim modlarından birini başlattığında sonuçların burada görünür.',
              badges: const ['Flashcard', 'Soru', 'Özet'],
              actionLabel: 'Üretime başla',
              onAction: onOpenSources,
            ),
          )
        else
          _ResponsiveGrid(
            minItemWidth: 260,
            children: [
              for (final entry in latestGenerations)
                ResultPreviewCard(
                  icon: generatedIcon(entry.$2.kind),
                  title: _baseForceKindLabel(entry.$2.kind),
                  source: entry.$1.title,
                  createdAt: entry.$2.updatedLabel,
                  preview: entry.$2.detail,
                  statusLabel: 'Hazır',
                  primaryActionLabel: 'Detayı aç',
                  onPrimaryAction: onOpenResult,
                  secondaryActionLabel: 'Tekrar üret',
                  onSecondaryAction: () =>
                      onOpenFactory(switch (entry.$2.kind) {
                        GeneratedKind.question => 'question',
                        GeneratedKind.summary => 'summary',
                        GeneratedKind.algorithm => 'algorithm',
                        GeneratedKind.comparison ||
                        GeneratedKind.table => 'comparison',
                        _ => 'flashcard',
                      }),
                  tint: generatedColor(entry.$2.kind),
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
    required this.onBack,
  });

  final DriveWorkspaceData data;
  final Set<String> selectedSources;
  final VoidCallback onSearch;
  final ValueChanged<String> onToggleSource;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final readyCount = data.recentFiles.where(_isBaseForceReadySource).length;
    final processingCount = data.recentFiles
        .where(
          (file) =>
              file.status == DriveItemStatus.processing ||
              file.status == DriveItemStatus.uploading,
        )
        .length;
    final blockedCount = data.recentFiles.length - readyCount - processingCount;
    return _BaseForcePage(
      title: 'Kaynak Seç',
      subtitle: 'Hazır Drive kaynaklarını seç ve üretime devam et.',
      onSearch: onSearch,
      onBack: onBack,
      heroTight: true,
      children: [
        PremiumHeroCard(
          eyebrow: 'Üretim için kaynak seç',
          title: 'Hangi dosyadan çalışalım?',
          description:
              'PDF, PPTX veya DOCX kaynaklarından sınav odaklı materyal oluşturabilirsin. Hazır olmayan dosyalar işlenene kadar seçilemez.',
          tint: AppColors.blue,
          anchorIcon: Icons.source_outlined,
          anchorLabel: selectedSources.isEmpty
              ? 'Kaynak seç'
              : '${selectedSources.length} seçili',
          metrics: [
            MetricPillData(
              label: 'Hazır kaynak',
              value: '$readyCount',
              tint: AppColors.green,
              icon: Icons.check_circle_rounded,
            ),
            MetricPillData(
              label: 'İşleniyor',
              value: '$processingCount',
              tint: AppColors.blue,
              icon: Icons.hourglass_top_rounded,
            ),
            MetricPillData(
              label: 'Uygun değil',
              value: '$blockedCount',
              tint: AppColors.red,
              icon: Icons.block_rounded,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _SearchBox(
                hint: 'Dosya adı veya konu ile ara...',
                onTap: onSearch,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _BaseNotice(
          icon: Icons.description_outlined,
          text:
              'PDF, PPTX ve mevcut destekli Drive kaynakları listelenir. Eski PPT dosyaları desteklenmez.',
        ),
        _SectionHeader(
          title: 'Drive’daki Dosyalar',
          trailing: '${data.recentFiles.length} dosya',
        ),
        _BasePanel(
          padding: EdgeInsets.zero,
          child: data.recentFiles.isEmpty
              ? PremiumEmptyState(
                  icon: Icons.folder_off_outlined,
                  title: 'Önce bir kaynak yükle',
                  message:
                      'PDF, PPTX veya DOCX dosyanı Drive’a ekledikten sonra buradan üretim başlatabilirsin.',
                  badges: const ['PDF', 'PPTX', 'DOCX'],
                  actionLabel: 'Drive’a git',
                  onAction: onBack,
                )
              : Column(
                  children: [
                    for (final file in data.recentFiles)
                      _SourceSelectRow(
                        source: _bfSourceFromFile(file),
                        selected: selectedSources.contains(file.id),
                        onTap: () => onToggleSource(file.id),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 18),
        const _BaseNotice(
          icon: Icons.info_outline_rounded,
          text:
              'Yalnızca kullanıma hazır kaynaklar seçilebilir. İşlenen, hatalı, desteklenmeyen veya eksik yüklenen dosyalar üretime alınmaz.',
        ),
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
    required this.selectedSources,
    required this.onSearch,
    required this.onBack,
    required this.onPickSources,
    required this.onGenerate,
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
  final Set<String> selectedSources;
  final VoidCallback onSearch;
  final VoidCallback onBack;
  final VoidCallback onPickSources;
  final VoidCallback onGenerate;
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
    DriveFile? readyFile;
    for (final file in data.recentFiles) {
      if (selectedSources.contains(file.id) && _isBaseForceReadySource(file)) {
        readyFile = file;
        break;
      }
    }
    final canGenerate = readyFile != null;
    final sourceStatus = readyFile == null
        ? 'Kaynak seç'
        : '${readyFile.title} • ${readyFile.sizeLabel} • ${_baseForceReadyLabel(readyFile)}';
    return _BaseForcePage(
      title: 'Flashcard Factory',
      subtitle:
          'Kaynağından tekrar kartları oluştur ve bilgiyi hızlıca pekiştir.',
      onSearch: onSearch,
      onBack: onBack,
      art: _BaseForceArtKind.cardSet,
      children: [
        _FactoryIdentityCard(
          title: 'Flashcard Factory',
          description:
              'Seçili kaynaktan kısa, sınav odaklı tekrar kartları üret.',
          tint: AppColors.blue,
          outputType: 'Flashcard',
          primaryValue: '$cardCount',
          primaryLabel: 'Kart adedi',
          sourceValue: readyFile?.title ?? 'Kaynak seç',
        ),
        const SizedBox(height: 14),
        _TwoPane(
          left: Column(
            children: [
              _SourcesPanel(
                data: data,
                selectedSources: selectedSources,
                onPickSources: onPickSources,
              ),
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
                            onTap: () =>
                                onStyleChanged('H\u0131zl\u0131 Tekrar'),
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
          right: const _BasePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PanelTitle(
                  icon: Icons.fact_check_outlined,
                  title: 'Üretim Akışı',
                ),
                SizedBox(height: 14),
                _BaseNotice(
                  icon: Icons.source_outlined,
                  text:
                      'Hazır bir kaynak seçildiğinde üretim gerçek Drive içeriğiyle başlatılır.',
                ),
                _BaseNotice(
                  icon: Icons.payments_outlined,
                  text:
                      'MC maliyeti üretim sırasında backend tarafından güvenli şekilde hesaplanır.',
                ),
                _BaseNotice(
                  icon: Icons.hourglass_top_rounded,
                  text:
                      'Oluşturma sırasında buton pasifleşir; sonuç hazır olduğunda üretim ekranında açılır.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        _ProductionSummary(
          items: [
            _SummaryItemData(
              Icons.style_rounded,
              '$cardCount',
              'Tahmini Kart',
              AppColors.blue,
            ),
            _SummaryItemData(
              Icons.menu_book_rounded,
              'Kaynağa bağlı',
              'Kapsam',
              AppColors.green,
            ),
            _SummaryItemData(
              Icons.payments_outlined,
              'Üretimde hesaplanır',
              'MC maliyeti',
              AppColors.orange,
            ),
            _SummaryItemData(
              Icons.auto_awesome_rounded,
              sourceStatus,
              'Seçili Kaynak',
              AppColors.purple,
            ),
          ],
        ),
        const SizedBox(height: 14),
        PrimaryGradientButton(
          label: canGenerate ? 'Flashcard üret' : 'Kaynak seç',
          icon: Icons.auto_awesome_rounded,
          height: 58,
          onTap: canGenerate ? onGenerate : null,
        ),
        if (canGenerate)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Üretim tamamlandığında koleksiyonlarında görünecek.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (!canGenerate) ...[
          const SizedBox(height: 8),
          _SourceRequiredNotice(onPickSources: onPickSources),
        ],
      ],
    );
  }
}

class _QuestionFactoryScreen extends StatelessWidget {
  const _QuestionFactoryScreen({
    required this.data,
    required this.selectedSources,
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
  final Set<String> selectedSources;
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
    DriveFile? readyFile;
    for (final file in data.recentFiles) {
      if (selectedSources.contains(file.id) && _isBaseForceReadySource(file)) {
        readyFile = file;
        break;
      }
    }
    final canGenerate = readyFile != null;
    final sourceStatus = readyFile == null
        ? 'Kaynak seç'
        : '${readyFile.title} • ${readyFile.sizeLabel} • ${_baseForceReadyLabel(readyFile)}';
    return _BaseForcePage(
      title: 'Soru Fabrikas\u0131',
      subtitle: 'Kaynağından çalışmaya uygun sorular üret.',
      onSearch: onSearch,
      onBack: onBack,
      children: [
        _FactoryIdentityCard(
          title: 'Soru Fabrikası',
          description: 'Kaynağından açıklamalı, sınav odaklı sorular üret.',
          tint: AppColors.green,
          outputType: questionType,
          primaryValue: '$questionCount',
          primaryLabel: 'Soru adedi',
          sourceValue: readyFile?.title ?? 'Kaynak seç',
        ),
        const SizedBox(height: 14),
        _SelectedSourceChips(
          data: data,
          selectedSources: selectedSources,
          onPickSources: onPickSources,
        ),
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
                  for (final value in const [
                    'Kolay',
                    'Orta',
                    'Zor',
                    '\xC7ok Zor',
                  ])
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
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _BaseNotice(
          icon: Icons.fact_check_outlined,
          text:
              'Sorular, seçilen hazır kaynağın gerçek içeriği üzerinden oluşturulur. Teknik hata mesajları yerine sade durum bilgisi gösterilir.',
        ),
        const SizedBox(height: 14),
        _ProductionSummary(
          items: [
            _SummaryItemData(
              Icons.description_outlined,
              '$questionCount',
              'Soru',
              AppColors.blue,
            ),
            _SummaryItemData(
              Icons.chat_bubble_outline_rounded,
              addExplanation ? 'Açıklamalı' : 'Yanıt odaklı',
              'Üretim',
              AppColors.cyan,
            ),
            _SummaryItemData(
              Icons.bar_chart_rounded,
              selectedDifficulty,
              'Zorluk Seviyesi',
              AppColors.orange,
            ),
            _SummaryItemData(
              Icons.payments_outlined,
              'Üretimde hesaplanır',
              'MC maliyeti',
              AppColors.orange,
            ),
            _SummaryItemData(
              Icons.source_outlined,
              sourceStatus,
              'Seçili Kaynak',
              AppColors.purple,
            ),
          ],
        ),
        const SizedBox(height: 14),
        PrimaryGradientButton(
          label: canGenerate ? 'Soru seti oluştur' : 'Kaynak seç',
          icon: Icons.auto_fix_high_rounded,
          height: 58,
          onTap: canGenerate ? onGenerate : null,
        ),
        if (!canGenerate) ...[
          const SizedBox(height: 8),
          _SourceRequiredNotice(onPickSources: onPickSources),
        ],
      ],
    );
  }
}

class _SummaryFactoryScreen extends StatelessWidget {
  const _SummaryFactoryScreen({
    required this.data,
    required this.selectedSources,
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
  final Set<String> selectedSources;

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
    DriveFile? readyFile;
    for (final file in data.recentFiles) {
      if (selectedSources.contains(file.id) && _isBaseForceReadySource(file)) {
        readyFile = file;
        break;
      }
    }
    final canGenerate = readyFile != null;
    final sourceStatus = readyFile == null
        ? 'Kaynak seç'
        : '${readyFile.title} • ${readyFile.sizeLabel} • ${_baseForceReadyLabel(readyFile)}';
    return _BaseForcePage(
      title: 'S\u0131nav Sabah\u0131 \xD6zeti',
      subtitle:
          'Son tekrar için kaynağından kısa ve yoğun bir çalışma özeti çıkar.',
      onSearch: onSearch,
      onBack: onBack,
      art: _BaseForceArtKind.notebook,
      children: [
        _FactoryIdentityCard(
          title: 'Sınav Sabahı Özeti',
          description:
              'Kaynağından hızlı tekrar için yüksek verimli özet çıkar.',
          tint: AppColors.purple,
          outputType: 'Özet',
          primaryValue: summaryLength,
          primaryLabel: 'Özet uzunluğu',
          sourceValue: readyFile?.title ?? 'Kaynak seç',
        ),
        const SizedBox(height: 14),
        _SelectedSourceChips(
          data: data,
          selectedSources: selectedSources,
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
        const SizedBox(height: 14),
        const _BaseNotice(
          icon: Icons.fact_check_outlined,
          text:
              'Özet, seçilen hazır kaynağın gerçek içeriğinden oluşturulur. Hazır olmayan kaynaklarla üretim başlatılmaz.',
        ),
        const SizedBox(height: 14),
        _ProductionSummary(
          items: [
            _SummaryItemData(
              Icons.description_rounded,
              summaryLength,
              'Tahmini uzunluk',
              AppColors.blue,
            ),
            _SummaryItemData(
              Icons.track_changes_rounded,
              summaryFocus,
              'Odak modu',
              AppColors.purple,
            ),
            _SummaryItemData(
              Icons.layers_rounded,
              sourceStatus,
              'Seçili kaynak',
              AppColors.cyan,
            ),
            _SummaryItemData(
              Icons.payments_outlined,
              'Üretimde hesaplanır',
              'MC maliyeti',
              AppColors.green,
            ),
          ],
        ),
        const SizedBox(height: 14),
        PrimaryGradientButton(
          label: canGenerate ? 'Son tekrar özeti çıkar' : 'Kaynak seç',
          icon: Icons.auto_awesome_rounded,
          height: 58,
          onTap: canGenerate ? onGenerate : null,
        ),
        if (!canGenerate) ...[
          const SizedBox(height: 8),
          _SourceRequiredNotice(onPickSources: onPickSources),
        ],
      ],
    );
  }
}

class _AlgorithmFactoryScreen extends StatelessWidget {
  const _AlgorithmFactoryScreen({
    required this.data,
    required this.selectedSources,
    required this.onSearch,
    required this.onBack,
    required this.onPickSources,
    required this.onGenerate,
    required this.algorithmMode,
    required this.algorithmLayout,
    required this.algorithmDetail,
    required this.algorithmQuality,
    required this.colorfulNodes,
    required this.clinicalNotes,
    required this.onModeChanged,
    required this.onLayoutChanged,
    required this.onDetailChanged,
    required this.onQualityChanged,
    required this.onColorfulNodesChanged,
    required this.onClinicalNotesChanged,
  });

  final DriveWorkspaceData data;
  final Set<String> selectedSources;
  final VoidCallback onSearch;
  final VoidCallback onBack;
  final VoidCallback onPickSources;
  final VoidCallback onGenerate;
  final String algorithmMode;
  final String algorithmLayout;
  final String algorithmDetail;
  final String algorithmQuality;
  final bool colorfulNodes;
  final bool clinicalNotes;
  final ValueChanged<String> onModeChanged;
  final ValueChanged<String> onLayoutChanged;
  final ValueChanged<String> onDetailChanged;
  final ValueChanged<String> onQualityChanged;
  final ValueChanged<bool> onColorfulNodesChanged;
  final ValueChanged<bool> onClinicalNotesChanged;

  @override
  Widget build(BuildContext context) {
    final readySources = data.recentFiles
        .where(
          (file) =>
              selectedSources.contains(file.id) &&
              _isBaseForceReadySource(file),
        )
        .toList();
    final selectedCount = readySources.length;
    final canGenerate = selectedCount > 0;
    final sourceSummary = canGenerate
        ? '$selectedCount kaynak seçildi'
        : 'Kaynak seç';
    return _BaseForcePage(
      title: 'Akış Şeması / Algoritma',
      subtitle: 'Kaynağındaki süreçleri adım adım takip edilebilir hale getir.',
      onSearch: onSearch,
      onBack: onBack,
      heroTight: true,
      art: _BaseForceArtKind.stack,
      actions: [
        _HeroAction(
          label: sourceSummary,
          icon: canGenerate
              ? Icons.check_circle_outline_rounded
              : Icons.source_outlined,
          onTap: onPickSources,
        ),
        if (!canGenerate)
          _HeroAction(
            label: 'Drive’dan kaynak seç',
            icon: Icons.drive_folder_upload_outlined,
            cyan: true,
            onTap: onPickSources,
          ),
      ],
      children: [
        _FactoryIdentityCard(
          title: 'Akış Şeması / Algoritma',
          description:
              'Kaynağındaki süreçleri adım adım çalışma algoritmasına dönüştür.',
          tint: AppColors.orange,
          outputType: algorithmLayout,
          primaryValue: algorithmMode,
          primaryLabel: 'Algoritma türü',
          sourceValue: canGenerate
              ? '$selectedCount kaynak seçili'
              : 'Kaynak seç',
        ),
        const SizedBox(height: 14),
        _SelectedSourceChips(
          data: data,
          selectedSources: selectedSources,
          onPickSources: onPickSources,
        ),
        const SizedBox(height: 14),
        _BasePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '\xC7\u0131kt\u0131 Ayarlar\u0131',
                style: _titleStyle,
              ),
              const SizedBox(height: 16),
              _SettingGridRow(
                label: 'Algoritma tipi',
                children: [
                  _SegmentButton(
                    label: 'Tan\u0131 Algoritmas\u0131',
                    icon: Icons.account_tree_outlined,
                    selected: algorithmMode == 'Tan\u0131 Algoritmas\u0131',
                    onTap: () => onModeChanged('Tan\u0131 Algoritmas\u0131'),
                  ),
                  _SegmentButton(
                    label: 'Tedavi Algoritması',
                    icon: Icons.polyline_rounded,
                    selected: algorithmMode == 'Tedavi Algoritması',
                    onTap: () => onModeChanged('Tedavi Algoritması'),
                  ),
                  _SegmentButton(
                    label: 'Klinik Karar Ağacı',
                    icon: Icons.device_hub_rounded,
                    selected: algorithmMode == 'Klinik Karar Ağacı',
                    onTap: () => onModeChanged('Klinik Karar Ağacı'),
                  ),
                ],
              ),
              _SettingGridRow(
                label: 'Algoritma tipi',
                children: [
                  _SegmentButton(
                    label: 'Patofizyoloji Mekanizma Akışı',
                    icon: Icons.schema_outlined,
                    selected: algorithmMode == 'Patofizyoloji Mekanizma Akışı',
                    onTap: () => onModeChanged('Patofizyoloji Mekanizma Akışı'),
                  ),
                  _SegmentButton(
                    label: 'Laboratuvar Yorumlama Akışı',
                    icon: Icons.biotech_outlined,
                    selected: algorithmMode == 'Laboratuvar Yorumlama Akışı',
                    onTap: () => onModeChanged('Laboratuvar Yorumlama Akışı'),
                  ),
                  _SegmentButton(
                    label: 'TUS Soru Çözüm Akışı',
                    icon: Icons.psychology_alt_outlined,
                    selected: algorithmMode == 'TUS Soru Çözüm Akışı',
                    onTap: () => onModeChanged('TUS Soru Çözüm Akışı'),
                  ),
                  _SegmentButton(
                    label: 'Acil Yaklaşım Algoritması',
                    icon: Icons.emergency_outlined,
                    selected: algorithmMode == 'Acil Yaklaşım Algoritması',
                    onTap: () => onModeChanged('Acil Yaklaşım Algoritması'),
                  ),
                ],
              ),
              _SettingGridRow(
                label: 'Çıktı formatı',
                children: [
                  _SegmentButton(
                    label: 'Akış şeması',
                    icon: Icons.account_tree_outlined,
                    selected: algorithmLayout == 'Akış şeması',
                    onTap: () => onLayoutChanged('Akış şeması'),
                  ),
                  _SegmentButton(
                    label: 'Karar ağacı',
                    icon: Icons.device_hub_rounded,
                    selected: algorithmLayout == 'Karar ağacı',
                    onTap: () => onLayoutChanged('Karar ağacı'),
                  ),
                  _SegmentButton(
                    label: 'Basamaklı algoritma',
                    icon: Icons.format_list_numbered_rounded,
                    selected: algorithmLayout == 'Basamaklı algoritma',
                    onTap: () => onLayoutChanged('Basamaklı algoritma'),
                  ),
                ],
              ),
              _SettingGridRow(
                label: 'Çıktı formatı',
                children: [
                  _SegmentButton(
                    label: 'Evet/Hayır dallanması',
                    icon: Icons.call_split_rounded,
                    selected: algorithmLayout == 'Evet/Hayır dallanması',
                    onTap: () => onLayoutChanged('Evet/Hayır dallanması'),
                  ),
                  _SegmentButton(
                    label: 'Mekanizma zinciri',
                    icon: Icons.link_rounded,
                    selected: algorithmLayout == 'Mekanizma zinciri',
                    onTap: () => onLayoutChanged('Mekanizma zinciri'),
                  ),
                  _SegmentButton(
                    label: 'Tablo + akış',
                    icon: Icons.table_chart_outlined,
                    selected: algorithmLayout == 'Tablo + akış',
                    onTap: () => onLayoutChanged('Tablo + akış'),
                  ),
                ],
              ),
              _SettingGridRow(
                label: 'Detay seviyesi',
                children: [
                  _SegmentButton(
                    label: 'Kısa',
                    icon: Icons.adjust_rounded,
                    selected: algorithmDetail == 'Kısa',
                    onTap: () => onDetailChanged('Kısa'),
                  ),
                  _SegmentButton(
                    label: 'Dengeli',
                    icon: Icons.center_focus_strong_rounded,
                    selected: algorithmDetail == 'Dengeli',
                    onTap: () => onDetailChanged('Dengeli'),
                  ),
                  _SegmentButton(
                    label: 'Detaylı',
                    icon: Icons.format_list_bulleted_rounded,
                    selected: algorithmDetail == 'Detaylı',
                    onTap: () => onDetailChanged('Detaylı'),
                  ),
                  _SegmentButton(
                    label: 'Klinik odaklı',
                    icon: Icons.local_hospital_outlined,
                    selected: algorithmDetail == 'Klinik odaklı',
                    onTap: () => onDetailChanged('Klinik odaklı'),
                  ),
                  _SegmentButton(
                    label: 'Sınav odaklı',
                    icon: Icons.school_outlined,
                    selected: algorithmDetail == 'Sınav odaklı',
                    onTap: () => onDetailChanged('Sınav odaklı'),
                  ),
                ],
              ),
              _SettingGridRow(
                label: 'Kalite',
                children: [
                  _SegmentButton(
                    label: 'Ekonomik',
                    icon: Icons.savings_outlined,
                    selected: algorithmQuality == 'Ekonomik',
                    onTap: () => onQualityChanged('Ekonomik'),
                  ),
                  _SegmentButton(
                    label: 'Standart',
                    icon: Icons.check_circle_outline_rounded,
                    selected: algorithmQuality == 'Standart',
                    onTap: () => onQualityChanged('Standart'),
                  ),
                  _SegmentButton(
                    label: 'Premium',
                    icon: Icons.workspace_premium_outlined,
                    selected: algorithmQuality == 'Premium',
                    onTap: () => onQualityChanged('Premium'),
                  ),
                ],
              ),
              if (algorithmQuality == 'Premium') ...[
                const SizedBox(height: 2),
                const _BaseNotice(
                  icon: Icons.payments_outlined,
                  text:
                      'Premium kalite daha kapsamlı model rotası kullanabilir ve daha yüksek MC tüketebilir.',
                ),
              ],
              const _BaseNotice(
                icon: Icons.lock_outline_rounded,
                text: 'MC tutarı üretim sırasında güvenli şekilde hesaplanır.',
              ),
              _ToggleLine(
                label: 'Renkli düğümler',
                initialValue: colorfulNodes,
                onChanged: onColorfulNodesChanged,
              ),
              _ToggleLine(
                label: 'Klinik not ve kırmızı bayrak ekle',
                initialValue: clinicalNotes,
                onChanged: onClinicalNotesChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _BaseNotice(
          icon: Icons.account_tree_outlined,
          text:
              'Akış çıktısı, mevcut üretim sonucunun desteklediği metinsel yapı ile hazırlanır. Bu ekranda gerçek diagram renderer varmış gibi gösterim yapılmaz.',
        ),
        const SizedBox(height: 18),
        _ProductionSummary(
          items: [
            _SummaryItemData(
              Icons.source_outlined,
              '$selectedCount',
              'Seçili kaynak',
              AppColors.blue,
            ),
            _SummaryItemData(
              Icons.polyline_rounded,
              algorithmLayout,
              'Format',
              AppColors.green,
            ),
            _SummaryItemData(
              Icons.device_hub_rounded,
              algorithmMode,
              'Algoritma tipi',
              AppColors.purple,
            ),
            _SummaryItemData(
              Icons.payments_outlined,
              'Üretimde hesaplanır',
              'MC maliyeti',
              AppColors.orange,
            ),
          ],
        ),
        const SizedBox(height: 14),
        PrimaryGradientButton(
          label: canGenerate ? 'Algoritma oluştur' : 'Kaynak seç',
          icon: Icons.auto_awesome_rounded,
          height: 58,
          onTap: canGenerate ? onGenerate : null,
        ),
        if (!canGenerate) ...[
          const SizedBox(height: 8),
          _SourceRequiredNotice(onPickSources: onPickSources),
        ],
      ],
    );
  }
}

class _ComparisonFactoryScreen extends StatelessWidget {
  const _ComparisonFactoryScreen({
    required this.data,
    required this.selectedSources,
    required this.onSearch,
    required this.onBack,
    required this.onPickSources,
    required this.comparisonType,
    required this.tableFormat,
    required this.detailLevel,
    required this.qualityTier,
    required this.onComparisonTypeChanged,
    required this.onTableFormatChanged,
    required this.onDetailLevelChanged,
    required this.onQualityTierChanged,
    required this.onGenerate,
    required this.onOpenResult,
  });

  final DriveWorkspaceData data;
  final Set<String> selectedSources;
  final VoidCallback onSearch;
  final VoidCallback onBack;
  final VoidCallback onPickSources;
  final String comparisonType;
  final String tableFormat;
  final String detailLevel;
  final String qualityTier;
  final ValueChanged<String> onComparisonTypeChanged;
  final ValueChanged<String> onTableFormatChanged;
  final ValueChanged<String> onDetailLevelChanged;
  final ValueChanged<String> onQualityTierChanged;
  final VoidCallback onGenerate;
  final VoidCallback onOpenResult;

  @override
  Widget build(BuildContext context) {
    final selectedFiles = data.recentFiles
        .where(
          (file) =>
              selectedSources.contains(file.id) &&
              _isBaseForceReadySource(file),
        )
        .toList();
    final blockedFiles = data.recentFiles
        .where(
          (file) =>
              selectedSources.contains(file.id) &&
              !_isBaseForceReadySource(file),
        )
        .toList();
    final canGenerate = selectedFiles.isNotEmpty && blockedFiles.isEmpty;
    final sourceSummary = canGenerate
        ? '${selectedFiles.length} kaynak seçildi'
        : 'Kaynak seç';
    return _BaseForcePage(
      title: 'Kar\u015F\u0131la\u015Ft\u0131rma Tablosu',
      subtitle:
          'Benzer kavramları farklarıyla birlikte tablo halinde karşılaştır.',
      onSearch: onSearch,
      onBack: onBack,
      heroTight: true,
      actions: [
        _HeroAction(
          label: sourceSummary,
          icon: canGenerate
              ? Icons.check_circle_outline_rounded
              : Icons.source_outlined,
          onTap: onPickSources,
        ),
        if (!canGenerate)
          _HeroAction(
            label: 'Drive’dan kaynak seç',
            icon: Icons.drive_folder_upload_outlined,
            cyan: true,
            onTap: onPickSources,
          ),
      ],
      children: [
        _FactoryIdentityCard(
          title: 'Karşılaştırma Tablosu',
          description:
              'Benzer kavramları farklarıyla birlikte düzenli tabloya dönüştür.',
          tint: AppColors.cyan,
          outputType: tableFormat,
          primaryValue: comparisonType,
          primaryLabel: 'Karşılaştırma konusu',
          sourceValue: canGenerate
              ? '${selectedFiles.length} kaynak seçili'
              : 'Kaynak seç',
        ),
        const SizedBox(height: 14),
        _BasePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PanelTitle(
                icon: Icons.source_outlined,
                title: 'Kaynak Seçimi (${selectedFiles.length})',
              ),
              const SizedBox(height: 12),
              if (selectedFiles.isEmpty)
                _SourceRequiredNotice(onPickSources: onPickSources)
              else
                for (final file in selectedFiles)
                  _ComparisonSourceLine(source: _bfSourceFromFile(file)),
              for (final file in blockedFiles) ...[
                const SizedBox(height: 10),
                _LabLikeNotice(text: _baseForceSourceBlockedMessage(file)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        _BasePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PanelTitle(
                icon: Icons.compare_arrows_rounded,
                title: 'Karşılaştırma Tipi',
              ),
              const SizedBox(height: 12),
              _ComparisonChoiceGrid(
                values: const [
                  'Hastalık Karşılaştırması',
                  'İlaç Karşılaştırması',
                  'Mekanizma Karşılaştırması',
                  'Klinik Bulgu Karşılaştırması',
                  'Tanı-Tedavi Karşılaştırması',
                  'Temel Bilim Karşılaştırması',
                  'TUS’ta Karıştırılanlar',
                ],
                selected: comparisonType,
                onSelected: onComparisonTypeChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _TableSettingsPanel(
          tableFormat: tableFormat,
          detailLevel: detailLevel,
          qualityTier: qualityTier,
          onTableFormatChanged: onTableFormatChanged,
          onDetailLevelChanged: onDetailLevelChanged,
          onQualityTierChanged: onQualityTierChanged,
        ),
        const SizedBox(height: 10),
        const _BaseNotice(
          icon: Icons.table_chart_outlined,
          text:
              'Tablo çıktısı gerçek üretim sonucunda oluşturulur. Bu ekranda yalnızca kaynak ve üretim ayarları düzenlenir.',
        ),
        const SizedBox(height: 18),
        _ProductionSummary(
          items: [
            _SummaryItemData(
              Icons.menu_book_outlined,
              '${selectedFiles.length}',
              'Kaynak',
              AppColors.green,
            ),
            _SummaryItemData(
              Icons.format_list_bulleted_rounded,
              detailLevel,
              'Yoğunluk',
              AppColors.purple,
            ),
            _SummaryItemData(
              Icons.track_changes_rounded,
              qualityTier,
              'Kalite',
              AppColors.orange,
            ),
            _SummaryItemData(
              Icons.payments_outlined,
              'Üretimde hesaplanır',
              'MC maliyeti',
              AppColors.blue,
            ),
          ],
        ),
        const SizedBox(height: 10),
        const _LabLikeNotice(
          text:
              'MC tutarı üretim sırasında güvenli şekilde hesaplanır. Premium kalite daha yüksek MC tüketebilir.',
        ),
        const SizedBox(height: 14),
        PrimaryGradientButton(
          label: canGenerate ? 'Karşılaştırma tablosu oluştur' : 'Kaynak seç',
          icon: Icons.table_chart_outlined,
          height: 58,
          onTap: canGenerate ? onGenerate : null,
        ),
      ],
    );
  }
}

class _QueueScreen extends StatelessWidget {
  const _QueueScreen({
    required this.data,
    required this.jobs,
    required this.onSearch,
    required this.onBack,
    required this.queueFilter,
    required this.onFilterChanged,
    required this.onOpenResult,
    required this.onRetryJob,
    required this.onCancelJob,
  });

  final DriveWorkspaceData data;
  final List<_BaseForceJobState> jobs;
  final VoidCallback onSearch;
  final VoidCallback onBack;
  final String queueFilter;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<_GenerationResult> onOpenResult;
  final ValueChanged<_BaseForceJobState> onRetryJob;
  final ValueChanged<_BaseForceJobState> onCancelJob;

  @override
  Widget build(BuildContext context) {
    final allRows = <Widget>[];
    for (final job in jobs) {
      allRows.add(
        _QueueRow(
          source: _BFSource(
            id: job.source.id,
            name: job.source.title,
            kind: job.source.kind,
            size: job.source.sizeLabel,
            pages: job.source.pageLabel,
            subject: job.source.courseTitle,
            time: 'Az önce',
          ),
          title: job.title,
          kind: job.kind,
          complete: job.status == _JobUiStatus.completed,
          failed: job.status == _JobUiStatus.failed,
          progress: job.progress,
          time:
              job.errorMessage ??
              _baseForceProgressLabel(job.kind, job.status, job.progress),
          filterStatus: _jobStatusLabel(job.status),
          onAction: () {
            if (job.status == _JobUiStatus.completed && job.result != null) {
              onOpenResult(job.result!);
            } else if (job.status == _JobUiStatus.failed) {
              onRetryJob(job);
            } else {
              onCancelJob(job);
            }
          },
        ),
      );
    }
    for (final file in data.recentFiles) {
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
              kind: gen.kind,
              complete: true,
              failed: false,
              progress: 1,
              time: gen.updatedLabel,
              filterStatus: 'Çıktı hazır',
              onAction: () => onOpenResult(
                _GenerationResult(
                  kind: gen.kind,
                  title: gen.title,
                  sourceTitle: file.title,
                  content:
                      'Bu üretim kaydı koleksiyonda görünüyor; ham sonuç içeriği bu ekranda yeniden çekilemiyor.',
                ),
              ),
            ),
          );
        }
      }
    }

    final filteredRows = queueFilter == 'T\xFCm\xFC'
        ? allRows
        : allRows.where((row) {
            return row is _QueueRow && row.filterStatus == queueFilter;
          }).toList();

    final runningCount = jobs
        .where(
          (job) =>
              job.status == _JobUiStatus.pending ||
              job.status == _JobUiStatus.running,
        )
        .length;
    final completedCount = jobs
        .where((job) => job.status == _JobUiStatus.completed)
        .length;
    final failedCount = jobs
        .where((job) => job.status == _JobUiStatus.failed)
        .length;

    return _BaseForcePage(
      title: '\xDcretim Kuyru\u011Fu',
      subtitle: 'Ba\u015Flat\u0131lan \xFCretimleri tek yerden takip et.',
      onSearch: onSearch,
      onBack: onBack,
      heroTight: true,
      children: [
        PremiumHeroCard(
          eyebrow: 'İşlem takibi',
          title: 'Üretim Kuyruğu',
          description:
              'Bekleyen, işlenen, tamamlanan ve hata alan üretimleri tek yerden takip et.',
          tint: AppColors.blue,
          anchorIcon: Icons.schedule_rounded,
          anchorLabel: jobs.isEmpty ? 'Kuyruk boş' : '${jobs.length} aktif iş',
          metrics: [
            MetricPillData(
              label: 'Bekleyen',
              value: '$runningCount',
              tint: AppColors.blue,
              icon: Icons.hourglass_top_rounded,
            ),
            MetricPillData(
              label: 'Tamamlanan',
              value: '$completedCount',
              tint: AppColors.green,
              icon: Icons.check_circle_rounded,
            ),
            MetricPillData(
              label: 'Hatalı',
              value: '$failedCount',
              tint: AppColors.red,
              icon: Icons.error_outline_rounded,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _ResponsiveGrid(
          minItemWidth: 230,
          children: [
            _QueueMetric(
              icon: Icons.play_circle_outline_rounded,
              title: 'Devam Eden',
              value: '$runningCount',
              subtitle: 'Çıktı hazırlanıyor',
              color: AppColors.blue,
            ),
            _QueueMetric(
              icon: Icons.check_circle_rounded,
              title: 'Hazır',
              value: '$completedCount',
              subtitle: 'Çıktı hazır',
              color: AppColors.green,
            ),
            _QueueMetric(
              icon: Icons.error_rounded,
              title: 'Başarısız',
              value: '$failedCount',
              subtitle: 'Tekrar denenebilir',
              color: AppColors.red,
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
              selected: queueFilter == 'T\xFCm\xFC',
              onTap: () => onFilterChanged('T\xFCm\xFC'),
            ),
            _QueueFilter(
              label: 'Çıktı hazırlanıyor',
              dot: AppColors.blue,
              selected: queueFilter == 'Çıktı hazırlanıyor',
              onTap: () => onFilterChanged('Çıktı hazırlanıyor'),
            ),
            _QueueFilter(
              label: 'Çıktı hazır',
              dot: AppColors.green,
              selected: queueFilter == 'Çıktı hazır',
              onTap: () => onFilterChanged('Çıktı hazır'),
            ),
            _QueueFilter(
              label: 'Çıktı oluşturulamadı',
              dot: AppColors.red,
              selected: queueFilter == 'Çıktı oluşturulamadı',
              onTap: () => onFilterChanged('Çıktı oluşturulamadı'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        if (filteredRows.isEmpty)
          _BasePanel(
            child: PremiumEmptyState(
              icon: Icons.pending_actions_rounded,
              title: 'Kuyruk boş',
              message:
                  'Üretim başlatıldığında bekleyen, işleniyor, tamamlandı ve hatalı işler burada görünür.',
              badges: const ['Bekleyen', 'İşleniyor', 'Tamamlandı', 'Hatalı'],
            ),
          )
        else
          ...filteredRows,
      ],
    );
  }
}

class _FlashcardResultsScreen extends StatelessWidget {
  const _FlashcardResultsScreen({
    required this.result,
    required this.saveError,
    required this.onSearch,
    required this.onBack,
    required this.onSave,
    required this.onExport,
    required this.onRegenerate,
  });

  final _GenerationResult? result;
  final String? saveError;
  final VoidCallback onSearch;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final VoidCallback onExport;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final current = result;
    return _BaseForcePage(
      title: current == null ? 'Üretim Sonucu' : current.title,
      subtitle: current == null
          ? 'Üretim tamamlandığında sonuç burada görünür.'
          : '${current.sourceTitle} kaynağından üretilen içeriği incele.',
      art: current?.kind == GeneratedKind.summary
          ? _BaseForceArtKind.notebook
          : _BaseForceArtKind.flashcards,
      onSearch: onSearch,
      onBack: onBack,
      children: [
        if (current != null)
          ResultPreviewCard(
            icon: generatedIcon(current.kind),
            title: _baseForceKindLabel(current.kind),
            source: current.sourceTitle,
            createdAt: current.createdAtLabel ?? 'Bugün',
            preview: _resultPreviewText(current.content),
            statusLabel: 'Hazır',
            primaryActionLabel: 'Koleksiyona kaydet',
            onPrimaryAction: onSave,
            secondaryActionLabel: 'Tekrar üret',
            onSecondaryAction: onRegenerate,
            tint: generatedColor(current.kind),
          ),
        if (current != null) const SizedBox(height: 14),
        _BasePanel(
          padding: const EdgeInsets.all(22),
          child: current == null
              ? const _EmptyBaseForceState(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Sonuç bekleniyor',
                  message:
                      'Bir üretim fabrikasından içerik üretip görüntülemek için Üret butonuna basın.',
                )
              : _GeneratedContentView(result: current),
        ),
        if (saveError != null && current != null) ...[
          const SizedBox(height: 12),
          _BasePanel(
            child: _EmptyBaseForceState(
              icon: Icons.sync_problem_rounded,
              title: 'Sonuç görüntülendi, kayıt bekliyor',
              message:
                  'Üretim tamamlandı ancak üretimler listesine kayıt oluşturulamadı. Kaydet butonuyla tekrar deneyin.\n$saveError',
            ),
          ),
        ],
        const SizedBox(height: 16),
        _SectionHeader(
          title: current == null ? 'Sonraki Adım' : 'Hızlı Aksiyonlar',
        ),
        if (current == null)
          PrimaryGradientButton(
            label: 'Yeniden Üretime Git',
            icon: Icons.auto_awesome_rounded,
            height: 58,
            onTap: onRegenerate,
          )
        else ...[
          _ResponsiveGrid(
            minItemWidth: 165,
            children: [
              _QuickResultAction(
                icon: Icons.folder_special_outlined,
                label: 'Koleksiyona\nKaydet',
                onTap: onSave,
              ),
              _QuickResultAction(
                icon: Icons.content_copy_rounded,
                label: 'Metni\nKopyala',
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
                icon: Icons.tune_rounded,
                label: 'Ayarları\nAç',
                color: AppColors.orange,
                onTap: onRegenerate,
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
      ],
    );
  }
}

class _GeneratedContentView extends StatelessWidget {
  const _GeneratedContentView({required this.result});

  final _GenerationResult result;

  @override
  Widget build(BuildContext context) {
    final content = result.content;
    if (content == null ||
        (content is String && content.trim().isEmpty) ||
        (content is List && content.isEmpty) ||
        (content is Map && content.isEmpty)) {
      return const _EmptyBaseForceState(
        icon: Icons.warning_amber_rounded,
        title: 'Boş içerik döndü',
        message:
            'AI işi tamamlandı ancak görüntülenecek içerik bulunamadı. Yeniden üretmeyi deneyin.',
      );
    }
    if (result.kind == GeneratedKind.algorithm) {
      return _AlgorithmResultView(result: result);
    }
    if (result.kind == GeneratedKind.comparison ||
        result.kind == GeneratedKind.table) {
      return _ComparisonResultView(result: result);
    }
    Widget withMeta(Widget child) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GenericResultMetaGrid(result: result),
          const SizedBox(height: 16),
          child,
        ],
      );
    }

    return withMeta(
      GeneratedOutputReadableContent(
        outputType: _baseForceOutputKind(result.kind),
        title: result.title,
        content: content,
      ),
    );
  }
}

class _FactoryIdentityCard extends StatelessWidget {
  const _FactoryIdentityCard({
    required this.title,
    required this.description,
    required this.tint,
    required this.outputType,
    required this.primaryValue,
    required this.primaryLabel,
    required this.sourceValue,
  });

  final String title;
  final String description;
  final Color tint;
  final String outputType;
  final String primaryValue;
  final String primaryLabel;
  final String sourceValue;

  @override
  Widget build(BuildContext context) {
    return PremiumHeroCard(
      eyebrow: 'Üretim kimliği',
      title: title,
      description: description,
      tint: tint,
      anchorIcon: Icons.auto_awesome_rounded,
      anchorLabel: outputType,
      metrics: [
        MetricPillData(
          label: primaryLabel,
          value: primaryValue,
          tint: tint,
          icon: Icons.tune_rounded,
        ),
        MetricPillData(
          label: 'Çıktı tipi',
          value: outputType,
          tint: AppColors.purple,
          icon: Icons.dataset_outlined,
        ),
        MetricPillData(
          label: 'Seçili kaynak',
          value: sourceValue,
          tint: AppColors.green,
          icon: Icons.source_outlined,
        ),
      ],
    );
  }
}

class _GenericResultMetaGrid extends StatelessWidget {
  const _GenericResultMetaGrid({required this.result});

  final _GenerationResult result;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Kaynak', result.sourceTitle),
      ('Üretim tarihi', result.createdAtLabel ?? 'Bugün'),
      ('Tür', _baseForceKindLabel(result.kind)),
      ('MC', result.mcCostLabel ?? 'MC tutarı güvenli hesaplanır'),
    ];
    return GeneratedOutputMetaCard(items: items);
  }
}

class _ComparisonResultView extends StatelessWidget {
  const _ComparisonResultView({required this.result});

  final _GenerationResult result;

  @override
  Widget build(BuildContext context) {
    final map = _comparisonContentMap(result.content);
    final table = _comparisonTableFromContent(result.content, map);
    final title = _comparisonText(map, const ['title', 'baslik'], result.title);
    final tips = _comparisonList(map, const [
      'distinguishing_tips',
      'distinguishingTips',
      'exam_tips',
      'examTips',
      'tips',
      'ayirt_ettiren_ipuclari',
    ]);
    final clinicalNotes = _comparisonList(map, const [
      'clinical_notes',
      'clinicalNotes',
      'tus_notes',
      'clinical_tus_notes',
      'notes',
    ]);
    final confusions = _comparisonList(map, const [
      'commonly_confused',
      'commonlyConfused',
      'pitfalls',
      'frequent_confusions',
      'sik_karistirilanlar',
    ]);
    final redFlags = _comparisonList(map, const [
      'red_flags',
      'redFlags',
      'warnings',
      'critical_warnings',
    ]);
    final summary = _comparisonText(map, const [
      'summary',
      'short_summary',
      'conclusion',
      'take_home',
    ], '');

    return Column(
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
        const SizedBox(height: 12),
        _ComparisonMetaGrid(result: result),
        const SizedBox(height: 16),
        if (table.headers.isNotEmpty && table.rows.isNotEmpty)
          _ComparisonResultTable(table: table)
        else
          _ComparisonFallbackText(content: result.content),
        _ComparisonSection(
          title: 'Ayırt ettiren ipuçları',
          icon: Icons.track_changes_rounded,
          items: tips,
          color: AppColors.blue,
        ),
        _ComparisonSection(
          title: 'Klinik / TUS notları',
          icon: Icons.school_outlined,
          items: clinicalNotes,
          color: AppColors.purple,
        ),
        _ComparisonSection(
          title: 'Sık karıştırılanlar',
          icon: Icons.compare_arrows_rounded,
          items: confusions,
          color: AppColors.orange,
        ),
        _ComparisonSection(
          title: 'Kırmızı bayraklar',
          icon: Icons.warning_amber_rounded,
          items: redFlags,
          color: AppColors.red,
        ),
        if (summary.isNotEmpty) ...[
          const SizedBox(height: 2),
          _AlgorithmCallout(
            icon: Icons.fact_check_outlined,
            title: 'Kısa sonuç',
            text: summary,
            color: AppColors.green,
          ),
        ],
      ],
    );
  }
}

class _ComparisonMetaGrid extends StatelessWidget {
  const _ComparisonMetaGrid({required this.result});

  final _GenerationResult result;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Kaynak', result.sourceTitle),
      ('Üretim tarihi', result.createdAtLabel ?? 'Bugün'),
      ('Tip', result.comparisonType ?? 'Hastalık Karşılaştırması'),
      ('Format', result.tableFormat ?? 'Ayırt ettiren ipucu tablosu'),
      ('Detay', result.comparisonDetail ?? 'Dengeli'),
      ('Kalite', result.comparisonQuality ?? 'Standart'),
      ('MC', result.mcCostLabel ?? 'MC tutarı güvenli hesaplanır'),
    ];
    return _ResponsiveGrid(
      minItemWidth: 155,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FBFF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.$1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.$2,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ComparisonResultTable extends StatelessWidget {
  const _ComparisonResultTable({required this.table});

  final _ComparisonTableData table;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 620;
        if (isCompact) return _ComparisonCardTable(table: table);
        final width = math.max(
          constraints.maxWidth,
          table.headers.length * 190,
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width.toDouble(),
                child: Table(
                  border: TableBorder.all(color: AppColors.line),
                  columnWidths: {
                    for (var i = 0; i < table.headers.length; i++)
                      i: FlexColumnWidth(i == 0 ? 1.05 : 1.35),
                  },
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(color: Color(0xFFF5FAFF)),
                      children: [
                        for (final header in table.headers)
                          _TableCell(text: header, bold: true),
                      ],
                    ),
                    for (final row in table.rows)
                      TableRow(
                        children: [
                          for (var i = 0; i < table.headers.length; i++)
                            _TableCell(
                              text: i < row.length ? row[i] : '',
                              bold: i == 0,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ComparisonCardTable extends StatelessWidget {
  const _ComparisonCardTable({required this.table});

  final _ComparisonTableData table;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in table.rows)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FBFF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.isNotEmpty ? row.first : 'Karşılaştırma satırı',
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                for (var i = 1; i < table.headers.length; i++) ...[
                  Text(
                    table.headers[i],
                    style: const TextStyle(
                      color: AppColors.blue,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    i < row.length ? row[i] : '',
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 13.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (i != table.headers.length - 1)
                    const Divider(height: 16, color: AppColors.softLine),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _ComparisonSection extends StatelessWidget {
  const _ComparisonSection({
    required this.title,
    required this.icon,
    required this.items,
    required this.color,
  });

  final String title;
  final IconData icon;
  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: CircleAvatar(radius: 3, backgroundColor: color),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 14,
                        height: 1.36,
                        fontWeight: FontWeight.w600,
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

class _ComparisonFallbackText extends StatelessWidget {
  const _ComparisonFallbackText({required this.content});

  final Object? content;

  @override
  Widget build(BuildContext context) {
    final text = _plainTextValue(content);
    return _AlgorithmCallout(
      icon: Icons.table_rows_outlined,
      title: 'Karşılaştırma özeti',
      text: text,
      color: AppColors.blue,
    );
  }
}

class _ComparisonTableData {
  const _ComparisonTableData({required this.headers, required this.rows});

  final List<String> headers;
  final List<List<String>> rows;
}

Map<dynamic, dynamic> _comparisonContentMap(Object? content) {
  if (content is Map) return content;
  if (content is String) {
    final text = content.trim();
    if (text.startsWith('{')) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map) return decoded;
      } catch (_) {
        return const {};
      }
    }
  }
  return const {};
}

String _comparisonText(
  Map<dynamic, dynamic> map,
  List<String> keys,
  String fallback,
) {
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return fallback;
}

List<String> _comparisonList(Map<dynamic, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is List && value.isNotEmpty) {
      return value.map(_comparisonCellText).where((v) => v.isNotEmpty).toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      return value
          .split(RegExp(r'\n+'))
          .map((line) => line.replaceFirst(RegExp(r'^[-*]\s*'), '').trim())
          .where((line) => line.isNotEmpty)
          .toList();
    }
  }
  return const [];
}

_ComparisonTableData _comparisonTableFromContent(
  Object? content,
  Map<dynamic, dynamic> map,
) {
  final markdown = content is String
      ? _comparisonTableFromMarkdown(content)
      : null;
  if (markdown != null) return markdown;

  final tableValue = map['table'] ?? map['comparison_table'] ?? map['matrix'];
  if (tableValue is String) {
    final parsed = _comparisonTableFromMarkdown(tableValue);
    if (parsed != null) return parsed;
  }
  final tableMap = tableValue is Map ? tableValue : map;
  final headers = _comparisonHeaders(tableMap);
  final rowsValue = tableMap['rows'] ?? tableMap['items'] ?? tableMap['data'];
  final rows = <List<String>>[];
  if (rowsValue is List) {
    for (final row in rowsValue) {
      rows.add(_comparisonRow(row, headers));
    }
  }
  final cleanRows = rows
      .where((row) => row.any((cell) => cell.trim().isNotEmpty))
      .toList();
  return _ComparisonTableData(headers: headers, rows: cleanRows);
}

List<String> _comparisonHeaders(Map<dynamic, dynamic> map) {
  final raw = map['headers'] ?? map['columns'];
  if (raw is List && raw.isNotEmpty) {
    return raw.map(_comparisonCellText).where((v) => v.isNotEmpty).toList();
  }
  return const ['Özellik', 'Kavram A', 'Kavram B', 'Ayırt ettiren ipucu'];
}

List<String> _comparisonRow(Object? row, List<String> headers) {
  if (row is List) {
    return row.map(_comparisonCellText).toList();
  }
  if (row is Map) {
    final label = _comparisonCellText(
      row['label'] ?? row['criterion'] ?? row['feature'] ?? row['ozellik'],
    );
    final values = row['values'] ?? row['cells'];
    if (values is List) {
      return [label, ...values.map(_comparisonCellText)];
    }
    return [
      for (final header in headers)
        _comparisonCellText(row[header] ?? row[header.toLowerCase()]),
    ];
  }
  return [_comparisonCellText(row)];
}

String _comparisonCellText(Object? value) {
  if (value == null) return '';
  if (value is String) return value.trim();
  if (value is List) {
    return value.map(_comparisonCellText).where((v) => v.isNotEmpty).join(', ');
  }
  if (value is Map) {
    return value.entries
        .map((entry) {
          final key = entry.key.toString();
          final text = _comparisonCellText(entry.value);
          return text.isEmpty ? '' : '$key: $text';
        })
        .where((v) => v.isNotEmpty)
        .join('\n');
  }
  return value.toString().trim();
}

_ComparisonTableData? _comparisonTableFromMarkdown(String value) {
  final lines = value
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.startsWith('|') && line.endsWith('|'))
      .toList();
  if (lines.length < 2) return null;
  final parsed = lines
      .map((line) => line.substring(1, line.length - 1).split('|'))
      .map((cells) => cells.map((cell) => cell.trim()).toList())
      .toList();
  final headers = parsed.first;
  final body = parsed.skip(1).where((row) {
    return !row.every((cell) => RegExp(r'^:?-{3,}:?$').hasMatch(cell));
  }).toList();
  if (headers.isEmpty || body.isEmpty) return null;
  return _ComparisonTableData(headers: headers, rows: body);
}

class _AlgorithmResultView extends StatelessWidget {
  const _AlgorithmResultView({required this.result});

  final _GenerationResult result;

  @override
  Widget build(BuildContext context) {
    final normalized = _algorithmContentMap(result.content);
    final title = _algorithmText(normalized, const ['title'], result.title);
    final startingPoint = _algorithmText(normalized, const [
      'starting_point',
      'startingPoint',
      'start',
      'chief_complaint',
    ], '');
    final steps = _algorithmList(normalized, const [
      'decision_nodes',
      'decisionNodes',
      'steps',
      'nodes',
      'algorithm_flow',
      'flow',
    ]);
    final branches = _algorithmList(normalized, const [
      'branches',
      'yes_no_branches',
      'edges',
      'branching',
    ]);
    final thresholds = _algorithmList(normalized, const [
      'critical_thresholds',
      'criticalThresholds',
      'thresholds',
    ]);
    final redFlags = _algorithmList(normalized, const [
      'red_flags',
      'redFlags',
      'warnings',
    ]);
    final actions = _algorithmList(normalized, const [
      'action_steps',
      'actionSteps',
      'management',
      'outcomes',
    ]);
    final examTips = _algorithmList(normalized, const [
      'exam_tips',
      'examTips',
      'clinical_tus_tips',
      'tips',
    ]);
    final notes = _algorithmList(normalized, const ['notes']);
    final visibleSteps = steps.isNotEmpty
        ? steps
        : _algorithmFallbackSteps(result.content);

    return Column(
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
        const SizedBox(height: 12),
        _AlgorithmMetaGrid(result: result),
        if (startingPoint.isNotEmpty) ...[
          const SizedBox(height: 14),
          _AlgorithmCallout(
            icon: Icons.play_arrow_rounded,
            title: 'Başlangıç noktası',
            text: startingPoint,
            color: AppColors.blue,
          ),
        ],
        const SizedBox(height: 16),
        _AlgorithmSection(
          title: 'Karar düğümleri',
          icon: Icons.account_tree_outlined,
          items: visibleSteps,
          decisionStyle: true,
        ),
        if (branches.isNotEmpty)
          _AlgorithmSection(
            title: 'Evet/Hayır dalları',
            icon: Icons.call_split_rounded,
            items: branches,
            branchStyle: true,
          ),
        if (thresholds.isNotEmpty)
          _AlgorithmSection(
            title: 'Kritik eşikler',
            icon: Icons.speed_rounded,
            items: thresholds,
            color: AppColors.orange,
          ),
        if (redFlags.isNotEmpty)
          _AlgorithmSection(
            title: 'Kırmızı bayraklar',
            icon: Icons.warning_amber_rounded,
            items: redFlags,
            color: AppColors.red,
          ),
        if (actions.isNotEmpty)
          _AlgorithmSection(
            title: 'Sonuç / eylem adımları',
            icon: Icons.checklist_rounded,
            items: actions,
            color: AppColors.green,
          ),
        if (examTips.isNotEmpty)
          _AlgorithmSection(
            title: 'Sınavda yakala',
            icon: Icons.school_outlined,
            items: examTips,
            color: AppColors.purple,
          ),
        if (notes.isNotEmpty)
          _AlgorithmSection(
            title: 'Klinik notlar',
            icon: Icons.edit_note_rounded,
            items: notes,
          ),
      ],
    );
  }
}

class _AlgorithmMetaGrid extends StatelessWidget {
  const _AlgorithmMetaGrid({required this.result});

  final _GenerationResult result;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Kaynak', result.sourceTitle),
      ('Üretim tarihi', result.createdAtLabel ?? 'Bugün'),
      ('Tip', result.algorithmType ?? 'Algoritma'),
      ('Format', result.outputFormat ?? 'Akış şeması'),
      ('Detay', result.detailLevel ?? 'Dengeli'),
      ('Kalite', result.qualityTier ?? 'Standart'),
      ('MC', result.mcCostLabel ?? 'MC tutarı güvenli hesaplanır'),
    ];
    return _ResponsiveGrid(
      minItemWidth: 155,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FBFF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.$1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.$2,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 13.5,
                    height: 1.18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AlgorithmSection extends StatelessWidget {
  const _AlgorithmSection({
    required this.title,
    required this.icon,
    required this.items,
    this.color = AppColors.blue,
    this.decisionStyle = false,
    this.branchStyle = false,
  });

  final String title;
  final IconData icon;
  final List<Object?> items;
  final Color color;
  final bool decisionStyle;
  final bool branchStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withValues(alpha: .12),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: _titleStyle)),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < items.length; i++)
            _AlgorithmNodeCard(
              index: i + 1,
              value: items[i],
              color: color,
              decisionStyle: decisionStyle,
              branchStyle: branchStyle,
              showConnector: i != items.length - 1,
            ),
        ],
      ),
    );
  }
}

class _AlgorithmNodeCard extends StatelessWidget {
  const _AlgorithmNodeCard({
    required this.index,
    required this.value,
    required this.color,
    required this.showConnector,
    this.decisionStyle = false,
    this.branchStyle = false,
  });

  final int index;
  final Object? value;
  final Color color;
  final bool showConnector;
  final bool decisionStyle;
  final bool branchStyle;

  @override
  Widget build(BuildContext context) {
    final parsed = _algorithmItemParts(value);
    final nodeIcon = branchStyle
        ? Icons.call_split_rounded
        : decisionStyle
        ? Icons.device_hub_rounded
        : Icons.arrow_forward_rounded;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: color,
              child: Text(
                '$index',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (showConnector)
              Container(
                width: 2,
                height: 32,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: color.withValues(alpha: .28),
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            margin: EdgeInsets.only(bottom: showConnector ? 6 : 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: .18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(nodeIcon, color: color, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        parsed.title,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 15.5,
                          height: 1.25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                if (parsed.body.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    parsed.body,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 14.5,
                      height: 1.42,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (parsed.children.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  for (final child in parsed.children)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.subdirectory_arrow_right_rounded,
                            color: color,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              child,
                              style: const TextStyle(
                                color: AppColors.navy,
                                fontSize: 13.5,
                                height: 1.32,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AlgorithmCallout extends StatelessWidget {
  const _AlgorithmCallout({
    required this.icon,
    required this.title,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  text,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 14.5,
                    height: 1.38,
                    fontWeight: FontWeight.w600,
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

class _AlgorithmItemParts {
  const _AlgorithmItemParts({
    required this.title,
    required this.body,
    required this.children,
  });

  final String title;
  final String body;
  final List<String> children;
}

Map<dynamic, dynamic> _algorithmContentMap(Object? content) {
  if (content is Map) return content;
  if (content is String) {
    final text = content.trim();
    if (text.startsWith('{')) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map) return decoded;
      } catch (_) {
        return const {};
      }
    }
  }
  return const {};
}

String _algorithmText(
  Map<dynamic, dynamic> map,
  List<String> keys,
  String fallback,
) {
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return fallback;
}

List<Object?> _algorithmList(Map<dynamic, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is List && value.isNotEmpty) return value.cast<Object?>();
    if (value is String && value.trim().isNotEmpty) return [value.trim()];
  }
  return const [];
}

List<Object?> _algorithmFallbackSteps(Object? content) {
  if (content is List) return content.cast<Object?>();
  if (content is String && content.trim().isNotEmpty) return [content.trim()];
  return const ['Karar akışı üretildi ancak yapılandırılmış düğüm bulunamadı.'];
}

_AlgorithmItemParts _algorithmItemParts(Object? value) {
  if (value is Map) {
    final title = _firstNonEmpty(value, const [
      'title',
      'label',
      'question',
      'decision',
      'step',
      'name',
    ]);
    final body = _firstNonEmpty(value, const [
      'description',
      'body',
      'rationale',
      'action',
      'answer',
      'next',
    ]);
    final children = <String>[];
    for (final key in const ['substeps', 'children', 'yes', 'no', 'options']) {
      final item = value[key];
      if (item is List) {
        children.addAll(item.map(_algorithmInlineText).where((e) => e != '-'));
      } else if (item != null) {
        final text = _algorithmInlineText(item);
        if (text != '-') children.add('${key.toUpperCase()}: $text');
      }
    }
    return _AlgorithmItemParts(
      title: title.isEmpty ? _algorithmInlineText(value) : title,
      body: body,
      children: children,
    );
  }
  final text = _algorithmInlineText(value);
  return _AlgorithmItemParts(title: text, body: '', children: const []);
}

String _firstNonEmpty(Map<dynamic, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is num) return value.toString();
  }
  return '';
}

String _algorithmInlineText(Object? value) {
  if (value == null) return '-';
  if (value is String) {
    final text = value.trim();
    return text.isEmpty ? '-' : text;
  }
  if (value is num || value is bool) return value.toString();
  if (value is List) {
    return value.map(_algorithmInlineText).where((e) => e != '-').join(' | ');
  }
  if (value is Map) {
    final pieces = <String>[];
    for (final entry in value.entries) {
      final key = entry.key.toString();
      if (key == 'stepNumber') continue;
      final text = _algorithmInlineText(entry.value);
      if (text != '-') pieces.add(text);
    }
    return pieces.isEmpty ? '-' : pieces.join(' - ');
  }
  final text = value.toString().trim();
  return text.isEmpty ? '-' : text;
}

class _AllGenerationsScreen extends StatelessWidget {
  const _AllGenerationsScreen({
    required this.data,
    required this.jobs,
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
  final List<_BaseForceJobState> jobs;
  final String selectedFilter;
  final VoidCallback onSearch;
  final VoidCallback onBack;
  final ValueChanged<String> onFilter;
  final ValueChanged<_GenerationRowData> onOpenResult;
  final ValueChanged<_GenerationRowData> onRegenerate;
  final ValueChanged<_GenerationRowData> onShare;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final allGenerations =
        data.recentFiles
            .expand(
              (file) => file.generated.map(
                (gen) => _GenerationRowData(
                  title: gen.title,
                  source: file.title,
                  kind: _baseForceKindLabel(gen.kind),
                  count: gen.detail,
                  time: gen.updatedLabel,
                ),
              ),
            )
            .toList()
          ..insertAll(
            0,
            jobs
                .where((job) => job.status == _JobUiStatus.completed)
                .map(
                  (job) => _GenerationRowData(
                    title: job.title,
                    source: job.source.title,
                    kind: _baseForceKindLabel(job.kind),
                    count: '${_baseForceContentCount(job.result?.content)} öğe',
                    time: 'Bugün',
                  ),
                ),
          );

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
            onPressed: () => _showBaseForceToast(
              context,
              'Sıralama şu anda en yeni üretimlere göre uygulanıyor.',
            ),
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
        if (visible.isEmpty)
          const _BasePanel(
            child: _EmptyBaseForceState(
              icon: Icons.collections_bookmark_outlined,
              title: 'Henüz üretim yok',
              message:
                  'Bir kaynak seçip üretim başlattığınızda sonuçlar burada listelenir.',
            ),
          )
        else
          for (final row in visible)
            _GenerationListRow(
              data: row,
              onOpen: () => onOpenResult(row),
              onShare: () => onShare(row),
              onRegenerate: () => onRegenerate(row),
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

class _EmptyBaseForceState extends StatelessWidget {
  const _EmptyBaseForceState({
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
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.selectedBlue,
            child: Icon(icon, color: AppColors.blue, size: 30),
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
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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
  const _TwoPane({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    const breakpoint = 760.0;
    const spacing = 12.0;
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
    final compact = MediaQuery.sizeOf(context).width < 420;
    return SizedBox(
      height: compact ? 48 : 58,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: compact ? 22 : 27),
        label: Text(label, maxLines: 1),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: cyan ? AppColors.cyan : AppColors.blue,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: TextStyle(
            fontSize: compact ? 16 : 20,
            fontWeight: FontWeight.w800,
          ),
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
    final compact = MediaQuery.sizeOf(context).width < 420;
    return _BasePanel(
      padding: EdgeInsets.fromLTRB(12, compact ? 14 : 20, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RoundGeneratedIcon(kind: kind, size: compact ? 54 : 64),
          SizedBox(height: compact ? 10 : 16),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.navy,
              fontSize: compact ? 15.5 : 17,
              height: 1.14,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: compact ? 8 : 12),
          SizedBox(
            height: compact ? 42 : 48,
            child: Text(
              subtitle,
              maxLines: compact ? 2 : 3,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: compact ? 12 : 12.5,
                height: 1.25,
              ),
            ),
          ),
          SizedBox(height: compact ? 10 : 14),
          SizedBox(
            width: double.infinity,
            height: compact ? 40 : 42,
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FileKindBadge(kind: source.kind, plain: true),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            source.name,
                            maxLines: compact ? 2 : 1,
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
                    if (!compact) ...[
                      const SizedBox(width: 10),
                      _SuitabilityPill(
                        label: source.suitabilityLabel,
                        status: source.status,
                        warning: !source.enabled,
                      ),
                      const _MoreMenuButton(),
                    ],
                  ],
                ),
                if (compact) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _SuitabilityPill(
                        label: source.suitabilityLabel,
                        status: source.status,
                        warning: !source.enabled,
                      ),
                      const Spacer(),
                      const _MoreMenuButton(),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
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
    final enabled = source.enabled;
    final status = _premiumStatusForDrive(source.status, enabled: enabled);
    final statusLabel = selected && enabled
        ? 'Seçili'
        : source.suitabilityLabel;
    return Opacity(
      opacity: enabled ? 1 : .68,
      child: SourceBaseCard(
        radius: 18,
        padding: const EdgeInsets.all(16),
        onTap: enabled ? onTap : null,
        borderColor: selected
            ? AppColors.blue.withValues(alpha: .34)
            : AppColors.line.withValues(alpha: .9),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 520;
            final action = Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.selectedBlue
                    : enabled
                    ? AppColors.blue.withValues(alpha: .08)
                    : const Color(0xFFF4F6F8),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? AppColors.blue.withValues(alpha: .24)
                      : enabled
                      ? AppColors.blue.withValues(alpha: .18)
                      : AppColors.line,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : enabled
                        ? Icons.add_circle_outline_rounded
                        : Icons.lock_outline_rounded,
                    size: 16,
                    color: selected || enabled
                        ? AppColors.blue
                        : AppColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    selected
                        ? 'Seçili'
                        : enabled
                        ? 'Kaynak seç'
                        : 'Hazır değil',
                    style: TextStyle(
                      color: selected || enabled
                          ? AppColors.blue
                          : AppColors.muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CheckSquare(
                      selected: selected && enabled,
                      enabled: enabled,
                    ),
                    const SizedBox(width: 12),
                    FileKindBadge(kind: source.kind, plain: true),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            source.name,
                            maxLines: compact ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              StatusBadge(
                                label: statusLabel,
                                status: status,
                                compact: true,
                              ),
                              _BaseMiniTag(
                                label: FileKindBadge.kindLabel(source.kind),
                                tint: FileKindBadge.kindColor(source.kind),
                              ),
                              if (source.subject.trim().isNotEmpty)
                                _BaseMiniTag(
                                  label: source.subject,
                                  tint: AppColors.purple,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!compact) ...[const SizedBox(width: 12), action],
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoPill(
                      icon: Icons.description_outlined,
                      label: source.pages,
                    ),
                    _InfoPill(
                      icon: Icons.data_object_rounded,
                      label: source.size,
                    ),
                    _InfoPill(icon: Icons.schedule_rounded, label: source.time),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  source.blockedReason ??
                      'Hazır kaynak. Bu dosyadan üretim başlatabilirsiniz.',
                  maxLines: compact ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: source.blockedReason == null
                        ? AppColors.muted
                        : AppColors.red,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (compact) ...[
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerLeft, child: action),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CheckSquare extends StatelessWidget {
  const _CheckSquare({required this.selected, this.enabled = true});

  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? AppColors.blue
        : enabled
        ? const Color(0xFFB8C5D8)
        : AppColors.line;
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: selected ? AppColors.blue : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
          : null,
    );
  }
}

class _SuitabilityPill extends StatelessWidget {
  const _SuitabilityPill({
    this.label,
    this.status = DriveItemStatus.completed,
    this.warning = false,
  });

  final String? label;
  final DriveItemStatus status;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final effectiveLabel = label ?? (warning ? 'Büyük Boyut' : 'Uygun');
    final color = warning
        ? status == DriveItemStatus.failed
              ? AppColors.red
              : const Color(0xFFE69A00)
        : AppColors.green;
    final bg = warning
        ? status == DriveItemStatus.failed
              ? AppColors.redBg
              : const Color(0xFFFFF2D8)
        : AppColors.greenBg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            warning ? Icons.error_rounded : Icons.check_circle_rounded,
            color: color,
            size: 17,
          ),
          const SizedBox(width: 6),
          Text(
            effectiveLabel,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
        .where(
          (file) =>
              selectedSources.contains(file.id) &&
              _isBaseForceReadySource(file),
        )
        .map((file) => _bfSourceFromFile(file))
        .toList();
    return SourceBaseCard(
      radius: 20,
      padding: const EdgeInsets.all(18),
      borderColor: AppColors.blue.withValues(alpha: .16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.selectedBlue,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.library_books_rounded,
                  color: AppColors.blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Seçili kaynaklar',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$selected.length hazır kaynak üretim için seçildi.',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              MetricPill(
                label: 'Seçili kaynak',
                value: '${selected.length}',
                icon: Icons.check_circle_outline_rounded,
              ),
              const MetricPill(
                label: 'Format',
                value: 'PDF/PPTX/DOCX',
                tint: AppColors.purple,
                icon: Icons.auto_awesome_mosaic_rounded,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final source in selected)
                _SelectedSourceChip(
                  source: source,
                  onRemove: () => onRemove(source.id),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: SBPrimaryButton(
              label: 'Bu kaynaklarla devam et',
              icon: Icons.arrow_forward_rounded,
              onPressed: selected.isEmpty ? null : onContinue,
              size: SBButtonSize.medium,
              fullWidth: true,
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Container(
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
            Expanded(
              child: Text(
                source.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w700,
                ),
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
      ),
    );
  }
}

class _SourcesPanel extends StatelessWidget {
  const _SourcesPanel({
    required this.data,
    required this.selectedSources,
    required this.onPickSources,
  });

  final DriveWorkspaceData data;
  final Set<String> selectedSources;
  final VoidCallback onPickSources;

  @override
  Widget build(BuildContext context) {
    final files = data.recentFiles
        .where(
          (file) =>
              selectedSources.contains(file.id) &&
              _isBaseForceReadySource(file),
        )
        .toList();
    return SourceBaseCard(
      radius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle(
            icon: Icons.description_outlined,
            title: 'Kaynaklarınız',
          ),
          const SizedBox(height: 18),
          if (files.isEmpty)
            _SourceRequiredNotice(onPickSources: onPickSources)
          else
            for (final file in files)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SelectedSourceSummaryCard(
                  source: _bfSourceFromFile(file),
                ),
              ),
          SourceBaseCard(
            radius: 16,
            padding: const EdgeInsets.all(16),
            onTap: onPickSources,
            borderColor: AppColors.blue.withValues(alpha: .22),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.selectedBlue,
                  child: Icon(
                    Icons.add_rounded,
                    color: AppColors.blue,
                    size: 28,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hazır kaynak ekle',
                        style: TextStyle(
                          color: AppColors.blue,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'PDF, PPTX veya DOCX kaynaklarından seçim yap.',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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

class _SelectedSourceChips extends StatelessWidget {
  const _SelectedSourceChips({
    required this.data,
    required this.selectedSources,
    required this.onPickSources,
    this.includeThird = false,
  });

  final DriveWorkspaceData data;
  final Set<String> selectedSources;
  final VoidCallback onPickSources;
  final bool includeThird;

  @override
  Widget build(BuildContext context) {
    final sources = data.recentFiles
        .where(
          (file) =>
              selectedSources.contains(file.id) &&
              _isBaseForceReadySource(file),
        )
        .take(includeThird ? 3 : 2)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Seçili Kaynaklar', style: _titleStyle),
        const SizedBox(height: 8),
        const Text(
          'Hazır olan kaynakları burada görür, gerektiğinde değiştirebilirsin.',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        if (sources.isEmpty)
          _SourceRequiredNotice(onPickSources: onPickSources)
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final file in sources)
                _SourceChipCard(
                  source: _bfSourceFromFile(file),
                  onTap: onPickSources,
                ),
              _DashedAddButton(onTap: onPickSources),
            ],
          ),
      ],
    );
  }
}

class _SourceRequiredNotice extends StatelessWidget {
  const _SourceRequiredNotice({required this.onPickSources});

  final VoidCallback onPickSources;

  @override
  Widget build(BuildContext context) {
    return SourceBaseCard(
      radius: 18,
      padding: const EdgeInsets.all(18),
      borderColor: AppColors.blue.withValues(alpha: .2),
      onTap: onPickSources,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.selectedBlue,
                child: Icon(Icons.source_outlined, color: AppColors.blue),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Önce bir kaynak seç',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Hazır PDF, PPTX veya DOCX kaynakları seçerek üretime başlayabilirsin.',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _BaseMiniTag(label: 'Hazır kaynak', tint: AppColors.blue),
              _BaseMiniTag(label: 'PDF / PPTX / DOCX', tint: AppColors.purple),
            ],
          ),
          const SizedBox(height: 14),
          SBSecondaryButton(
            label: 'Kaynak seç',
            icon: Icons.folder_open_rounded,
            onPressed: onPickSources,
            size: SBButtonSize.small,
            fullWidth: false,
          ),
        ],
      ),
    );
  }
}

class _LabLikeNotice extends StatelessWidget {
  const _LabLikeNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.orange.withValues(alpha: .18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.orange,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 13.5,
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
                  '${source.size} • ${source.suitabilityLabel}',
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
      onTap:
          onTap ??
          () => _showBaseForceToast(
            context,
            'Bu seçenek bu sürümde pasif. Üretim, ekranda seçili ayarlarla başlatılır.',
          ),
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
    final next = math.min(100, math.max(1, value + delta));
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
  const _ToggleLine({
    required this.label,
    this.initialValue = true,
    this.onChanged,
  });

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

class _ProductionSummary extends StatelessWidget {
  const _ProductionSummary({required this.items});

  final List<_SummaryItemData> items;

  @override
  Widget build(BuildContext context) {
    return SourceBaseCard(
      radius: 20,
      padding: const EdgeInsets.all(18),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final item in items)
            MetricPill(
              label: item.label,
              value: item.value,
              tint: item.color,
              icon: item.icon,
            ),
        ],
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

class _SummaryOptionPanel extends StatelessWidget {
  const _SummaryOptionPanel({
    required this.selectedLength,
    required this.onLengthChanged,
  });

  final String selectedLength;
  final ValueChanged<String> onLengthChanged;

  @override
  Widget build(BuildContext context) {
    return _BasePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle(
            icon: Icons.description_outlined,
            title: '\xD6zet Uzunlu\u011Fu',
          ),
          const SizedBox(height: 16),
          _RadioOption(
            title: '1 sayfa',
            subtitle: 'Kompakt ve odakl\u0131',
            selected: selectedLength == '1 sayfa',
            onTap: (selected) => onLengthChanged('1 sayfa'),
          ),
          _RadioOption(
            title: '3 sayfa',
            subtitle: 'Daha detayl\u0131 \xF6zet',
            selected: selectedLength == '3 sayfa',
            onTap: (selected) => onLengthChanged('3 sayfa'),
          ),
          _RadioOption(
            title: 'Ultra k\u0131sa',
            subtitle: 'En k\u0131sa format',
            selected: selectedLength == 'Ultra k\u0131sa',
            onTap: (selected) => onLengthChanged('Ultra k\u0131sa'),
          ),
        ],
      ),
    );
  }
}

class _FocusOptionPanel extends StatelessWidget {
  const _FocusOptionPanel({
    required this.selectedFocus,
    required this.onFocusChanged,
  });

  final String selectedFocus;
  final ValueChanged<String> onFocusChanged;

  @override
  Widget build(BuildContext context) {
    return _BasePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle(
            icon: Icons.track_changes_rounded,
            title: 'Odak Modu',
          ),
          const SizedBox(height: 16),
          _RadioOption(
            title: 'Y\xFCksek Olas\u0131l\u0131kl\u0131 Sorular',
            subtitle: '\xC7\u0131kma ihtimali y\xFCksek konular',
            selected:
                selectedFocus == 'Y\xFCksek Olas\u0131l\u0131kl\u0131 Sorular',
            onTap: (selected) =>
                onFocusChanged('Y\xFCksek Olas\u0131l\u0131kl\u0131 Sorular'),
          ),
          _RadioOption(
            title: 'Kritik Noktalar',
            subtitle: 'En \xF6nemli kavramlar',
            selected: selectedFocus == 'Kritik Noktalar',
            onTap: (selected) => onFocusChanged('Kritik Noktalar'),
          ),
          _RadioOption(
            title: 'Hoca Vurgular\u0131',
            subtitle: '\xD6\u011Fretmenin vurgulad\u0131klar\u0131',
            selected: selectedFocus == 'Hoca Vurgular\u0131',
            onTap: (selected) => onFocusChanged('Hoca Vurgular\u0131'),
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
          const _PanelTitle(
            icon: Icons.edit_outlined,
            title: 'Vurgu Se\xE7enekleri',
          ),
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

class _RadioOption extends StatefulWidget {
  const _RadioOption({
    required this.title,
    required this.subtitle,
    this.selected = false,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final ValueChanged<bool>? onTap;

  @override
  State<_RadioOption> createState() => _RadioOptionState();
}

class _RadioOptionState extends State<_RadioOption> {
  late bool selected;

  @override
  void initState() {
    super.initState();
    selected = widget.selected;
  }

  @override
  void didUpdateWidget(covariant _RadioOption oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      selected = widget.selected;
    }
  }

  void _toggle() {
    widget.onTap?.call(selected);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _toggle,
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
                    widget.title,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
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

class _BaseNotice extends StatelessWidget {
  const _BaseNotice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.selectedBlue.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.blue.withValues(alpha: .18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.blue, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 13.5,
                height: 1.32,
                fontWeight: FontWeight.w700,
              ),
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
            onPressed: () => _showBaseForceToast(
              context,
              'Kaynağı değiştirmek için kaynak seçimi ekranını açın.',
            ),
            icon: const Icon(Icons.close_rounded, color: AppColors.navy),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _TableSettingsPanel extends StatelessWidget {
  const _TableSettingsPanel({
    required this.tableFormat,
    required this.detailLevel,
    required this.qualityTier,
    required this.onTableFormatChanged,
    required this.onDetailLevelChanged,
    required this.onQualityTierChanged,
  });

  final String tableFormat;
  final String detailLevel;
  final String qualityTier;
  final ValueChanged<String> onTableFormatChanged;
  final ValueChanged<String> onDetailLevelChanged;
  final ValueChanged<String> onQualityTierChanged;

  @override
  Widget build(BuildContext context) {
    return _BasePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle(icon: Icons.tune_rounded, title: 'Tablo Formatı'),
          const SizedBox(height: 12),
          _ComparisonChoiceGrid(
            values: const [
              'Klasik tablo',
              'Sütun bazlı ayrım',
              '“Ayırt ettiren ipucu” tablosu',
              'Tanı / Tetkik / Tedavi matrisi',
              'Artı-eksi karşılaştırması',
              'Mini özet + tablo',
            ],
            selected: tableFormat,
            onSelected: onTableFormatChanged,
          ),
          const SizedBox(height: 18),
          const _PanelTitle(
            icon: Icons.density_medium_rounded,
            title: 'Kapsam ve Kalite',
          ),
          const SizedBox(height: 12),
          _ResponsiveGrid(
            minItemWidth: 210,
            children: [
              _ChoicePanel(
                label: 'Kapsam / Yoğunluk',
                values: const [
                  'Kısa',
                  'Dengeli',
                  'Detaylı',
                  'Klinik odaklı',
                  'Sınav odaklı',
                ],
                selected: detailLevel,
                onSelected: onDetailLevelChanged,
              ),
              _ChoicePanel(
                label: 'Kalite',
                values: const ['Ekonomik', 'Standart', 'Premium'],
                selected: qualityTier,
                onSelected: onQualityTierChanged,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: AppColors.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Tablo klinik bulgu, tanı/tetkik, tedavi, mekanizma, TUS ipucu ve kırmızı bayrak ayrımlarını önceliklendirir.',
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

class _ChoicePanel extends StatelessWidget {
  const _ChoicePanel({
    required this.label,
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in values)
                _SmallChoiceChip(
                  label: value,
                  selected: selected == value,
                  onTap: () => onSelected(value),
                ),
            ],
          ),
          if (label == 'Kalite' && selected == 'Premium') ...[
            const SizedBox(height: 10),
            const Text(
              'Premium daha yüksek MC tüketebilir.',
              style: TextStyle(
                color: AppColors.orange,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SmallChoiceChip extends StatelessWidget {
  const _SmallChoiceChip({
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
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.selectedBlue : const Color(0xFFF8FBFF),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: selected ? AppColors.blue : AppColors.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.blue : AppColors.navy,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ComparisonChoiceGrid extends StatelessWidget {
  const _ComparisonChoiceGrid({
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return _ResponsiveGrid(
      minItemWidth: 205,
      children: [
        for (final value in values)
          _ComparisonChoiceCard(
            label: value,
            selected: selected == value,
            onTap: () => onSelected(value),
          ),
      ],
    );
  }
}

class _ComparisonChoiceCard extends StatelessWidget {
  const _ComparisonChoiceCard({
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
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.selectedBlue : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.blue : AppColors.line,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppColors.blue : AppColors.muted,
              size: 20,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.blue : AppColors.navy,
                  fontSize: 14,
                  height: 1.2,
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
    required this.kind,
    required this.time,
    required this.onAction,
    this.progress,
    this.complete = false,
    this.failed = false,
    this.filterStatus = '',
  });

  final _BFSource source;
  final String title;
  final GeneratedKind kind;
  final String time;
  final VoidCallback onAction;
  final double? progress;
  final bool complete;
  final bool failed;
  final String filterStatus;

  @override
  Widget build(BuildContext context) {
    final queueStatus = _queueStatus;
    final statusTone = _premiumStatusForJob(queueStatus);
    final actionIcon = complete
        ? Icons.visibility_rounded
        : failed
        ? Icons.refresh_rounded
        : Icons.schedule_rounded;
    final actionLabel = complete
        ? 'Detayı aç'
        : failed
        ? 'Tekrar dene'
        : 'Durumu aç';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SourceBaseCard(
        radius: 20,
        padding: const EdgeInsets.all(18),
        borderColor: failed
            ? AppColors.red.withValues(alpha: .16)
            : AppColors.line.withValues(alpha: .9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RoundGeneratedIcon(kind: kind, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        source.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                StatusBadge(
                  label: _queueStatusLabel,
                  status: statusTone,
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _BaseMiniTag(
                  label: _baseForceKindLabel(kind),
                  tint: generatedColor(kind),
                ),
                _BaseMiniTag(
                  label: FileKindBadge.kindLabel(source.kind),
                  tint: FileKindBadge.kindColor(source.kind),
                ),
                _BaseMiniTag(label: source.pages, tint: AppColors.blue),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _baseForceProgressLabel(kind, queueStatus, progress ?? 0),
              style: TextStyle(
                color: failed ? AppColors.red : AppColors.muted,
                fontSize: 13.5,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (progress != null && !complete && !failed) ...[
              const SizedBox(height: 12),
              ProcessingCard(
                title: 'İşlem sürüyor',
                message: _baseForceProgressLabel(kind, queueStatus, progress!),
                tags: [source.size, source.pages, time],
              ),
            ] else ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoPill(
                    icon: Icons.data_object_rounded,
                    label: source.size,
                  ),
                  _InfoPill(icon: Icons.schedule_rounded, label: time),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    failed
                        ? 'Kaynağı kontrol edip aynı modda yeniden deneyebilirsin.'
                        : complete
                        ? 'Hazır çıktı koleksiyonlardan da açılabilir.'
                        : 'Hazır olduğunda sonuç ekranı otomatik güncellenir.',
                    style: const TextStyle(
                      color: AppColors.softText,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SBSecondaryButton(
                  label: actionLabel,
                  icon: actionIcon,
                  onPressed: onAction,
                  size: SBButtonSize.small,
                  fullWidth: false,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  _JobUiStatus get _queueStatus {
    if (failed) return _JobUiStatus.failed;
    if (complete) return _JobUiStatus.completed;
    if (progress == null || progress == 0) return _JobUiStatus.pending;
    return _JobUiStatus.running;
  }

  String get _queueStatusLabel {
    return switch (_queueStatus) {
      _JobUiStatus.pending => 'Beklemede',
      _JobUiStatus.running => 'İşleniyor',
      _JobUiStatus.completed => 'Tamamlandı',
      _JobUiStatus.failed => 'Hatalı',
    };
  }
}

class _SelectedSourceSummaryCard extends StatelessWidget {
  const _SelectedSourceSummaryCard({required this.source});

  final _BFSource source;

  @override
  Widget build(BuildContext context) {
    return SourceBaseCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      borderColor: AppColors.line.withValues(alpha: .9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FileKindBadge(kind: source.kind, plain: true),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  source.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(
                label: source.suitabilityLabel,
                status: _premiumStatusForDrive(
                  source.status,
                  enabled: source.enabled,
                ),
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(icon: Icons.menu_book_outlined, label: source.subject),
              _InfoPill(icon: Icons.description_outlined, label: source.pages),
              _InfoPill(icon: Icons.data_object_rounded, label: source.size),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.muted),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BaseMiniTag extends StatelessWidget {
  const _BaseMiniTag({required this.label, required this.tint});

  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: .14)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tint,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

PremiumStatus _premiumStatusForDrive(
  DriveItemStatus status, {
  bool enabled = true,
}) {
  if (!enabled) {
    return status == DriveItemStatus.failed
        ? PremiumStatus.ineligible
        : PremiumStatus.processing;
  }
  return switch (status) {
    DriveItemStatus.completed => PremiumStatus.ready,
    DriveItemStatus.processing => PremiumStatus.processing,
    DriveItemStatus.uploading => PremiumStatus.processing,
    DriveItemStatus.failed => PremiumStatus.failed,
    DriveItemStatus.draft => PremiumStatus.draft,
  };
}

PremiumStatus _premiumStatusForJob(_JobUiStatus status) {
  return switch (status) {
    _JobUiStatus.pending => PremiumStatus.processing,
    _JobUiStatus.running => PremiumStatus.processing,
    _JobUiStatus.completed => PremiumStatus.ready,
    _JobUiStatus.failed => PremiumStatus.failed,
  };
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
      onPressed: () => _showBaseForceToast(
        context,
        'Ek işlemler bu sürümde kaynak seçimi ve yeniden üretim akışları üzerinden yönetilir.',
      ),
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
    'Tablo' => GeneratedKind.comparison,
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
    this.status = DriveItemStatus.completed,
    this.enabled = true,
    this.suitabilityLabel = 'Uygun',
    this.blockedReason,
  });

  final String id;
  final String name;
  final DriveFileKind kind;
  final String size;
  final String pages;
  final String subject;
  final String time;
  final DriveItemStatus status;
  final bool enabled;
  final String suitabilityLabel;
  final String? blockedReason;
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
