import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design_system/layout/sourcebase_mobile_metrics.dart';
import '../../../../core/design_system/layout/sourcebase_page_header.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sourcebase_brand.dart';
import '../../../drive/data/drive_models.dart';
import '../../../drive/data/drive_repository.dart';
import '../../../drive/data/sourcebase_drive_api.dart';
import '../../../drive/presentation/widgets/drive_ui.dart';
import '../../../drive/presentation/widgets/sourcebase_bottom_nav.dart';

class CentralAiScreen extends StatefulWidget {
  const CentralAiScreen({
    required this.onSearch,
    this.repository = const DriveRepository(),
    this.api = const SourceBaseDriveApi(),
    super.key,
  });

  final VoidCallback onSearch;
  final DriveRepository repository;
  final SourceBaseDriveApi api;

  @override
  State<CentralAiScreen> createState() => _CentralAiScreenState();
}

class _CentralAiScreenState extends State<CentralAiScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  DriveWorkspaceData _workspace = DriveWorkspaceData.empty;
  final Set<String> _selectedFileIds = {};
  _AiMode _mode = _AiMode.tutor;
  bool _isSending = false;
  bool _loadingSources = true;
  String? _sourceError;

  _AiModeSpec get _modeSpec => _specForMode(_mode);

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  Future<void> _loadSources() async {
    setState(() {
      _loadingSources = true;
      _sourceError = null;
    });
    try {
      final workspace = await widget.repository.loadWorkspace();
      if (!mounted) return;
      setState(() {
        _workspace = workspace;
        _pruneSelectedFiles();
        _loadingSources = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sourceError = _friendlyAiError(error);
        _loadingSources = false;
      });
    }
  }

  void _pruneSelectedFiles() {
    final readyIds = _contextFiles()
        .where((file) => file.status == DriveItemStatus.completed)
        .map((file) => file.id)
        .toSet();
    _selectedFileIds.removeWhere((id) => !readyIds.contains(id));
  }

  Future<void> _sendMessage() => _submitPrompt(_controller.text);

  Future<void> _submitPrompt(
    String rawPrompt, {
    bool addUserMessage = true,
  }) async {
    final prompt = rawPrompt.trim();
    if (prompt.isEmpty || _isSending) return;

    final mode = _modeSpec;
    final sourceTitles = _selectedSourceTitles();
    FocusScope.of(context).unfocus();
    setState(() {
      _isSending = true;
      if (addUserMessage) {
        _messages.add(
          _ChatMessage(
            text: prompt,
            isAi: false,
            modeLabel: mode.label,
            sourceTitles: sourceTitles,
          ),
        );
      }
      _controller.clear();
    });
    _scrollToBottom();

    try {
      final response = await widget.api.centralAiChat(
        prompt,
        context: _contextText(),
        fileIds: _contextFileIds(),
      );
      final data = response['data'];
      final answer = data is Map
          ? data['message']?.toString().trim() ?? ''
          : '';
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            text: answer.isEmpty
                ? 'Cevap üretildi ama içerik boş döndü. Lütfen tekrar dene.'
                : answer,
            isAi: true,
            prompt: prompt,
            modeLabel: mode.label,
            sourceTitles: sourceTitles,
            meta: _AiResponseMeta.fromResponse(response),
          ),
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            text: _friendlyAiError(error),
            isAi: true,
            prompt: prompt,
            modeLabel: mode.label,
            sourceTitles: sourceTitles,
            isError: true,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
  }

  Future<void> _regenerate(_ChatMessage message) async {
    final prompt = message.prompt ?? message.text;
    await _submitPrompt(prompt, addUserMessage: false);
  }

  Future<void> _copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Yanıt panoya kopyalandı.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _continueFrom(_ChatMessage message) {
    final cleaned = message.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final excerpt = cleaned.length > 180
        ? '${cleaned.substring(0, 180)}...'
        : cleaned;
    _controller.text =
        'Bu yanıtı klinik çalışma adımlarıyla devam ettir: $excerpt';
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
  }

  void _setPrompt(String prompt) {
    _controller.text = prompt;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: prompt.length),
    );
  }

  Future<void> _showSourcePicker() async {
    FocusScope.of(context).unfocus();
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SourcePickerSheet(
          files: _contextFiles(),
          selectedFileIds: _selectedFileIds,
          loading: _loadingSources,
          error: _sourceError,
          onRetry: () {
            Navigator.of(context).pop();
            _loadSources();
          },
        );
      },
    );
    if (!mounted || result == null) return;
    setState(() {
      _selectedFileIds
        ..clear()
        ..addAll(result);
      _pruneSelectedFiles();
    });
  }

  String _contextText() {
    final files = _selectedFiles();
    final mode = _modeSpec;
    final buffer = StringBuffer()
      ..writeln('Mod: ${mode.label}')
      ..writeln('Çalışma niyeti: ${mode.instruction}');
    if (files.isEmpty) {
      buffer.writeln('Kullanıcı Drive dosyası seçmedi.');
      return buffer.toString();
    }
    buffer.writeln('Seçili Drive kaynakları:');
    for (final file in files) {
      buffer.writeln(
        '- ${file.title} (${file.kind.name.toUpperCase()}, ${file.sizeLabel}, ${file.pageLabel}, ders: ${file.courseTitle}, bölüm: ${file.sectionTitle})',
      );
    }
    return buffer.toString();
  }

  List<String> _contextFileIds() {
    return _selectedFiles().map((file) => file.id).toList();
  }

  List<String> _selectedSourceTitles() {
    return _selectedFiles().map((file) => file.title).toList();
  }

  List<DriveFile> _selectedFiles() {
    return _contextFiles()
        .where(
          (file) =>
              _selectedFileIds.contains(file.id) &&
              file.status == DriveItemStatus.completed,
        )
        .toList();
  }

  List<DriveFile> _readyFiles() {
    return _contextFiles()
        .where((file) => file.status == DriveItemStatus.completed)
        .toList();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final horizontalPadding = SourceBaseMobileMetrics.horizontalPadding(
      context,
    );
    final topPadding = SourceBaseMobileMetrics.topSafePadding(
      context,
      extra: 10,
    );
    final bottomListPadding = media.viewInsets.bottom > 0
        ? 16.0
        : SourceBaseBottomNav.navHeight + 22;
    final mode = _modeSpec;
    final selectedFiles = _selectedFiles();
    final readyFiles = _readyFiles();

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    topPadding,
                    horizontalPadding,
                    0,
                  ),
                  child: SourceBasePageHeader(
                    title: 'Sohbet',
                    leading: const SourceBaseMark(size: 30),
                    actions: [
                      _HeaderIconButton(
                        icon: Icons.folder_copy_outlined,
                        tooltip: 'Kaynak seç',
                        onTap: _showSourcePicker,
                      ),
                      _HeaderIconButton(
                        icon: Icons.search_rounded,
                        tooltip: 'Ara',
                        onTap: widget.onSearch,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      0,
                      horizontalPadding,
                      bottomListPadding,
                    ),
                    children: [
                      _ModeSelector(
                        selectedMode: _mode,
                        onChanged: (value) => setState(() => _mode = value),
                      ),
                      const SizedBox(height: 12),
                      _SourceSummaryCard(
                        files: _contextFiles(),
                        readyFiles: readyFiles,
                        selectedFiles: selectedFiles,
                        loading: _loadingSources,
                        error: _sourceError,
                        onOpenPicker: _showSourcePicker,
                        onRetry: _loadSources,
                      ),
                      const SizedBox(height: 12),
                      _PromptSuggestionPanel(
                        mode: mode,
                        hasSources: selectedFiles.isNotEmpty,
                        onPrompt: _setPrompt,
                      ),
                      const SizedBox(height: 16),
                      if (_messages.isEmpty)
                        _EmptyConversationPanel(
                          mode: mode,
                          selectedCount: selectedFiles.length,
                          onOpenSources: _showSourcePicker,
                        ),
                      for (final message in _messages)
                        _ChatBubble(
                          message: message,
                          sending: _isSending,
                          onCopy: _copyText,
                          onRegenerate: _regenerate,
                          onContinue: _continueFrom,
                          onOpenSources: _showSourcePicker,
                        ),
                      if (_isSending)
                        _TypingBubble(sourceCount: selectedFiles.length),
                    ],
                  ),
                ),
                _AiInputArea(
                  controller: _controller,
                  onSend: _sendMessage,
                  onOpenSources: _showSourcePicker,
                  sending: _isSending,
                  sourceCount: selectedFiles.length,
                  placeholder: mode.placeholder,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<DriveFile> _contextFiles() {
    final files = <DriveFile>[];
    final seen = <String>{};
    for (final course in _workspace.courses) {
      for (final section in course.sections) {
        for (final file in section.files) {
          if (seen.add(file.id)) files.add(file);
        }
      }
    }
    for (final file in _workspace.recentFiles) {
      if (seen.add(file.id)) files.add(file);
    }
    return files;
  }
}

