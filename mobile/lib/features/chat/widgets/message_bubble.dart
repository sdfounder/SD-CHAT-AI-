import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../../../core/theme/sd_chat_colors.dart';
import '../../../shared/models/chat_message.dart';

import 'attachment_view.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final void Function(ChatMessage message)? onEdit;

  const MessageBubble({
    super.key,
    required this.message,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return _buildUserBubble(context);
    } else {
      return _buildAssistantMessage(context);
    }
  }

  Widget _buildUserBubble(BuildContext context) {
    final hasContent = message.content.trim().isNotEmpty;
    final hasAttachments = message.attachments.isNotEmpty;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 8, left: 48, right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Affichage des pièces jointes associées au message
            if (hasAttachments)
              MessageAttachmentsView(
                attachments: message.attachments,
                isUser: true,
              ),

            if (hasContent)
              Container(
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
            const SizedBox(height: 4),
            // Barre d'actions sous le message utilisateur
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onEdit != null)
                  InkWell(
                    onTap: () => onEdit!(message),
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_outlined, size: 14, color: SDChatColors.textMuted),
                          SizedBox(width: 4),
                          Text(
                            'Modifier',
                            style: TextStyle(
                              fontSize: 11,
                              color: SDChatColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: message.content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Message copié'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Icon(Icons.copy_outlined, size: 14, color: SDChatColors.textMuted),
                  ),
                ),
              ],
            ),
          ],
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
          // En-tête assistant avec badge officiel et action de copie
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
              if (message.isStreaming) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: SDChatColors.primary,
                  ),
                ),
              ],
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
                        content: Text('Réponse copiée dans le presse-papier'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Contenu du message rendu en Markdown riche
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: _buildMarkdownContent(context, message.content),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdownContent(BuildContext context, String content) {
    if (content.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final markdownStyle = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: const TextStyle(
        color: SDChatColors.textPrimary,
        fontSize: 15.5,
        height: 1.55,
      ),
      h1: const TextStyle(
        color: SDChatColors.secondary,
        fontSize: 22,
        fontWeight: FontWeight.bold,
        height: 1.4,
      ),
      h2: const TextStyle(
        color: SDChatColors.secondary,
        fontSize: 19,
        fontWeight: FontWeight.bold,
        height: 1.4,
      ),
      h3: const TextStyle(
        color: SDChatColors.secondary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      code: const TextStyle(
        backgroundColor: SDChatColors.surfaceHighlight,
        color: SDChatColors.secondary,
        fontFamily: 'monospace',
        fontSize: 13.5,
      ),
      blockquote: const TextStyle(
        color: SDChatColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
      blockquoteDecoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: SDChatColors.primary, width: 3),
        ),
      ),
      listBullet: const TextStyle(
        color: SDChatColors.primary,
        fontSize: 15,
      ),
    );

    return MarkdownBody(
      data: content,
      selectable: true,
      styleSheet: markdownStyle,
      builders: {
        'pre': _CodeElementBuilder(context),
      },
    );
  }
}

class _CodeElementBuilder extends MarkdownElementBuilder {
  final BuildContext context;
  _CodeElementBuilder(this.context);

  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    String language = 'code';
    if (element.children != null && element.children!.isNotEmpty) {
      final child = element.children!.first;
      if (child is md.Element && child.attributes.containsKey('class')) {
        final cl = child.attributes['class'] ?? '';
        if (cl.startsWith('language-')) {
          language = cl.substring('language-'.length);
        }
      }
    }

    final codeText = element.textContent.trim();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: SDChatColors.codeBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SDChatColors.codeBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: SDChatColors.surfaceHighlight,
              borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  language.toLowerCase(),
                  style: const TextStyle(
                    color: SDChatColors.textMuted,
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: codeText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Code copié dans le presse-papier'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy_rounded, size: 14, color: SDChatColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'Copier',
                          style: TextStyle(
                            color: SDChatColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              codeText,
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
    );
  }
}
