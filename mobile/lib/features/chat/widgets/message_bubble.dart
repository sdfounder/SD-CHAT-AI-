import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../../../core/theme/sd_chat_colors.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../shared/models/chat_message.dart';
import 'attachment_view.dart';

class MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final void Function(ChatMessage message)? onEdit;

  const MessageBubble({
    super.key,
    required this.message,
    this.onEdit,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _copied = false;

  void _copyToClipboard(String text, {String label = 'Message copié'}) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: text));
    setState(() => _copied = true);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: SDChatColors.success, size: 16),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  String _formatModelName() {
    final raw = SyncService.instance.activeModelName ?? AppConfig.defaultModel;
    if (raw.contains('3.8')) return 'Gemini 3.8 Flash';
    if (raw.contains('3.6')) return 'Gemini 3.6 Flash';
    if (raw.contains('2.5')) return 'Gemini 2.5 Flash';
    if (raw.contains('flash-latest')) return 'Gemini Flash';
    return raw.replaceAll('models/', '');
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.message.isUser
        ? _buildUserBubble(context)
        : _buildAssistantMessage(context);

    // Ne pas relancer l'animation d'entrée pendant le streaming actif pour préserver le GPU
    if (widget.message.isStreaming) {
      return content;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1.0 - value) * 5),
            child: child,
          ),
        );
      },
      child: content,
    );
  }

  Widget _buildUserBubble(BuildContext context) {
    final hasContent = widget.message.content.trim().isNotEmpty;
    final hasAttachments = widget.message.attachments.isNotEmpty;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 8, left: 44, right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Affichage des pièces jointes
            if (hasAttachments)
              MessageAttachmentsView(
                attachments: widget.message.attachments,
                isUser: true,
              ),

            if (hasContent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: SDChatColors.userBubbleGradient,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(5),
                  ),
                  border: Border.all(
                    color: SDChatColors.userBubbleBorder,
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: SelectableText(
                  widget.message.content,
                  style: TextStyle(
                    color: SDChatColors.textPrimary,
                    fontSize: 15 * SettingsService.instance.fontScale,
                    height: 1.48,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            const SizedBox(height: 4),

            // Barre d'actions sous le message utilisateur
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.onEdit != null)
                  InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.onEdit!(widget.message);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_outlined, size: 14, color: SDChatColors.textMuted),
                          SizedBox(width: 4),
                          Text(
                            'Modifier',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: SDChatColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => _copyToClipboard(widget.message.content, label: 'Message copié'),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _copied ? Icons.check_rounded : Icons.copy_outlined,
                          size: 14,
                          color: _copied ? SDChatColors.success : SDChatColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _copied ? 'Copié' : 'Copier',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: _copied ? SDChatColors.success : SDChatColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
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
    final isStreaming = widget.message.isStreaming;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête assistant avec badge d'intelligence et modèle
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: SDChatColors.surfaceHighlight,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: SDChatColors.primary.withValues(alpha: 0.4),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: SDChatColors.primary.withValues(alpha: 0.15),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 13,
                  color: SDChatColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'SD CHAT AI',
                style: TextStyle(
                  color: SDChatColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: SDChatColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: SDChatColors.borderSubtle, width: 0.6),
                ),
                child: Text(
                  _formatModelName(),
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: SDChatColors.textMuted,
                  ),
                ),
              ),
              if (isStreaming) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.6,
                    color: SDChatColors.primary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Contenu du message rendu en Markdown riche
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: _buildMarkdownContent(context, widget.message.content, isStreaming),
          ),

          // Barre d'actions sous la réponse finalisée
          if (!isStreaming && widget.message.content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => _copyToClipboard(widget.message.content, label: 'Réponse copiée'),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: SDChatColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: SDChatColors.borderSubtle, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _copied ? Icons.check_rounded : Icons.copy_rounded,
                            size: 13,
                            color: _copied ? SDChatColors.success : SDChatColors.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _copied ? 'Copié' : 'Copier',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: _copied ? SDChatColors.success : SDChatColors.textSecondary,
                            ),
                          ),
                        ],
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

  Widget _buildMarkdownContent(BuildContext context, String content, bool isStreaming) {
    if (content.isEmpty) {
      return const SizedBox.shrink();
    }

    final scale = SettingsService.instance.fontScale;
    final theme = Theme.of(context);
    final markdownStyle = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: TextStyle(
        color: SDChatColors.textPrimary,
        fontSize: 15.5 * scale,
        height: 1.58,
        letterSpacing: -0.1,
      ),
      h1: TextStyle(
        color: SDChatColors.secondaryLight,
        fontSize: 21 * scale,
        fontWeight: FontWeight.w700,
        height: 1.35,
        letterSpacing: -0.4,
      ),
      h2: TextStyle(
        color: SDChatColors.secondaryLight,
        fontSize: 18.5 * scale,
        fontWeight: FontWeight.w600,
        height: 1.35,
        letterSpacing: -0.3,
      ),
      h3: TextStyle(
        color: SDChatColors.secondaryLight,
        fontSize: 16.5 * scale,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      code: TextStyle(
        backgroundColor: SDChatColors.surfaceHighlight,
        color: SDChatColors.primaryBright,
        fontFamily: 'monospace',
        fontSize: 13.5 * scale,
      ),
      blockquote: TextStyle(
        color: SDChatColors.textSecondary,
        fontStyle: FontStyle.italic,
        fontSize: 14 * scale,
        height: 1.45,
      ),
      blockquoteDecoration: BoxDecoration(
        color: SDChatColors.surfaceHighlight.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
        border: const Border(
          left: BorderSide(color: SDChatColors.primary, width: 3),
        ),
      ),
      listBullet: TextStyle(
        color: SDChatColors.primary,
        fontSize: 15 * scale,
        fontWeight: FontWeight.bold,
      ),
      tableBorder: TableBorder.all(
        color: SDChatColors.borderMedium,
        width: 0.8,
      ),
      tableHead: TextStyle(
        color: SDChatColors.primaryBright,
        fontWeight: FontWeight.w600,
        fontSize: 13.5 * scale,
      ),
      tableBody: TextStyle(
        color: SDChatColors.textPrimary,
        fontSize: 13.5 * scale,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarkdownBody(
          data: content,
          selectable: true,
          styleSheet: markdownStyle,
          builders: {
            'pre': _CodeElementBuilder(context),
          },
        ),
        if (isStreaming)
          const Padding(
            padding: EdgeInsets.only(top: 4.0),
            child: _StreamingPulseCursor(),
          ),
      ],
    );
  }
}