enum _AiMode { tutor, clinical, research, planner }

class _AiModeSpec {
  const _AiModeSpec({
    required this.mode,
    required this.label,
    required this.icon,
    required this.description,
    required this.instruction,
    required this.placeholder,
    required this.sourcePrompts,
    required this.generalPrompts,
  });

  final _AiMode mode;
  final String label;
  final IconData icon;
  final String description;
  final String instruction;
  final String placeholder;
  final List<String> sourcePrompts;
  final List<String> generalPrompts;
}

const List<_AiModeSpec> _modeSpecs = [
  _AiModeSpec(
    mode: _AiMode.tutor,
    label: 'Tutor',
    icon: Icons.school_outlined,
    description: 'Anlat, sor, pekiştir',
    instruction:
        'Yanıtı bir eğitmen gibi yapılandır. Önce kısa mantık, sonra öğrenme adımları ve kontrol soruları ver.',
    placeholder: 'Bu konuyu sınav odaklı anlat...',
    sourcePrompts: [
      'Seçili kaynağın ana fikrini sınav sabahı okunacak şekilde özetle.',
      'Bu kaynaktan yüksek getirili 5 öğrenme hedefi çıkar.',
      'Bana bu konuyu önce basit, sonra klinik düzeyde anlat.',
    ],
    generalPrompts: [
      'Kardiyak debiyi klinik örnekle anlat.',
      'Bu hafta için 30 dakikalık çalışma planı çıkar.',
      'Bir konuyu nasıl hızlı tekrar etmeliyim?',
    ],
  ),
  _AiModeSpec(
    mode: _AiMode.clinical,
    label: 'Klinik',
    icon: Icons.medical_services_outlined,
    description: 'Vaka, karar, ayırıcı',
    instruction:
        'Yanıtı klinik akıl yürütme diliyle ver. Bulgular, ön tanılar, kritik kırmızı bayraklar ve karar adımlarını ayır.',
    placeholder: 'Bu bulgularla klinik yaklaşımı kur...',
    sourcePrompts: [
      'Bu kaynaktan bir klinik senaryo ve karar ağacı üret.',
      'Bu konunun ayırıcı tanısını tablo gibi yaz.',
      'Bu kaynakta sınavda tuzak olabilecek klinik noktaları çıkar.',
    ],
    generalPrompts: [
      'Göğüs ağrısında ilk klinik yaklaşımı sırala.',
      'Hiponatremide ayırıcı tanıyı sadeleştir.',
      'Acilde kırmızı bayrak bulguları nasıl taranır?',
    ],
  ),
  _AiModeSpec(
    mode: _AiMode.research,
    label: 'Araştırma',
    icon: Icons.manage_search_outlined,
    description: 'Kanıt, karşılaştır, sınır',
    instruction:
        'Yanıtı akademik ve kaynak temkinli kur. Bilinen/kaynakta geçen ayrımını açık tut, belirsizlikleri belirt.',
    placeholder: 'Bu bilgiyi akademik çerçevede değerlendir...',
    sourcePrompts: [
      'Seçili kaynaklarda geçen kavramları karşılaştırma tablosuna dönüştür.',
      'Bu kaynaktaki güçlü ve zayıf kanıt noktalarını ayır.',
      'Bu metnin akademik kısa notunu çıkar.',
    ],
    generalPrompts: [
      'Randomize kontrollü çalışmayı nasıl hızlı okurum?',
      'Duyarlılık ve özgüllüğü klinik karar açısından açıkla.',
      'Bir derleme makalesinden çalışma notu nasıl çıkarılır?',
    ],
  ),
  _AiModeSpec(
    mode: _AiMode.planner,
    label: 'Planlama',
    icon: Icons.event_note_outlined,
    description: 'Takvim, tekrar, görev',
    instruction:
        'Yanıtı yapılabilir görev listesi, zaman kutuları ve tekrar ritmiyle planla. Gereksiz motivasyon dili kullanma.',
    placeholder: 'Bu kaynaklardan bir çalışma planı çıkar...',
    sourcePrompts: [
      'Seçili kaynaklardan 3 günlük tekrar planı hazırla.',
      'Bu dosyayı flashcard ve soru üretimine hazırlayacak görevleri sırala.',
      'Eksik olduğum alanlar için kısa bir tekrar rotası kur.',
    ],
    generalPrompts: [
      'Finale 7 gün kala tıp dersi çalışma planı kur.',
      'Günde 45 dakikam varsa tekrar düzeni öner.',
      'Zorlandığım konuları takip etmek için bir rutin çıkar.',
    ],
  ),
];

