import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sourcebase_brand.dart';
import '../../../drive/data/drive_models.dart';
import '../../../drive/data/sourcebase_drive_api.dart';
import '../../../drive/presentation/widgets/drive_ui.dart';

enum _AiMode { tutor, clinic, research, planning }

class CentralAiScreen extends StatefulWidget {
  const CentralAiScreen({
    required this.data,
    required this.onSearch,
    super.key,
  });

  final DriveWorkspaceData data;
  final VoidCallback onSearch;

  @override
  State<CentralAiScreen> createState() => _CentralAiScreenState();
}

class _CentralAiScreenState extends State<CentralAiScreen> {
  final SourceBaseDriveApi _api = const SourceBaseDriveApi();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      text:
          'Merkezi AI hazır. Drive bağlamını seç, hedefini söyle; cevabı kaynak odaklı ve uygulanabilir şekilde toparlayayım.',
      isAi: true,
      mode: _AiMode.tutor,
    ),
  ];

  _AiMode _mode = _AiMode.tutor;
  bool _isSending = false;
  String? _lastError;
  int? _lastInputTokens;
  int? _lastOutputTokens;
  double? _lastCostEstimate;
  late Set<String> _selectedFileIds;

  @override
  void initState() {
    super.initState();
    _selectedFileIds = _defaultSelectedFiles(
      widget.data,
    ).map((file) => file.id).toSet();
  }

  @override
  void didUpdateWidget(covariant CentralAiScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      final availableIds = _contextFiles.map((file) => file.id).toSet();
      _selectedFileIds = _selectedFileIds.intersection(availableIds);
      if (_selectedFileIds.isEmpty) {
        _selectedFileIds = _defaultSelectedFiles(
          widget.data,
        ).map((file) => file.id).toSet();
      }
    }
  }

  List<DriveFile> get _contextFiles {
    final byId = <String, DriveFile>{};
    for (final file in widget.data.recentFiles) {
      byId[file.id] = file;
    }
    for (final course in widget.data.courses) {
      for (final section in course.sections) {
        for (final file in section.files) {
          byId[file.id] = file;
        }
      }
    }
    return byId.values.toList();
  }

  List<DriveFile> get _selectedFiles => _contextFiles
      .where((file) => _selectedFileIds.contains(file.id))
      .take(6)
      .toList();

  Future<void> _sendMessage({String? promptOverride}) async {
    final prompt = (promptOverride ?? _controller.text).trim();
    if (prompt.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
      _lastError = null;
      _messages.add(_ChatMessage(text: prompt, isAi: false, mode: _mode));
      _controller.clear();
    });
    _scrollToBottom();

    try {
      final response = await _api.centralAiChat(
        prompt,
        context: _buildContext(),
      );
      final data = response['data'];
      final answer = data is Map
          ? data['message']?.toString().trim() ?? ''
          : '';
      if (!mounted) return;
      setState(() {
        if (data is Map) {
          _lastInputTokens = _asInt(data['inputTokens']);
          _lastOutputTokens = _asInt(data['outputTokens']);
          _lastCostEstimate = _asDouble(data['costEstimate']);
        }
        _messages.add(
          _ChatMessage(
            text: answer.isEmpty
                ? 'Cevap üretildi ama içerik boş döndü. Aynı isteği biraz daha bağlamla tekrar deneyebilirsin.'
                : answer,
            isAi: true,
            mode: _mode,
          ),
        );
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Bad state: ', '');
      setState(() {
        _lastError = message;
        _messages.add(
          _ChatMessage(
            text: 'Bağlantıda sorun yaşadım: $message',
            isAi: true,
            mode: _mode,
            failed: true,
          ),
        );
      });
      _scrollToBottom();
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  String _buildContext() {
    final files = _selectedFiles;
    final mode = _modeSpec(_mode);
    final buffer = StringBuffer()
      ..writeln('Çalışma modu: ${mode.title}')
      ..writeln('Yanıt odağı: ${mode.contextInstruction}');

    if (files.isEmpty) {
      buffer.writeln('Seçili Drive kaynağı yok.');
    } else {
      buffer.writeln('Seçili Drive kaynakları:');
      for (final file in files) {
        buffer.writeln(
          '- ${file.title} (${file.courseTitle} / ${file.sectionTitle}, ${file.pageLabel}, ${file.updatedLabel})',
        );
        if (file.generated.isNotEmpty) {
          buffer.writeln(
            '  Üretilmiş içerikler: ${file.generated.map((item) => item.title).take(3).join(', ')}',
          );
        }
      }
    }
    return buffer.toString();
  }

  void _toggleFile(DriveFile file) {
    setState(() {
      if (_selectedFileIds.contains(file.id)) {
        _selectedFileIds.remove(file.id);
      } else {
        _selectedFileIds.add(file.id);
      }
    });
  }

  void _selectMode(_AiMode mode) {
    setState(() => _mode = mode);
  }

  void _clearChat() {
    setState(() {
      _messages
        ..clear()
        ..add(
          _ChatMessage(
            text:
                '${_modeSpec(_mode).title} modu açık. Yeni oturum temizlendi; nasıl ilerleyelim?',
            isAi: true,
            mode: _mode,
          ),
        );
      _lastError = null;
      _lastInputTokens = null;
      _lastOutputTokens = null;
      _lastCostEstimate = null;
    });
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1060;
        final sidePanel = _ContextPanel(
          files: _contextFiles,
          selectedIds: _selectedFileIds,
          lastInputTokens: _lastInputTokens,
          lastOutputTokens: _lastOutputTokens,
          lastCostEstimate: _lastCostEstimate,
          onToggleFile: _toggleFile,
        );

        return Material(
          color: AppColors.page,
          child: Stack(
            children: [
              const _AiBackground(),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    wide ? 28 : 18,
                    14,
                    wide ? 28 : 18,
                    0,
                  ),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _ChatWorkspace(
                                controller: _controller,
                                scrollController: _scrollController,
                                messages: _messages,
                                mode: _mode,
                                sending: _isSending,
                                lastError: _lastError,
                                onModeSelected: _selectMode,
                                onSearch: widget.onSearch,
                                onSend: _sendMessage,
                                onClear: _clearChat,
                              ),
                            ),
                            const SizedBox(width: 18),
                            SizedBox(width: 344, child: sidePanel),
                          ],
                        )
                      : _MobileWorkspace(
                          chat: _ChatWorkspace(
                            controller: _controller,
                            scrollController: _scrollController,
                            messages: _messages,
                            mode: _mode,
                            sending: _isSending,
                            lastError: _lastError,
                            onModeSelected: _selectMode,
                            onSearch: widget.onSearch,
                            onSend: _sendMessage,
                            onClear: _clearChat,
                          ),
                          contextPanel: sidePanel,
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MobileWorkspace extends StatelessWidget {
  const _MobileWorkspace({required this.chat, required this.contextPanel});

  final Widget chat;
  final Widget contextPanel;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: const TabBar(
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppColors.selectedBlue,
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              labelColor: AppColors.blue,
              unselectedLabelColor: AppColors.muted,
              labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              tabs: [
                Tab(text: 'Sohbet'),
                Tab(text: 'Bağlam'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              children: [
                chat,
                Padding(
                  padding: const EdgeInsets.only(bottom: 132),
                  child: contextPanel,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatWorkspace extends StatelessWidget {
  const _ChatWorkspace({
    required this.controller,
    required this.scrollController,
    required this.messages,
    required this.mode,
    required this.sending,
    required this.lastError,
    required this.onModeSelected,
    required this.onSearch,
    required this.onSend,
    required this.onClear,
  });

  final TextEditingController controller;
  final ScrollController scrollController;
  final List<_ChatMessage> messages;
  final _AiMode mode;
  final bool sending;
  final String? lastError;
  final ValueChanged<_AiMode> onModeSelected;
  final VoidCallback onSearch;
  final Future<void> Function({String? promptOverride}) onSend;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;

    return GlassPanel(
      radius: 22,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _AiHeader(
            mode: mode,
            sending: sending,
            onSearch: onSearch,
            onClear: onClear,
          ),
          _ModeSelector(selected: mode, onSelected: onModeSelected),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              itemCount: messages.length + (sending ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == messages.length) {
                  return const _ThinkingBubble();
                }
                return _ChatBubble(message: messages[index]);
              },
            ),
          ),
          if (messages.length <= 2)
            _PromptStarters(
              mode: mode,
              onSelected: (text) => onSend(promptOverride: text),
            ),
          if (lastError != null)
            _InlineStatus(
              icon: Icons.cloud_off_rounded,
              label:
                  'Son istek tamamlanamadı. API bağlantısı ve oturumu kontrol edildiğinde tekrar denenebilir.',
              color: AppColors.red,
            ),
          _AiInputArea(
            controller: controller,
            onSend: onSend,
            sending: sending,
            bottomPadding: bottomPadding,
          ),
        ],
      ),
    );
  }
}

class _AiHeader extends StatelessWidget {
  const _AiHeader({
    required this.mode,
    required this.sending,
    required this.onSearch,
    required this.onClear,
  });

  final _AiMode mode;
  final bool sending;
  final VoidCallback onSearch;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final spec = _modeSpec(mode);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 12),
      child: Row(
        children: [
          const SourceBaseBrand(compact: true),
          Container(
            width: 1,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: AppColors.line,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Merkezi AI',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _LiveDot(active: sending),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        sending ? 'Canlı yanıt üretiliyor' : spec.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _HeaderIconButton(
            icon: Icons.search_rounded,
            tooltip: 'Drive içinde ara',
            onTap: onSearch,
          ),
          const SizedBox(width: 8),
          _HeaderIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Sohbeti temizle',
            onTap: onClear,
          ),
        ],
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.selected, required this.onSelected});

  final _AiMode selected;
  final ValueChanged<_AiMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final mode = _AiMode.values[index];
          final spec = _modeSpec(mode);
          final active = selected == mode;
          return Semantics(
            button: true,
            selected: active,
            label: spec.title,
            child: InkWell(
              onTap: () => onSelected(mode),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                constraints: const BoxConstraints(minWidth: 124),
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  color: active
                      ? spec.color.withValues(alpha: .11)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active ? spec.color : AppColors.softLine,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      spec.icon,
                      color: active ? spec.color : AppColors.muted,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      spec.title,
                      style: TextStyle(
                        color: active ? AppColors.navy : AppColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemCount: _AiMode.values.length,
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isAi,
    required this.mode,
    this.failed = false,
  });

  final String text;
  final bool isAi;
  final _AiMode mode;
  final bool failed;
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final spec = _modeSpec(message.mode);
    final align = message.isAi
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.end;
    final bubbleColor = message.isAi
        ? (message.failed ? AppColors.redBg : Colors.white)
        : AppColors.navy;
    final textColor = message.isAi
        ? (message.failed ? AppColors.red : AppColors.ink)
        : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Row(
            mainAxisAlignment: message.isAi
                ? MainAxisAlignment.start
                : MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.isAi) ...[
                _Avatar(
                  icon: message.failed ? Icons.warning_rounded : spec.icon,
                  color: spec.color,
                ),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 720),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(message.isAi ? 5 : 16),
                      bottomRight: Radius.circular(message.isAi ? 16 : 5),
                    ),
                    border: Border.all(
                      color: message.isAi
                          ? (message.failed
                                ? AppColors.red.withValues(alpha: .22)
                                : AppColors.softLine)
                          : AppColors.navy,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.navy.withValues(alpha: .055),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: SelectableText(
                    message.text,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15.5,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              if (!message.isAi) ...[
                const SizedBox(width: 10),
                const _Avatar(
                  icon: Icons.person_rounded,
                  color: AppColors.blue,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          _Avatar(icon: Icons.auto_awesome_rounded, color: AppColors.blue),
          SizedBox(width: 10),
          _TypingIndicator(),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.softLine),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              final phase = (_controller.value + index * .22) % 1;
              final scale = .72 + math.sin(phase * math.pi) * .28;
              return Container(
                width: 7 * scale,
                height: 7 * scale,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: .45 + scale * .35),
                  shape: BoxShape.circle,
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class _PromptStarters extends StatelessWidget {
  const _PromptStarters({required this.mode, required this.onSelected});

  final _AiMode mode;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final prompts = _modeSpec(mode).prompts;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final prompt in prompts)
            ActionChip(
              onPressed: () => onSelected(prompt),
              avatar: const Icon(Icons.bolt_rounded, size: 17),
              label: Text(prompt, maxLines: 1, overflow: TextOverflow.ellipsis),
              labelStyle: const TextStyle(
                color: AppColors.navy,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              backgroundColor: AppColors.selectedBlue,
              side: const BorderSide(color: AppColors.softLine),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
        ],
      ),
    );
  }
}

class _AiInputArea extends StatelessWidget {
  const _AiInputArea({
    required this.controller,
    required this.onSend,
    required this.sending,
    required this.bottomPadding,
  });

  final TextEditingController controller;
  final Future<void> Function({String? promptOverride}) onSend;
  final bool sending;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomPadding),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .96),
        border: const Border(top: BorderSide(color: AppColors.softLine)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _HeaderIconButton(
            icon: Icons.attach_file_rounded,
            tooltip: 'Bağlam panelinden kaynak seç',
            onTap: () {
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Kaynakları Bağlam sekmesinden seçebilirsin.',
                    ),
                    duration: Duration(milliseconds: 1200),
                  ),
                );
            },
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              decoration: InputDecoration(
                hintText: 'Merkezi AI’ya hedefini yaz...',
                filled: true,
                fillColor: AppColors.page,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(
                    color: AppColors.blue,
                    width: 1.4,
                  ),
                ),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 10),
          _SendButton(onTap: onSend, sending: sending),
        ],
      ),
    );
  }
}

