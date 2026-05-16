import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sourcebase_brand.dart';
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
  final TextEditingController _controller = TextEditingController();
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      text: 'Merhaba! Ben SourceBase AI. Bugün size nasıl yardımcı olabilirim?',
      isAi: true,
    ),
  ];
  bool _isSending = false;

  Future<void> _sendMessage() async {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty || _isSending) return;
    setState(() {
      _isSending = true;
      _messages.add(_ChatMessage(text: prompt, isAi: false));
      _controller.clear();
    });

    try {
      final response = await _api.centralAiChat(prompt);
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
            text: error.toString().replaceFirst('Bad state: ', ''),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                reverse: true,
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[_messages.length - 1 - index];
                  return _ChatBubble(message: message);
                },
              ),
            ),
            _AiInputArea(
              controller: _controller,
              onSend: _sendMessage,
              sending: _isSending,
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
  });
  final TextEditingController controller;
  final Future<void> Function() onSend;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 134),
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
              onPressed: () {},
              icon: const Icon(
                Icons.add_circle_outline_rounded,
                color: AppColors.blue,
              ),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'SourceBase AI’ya bir şey sor...',
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