_AiModeSpec _specForMode(_AiMode mode) {
  return _modeSpecs.firstWhere((spec) => spec.mode == mode);
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isAi,
    this.prompt,
    this.modeLabel,
    this.sourceTitles = const [],
    this.isError = false,
    this.meta,
  });

  final String text;
  final bool isAi;
  final String? prompt;
  final String? modeLabel;
  final List<String> sourceTitles;
  final bool isError;
  final _AiResponseMeta? meta;
}

class _AiResponseMeta {
  const _AiResponseMeta({
    this.inputTokens,
    this.outputTokens,
    this.amountUnits,
    this.modelLabel,
    this.fallbackUsed,
  });

  final int? inputTokens;
  final int? outputTokens;
  final num? amountUnits;
  final String? modelLabel;
  final bool? fallbackUsed;

  static _AiResponseMeta? fromResponse(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map) return null;
    final route = data['modelRoute'] is Map ? data['modelRoute'] as Map : null;
    final provider = route?['provider']?.toString();
    final model = route?['model']?.toString();
    final modelLabel = [
      if (provider != null && provider.isNotEmpty) provider,
      if (model != null && model.isNotEmpty) model,
    ].join(' / ');
    final meta = _AiResponseMeta(
      inputTokens: _intOrNull(data['inputTokens']),
      outputTokens: _intOrNull(data['outputTokens']),
      amountUnits: _numOrNull(data['amount_units'] ?? data['amountUnits']),
      modelLabel: modelLabel.isEmpty ? null : modelLabel,
      fallbackUsed: route?['fallbackUsed'] == true,
    );
    if (meta.inputTokens == null &&
        meta.outputTokens == null &&
        meta.amountUnits == null &&
        meta.modelLabel == null &&
        meta.fallbackUsed != true) {
      return null;
    }
    return meta;
  }

  bool get hasVisibleData =>
      inputTokens != null ||
      outputTokens != null ||
      amountUnits != null ||
      modelLabel != null ||
      fallbackUsed == true;
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.selectedMode, required this.onChanged});

  final _AiMode selectedMode;
  final ValueChanged<_AiMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 18,
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 620 ? 2 : 4;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _modeSpecs.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              mainAxisExtent: 78,
            ),
            itemBuilder: (context, index) {
              final spec = _modeSpecs[index];
              return _ModeTile(
                spec: spec,
                selected: selectedMode == spec.mode,
                onTap: () => onChanged(spec.mode),
              );
            },
          );
        },
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final _AiModeSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.clinicalActive : AppColors.muted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.clinicalActiveBg
                : AppColors.clinicalSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.clinicalActive
                  : AppColors.clinicalBorder,
              width: selected ? 1.3 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.white
                      : AppColors.white.withValues(alpha: .78),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: selected
                        ? AppColors.clinicalActive.withValues(alpha: .18)
                        : AppColors.softLine,
                  ),
                ),
                child: Icon(spec.icon, color: color, size: 19),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      spec.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? AppColors.clinicalActive
                            : AppColors.navy,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      spec.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceSummaryCard extends StatelessWidget {
  const _SourceSummaryCard({
    required this.files,
    required this.readyFiles,
    required this.selectedFiles,
    required this.loading,
    required this.error,
    required this.onOpenPicker,
    required this.onRetry,
  });

  final List<DriveFile> files;
  final List<DriveFile> readyFiles;
  final List<DriveFile> selectedFiles;
  final bool loading;
  final String? error;
  final VoidCallback onOpenPicker;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final selected = selectedFiles.length;
    return GlassPanel(
      radius: 18,
      padding: const EdgeInsets.all(14),
      borderColor: selected > 0
          ? AppColors.clinicalActive.withValues(alpha: .28)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.clinicalActiveBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.folder_copy_outlined,
                  color: AppColors.clinicalActive,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selected == 0
                          ? 'Henüz kaynak seçilmedi'
                          : '$selected kaynak seçildi',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _sourceSummaryLine,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12.5,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _CompactActionButton(
                label: selected == 0 ? 'Seç' : 'Düzenle',
                icon: Icons.tune_rounded,
                onTap: onOpenPicker,
              ),
            ],
          ),
          if (loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 3),
          ] else if (error != null) ...[
            const SizedBox(height: 12),
            _InlineNotice(
              icon: Icons.error_outline_rounded,
              text: error!,
              tone: _NoticeTone.error,
              actionLabel: 'Tekrar dene',
              onAction: onRetry,
            ),
          ] else if (files.isEmpty) ...[
            const SizedBox(height: 12),
            const _InlineNotice(
              icon: Icons.folder_off_outlined,
              text:
                  'Drive’da bağlanabilir kaynak yok. Önce dosya yükleyebilirsin.',
            ),
          ] else if (selectedFiles.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final file in selectedFiles.take(4))
                  _SourceChip(title: file.title, kind: file.kind),
                if (selectedFiles.length > 4)
                  _CountChip(label: '+${selectedFiles.length - 4}'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String get _sourceSummaryLine {
    if (loading) return 'Drive kaynakları yükleniyor.';
    if (error != null) return 'Kaynak listesi alınamadı.';
    if (files.isEmpty) return 'Sohbete bağlanacak kaynak bulunamadı.';
    if (selectedFiles.isEmpty) {
      if (readyFiles.isEmpty) {
        return 'Kaynaklar hazırlanıyor; yalnızca hazır dosyalar bağlanır.';
      }
      return '${readyFiles.length} hazır kaynak bağlanabilir.';
    }
    return 'Yanıtlar seçili kaynakları önceliklendirir.';
  }
}

