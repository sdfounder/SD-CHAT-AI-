import 'package:flutter/material.dart';
import '../../../core/theme/sd_chat_colors.dart';

class ChatInputBar extends StatefulWidget {
  final ValueChanged<String> onSend;
  final bool isStreaming;
  final VoidCallback? onStop;

  const ChatInputBar({
    super.key,
    required this.onSend,
    this.isStreaming = false,
    this.onStop,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) {
        setState(() => _hasText = has);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && !widget.isStreaming) {
      widget.onSend(text);
      _controller.clear();
      setState(() => _hasText = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: const BoxDecoration(
        color: SDChatColors.background,
        border: Border(
          top: BorderSide(color: SDChatColors.borderSubtle, width: 0.8),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: SDChatColors.surfaceElevated,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: _hasText
                ? SDChatColors.primary.withValues(alpha: 0.5)
                : SDChatColors.borderMedium,
            width: 0.8,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Bouton pièce jointe (prêt pour images / txt V1)
            IconButton(
              icon: const Icon(Icons.attach_file_rounded, size: 20),
              color: SDChatColors.textMuted,
              tooltip: 'Joindre un fichier (Images / TXT)',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Upload de fichiers disponible sous peu.'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),

            // Champ de saisie extensible
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: TextField(
                  controller: _controller,
                  maxLines: 5,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(
                    color: SDChatColors.textPrimary,
                    fontSize: 15,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Posez votre question à SD CHAT AI...',
                    hintStyle: TextStyle(
                      color: SDChatColors.textMuted,
                      fontSize: 14.5,
                    ),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _handleSend(),
                ),
              ),
            ),

            // Bouton dictée vocale
            IconButton(
              icon: const Icon(Icons.mic_none_rounded, size: 21),
              color: SDChatColors.textMuted,
              tooltip: 'Dictée vocale',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reconnaissance vocale native prête.'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),

            // Bouton d'envoi ou stop
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 3),
              child: widget.isStreaming
                  ? IconButton(
                      icon: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: SDChatColors.surfaceHighlight,
                          shape: BoxShape.circle,
                          border: Border.all(color: SDChatColors.primary),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.stop_rounded,
                            size: 16,
                            color: SDChatColors.primary,
                          ),
                        ),
                      ),
                      onPressed: widget.onStop,
                    )
                  : IconButton(
                      icon: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _hasText
                              ? SDChatColors.primary
                              : SDChatColors.surfaceHighlight,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            size: 18,
                            color: _hasText
                                ? SDChatColors.background
                                : SDChatColors.textDisabled,
                          ),
                        ),
                      ),
                      onPressed: _hasText ? _handleSend : null,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
