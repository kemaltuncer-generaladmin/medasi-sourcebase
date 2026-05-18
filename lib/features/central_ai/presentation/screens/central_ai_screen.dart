import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sourcebase_brand.dart';
import '../../../drive/data/drive_models.dart';
import '../../../drive/data/drive_repository.dart';
import '../../../drive/data/sourcebase_drive_api.dart';
import '../../../drive/presentation/widgets/drive_ui.dart';

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
      text: 'Merhaba! Ben SourceBase AI. Bugün size nasıl yardımcı olabilirim?',
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
        _messages.add(
          _ChatMessage(
            text: _friendlyAiError(error),
            isAi: true,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  String _contextText() {
    final files = _workspace.recentFiles
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

  void _toggleFile(String id) {
    setState(() {
      if (_selectedFileIds.contains(id)) {
        _selectedFileIds.remove(id);
      } else {
        _selectedFileIds.add(id);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
              child: Row(
                children: [
                  const SourceBaseBrand(compact: true),
                  const _TopDivider(),
                  const Expanded(
                    child: Text(
                      'Merkezi AI',
                      style: TextStyle(
                        color: AppColors.blue,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _RoundIconButton(
                    icon: Icons.search_rounded,
                    onTap: widget.onSearch,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                reverse: true,
                itemCount: _messages.length + 1,
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return _ContextPanel(
                      files: _workspace.recentFiles,
                      selectedFileIds: _selectedFileIds,
                      loading: _loadingSources,
                      error: _sourceError,
                      mode: _mode,
                      onMode: (value) => setState(() => _mode = value),
                      onToggleFile: _toggleFile,
                      onRetry: _loadSources,
                    );
                  }
                  final message = _messages[_messages.length - 1 - index];
                  return _ChatBubble(message: message);
                },
              ),
            ),
            _AiInputArea(
              controller: _controller,
              onSend: _sendMessage,
              sending: _isSending,
              hasContext: _selectedFileIds.isNotEmpty,
            ),
          ],
        ),
      ),
    );
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
              const LinearProgressIndicator(minHeight: 3)
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
            else
              SizedBox(
                height: 104,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: files.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final file = files[index];
                    final selected = selectedFileIds.contains(file.id);
                    return _ContextFileCard(
                      file: file,
                      selected: selected,
                      onTap: () => onToggleFile(file.id),
                    );
                  },
                ),
              ),
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
    required this.onTap,
  });

  final DriveFile file;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.selectedBlue : Colors.white,
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
                    '${file.sizeLabel} • ${file.pageLabel}',
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
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? AppColors.blue : AppColors.muted,
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
                child: const Icon(
                  Icons.psychology_rounded,
                  color: AppColors.blue,
                  size: 22,
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

class _AiInputArea extends StatelessWidget {
  const _AiInputArea({
    required this.controller,
    required this.onSend,
    required this.sending,
    required this.hasContext,
  });
  final TextEditingController controller;
  final Future<void> Function() onSend;
  final bool sending;
  final bool hasContext;

  void _showContextHint(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hasContext
              ? 'Seçili Drive kaynakları bu sohbete bağlandı.'
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        radius: 24,
        child: Row(
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
                  hintText: "SourceBase AI'ya bir şey sor...",
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            _SendButton(onTap: onSend, sending: sending),
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

class _TopDivider extends StatelessWidget {
  const _TopDivider();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 18),
      color: const Color(0xFFE2E8F0),
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
    return 'Oturum bağlantısı hazır değil. Lütfen tekrar giriş yapın.';
  }
  return text.isEmpty
      ? 'Merkezi AI isteği tamamlanamadı. Lütfen tekrar deneyin.'
      : text;
}