class _PromptSuggestionPanel extends StatelessWidget {
  const _PromptSuggestionPanel({
    required this.mode,
    required this.hasSources,
    required this.onPrompt,
  });

  final _AiModeSpec mode;
  final bool hasSources;
  final ValueChanged<String> onPrompt;

  @override
  Widget build(BuildContext context) {
    final prompts = hasSources ? mode.sourcePrompts : mode.generalPrompts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            children: [
              Icon(mode.icon, color: AppColors.clinicalActive, size: 18),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${mode.label} başlangıçları',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: prompts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final prompt = prompts[index];
              return _PromptChip(prompt: prompt, onTap: () => onPrompt(prompt));
            },
          ),
        ),
      ],
    );
  }
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({required this.prompt, required this.onTap});

  final String prompt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 270),
      child: SourceBaseChip(
        label: prompt,
        icon: Icons.add_rounded,
        foregroundColor: AppColors.clinicalActive,
        onTap: onTap,
      ),
    );
  }
}

class _EmptyConversationPanel extends StatelessWidget {
  const _EmptyConversationPanel({
    required this.mode,
    required this.selectedCount,
    required this.onOpenSources,
  });

  final _AiModeSpec mode;
  final int selectedCount;
  final VoidCallback onOpenSources;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: GlassPanel(
        radius: 22,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.selectedBlue,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.softLine),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(9),
                    child: SourceBaseMark(size: 26),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${mode.label} oturumu hazır',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedCount == 0
                            ? 'Kaynak seçebilir veya genel bir çalışma sorusu yazabilirsin.'
                            : '$selectedCount kaynak bu oturuma bağlı.',
                        style: const TextStyle(
                          color: AppColors.muted,
                          height: 1.35,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
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
                _SmallMetricChip(
                  icon: mode.icon,
                  label: mode.label,
                  color: AppColors.clinicalActive,
                ),
                _SmallMetricChip(
                  icon: Icons.folder_copy_outlined,
                  label: selectedCount == 0
                      ? 'Kaynak yok'
                      : '$selectedCount kaynak',
                  color: selectedCount == 0
                      ? AppColors.warning
                      : AppColors.green,
                ),
                _CompactActionButton(
                  label: 'Kaynaklar',
                  icon: Icons.tune_rounded,
                  onTap: onOpenSources,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.sending,
    required this.onCopy,
    required this.onRegenerate,
    required this.onContinue,
    required this.onOpenSources,
  });

