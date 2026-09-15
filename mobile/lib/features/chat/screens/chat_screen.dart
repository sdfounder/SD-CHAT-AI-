import 'package:flutter/material.dart';
import '../../../core/theme/sd_chat_colors.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/chat_api_service.dart';
import '../../../shared/models/conversation.dart';
import '../../../shared/models/chat_message.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/message_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/empty_chat_hero.dart';
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
    setState(() {
      _currentConversation = null;
      _messages = [];
      _isStreaming = false;
    });
  }

  Future<void> _loadConversation(Conversation conv) async {
    setState(() {
      _currentConversation = conv;
      _isLoading = true;
      _messages = [];
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

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isStreaming) return;

    // 1. Ajouter le message de l'utilisateur dans l'UI immédiatement
    final userMessage = ChatMessage(
      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: _currentConversation?.id ?? '',
      userId: '',
      role: MessageRole.user,
      content: text,
      createdAt: DateTime.now(),
    );

    // 2. Préparer le message de l'assistant (vide pour le streaming)
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

    // 3. Déclencher le streaming SSE vers le backend
    await _chatApi.streamChatMessage(
      conversationId: _currentConversation?.id,
      content: text,
      model: AppConfig.defaultModel,
      onInit: (convId, title) {
        if (mounted) {
          setState(() {
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
            if (title != null && _currentConversation != null) {
              _currentConversation = _currentConversation!.copyWith(title: title);
            }
          });
          _scrollToBottom();
        }
      },
      onError: (errorMsg) {
        if (mounted) {
          setState(() {
            assistantMessage.content += '\n\n*[$errorMsg]*';
            assistantMessage.isStreaming = false;
            _isStreaming = false;
          });
          _scrollToBottom();
        }
      },
    );
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
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: SDChatColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: SDChatColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  'Gemini 3.6 Flash',
                  style: TextStyle(
                    fontSize: 11,
                    color: SDChatColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, size: 22, color: SDChatColors.textSecondary),
            tooltip: 'Nouveau chat',
            onPressed: _startNewChat,
          ),
        ],
      ),
      drawer: ConversationsDrawer(
        activeConversationId: _currentConversation?.id,
        onSelectConversation: _loadConversation,
        onNewChat: _startNewChat,
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
                    ? EmptyChatHero(onSelectPrompt: _sendMessage)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(top: 8, bottom: 16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          // Indicateur de frappe si l'assistant attend le premier token
                          if (msg.isAssistant && msg.isStreaming && msg.content.isEmpty) {
                            return const TypingIndicator();
                          }
                          return MessageBubble(message: msg);
                        },
                      ),
          ),
          ChatInputBar(
            onSend: _sendMessage,
            isStreaming: _isStreaming,
            onStop: () {
              setState(() => _isStreaming = false);
            },
          ),
        ],
      ),
    );
  }
}
