import 'package:flutter/material.dart';
import '../../../core/theme/sd_chat_colors.dart';
import '../../../core/services/voice_service.dart';

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

class _ChatInputBarState extends State<ChatInputBar> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final VoiceService _voice = VoiceService();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _hasText = false;
  String _textBeforeDictation = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _voice.addListener(_onVoiceStateChanged);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _onTextChanged() {
    final has = _controller.text.trim().isNotEmpty;
    if (has != _hasText) {
      setState(() => _hasText = has);
    }
  }

  void _onVoiceStateChanged() {
    if (!mounted) return;

    setState(() {});

    if (_voice.status == VoiceStatus.permissionDenied) {
      _showFeedbackSnackbar(
        _voice.errorMessage.isNotEmpty
            ? _voice.errorMessage
            : 'Permission microphone refusée. Veuillez l\'autoriser dans les réglages.',
        isError: true,
      );
    } else if (_voice.status == VoiceStatus.unavailable) {
      _showFeedbackSnackbar(
        _voice.errorMessage.isNotEmpty
            ? _voice.errorMessage
            : 'Reconnaissance vocale native indisponible sur cet appareil.',
        isError: true,
      );
    } else if (_voice.status == VoiceStatus.error && _voice.errorMessage.isNotEmpty) {
      _showFeedbackSnackbar(_voice.errorMessage, isError: true);
    }
  }

  void _showFeedbackSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: isError ? SDChatColors.error : SDChatColors.textPrimary,
            fontSize: 13,
          ),
        ),
        backgroundColor: SDChatColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isError ? SDChatColors.error.withValues(alpha: 0.5) : SDChatColors.borderMedium,
            width: 0.8,
          ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _voice.removeListener(_onVoiceStateChanged);
    _pulseController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleDictation() async {
    if (widget.isStreaming) return;

    if (_voice.isListening) {
      await _voice.stopListening();
    } else {
      _textBeforeDictation = _controller.text.trim();
      await _voice.startListening(
        onResult: (words, isFinal) {
          if (!mounted) return;

          setState(() {
            if (_textBeforeDictation.isNotEmpty) {
              _controller.text = '$_textBeforeDictation $words';
            } else {
              _controller.text = words;
            }
            // Déplacer le curseur à la fin du texte pour permettre la saisie et modification immédiate
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _controller.text.length),
            );
          });
        },
      );
    }
  }

  void _handleSend() {
    // Si la dictée est en cours, l'arrêter avant d'envoyer
    if (_voice.isListening) {
      _voice.stopListening();
    }

    final text = _controller.text.trim();
    if (text.isNotEmpty && !widget.isStreaming) {
      widget.onSend(text);
      _controller.clear();
      _textBeforeDictation = '';
      setState(() => _hasText = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isListening = _voice.isListening;

    return Container(
      decoration: const BoxDecoration(
        color: SDChatColors.background,
        border: Border(
          top: BorderSide(color: SDChatColors.borderSubtle, width: 0.8),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bannière animée lorsque la dictée vocale est active
          if (isListening)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              decoration: BoxDecoration(
                color: SDChatColors.surfaceHighlight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: SDChatColors.primary.withValues(alpha: 0.6),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: SDChatColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Écoute vocale active... Parlez à SD CHAT AI',
                      style: TextStyle(
                        color: SDChatColors.primary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () => _voice.stopListening(),
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        'Arrêter',
                        style: TextStyle(
                          color: SDChatColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Barre d'entrée principale
          Padding(
            padding: EdgeInsets.only(
              left: 14,
              right: 14,
              top: isListening ? 6 : 10,
              bottom: MediaQuery.of(context).padding.bottom + 10,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: SDChatColors.surfaceElevated,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: isListening
                      ? SDChatColors.primary
                      : _hasText
                          ? SDChatColors.primary.withValues(alpha: 0.5)
                          : SDChatColors.borderMedium,
                  width: isListening ? 1.2 : 0.8,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Bouton pièce jointe
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
                        decoration: InputDecoration(
                          hintText: isListening
                              ? 'Dictée en cours...'
                              : 'Posez votre question à SD CHAT AI...',
                          hintStyle: TextStyle(
                            color: isListening ? SDChatColors.primary : SDChatColors.textMuted,
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

                  // Bouton dictée vocale 🎙️
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 2),
                    child: IconButton(
                      icon: isListening
                          ? ScaleTransition(
                              scale: _pulseAnimation,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: SDChatColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.mic_rounded,
                                  size: 18,
                                  color: SDChatColors.background,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.mic_none_rounded,
                              size: 22,
                              color: SDChatColors.textSecondary,
                            ),
                      tooltip: isListening ? 'Arrêter la dictée' : 'Activer la dictée vocale',
                      onPressed: _toggleDictation,
                    ),
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
          ),
        ],
      ),
    );
  }
}