  final _ChatMessage message;
  final bool sending;
  final Future<void> Function(String text) onCopy;
  final Future<void> Function(_ChatMessage message) onRegenerate;
  final ValueChanged<_ChatMessage> onContinue;
  final VoidCallback onOpenSources;

  @override
  Widget build(BuildContext context) {
    final isAi = message.isAi;
    final bubbleColor = message.isError
        ? AppColors.clinicalErrorBg
        : isAi
        ? AppColors.white
        : AppColors.clinicalActive;
    final textColor = message.isError
        ? AppColors.clinicalError
        : isAi
        ? AppColors.navy
        : AppColors.white;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isAi) ...[
              _BubbleAvatar(isAi: true, error: message.isError),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 680),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isAi ? 5 : 20),
                    bottomRight: Radius.circular(isAi ? 20 : 5),
                  ),
                  border: Border.all(
                    color: message.isError
                        ? AppColors.clinicalError.withValues(alpha: .18)
                        : isAi
                        ? AppColors.softLine
                        : AppColors.clinicalActive,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navy.withValues(alpha: .055),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.modeLabel != null ||
                        message.sourceTitles.isNotEmpty)
                      _MessageContextRow(message: message, isAi: isAi),
                    SelectableText(
                      message.text,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15.5,
                        height: 1.42,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (message.sourceTitles.isNotEmpty && isAi) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (final title in message.sourceTitles.take(3))
                            _PlainSourceReference(title: title),
                          if (message.sourceTitles.length > 3)
                            _CountChip(
                              label: '+${message.sourceTitles.length - 3}',
                            ),
                        ],
                      ),
                    ],
                    if (message.meta?.hasVisibleData == true) ...[
                      const SizedBox(height: 12),
                      _AiMetaRow(meta: message.meta!),
                    ],
                    const SizedBox(height: 12),
                    _BubbleActions(
                      isAi: isAi,
                      error: message.isError,
                      sending: sending,
                      onCopy: () => onCopy(message.text),
                      onRegenerate: () => onRegenerate(message),
                      onContinue: () => onContinue(message),
                      onOpenSources: onOpenSources,
                    ),
                  ],
                ),
              ),
            ),
            if (!isAi) ...[
              const SizedBox(width: 10),
              _BubbleAvatar(isAi: false, error: false),
            ],
          ],
        ),
      ),
    );
  }
}

class _BubbleAvatar extends StatelessWidget {
  const _BubbleAvatar({required this.isAi, required this.error});

  final bool isAi;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: error
            ? AppColors.clinicalErrorBg
            : isAi
            ? AppColors.selectedBlue
            : const Color(0xFFE2E8F0),
        shape: BoxShape.circle,
        border: Border.all(
          color: error
              ? AppColors.clinicalError.withValues(alpha: .18)
              : AppColors.softLine,
        ),
      ),
      child: isAi
          ? Padding(
              padding: const EdgeInsets.all(7),
              child: error
                  ? const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.clinicalError,
                      size: 20,
                    )
                  : const SourceBaseMark(size: 22),
            )
          : const Icon(Icons.person_rounded, color: AppColors.muted, size: 21),
    );
  }
}

class _MessageContextRow extends StatelessWidget {
  const _MessageContextRow({required this.message, required this.isAi});

  final _ChatMessage message;
  final bool isAi;

  @override
  Widget build(BuildContext context) {
    final foreground = isAi
        ? AppColors.muted
        : Colors.white.withValues(alpha: .82);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          if (message.modeLabel != null)
            _MiniContextPill(
              icon: Icons.tune_rounded,
              label: message.modeLabel!,
              color: foreground,
              onDark: !isAi,
            ),
          if (message.sourceTitles.isNotEmpty)
            _MiniContextPill(
              icon: Icons.folder_copy_outlined,
              label: '${message.sourceTitles.length} kaynak',
              color: foreground,
              onDark: !isAi,
            ),
        ],
      ),
    );
  }
}

class _BubbleActions extends StatelessWidget {
  const _BubbleActions({
    required this.isAi,
    required this.error,
    required this.sending,
    required this.onCopy,
    required this.onRegenerate,
    required this.onContinue,
    required this.onOpenSources,
  });