class _StreamingPulseCursor extends StatefulWidget {
  const _StreamingPulseCursor();

  @override
  State<_StreamingPulseCursor> createState() => _StreamingPulseCursorState();
}

class _StreamingPulseCursorState extends State<_StreamingPulseCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return Opacity(
          opacity: 0.2 + 0.8 * _anim.value,
          child: Container(
            width: 8,
            height: 15,
            decoration: BoxDecoration(
              color: SDChatColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
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
    return _CodeBlockCard(code: codeText, language: language);
  }
}

class _CodeBlockCard extends StatefulWidget {
  final String code;
  final String language;

  const _CodeBlockCard({required this.code, required this.language});

  @override
  State<_CodeBlockCard> createState() => _CodeBlockCardState();
}

class _CodeBlockCardState extends State<_CodeBlockCard> {
  bool _copied = false;

  void _copy() {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: SDChatColors.success, size: 16),
            SizedBox(width: 8),
            Text('Code copié dans le presse-papier'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: SDChatColors.codeBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SDChatColors.codeBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête du bloc de code
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: const BoxDecoration(
              color: SDChatColors.surfaceHighlight,
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: SDChatColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.language.toUpperCase(),
                      style: const TextStyle(
                        color: SDChatColors.secondary,
                        fontSize: 11.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: _copy,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Row(
                        key: ValueKey<bool>(_copied),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _copied ? Icons.check_rounded : Icons.copy_rounded,
                            size: 13,
                            color: _copied ? SDChatColors.success : SDChatColors.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _copied ? 'Copié !' : 'Copier',
                            style: TextStyle(
                              color: _copied ? SDChatColors.success : SDChatColors.primary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Corps de code avec défilement horizontal fluide
          Padding(
            padding: const EdgeInsets.all(14),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                widget.code,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13.5,
                  color: SDChatColors.secondary,
                  height: 1.48,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