class _ContextPanel extends StatelessWidget {
  const _ContextPanel({
    required this.files,
    required this.selectedIds,
    required this.lastInputTokens,
    required this.lastOutputTokens,
    required this.lastCostEstimate,
    required this.onToggleFile,
  });

  final List<DriveFile> files;
  final Set<String> selectedIds;
  final int? lastInputTokens;
  final int? lastOutputTokens;
  final double? lastCostEstimate;
  final ValueChanged<DriveFile> onToggleFile;

  @override
  Widget build(BuildContext context) {
    final selectedCount = selectedIds.length;

    return GlassPanel(
      radius: 22,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _Avatar(icon: Icons.hub_rounded, color: AppColors.cyan),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Canlı Bağlam',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              _CountPill(label: '$selectedCount seçili'),
            ],
          ),
          const SizedBox(height: 14),
          _UsagePanel(
            inputTokens: lastInputTokens,
            outputTokens: lastOutputTokens,
            costEstimate: lastCostEstimate,
          ),
          const SizedBox(height: 16),
          const Text(
            'Drive Kaynakları',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: files.isEmpty
                ? const _EmptySources()
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: files.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 9),
                    itemBuilder: (context, index) {
                      final file = files[index];
                      return _SourceTile(
                        file: file,
                        selected: selectedIds.contains(file.id),
                        onTap: () => onToggleFile(file),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _UsagePanel extends StatelessWidget {
  const _UsagePanel({
    required this.inputTokens,
    required this.outputTokens,
    required this.costEstimate,
  });

  final int? inputTokens;
  final int? outputTokens;
  final double? costEstimate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Son canlı istek',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricCell(
                  label: 'Girdi',
                  value: inputTokens == null ? '-' : '$inputTokens',
                ),
              ),
              Expanded(
                child: _MetricCell(
                  label: 'Çıktı',
                  value: outputTokens == null ? '-' : '$outputTokens',
                ),
              ),
              Expanded(
                child: _MetricCell(
                  label: 'Maliyet',
                  value: costEstimate == null
                      ? '-'
                      : '\$${costEstimate!.toStringAsFixed(4)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .62),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.file,
    required this.selected,
    required this.onTap,
  });

  final DriveFile file;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: file.title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? AppColors.selectedBlue : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.blue : AppColors.softLine,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : AppColors.page,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _fileIcon(file.kind),
                  color: selected ? AppColors.blue : AppColors.muted,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${file.courseTitle} • ${file.pageLabel}',
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
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.add_circle_outline_rounded,
                color: selected ? AppColors.blue : AppColors.softText,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySources extends StatelessWidget {
  const _EmptySources();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.page,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.softLine),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded, color: AppColors.softText, size: 34),
          SizedBox(height: 10),
          Text(
            'Drive kaynağı yok',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Dosya yüklediğinde Merkezi AI cevaplarını bu kaynaklarla zenginleştirir.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineStatus extends StatelessWidget {
  const _InlineStatus({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: .16)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12.5,
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

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onTap, required this.sending});

  final Future<void> Function({String? promptOverride}) onTap;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Mesaj gönder',
      child: InkWell(
        onTap: sending ? null : () => onTap(),
        borderRadius: BorderRadius.circular(13),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(13),
          ),
          child: sending
              ? const Center(
                  child: SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  ),
                )
              : const Icon(
                  Icons.arrow_upward_rounded,
                  color: Colors.white,
                  size: 24,
                ),
        ),
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
      child: Semantics(
        button: true,
        label: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Icon(icon, color: AppColors.navy, size: 22),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: active ? AppColors.green : AppColors.cyan,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (active ? AppColors.green : AppColors.cyan).withValues(
              alpha: .35,
            ),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.greenBg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.green,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AiBackground extends StatelessWidget {
  const _AiBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _AiBackgroundPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _AiBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var i = 0; i < 11; i++) {
      final y = size.height * (.12 + i * .08);
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= size.width; x += 80) {
        path.lineTo(x, y + math.sin((x / 120) + i) * 9);
      }
      paint.color = (i.isEven ? AppColors.cyan : AppColors.blue).withValues(
        alpha: .045,
      );
      canvas.drawPath(path, paint);
    }

    final nodePaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 18; i++) {
      final x = (size.width * ((i * 37) % 100) / 100);
      final y = (size.height * ((i * 23 + 12) % 100) / 100);
      nodePaint.color = AppColors.blue.withValues(alpha: .045);
      canvas.drawCircle(Offset(x, y), 2.5 + (i % 3), nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ModeSpec {
  const _ModeSpec({
    required this.title,
    required this.subtitle,
    required this.contextInstruction,
    required this.icon,
    required this.color,
    required this.prompts,
  });

  final String title;
  final String subtitle;
  final String contextInstruction;
  final IconData icon;
  final Color color;
  final List<String> prompts;
}

_ModeSpec _modeSpec(_AiMode mode) {
  return switch (mode) {
    _AiMode.tutor => const _ModeSpec(
      title: 'Öğretmen',
      subtitle: 'Konuyu adım adım anlatır',
      contextInstruction:
          'Kavramları basitten karmaşığa açıkla, yanlış anlaşılabilecek noktaları vurgula.',
      icon: Icons.school_rounded,
      color: AppColors.blue,
      prompts: [
        'Bu konuyu sınava yönelik özetle',
        'Bana 5 kritik soru sor',
        'Zayıf noktalarımı bulacak mini tekrar planı hazırla',
      ],
    ),
    _AiMode.clinic => const _ModeSpec(
      title: 'Klinik',
      subtitle: 'Klinik akış ve ayırıcı tanı',
      contextInstruction:
          'Klinik karar yerine eğitim amaçlı yaklaşım sun; kırmızı bayrakları ve uzman değerlendirmesini belirt.',
      icon: Icons.local_hospital_rounded,
      color: AppColors.green,
      prompts: [
        'Bu tablo için ayırıcı tanı listesi çıkar',
        'Klinik yaklaşımı algoritma gibi yaz',
        'Kırmızı bayrakları ve ilk değerlendirmeyi özetle',
      ],
    ),
    _AiMode.research => const _ModeSpec(
      title: 'Araştırma',
      subtitle: 'Kaynakları sentezler',
      contextInstruction:
          'Seçili kaynakları önceliklendir, belirsiz bilgi ile kaynak bilgisini birbirinden ayır.',
      icon: Icons.manage_search_rounded,
      color: AppColors.purple,
      prompts: [
        'Seçili kaynakları karşılaştır',
        'Ana argümanları ve boşlukları çıkar',
        'Bu içerikten literatür notu üret',
      ],
    ),
    _AiMode.planning => const _ModeSpec(
      title: 'Plan',
      subtitle: 'Çalışma planı ve görev akışı',
      contextInstruction:
          'Somut zaman blokları, tekrar aralıkları ve ölçülebilir çıktı öner.',
      icon: Icons.event_note_rounded,
      color: AppColors.orange,
      prompts: [
        '7 günlük çalışma planı yap',
        'Bugün için 90 dakikalık program çıkar',
        'Bu kaynaklardan tekrar takvimi oluştur',
      ],
    ),
  };
}

List<DriveFile> _defaultSelectedFiles(DriveWorkspaceData data) {
  final recent = data.recentFiles.take(3).toList();
  if (recent.isNotEmpty) return recent;
  return [
    for (final course in data.courses)
      for (final section in course.sections)
        for (final file in section.files) file,
  ].take(3).toList();
}

IconData _fileIcon(DriveFileKind kind) {
  return switch (kind) {
    DriveFileKind.pdf => Icons.picture_as_pdf_rounded,
    DriveFileKind.pptx => Icons.slideshow_rounded,
    DriveFileKind.docx || DriveFileKind.doc => Icons.description_rounded,
    DriveFileKind.zip => Icons.folder_zip_rounded,
  };
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? _asDouble(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}