  final bool isAi;
  final bool error;
  final bool sending;
  final VoidCallback onCopy;
  final VoidCallback onRegenerate;
  final VoidCallback onContinue;
  final VoidCallback onOpenSources;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _IconTextAction(
          icon: Icons.copy_rounded,
          label: 'Kopyala',
          onTap: onCopy,
          onDark: !isAi,
        ),
        if (isAi) ...[
          _IconTextAction(
            icon: Icons.refresh_rounded,
            label: error ? 'Tekrar dene' : 'Yenile',
            onTap: sending ? null : onRegenerate,
            onDark: false,
          ),
          _IconTextAction(
            icon: Icons.subdirectory_arrow_right_rounded,
            label: 'Devam',
            onTap: onContinue,
            onDark: false,
          ),
          _IconTextAction(
            icon: Icons.folder_copy_outlined,
            label: 'Kaynaklar',
            onTap: onOpenSources,
            onDark: false,
          ),
        ],
      ],
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble({required this.sourceCount});

  final int sourceCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _BubbleAvatar(isAi: true, error: false),
            const SizedBox(width: 10),
            Flexible(
              child: GlassPanel(
                radius: 20,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.clinicalActive,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        sourceCount == 0
                            ? 'Yanıt hazırlanıyor'
                            : '$sourceCount kaynak okunuyor',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiInputArea extends StatelessWidget {
  const _AiInputArea({
    required this.controller,
    required this.onSend,
    required this.onOpenSources,
    required this.sending,
    required this.sourceCount,
    required this.placeholder,
  });

  final TextEditingController controller;
  final Future<void> Function() onSend;
  final VoidCallback onOpenSources;
  final bool sending;
  final int sourceCount;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomPadding = media.viewInsets.bottom > 0
        ? media.viewInsets.bottom + 12
        : SourceBaseBottomNav.contentBottomPadding(context);
    final horizontalPadding = SourceBaseMobileMetrics.horizontalPadding(
      context,
    );
    return Container(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        0,
        horizontalPadding,
        bottomPadding,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: .92),
            Colors.white,
          ],
        ),
      ),
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        radius: 8,
        borderColor: sourceCount > 0
            ? AppColors.clinicalActive.withValues(alpha: .24)
            : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _ComposerSourceButton(
              sourceCount: sourceCount,
              onTap: onOpenSources,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 118),
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: placeholder,
                    hintMaxLines: 2,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 11,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                return _SendButton(
                  onTap: onSend,
                  sending: sending,
                  enabled: value.text.trim().isNotEmpty && !sending,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerSourceButton extends StatelessWidget {
  const _ComposerSourceButton({required this.sourceCount, required this.onTap});

  final int sourceCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasSources = sourceCount > 0;
    return Tooltip(
      message: hasSources ? '$sourceCount kaynak bağlı' : 'Kaynak seç',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 40,
          constraints: const BoxConstraints(minWidth: 40),
          padding: EdgeInsets.symmetric(horizontal: hasSources ? 10 : 0),
          decoration: BoxDecoration(
            color: hasSources ? AppColors.greenBg : AppColors.clinicalSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasSources
                  ? AppColors.green.withValues(alpha: .24)
                  : AppColors.clinicalBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                hasSources
                    ? Icons.folder_special_rounded
                    : Icons.attach_file_rounded,
                color: hasSources ? AppColors.green : AppColors.clinicalActive,
                size: 20,
              ),
              if (hasSources) ...[
                const SizedBox(width: 6),
                Text(
                  '$sourceCount',
                  style: const TextStyle(
                    color: AppColors.green,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.onTap,
    required this.sending,
    required this.enabled,
  });

  final Future<void> Function() onTap;
  final bool sending;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Gönder',
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: enabled ? AppColors.clinicalActive : AppColors.line,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              if (enabled)
                BoxShadow(
                  color: AppColors.clinicalActive.withValues(alpha: .18),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: sending
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  Icons.arrow_upward_rounded,
                  color: enabled ? Colors.white : AppColors.muted,
                  size: 22,
                ),
        ),
      ),
    );
  }
}

