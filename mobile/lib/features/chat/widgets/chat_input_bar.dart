import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/theme/sd_chat_colors.dart';
import '../../../core/services/voice_service.dart';
import '../../../core/services/chat_api_service.dart';
import '../../../shared/models/chat_attachment.dart';

class ChatInputBar extends StatefulWidget {
  final void Function(String text, List<ChatAttachment> attachments) onSend;
  final bool isStreaming;
  final VoidCallback? onStop;
  final String? conversationId;

  const ChatInputBar({
    super.key,
    required this.onSend,
    this.isStreaming = false,
    this.onStop,
    this.conversationId,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final VoiceService _voice = VoiceService();
  final ChatApiService _chatApi = ChatApiService();
  final ImagePicker _imagePicker = ImagePicker();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _hasText = false;
  String _textBeforeDictation = '';

  // Liste des pièces jointes en attente d'envoi
  final List<ChatAttachment> _pendingAttachments = [];

  static const int _maxFileSizeBytes = 10 * 1024 * 1024; // 10 Mo

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
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _controller.text.length),
            );
          });
        },
      );
    }
  }

  /// Ouvre le menu modal pour choisir Image, Photo ou Fichier texte
  void _showAttachmentOptions() {
    if (widget.isStreaming) return;
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: SDChatColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: SDChatColors.borderMedium,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Ajouter une pièce jointe',
                  style: TextStyle(
                    color: SDChatColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Images, captures ou documents (max 10 Mo)',
                  style: TextStyle(
                    color: SDChatColors.textMuted,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 18),
                _buildAttachmentOptionTile(
                  icon: Icons.photo_library_rounded,
                  title: 'Galerie Photos',
                  subtitle: 'JPEG, PNG, WebP',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 10),
                _buildAttachmentOptionTile(
                  icon: Icons.camera_alt_rounded,
                  title: 'Prendre une Photo',
                  subtitle: 'Capture instantanée par l\'appareil',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 10),
                _buildAttachmentOptionTile(
                  icon: Icons.description_rounded,
                  title: 'Document texte ou code',
                  subtitle: '.txt, .md, .csv, .json, .dart, .py',
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickTextFile();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: SDChatColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SDChatColors.borderSubtle, width: 0.8),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: SDChatColors.surfaceHighlight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: SDChatColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: SDChatColors.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: SDChatColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13,
              color: SDChatColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  /// Sélection d'image via image_picker
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 88,
      );
      if (picked == null) return;

      final file = File(picked.path);
      final size = await file.length();

      if (size > _maxFileSizeBytes) {
        _showFeedbackSnackbar(
          'L\'image dépasse la taille maximale autorisée de 10 Mo.',
          isError: true,
        );
        return;
      }

      final fileName = picked.name.isNotEmpty ? picked.name : 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      _uploadAndAddAttachment(
        filePath: picked.path,
        fileName: fileName,
        fileType: 'image',
        mimeType: picked.mimeType ?? 'image/jpeg',
        fileSizeBytes: size,
      );
    } catch (e) {
      _showFeedbackSnackbar('Erreur lors de la sélection de l\'image: $e', isError: true);
    }
  }

  /// Sélection de fichier texte via file_picker
  Future<void> _pickTextFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'md', 'csv', 'log'],
      );

      if (result.isEmpty) return;
      final pickedFile = result.first;
      final path = pickedFile.path;
      if (path == null) return;

      final size = pickedFile.lengthSync() ?? (await File(path).length());
      if (size > _maxFileSizeBytes) {
        _showFeedbackSnackbar(
          'Le fichier texte dépasse la taille maximale autorisée de 10 Mo.',
          isError: true,
        );
        return;
      }

      final fileName = pickedFile.name;
      _uploadAndAddAttachment(
        filePath: path,
        fileName: fileName,
        fileType: 'text',
        mimeType: 'text/plain',
        fileSizeBytes: size,
      );
    } catch (e) {
      _showFeedbackSnackbar('Erreur lors de la sélection du fichier: $e', isError: true);
    }
  }

  /// Téléversement réel vers le backend Cloud et suivi d'état
  Future<void> _uploadAndAddAttachment({
    required String filePath,
    required String fileName,
    required String fileType,
    required String mimeType,
    required int fileSizeBytes,
  }) async {
    // Création d'un élément local temporaire
    final tempAttachment = ChatAttachment(
      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
      userId: '',
      fileName: fileName,
      fileType: fileType,
      storagePath: '',
      mimeType: mimeType,
      fileSizeBytes: fileSizeBytes,
      createdAt: DateTime.now(),
      localPath: filePath,
      isUploading: true,
      hasError: false,
    );

    setState(() {
      _pendingAttachments.add(tempAttachment);
    });

    try {
      final uploaded = await _chatApi.uploadAttachment(
        filePath: filePath,
        fileName: fileName,
        conversationId: widget.conversationId,
      );

      if (!mounted) return;

      setState(() {
        final index = _pendingAttachments.indexOf(tempAttachment);
        if (index != -1) {
          if (uploaded != null) {
            _pendingAttachments[index] = ChatAttachment(
              id: uploaded.id,
              conversationId: uploaded.conversationId,
              messageId: uploaded.messageId,
              userId: uploaded.userId,
              fileName: uploaded.fileName,
              fileType: uploaded.fileType,
              storagePath: uploaded.storagePath,
              mimeType: uploaded.mimeType,
              fileSizeBytes: uploaded.fileSizeBytes,
              createdAt: uploaded.createdAt,
              url: uploaded.url,
              localPath: filePath,
              isUploading: false,
              hasError: false,
            );
          } else {
            _pendingAttachments[index].isUploading = false;
            _pendingAttachments[index].hasError = true;
            _pendingAttachments[index].errorMessage = 'Échec du téléversement';
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final index = _pendingAttachments.indexOf(tempAttachment);
        if (index != -1) {
          _pendingAttachments[index].isUploading = false;
          _pendingAttachments[index].hasError = true;
          _pendingAttachments[index].errorMessage = '$e';
        }
      });
    }
  }

  /// Suppression d'une pièce jointe avant l'envoi
  Future<void> _removeAttachment(ChatAttachment att) async {
    HapticFeedback.selectionClick();
    setState(() {
      _pendingAttachments.remove(att);
    });

    // Si déjà uploadée sur le serveur, la supprimer
    if (!att.id.startsWith('local-')) {
      await _chatApi.deleteAttachment(att.id);
    }
  }

  void _handleSend() {
    if (_voice.isListening) {
      _voice.stopListening();
    }

    // Vérifier si des uploads sont encore en cours
    final isStillUploading = _pendingAttachments.any((a) => a.isUploading);
    if (isStillUploading) {
      _showFeedbackSnackbar('Veuillez patienter pendant le téléversement des pièces jointes...');
      return;
    }

    final validAttachments = _pendingAttachments.where((a) => !a.hasError).toList();
    final text = _controller.text.trim();

    if ((text.isNotEmpty || validAttachments.isNotEmpty) && !widget.isStreaming) {
      final promptToSend = text.isNotEmpty
          ? text
          : (validAttachments.length == 1
              ? 'Analyse ce document : ${validAttachments.first.fileName}'
              : 'Analyse ces pièces jointes jointes au message');

      widget.onSend(promptToSend, validAttachments);

      _controller.clear();
      _textBeforeDictation = '';
      setState(() {
        _hasText = false;
        _pendingAttachments.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isListening = _voice.isListening;
    final bool hasPendingAttachments = _pendingAttachments.isNotEmpty;
    final bool canSend = (_hasText || hasPendingAttachments) &&
        !_pendingAttachments.any((a) => a.isUploading);

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

          // Prévisualisation des pièces jointes en attente d'envoi
          if (hasPendingAttachments)
            Container(
              height: 72,
              margin: const EdgeInsets.fromLTRB(14, 8, 14, 2),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _pendingAttachments.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final att = _pendingAttachments[index];
                  return _buildAttachmentPreviewChip(att);
                },
              ),
            ),

          // Barre d'entrée principale
          Padding(
            padding: EdgeInsets.only(
              left: 14,
              right: 14,
              top: isListening ? 6 : 8,
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
                      : canSend
                          ? SDChatColors.primary.withValues(alpha: 0.5)
                          : SDChatColors.borderMedium,
                  width: isListening ? 1.2 : 0.8,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Bouton pièce jointe 📎
                  IconButton(
                    icon: const Icon(Icons.attach_file_rounded, size: 20),
                    color: hasPendingAttachments ? SDChatColors.primary : SDChatColors.textSecondary,
                    tooltip: 'Joindre une image ou un fichier texte',
                    onPressed: _showAttachmentOptions,
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
                              : hasPendingAttachments
                                  ? 'Ajoutez un commentaire (optionnel)...'
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
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        _toggleDictation();
                      },
                    ),
                  ),

                  // Bouton d'envoi ou stop
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 3),
                    child: widget.isStreaming
                        ? IconButton(
                            icon: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: SDChatColors.surfaceHighlight,
                                shape: BoxShape.circle,
                                border: Border.all(color: SDChatColors.primary, width: 1.2),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.stop_rounded,
                                  size: 16,
                                  color: SDChatColors.primary,
                                ),
                              ),
                            ),
                            tooltip: 'Arrêter la génération',
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              widget.onStop?.call();
                            },
                          )
                        : IconButton(
                            icon: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: canSend
                                    ? SDChatColors.primary
                                    : SDChatColors.surfaceHighlight,
                                shape: BoxShape.circle,
                                boxShadow: canSend
                                    ? [
                                        BoxShadow(
                                          color: SDChatColors.primary.withValues(alpha: 0.35),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.arrow_upward_rounded,
                                  size: 19,
                                  color: canSend
                                      ? SDChatColors.background
                                      : SDChatColors.textDisabled,
                                ),
                              ),
                            ),
                            tooltip: 'Envoyer',
                            onPressed: canSend
                                ? () {
                                    HapticFeedback.lightImpact();
                                    _handleSend();
                                  }
                                : null,
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

  /// Miniature pour chaque pièce jointe en attente avec jauge d'upload et bouton ✕
  Widget _buildAttachmentPreviewChip(ChatAttachment att) {
    return Container(
      width: 140,
      decoration: BoxDecoration(
        color: SDChatColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: att.hasError
              ? SDChatColors.error.withValues(alpha: 0.7)
              : SDChatColors.borderMedium,
          width: 0.8,
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                // Vignette ou icône
                if (att.isImage && att.localPath != null && File(att.localPath!).existsSync())
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(
                      File(att.localPath!),
                      width: 42,
                      height: 42,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: SDChatColors.surfaceHighlight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      att.isImage ? Icons.image_rounded : Icons.description_rounded,
                      color: SDChatColors.primary,
                      size: 22,
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        att.fileName,
                        style: const TextStyle(
                          color: SDChatColors.textPrimary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        att.hasError
                            ? 'Erreur'
                            : att.isUploading
                                ? 'Envoi...'
                                : att.formattedSize,
                        style: TextStyle(
                          color: att.hasError ? SDChatColors.error : SDChatColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Indicateur de chargement en overlay
          if (att.isUploading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: SDChatColors.primary,
                    ),
                  ),
                ),
              ),
            ),

          // Bouton supprimer ✕
          Positioned(
            top: 2,
            right: 2,
            child: InkWell(
              onTap: () => _removeAttachment(att),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: SDChatColors.surfaceHighlight,
                  shape: BoxShape.circle,
                  border: Border.all(color: SDChatColors.borderMedium, width: 0.5),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: SDChatColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
