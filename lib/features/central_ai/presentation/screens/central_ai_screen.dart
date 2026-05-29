import 'package:flutter/material.dart';
import '../../../../core/design_system/components/sourcebase_card.dart';
import '../../../../core/design_system/layout/sourcebase_page_header.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sourcebase_brand.dart';
import '../../../drive/data/drive_models.dart';
import '../../../drive/data/drive_repository.dart';
import '../../../drive/data/sourcebase_drive_api.dart';
import '../../../drive/presentation/widgets/drive_ui.dart';
import '../../../drive/presentation/widgets/premium_workspace_components.dart';

class CentralAiScreen extends StatefulWidget {
  const CentralAiScreen({required this.onSearch, super.key});

  final VoidCallback onSearch;

  @override
  State<CentralAiScreen> createState() => _CentralAiScreenState();
}

class _CentralAiScreenState extends State<CentralAiScreen> {
  final SourceBaseDriveApi _api = const SourceBaseDriveApi();
  final DriveRepository _repository = const DriveRepository();
  final TextEditingController _controller = TextEditingController();
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      text:
          'Hazır bir kaynak seçtiğinde içerik üzerinden soru çözebilir, zorlandığın yerleri toparlayabilir ve kısa tekrar notları çıkarabilirim.',
      isAi: true,
    ),
  ];
  DriveWorkspaceData _workspace = DriveWorkspaceData.empty;
  final Set<String> _selectedFileIds = {};
  String _mode = 'Tutor';
  bool _isSending = false;
  bool _loadingSources = true;
  String? _sourceError;

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
      final workspace = await _repository.loadWorkspace();
      if (!mounted) return;
      setState(() {
        _workspace = workspace;
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

  Future<void> _sendMessage() async {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty || _isSending) return;
    setState(() {
      _isSending = true;
      _messages.add(_ChatMessage(text: prompt, isAi: false));
      _controller.clear();
    });

    try {
      final response = await _api.centralAiChat(
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
          ),
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(text: _friendlyAiError(error), isAi: true));
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  String _contextText() {
    final files = _contextFiles()
        .where((file) => _selectedFileIds.contains(file.id))
        .toList();
    final buffer = StringBuffer('Mod: $_mode');
    if (files.isEmpty) {
      buffer.writeln('\nKullanıcı Drive dosyası seçmedi.');
      return buffer.toString();
    }
    buffer.writeln('\nSeçili Drive kaynakları:');
    for (final file in files) {
      buffer.writeln(
        '- ${file.title} (${file.kind.name.toUpperCase()}, ${file.sizeLabel}, ${file.pageLabel}, ders: ${file.courseTitle}, bölüm: ${file.sectionTitle})',
      );
    }
    return buffer.toString();
  }

  List<String> _contextFileIds() {
    return _contextFiles()
        .where(
          (file) =>
              _selectedFileIds.contains(file.id) &&
              file.status == DriveItemStatus.completed,
        )
        .map((file) => file.id)
        .toList();
  }

  void _toggleFile(String id) {
    setState(() {
      if (_selectedFileIds.contains(id)) {
        _selectedFileIds.remove(id);
      } else {
        _selectedFileIds.add(id);
      }
    });
  }

  Future<void> _sendPresetPrompt(String prompt) async {
    _controller
      ..text = prompt
      ..selection = TextSelection.collapsed(offset: prompt.length);
    await _sendMessage();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedFiles = _contextFiles()
        .where((file) => _selectedFileIds.contains(file.id))
        .toList();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
              child: SourceBasePageHeader(
                title: 'Merkezi AI',
                subtitle: 'Drive kaynaklarınla güvenli çalışma sohbeti başlat.',
                leading: const SourceBaseBrand(compact: true),
                actions: [
                  _RoundIconButton(
                    icon: Icons.search_rounded,
                    onTap: widget.onSearch,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                children: [
                  PremiumHeroCard(
                    eyebrow: 'Kaynak odaklı çalışma',
                    title: 'Kaynağına göre çalış',
                    description:
                        'Bir PDF veya PPTX seç; sorularını doğrudan o kaynak üzerinden ilerletelim.',
                    tint: AppColors.blue,
                    anchorIcon: Icons.forum_rounded,
                    anchorLabel: _selectedFileIds.isEmpty
                        ? 'Kaynak seç'
                        : '${_selectedFileIds.length} kaynak',
                    metrics: [
                      MetricPillData(
                        label: 'Hazır kaynak',
                        value:
                            '${_contextFiles().where((file) => file.status == DriveItemStatus.completed).length}',
                        tint: AppColors.green,
                        icon: Icons.check_circle_rounded,
                      ),
                      MetricPillData(
                        label: 'Seçili',
                        value: '${_selectedFileIds.length}',
                        tint: AppColors.blue,
                        icon: Icons.folder_special_rounded,
                      ),
                      MetricPillData(
                        label: 'Mod',
                        value: _mode,
                        tint: AppColors.purple,
                        icon: Icons.tune_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SourceBaseCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Önerilen başlangıçlar',
                          style: TextStyle(
                            color: AppColors.navy,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final prompt in const [
                              'Bu kaynaktan sınav sorusu çıkar',
                              'Özetle',
                              'Zorlandığım yerleri anlat',
                              'Klinik bağlantı kur',
                            ])
                              ActionChip(
                                label: Text(prompt),
                                onPressed: () => _sendPresetPrompt(prompt),
                                backgroundColor: AppColors.page,
                                side: const BorderSide(
                                  color: AppColors.softLine,
                                ),
                                labelStyle: const TextStyle(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ContextPanel(
                    files: _contextFiles(),
                    selectedFileIds: _selectedFileIds,
                    loading: _loadingSources,
                    error: _sourceError,
                    mode: _mode,
                    onMode: (value) => setState(() => _mode = value),
                    onToggleFile: _toggleFile,
                    onRetry: _loadSources,
                  ),
                  for (final message in _messages)
                    _ChatBubble(message: message),
                  if (_isSending && (_messages.isEmpty || !_messages.last.isAi))
                    const _ChatThinkingBubble(),
                ],
              ),
            ),
            _AiInputArea(
              controller: _controller,
              onSend: _sendMessage,
              sending: _isSending,
              hasContext: _selectedFileIds.isNotEmpty,
              selectedFiles: selectedFiles,
            ),
          ],
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

class _ChatMessage {
  const _ChatMessage({required this.text, required this.isAi});
  final String text;
  final bool isAi;
}

class _ContextPanel extends StatelessWidget {
  const _ContextPanel({
    required this.files,
    required this.selectedFileIds,
    required this.loading,
    required this.error,
    required this.mode,
    required this.onMode,
    required this.onToggleFile,
    required this.onRetry,
  });

  final List<DriveFile> files;
  final Set<String> selectedFileIds;
  final bool loading;
  final String? error;
  final String mode;
  final ValueChanged<String> onMode;
  final ValueChanged<String> onToggleFile;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: GlassPanel(
        padding: const EdgeInsets.all(16),
        radius: 22,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.folder_copy_outlined, color: AppColors.blue),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Drive Bağlamı',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  selectedFileIds.isEmpty
                      ? 'Dosya seçilmedi'
                      : '${selectedFileIds.length} dosya',
                  style: TextStyle(
                    color: selectedFileIds.isEmpty
                        ? AppColors.muted
                        : AppColors.green,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in const [
                  'Tutor',
                  'Klinik',
                  'Araştırma',
                  'Planlama',
                ])
                  ChoiceChip(
                    label: Text(value),
                    selected: mode == value,
                    onSelected: (_) => onMode(value),
                    selectedColor: AppColors.selectedBlue,
                    labelStyle: TextStyle(
                      color: mode == value ? AppColors.blue : AppColors.navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (loading)
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.blue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Drive kaynakların yükleniyor',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ],
              )
            else if (error != null)
              _ContextNotice(
                icon: Icons.error_outline_rounded,
                text: error!,
                actionLabel: 'Tekrar dene',
                onAction: onRetry,
              )
            else if (files.isEmpty)
              const _ContextNotice(
                icon: Icons.folder_off_outlined,
                text:
                    'Drive’da seçilebilir kaynak yok. Dosya yükledikten sonra bağlam seçilebilir.',
              )
            else ...[
              const _ContextNotice(
                icon: Icons.verified_outlined,
                text:
                    'Merkezi AI yalnızca işlenmesi tamamlanmış Drive kaynaklarını modele bağlar.',
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 104,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: files.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final file = files[index];
                    final selected = selectedFileIds.contains(file.id);
                    final disabledReason = _contextFileDisabledReason(file);
                    return _ContextFileCard(
                      file: file,
                      selected: selected,
                      disabledReason: disabledReason,
                      onTap: disabledReason == null
                          ? () => onToggleFile(file.id)
                          : null,
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContextNotice extends StatelessWidget {
  const _ContextNotice({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.muted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _ContextFileCard extends StatelessWidget {
  const _ContextFileCard({
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: disabledReason != null
              ? const Color(0xFFF8FAFC)
              : selected
              ? AppColors.selectedBlue
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.blue : AppColors.line),
        ),
        child: Row(
          children: [
            FileKindBadge(kind: file.kind, compact: true),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    file.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    disabledReason ?? '${file.sizeLabel} • ${file.pageLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              disabledReason != null
                  ? Icons.hourglass_empty_rounded
                  : selected
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              color: disabledReason != null
                  ? AppColors.muted
                  : selected
                  ? AppColors.blue
                  : AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});
  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Align(
        alignment: message.isAi ? Alignment.centerLeft : Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.isAi) ...[
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AppColors.selectedBlue,
                  shape: BoxShape.circle,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(7),
                  child: SourceBaseMark(size: 24),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: message.isAi ? Colors.white : AppColors.blue,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(message.isAi ? 4 : 20),
                    bottomRight: Radius.circular(message.isAi ? 20 : 4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navy.withValues(alpha: .06),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(
                  message.text,
                  style: TextStyle(
                    color: message.isAi ? AppColors.navy : Colors.white,
                    fontSize: 16,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            if (!message.isAi) ...[
              const SizedBox(width: 12),
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFFE2E8F0),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Color(0xFF64748B),
                  size: 22,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChatThinkingBubble extends StatefulWidget {
  const _ChatThinkingBubble();

  @override
  State<_ChatThinkingBubble> createState() => _ChatThinkingBubbleState();
}

class _ChatThinkingBubbleState extends State<_ChatThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppColors.selectedBlue,
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(7),
                child: SourceBaseMark(size: 24),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.navy.withValues(alpha: .06),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i != 0) const SizedBox(width: 6),
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final phase = (_controller.value + i * 0.18) % 1.0;
                        final t = (phase < 0.5) ? phase * 2 : (1 - phase) * 2;
                        return Opacity(
                          opacity: 0.35 + (0.55 * t),
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AppColors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(width: 10),
                  const Text(
                    'Yanıt hazırlanıyor',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
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

class _AiInputArea extends StatelessWidget {
  const _AiInputArea({
    required this.controller,
    required this.onSend,
    required this.sending,
    required this.hasContext,
    required this.selectedFiles,
  });
  final TextEditingController controller;
  final Future<void> Function() onSend;
  final bool sending;
  final bool hasContext;
  final List<DriveFile> selectedFiles;

  void _showContextHint(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hasContext
              ? 'Hazır durumdaki seçili Drive kaynakları bu sohbete bağlandı.'
              : 'Drive bağlamı için üstteki kaynak kartlarından dosya seçin.',
        ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomPadding = media.viewInsets.bottom > 0
        ? media.viewInsets.bottom + 16
        : 134 + media.padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: .9),
            Colors.white,
          ],
        ),
      ),
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        radius: 24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selectedFiles.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.page,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.softLine),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.folder_special_rounded,
                      color: AppColors.blue,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selectedFiles.length == 1
                            ? selectedFiles.first.title
                            : '${selectedFiles.length} kaynak seçili',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      selectedFiles.length == 1
                          ? FileKindBadge.kindLabel(selectedFiles.first.kind)
                          : 'Hazır bağlam',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                IconButton(
                  onPressed: () => _showContextHint(context),
                  tooltip: 'Drive bağlamı',
                  icon: Icon(
                    hasContext
                        ? Icons.attach_file_rounded
                        : Icons.attach_file_outlined,
                    color: hasContext ? AppColors.green : AppColors.blue,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'Kaynağın içeriğiyle ilgili bir soru yaz...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                _SendButton(onTap: onSend, sending: sending),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onTap, required this.sending});
  final Future<void> Function() onTap;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: sending ? null : onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
          shape: BoxShape.circle,
        ),
        child: sending
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(
                Icons.arrow_upward_rounded,
                color: Colors.white,
                size: 24,
              ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Icon(icon, color: AppColors.navy, size: 24),
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
    return 'İşlenemedi';
  }
  if (file.status == DriveItemStatus.draft) {
    return 'Taslak';
  }
  return null;
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