class _SourcePickerSheet extends StatefulWidget {
  const _SourcePickerSheet({
    required this.files,
    required this.selectedFileIds,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final List<DriveFile> files;
  final Set<String> selectedFileIds;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  State<_SourcePickerSheet> createState() => _SourcePickerSheetState();
}

class _SourcePickerSheetState extends State<_SourcePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  late final Set<String> _draftSelected;
  _SourceFilter _filter = _SourceFilter.ready;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _draftSelected = {...widget.selectedFileIds};
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: .84,
      minChildSize: .58,
      maxChildSize: .94,
      expand: false,
      builder: (context, scrollController) {
        final files = _filteredFiles();
        final readyCount = widget.files
            .where((file) => file.status == DriveItemStatus.completed)
            .length;
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          child: Material(
            color: AppColors.white,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Kaynak seçimi',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.navy,
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Kapat',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${_draftSelected.length} seçili · $readyCount hazır kaynak',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _SourceSearchField(controller: _searchController),
                      const SizedBox(height: 12),
                      _SourceFilterBar(
                        selected: _filter,
                        selectedCount: _draftSelected.length,
                        onChanged: (value) => setState(() => _filter = value),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (widget.loading) {
                        return const _SourcePickerLoading();
                      }
                      if (widget.error != null) {
                        return _SourcePickerMessage(
                          icon: Icons.error_outline_rounded,
                          title: 'Kaynak listesi alınamadı',
                          body: widget.error!,
                          actionLabel: 'Tekrar dene',
                          onAction: widget.onRetry,
                        );
                      }
                      if (widget.files.isEmpty) {
                        return const _SourcePickerMessage(
                          icon: Icons.folder_off_outlined,
                          title: 'Kaynak yok',
                          body:
                              'Drive’a dosya yükledikten sonra burada seçilebilir.',
                        );
                      }
                      if (files.isEmpty) {
                        return const _SourcePickerMessage(
                          icon: Icons.manage_search_outlined,
                          title: 'Sonuç bulunamadı',
                          body: 'Arama veya filtreyi değiştirerek tekrar dene.',
                        );
                      }
                      return ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                        itemCount: files.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final file = files[index];
                          final disabledReason = _contextFileDisabledReason(
                            file,
                          );
                          final selected = _draftSelected.contains(file.id);
                          return _SourcePickerTile(
                            file: file,
                            selected: selected,
                            disabledReason: disabledReason,
                            onTap: disabledReason == null
                                ? () => _toggle(file.id)
                                : null,
                          );
                        },
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      border: Border(
                        top: BorderSide(color: AppColors.softLine),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _draftSelected.isEmpty
                                ? null
                                : () => setState(_draftSelected.clear),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.clinicalActive,
                              side: const BorderSide(
                                color: AppColors.clinicalBorder,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              minimumSize: const Size(0, 48),
                            ),
                            child: const Text('Temizle'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                Navigator.of(context).pop(_draftSelected),
                            icon: const Icon(Icons.check_rounded),
                            label: Text(
                              _draftSelected.isEmpty
                                  ? 'Uygula'
                                  : '${_draftSelected.length} kaynak uygula',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.clinicalActive,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _toggle(String id) {
    setState(() {
      if (_draftSelected.contains(id)) {
        _draftSelected.remove(id);
      } else {
        _draftSelected.add(id);
      }
    });
  }

  List<DriveFile> _filteredFiles() {
    Iterable<DriveFile> files = widget.files;
    if (_filter == _SourceFilter.ready) {
      files = files.where((file) => file.status == DriveItemStatus.completed);
    } else if (_filter == _SourceFilter.selected) {
      files = files.where((file) => _draftSelected.contains(file.id));
    }
    if (_query.isNotEmpty) {
      files = files.where((file) {
        final text = [
          file.title,
          file.courseTitle,
          file.sectionTitle,
          file.kind.name,
        ].join(' ').toLowerCase();
        return text.contains(_query);
      });
    }
    return files.toList();
  }
}

enum _SourceFilter { all, ready, selected }

class _SourceSearchField extends StatelessWidget {
  const _SourceSearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: 'Dosya, ders veya bölüm ara',
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: AppColors.clinicalSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.clinicalBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.clinicalBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.clinicalActive),
        ),
      ),
    );
  }
}

class _SourceFilterBar extends StatelessWidget {
  const _SourceFilterBar({
    required this.selected,
    required this.selectedCount,
    required this.onChanged,
  });

  final _SourceFilter selected;
  final int selectedCount;
  final ValueChanged<_SourceFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _FilterChipButton(
          label: 'Hazır',
          selected: selected == _SourceFilter.ready,
          onTap: () => onChanged(_SourceFilter.ready),
        ),
        _FilterChipButton(
          label: 'Tümü',
          selected: selected == _SourceFilter.all,
          onTap: () => onChanged(_SourceFilter.all),
        ),
        _FilterChipButton(
          label: 'Seçili $selectedCount',
          selected: selected == _SourceFilter.selected,
          onTap: () => onChanged(_SourceFilter.selected),
        ),
      ],
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.clinicalActiveBg,
      backgroundColor: AppColors.clinicalSurface,
      side: BorderSide(
        color: selected ? AppColors.clinicalActive : AppColors.clinicalBorder,
      ),
      labelStyle: TextStyle(
        color: selected ? AppColors.clinicalActive : AppColors.navy,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _SourcePickerTile extends StatelessWidget {
  const _SourcePickerTile({
    required this.file,
    required this.selected,
    required this.disabledReason,
    required this.onTap,
  });

  final DriveFile file;
  final bool selected;
  final String? disabledReason;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = disabledReason != null;
    return Opacity(
      opacity: disabled ? .68 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected ? AppColors.clinicalActiveBg : AppColors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? AppColors.clinicalActive : AppColors.softLine,
                width: selected ? 1.3 : 1,
              ),
            ),
            child: Row(
              children: [
                FileKindBadge(kind: file.kind, compact: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              file.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.navy,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusPill(status: file.status, compact: true),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${file.courseTitle} · ${file.sectionTitle}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        disabledReason ??
                            '${file.sizeLabel} · ${file.pageLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: disabled ? AppColors.warning : AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  disabled
                      ? Icons.lock_outline_rounded
                      : selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: disabled
                      ? AppColors.muted
                      : selected
                      ? AppColors.clinicalActive
                      : AppColors.muted,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SourcePickerLoading extends StatelessWidget {
  const _SourcePickerLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: AppColors.clinicalActive,
        ),
      ),
    );
  }
}

class _SourcePickerMessage extends StatelessWidget {
  const _SourcePickerMessage({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.clinicalActive, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 10),
              _CompactActionButton(
                label: actionLabel!,
                icon: Icons.refresh_rounded,
                onTap: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.text,
    this.tone = _NoticeTone.neutral,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final _NoticeTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final color = tone == _NoticeTone.error
        ? AppColors.clinicalError
        : AppColors.clinicalActive;
    final bg = tone == _NoticeTone.error
        ? AppColors.clinicalErrorBg
        : AppColors.clinicalActiveBg;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: tone == _NoticeTone.error ? color : AppColors.navy,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(width: 8),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

enum _NoticeTone { neutral, error }

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.title, required this.kind});

