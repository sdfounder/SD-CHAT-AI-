import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/sd_chat_colors.dart';
import '../../../shared/models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return _buildUserBubble(context);
    } else {
      return _buildAssistantMessage(context);
    }
  }

  Widget _buildUserBubble(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 8, left: 48, right: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: SDChatColors.userBubble,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
          border: Border.all(
            color: SDChatColors.userBubbleBorder,
            width: 0.8,
          ),
        ),
        child: SelectableText(
          message.content,
          style: const TextStyle(
            color: SDChatColors.textPrimary,
            fontSize: 15,
            height: 1.45,
          ),
        ),
      ),
    );
  }

  Widget _buildAssistantMessage(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête assistant avec badge et action de copie
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: SDChatColors.surfaceHighlight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: SDChatColors.borderMedium,
                    width: 0.8,
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: SDChatColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'SD CHAT AI',
                style: TextStyle(
                  color: SDChatColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              if (!message.isStreaming && message.content.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.copy_outlined, size: 16),
                  color: SDChatColors.textMuted,
                  tooltip: 'Copier la réponse',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: message.content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Message copié dans le presse-papier'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Contenu du message
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: _buildFormattedText(message.content),
          ),
        ],
      ),
    );
  }

  /// Rend le texte avec détection simple des blocs de code ```
  Widget _buildFormattedText(String text) {
    if (!text.contains('```')) {
      return SelectableText(
        text,
        style: const TextStyle(
          color: SDChatColors.textPrimary,
          fontSize: 15.5,
          height: 1.55,
        ),
      );
    }

    final parts = text.split('```');
    final children = <Widget>[];

    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 0) {
        // Texte normal
        if (parts[i].isNotEmpty) {
          children.add(
            SelectableText(
              parts[i],
              style: const TextStyle(
                color: SDChatColors.textPrimary,
                fontSize: 15.5,
                height: 1.55,
              ),
            ),
          );
        }
      } else {
        // Bloc de code
        final codeLines = parts[i].split('\n');
        String lang = '';
        String code = parts[i];
        if (codeLines.isNotEmpty && codeLines.first.trim().isNotEmpty && !codeLines.first.contains(' ')) {
          lang = codeLines.first.trim();
          code = codeLines.sublist(1).join('\n');
        }

        children.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: SDChatColors.codeBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: SDChatColors.codeBorder, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (lang.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: const BoxDecoration(
                      color: SDChatColors.surfaceHighlight,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                    ),
                    child: Text(
                      lang,
                      style: const TextStyle(
                        color: SDChatColors.textMuted,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    code.trim(),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13.5,
                      color: SDChatColors.secondary,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
