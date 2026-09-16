import 'package:flutter/material.dart';
import '../../../core/theme/sd_chat_colors.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/chat_api_service.dart';
import '../../../shared/models/conversation.dart';
import '../../../shared/models/chat_message.dart';
import '../../../shared/models/chat_attachment.dart';
import '../../../shared/models/user_quota.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/message_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/empty_chat_hero.dart';
import '../widgets/quota_dialog.dart';
import '../../conversations/widgets/conversations_drawer.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatApiService _chatApi = ChatApiService();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Conversation? _currentConversation;
  List<ChatMessage> _messages = [];

  bool _isLoading = false;
  bool _isStreaming = false;
  ChatStreamHandle? _currentStreamHandle;

  // État de connexion au backend Cloud
  bool _isBackendConnected = true;
  String? _lastErrorMessage;
  String? _lastFailedPrompt;

  // Statut Quotas et Entitlements Free / Premium
  UserQuota? _userQuota;

  @override
  void initState() {
    super.initState();
    _checkBackendConnection();
    _loadUserQuota();
  }

  @override
  void dispose() {
    _currentStreamHandle?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserQuota() async {
    final quota = await _chatApi.fetchUserQuota();
    if (mounted && quota != null) {
      setState(() {
        _userQuota = quota;
      });
    }
  }

  Future<void> _checkBackendConnection() async {
    final health = await _chatApi.checkHealth();
    if (mounted) {
      setState(() {
        _isBackendConnected = (health != null && health['status'] == 'online');
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _startNewChat() {
    _currentStreamHandle?.cancel();
    setState(() {
      _currentConversation = null;
      _messages = [];
      _isStreaming = false;
      _lastErrorMessage = null;
      _lastFailedPrompt = null;
    });
  }

  Future<void> _loadConversation(Conversation conv) async {
    _currentStreamHandle?.cancel();
    setState(() {
      _currentConversation = conv;
      _isLoading = true;
      _messages = [];
      _isStreaming = false;
      _lastErrorMessage = null;
      _lastFailedPrompt = null;
    });

    final detail = await _chatApi.fetchConversationDetail(conv.id);
    if (mounted) {
      setState(() {
        if (detail != null) {
          _currentConversation = detail['conversation'] as Conversation;
          _messages = detail['messages'] as List<ChatMessage>;
        }
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _stopGeneration() {
    if (_isStreaming) {
      _currentStreamHandle?.cancel();
      setState(() {
        _isStreaming = false;
        if (_messages.isNotEmpty && _messages.last.isAssistant && _messages.last.isStreaming) {
          _messages.last.isStreaming = false;
        }
      });
    }
  }

  Future<void> _sendMessage(
    String text, {
    List<ChatAttachment> attachments = const [],
    String? editMessageId,
  }) async {
    if ((text.trim().isEmpty && attachments.isEmpty) || _isStreaming) return;

    setState(() {
      _lastErrorMessage = null;
      _lastFailedPrompt = null;
    });

    // 1. Si modification, remplacer le message existant et tronquer la suite
    if (editMessageId != null) {
      final editIdx = _messages.indexWhere((m) => m.id == editMessageId);
      if (editIdx != -1) {
        _messages = _messages.sublist(0, editIdx);
      }
    }

    // 2. Ajouter le message de l'utilisateur avec ses pièces jointes
    final userMessage = ChatMessage(
      id: editMessageId ?? 'local-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: _currentConversation?.id ?? '',
      userId: '',
      role: MessageRole.user,
      content: text,
      attachments: attachments,
      createdAt: DateTime.now(),
    );

    // 3. Préparer le message de l'assistant (vide pour le streaming SSE)
    final assistantMessage = ChatMessage(
      id: 'assistant-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: _currentConversation?.id ?? '',
      userId: '',
      role: MessageRole.assistant,
      content: '',
      createdAt: DateTime.now(),
      isStreaming: true,
    );

    setState(() {
      _messages.add(userMessage);
      _messages.add(assistantMessage);
      _isStreaming = true;
    });
    _scrollToBottom();

    // 4. Déclencher le streaming SSE vers le backend FastAPI Cloud
    final attachmentIds = attachments
        .map((a) => a.id)
        .where((id) => !id.startsWith('local-'))
        .toList();

    _currentStreamHandle = _chatApi.streamChatMessage(
      conversationId: _currentConversation?.id,
      content: text,
      editMessageId: editMessageId,
      attachmentIds: attachmentIds.isNotEmpty ? attachmentIds : null,
      model: AppConfig.defaultModel,
      onInit: (convId, title) {
        if (mounted) {
          setState(() {
            _isBackendConnected = true;
            _currentConversation ??= Conversation(
              id: convId,
              userId: '',
              title: title ?? 'Nouvelle discussion',
              model: AppConfig.defaultModel,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
          });
        }
      },
      onToken: (token) {
        if (mounted) {
          setState(() {
            assistantMessage.content += token;
          });
          _scrollToBottom();
        }
      },
      onDone: (messageId, title) {
        if (mounted) {
          setState(() {
            assistantMessage.isStreaming = false;
            _isStreaming = false;
            _lastErrorMessage = null;
            if (title != null && _currentConversation != null) {
              _currentConversation = _currentConversation!.copyWith(title: title);
            }
          });
          _scrollToBottom();
          _loadUserQuota();
        }
      },
      onError: (errorMsg) {
        if (mounted) {
          final isQuotaErr = errorMsg.contains('QUOTA_EXCEEDED') ||
              errorMsg.contains('ATTACHMENTS_QUOTA_EXCEEDED') ||
              errorMsg.toLowerCase().contains('quota') ||
              errorMsg.contains('429');

          setState(() {
            assistantMessage.isStreaming = false;
            _isStreaming = false;
            _lastErrorMessage = errorMsg;
            _lastFailedPrompt = text;
            if (!isQuotaErr) {
              _isBackendConnected = false;
            }
          });
          _scrollToBottom();

          if (isQuotaErr) {
            _loadUserQuota().then((_) {
              if (mounted && _userQuota != null) {
                QuotaDialog.show(context, _userQuota!, onRefresh: _loadUserQuota);
              }
            });
          }
        }
      },
    );
  }

  /// Modifier un message existant et régénérer la réponse
  Future<void> _handleEditUserMessage(ChatMessage message) async {
    final controller = TextEditingController(text: message.content);

    final editedText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SDChatColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Modifier le message',
          style: TextStyle(color: SDChatColors.textPrimary, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          maxLines: 5,
          minLines: 1,
          autofocus: true,
          style: const TextStyle(color: SDChatColors.textPrimary, fontSize: 14.5),
          decoration: InputDecoration(
            hintText: 'Votre nouveau message...',
            hintStyle: const TextStyle(color: SDChatColors.textMuted),
            fillColor: SDChatColors.surfaceElevated,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: SDChatColors.borderMedium),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: SDChatColors.primary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Annuler', style: TextStyle(color: SDChatColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: SDChatColors.primary,
              foregroundColor: SDChatColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Régénérer', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (editedText != null && editedText.isNotEmpty) {
      await _sendMessage(editedText, editMessageId: message.id);
    }
  }

  void _retryLastFailedMessage() {
    if (_lastFailedPrompt != null && !_isStreaming) {
      final prompt = _lastFailedPrompt!;
      // Retirer le dernier message assistant d'erreur s'il est vide
      if (_messages.isNotEmpty && _messages.last.isAssistant && _messages.last.content.isEmpty) {
        _messages.removeLast();
      }
      // Retirer le dernier message user échoué pour qu'il soit réinséré proprement
      if (_messages.isNotEmpty && _messages.last.isUser && _messages.last.content == prompt) {
        _messages.removeLast();
      }
      _sendMessage(prompt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _currentConversation?.title ?? 'SD CHAT AI';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: SDChatColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: SDChatColors.textPrimary),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                color: SDChatColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            InkWell(
              onTap: _checkBackendConnection,
              borderRadius: BorderRadius.circular(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _isBackendConnected ? SDChatColors.primary : SDChatColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _isBackendConnected ? 'Gemini 3.6 Flash • En ligne' : 'Déconnecté • Réessayer',
                    style: TextStyle(
                      fontSize: 11,
                      color: _isBackendConnected ? SDChatColors.textMuted : SDChatColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_userQuota != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: InkWell(
                onTap: () => QuotaDialog.show(context, _userQuota!, onRefresh: _loadUserQuota),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: _userQuota!.isPremium
                        ? SDChatColors.primary.withValues(alpha: 0.15)
                        : (_userQuota!.isQuotaExceeded
                            ? SDChatColors.error.withValues(alpha: 0.15)
                            : SDChatColors.surfaceHighlight),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _userQuota!.isPremium
                          ? SDChatColors.primary.withValues(alpha: 0.6)
                          : (_userQuota!.isQuotaExceeded
                              ? SDChatColors.error.withValues(alpha: 0.5)
                              : SDChatColors.borderSubtle),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _userQuota!.isPremium
                            ? Icons.workspace_premium_rounded
                            : Icons.bolt_rounded,
                        size: 14,
                        color: _userQuota!.isPremium
                            ? SDChatColors.primary
                            : (_userQuota!.isQuotaExceeded
                                ? SDChatColors.error
                                : SDChatColors.textSecondary),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _userQuota!.isPremium
                            ? 'Premium'
                            : '${_userQuota!.messagesRemaining}/${_userQuota!.messagesLimit}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _userQuota!.isPremium
                              ? SDChatColors.primary
                              : (_userQuota!.isQuotaExceeded
                                  ? SDChatColors.error
                                  : SDChatColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, size: 24, color: SDChatColors.textSecondary),
            tooltip: 'Nouveau chat',
            onPressed: _startNewChat,
          ),
        ],
      ),
      drawer: ConversationsDrawer(
        activeConversationId: _currentConversation?.id,
        onSelectConversation: _loadConversation,
        onNewChat: _startNewChat,
        onConversationRenamed: (newTitle) {
          if (_currentConversation != null) {
            setState(() {
              _currentConversation = _currentConversation!.copyWith(title: newTitle);
            });
          }
        },
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: SDChatColors.primary,
                    ),
                  )
                : _messages.isEmpty
                    ? EmptyChatHero(onSelectPrompt: (p) => _sendMessage(p))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(top: 8, bottom: 16),
                        itemCount: _messages.length + (_lastErrorMessage != null ? 1 : 0),
                        itemBuilder: (context, index) {
                          // Affichage de la carte d'erreur et bouton Réessayer
                          if (index == _messages.length && _lastErrorMessage != null) {
                            return _buildErrorCard();
                          }

                          final msg = _messages[index];
                          // Indicateur de frappe si l'assistant attend le premier token
                          if (msg.isAssistant && msg.isStreaming && msg.content.isEmpty) {
                            return const TypingIndicator();
                          }
                          return MessageBubble(
                            message: msg,
                            onEdit: msg.isUser ? _handleEditUserMessage : null,
                          );
                        },
                      ),
          ),
          ChatInputBar(
            conversationId: _currentConversation?.id,
            onSend: (text, atts) => _sendMessage(text, attachments: atts),
            isStreaming: _isStreaming,
            onStop: _stopGeneration,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SDChatColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SDChatColors.error.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: SDChatColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Une erreur est survenue',
                  style: TextStyle(
                    color: SDChatColors.error,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _lastErrorMessage ?? 'Vérifiez la connexion au backend Cloud',
                  style: const TextStyle(
                    color: SDChatColors.textSecondary,
                    fontSize: 11.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: SDChatColors.surfaceHighlight,
              foregroundColor: SDChatColors.primary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: SDChatColors.primary, width: 0.8),
              ),
            ),
            onPressed: _retryLastFailedMessage,
            child: const Text('Réessayer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