  final String title;
  final DriveFileKind kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.clinicalSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.clinicalBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            FileKindBadge.kindLabel(kind),
            style: TextStyle(
              color: FileKindBadge.kindColor(kind),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlainSourceReference extends StatelessWidget {
  const _PlainSourceReference({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.clinicalSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.softLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.insert_drive_file_outlined,
            color: AppColors.clinicalActive,
            size: 14,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiMetaRow extends StatelessWidget {
  const _AiMetaRow({required this.meta});

  final _AiResponseMeta meta;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        if (meta.amountUnits != null)
          _SmallMetricChip(
            icon: Icons.paid_outlined,
            label:
                '${meta.amountUnits!.toStringAsFixed(meta.amountUnits! % 1 == 0 ? 0 : 1)} MC',
            color: AppColors.warning,
          ),
        if (meta.inputTokens != null || meta.outputTokens != null)
          _SmallMetricChip(
            icon: Icons.data_usage_rounded,
            label: '${meta.inputTokens ?? 0}/${meta.outputTokens ?? 0} token',
            color: AppColors.muted,
          ),
        if (meta.modelLabel != null)
          _SmallMetricChip(
            icon: Icons.route_outlined,
            label: meta.fallbackUsed == true ? 'Yedek model' : meta.modelLabel!,
            color: AppColors.clinicalActive,
          ),
      ],
    );
  }
}

class _SmallMetricChip extends StatelessWidget {
  const _SmallMetricChip({
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniContextPill extends StatelessWidget {
  const _MiniContextPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onDark,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: onDark
            ? Colors.white.withValues(alpha: .12)
            : AppColors.clinicalSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.clinicalActiveBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.clinicalActive,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _IconTextAction extends StatelessWidget {
  const _IconTextAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.onDark,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final foreground = onDark ? Colors.white : AppColors.clinicalActive;
    final border = onDark
        ? Colors.white.withValues(alpha: .22)
        : AppColors.clinicalBorder;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: onDark
              ? Colors.white.withValues(alpha: .10)
              : AppColors.clinicalSurface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: foreground, size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactActionButton extends StatelessWidget {
  const _CompactActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.clinicalActive,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        side: const BorderSide(color: AppColors.clinicalBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.white,
            border: Border.all(color: AppColors.clinicalBorder),
          ),
          child: Icon(icon, color: AppColors.navy, size: 22),
        ),
      ),
    );
  }
}

String _friendlyAiError(Object error) {
  final text = error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '')
      .trim();
  if (text.contains('SourceBase Supabase client is not configured')) {
    return 'Oturum süren dolmuş olabilir. Devam etmek için tekrar giriş yap.';
  }
  final lowerText = text.toLowerCase();
  if (lowerText.contains('unauthorized') || lowerText.contains('401')) {
    return 'Oturum süren dolmuş olabilir. Devam etmek için tekrar giriş yap.';
  }
  if (lowerText.contains('network') ||
      lowerText.contains('socket') ||
      lowerText.contains('failed to fetch')) {
    return 'Bağlantı kurulamadı. İnternet bağlantını kontrol edip tekrar dene.';
  }
  if (_isRawAiProviderError(text)) {
    return 'Yanıt oluşturulamadı. Kaynağı kontrol edip tekrar deneyebilirsin.';
  }
  return 'Yanıt oluşturulamadı. Kaynağı veya mesajı kontrol edip tekrar deneyebilirsin.';
}

String? _contextFileDisabledReason(DriveFile file) {
  if (file.status == DriveItemStatus.processing) {
    return 'İşleniyor';
  }
  if (file.status == DriveItemStatus.uploading) {
    return 'Yükleniyor';
  }
  if (file.status == DriveItemStatus.failed) {
    return file.statusMessage == null
        ? 'İşlenemedi'
        : driveFriendlyErrorMessage(file.statusMessage!);
  }
  if (file.status == DriveItemStatus.draft) {
    return 'Eksik yükleme';
  }
  return null;
}

int? _intOrNull(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '');
}

num? _numOrNull(Object? value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '');
}

bool _isRawAiProviderError(String text) {
  final normalized = text.toUpperCase();
  return normalized.contains('VERTEX_') ||
      normalized.contains('OPENAI_') ||
      normalized.contains('ANTHROPIC_') ||
      normalized.contains('CENTRAL_AI_UNAVAILABLE') ||
      normalized.contains('UPSTREAM') ||
      normalized.contains('PROVIDER') ||
      normalized.contains('STACK') ||
      normalized.contains('UNDEFINED') ||
      normalized.contains('NULL') ||
      normalized.contains('{') ||
      normalized.contains('}');
}
