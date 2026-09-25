import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/sd_chat_colors.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/chat_api_service.dart';
import '../../../core/services/sync_service.dart';
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
import '../../premium/screens/premium_screen.dart';

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
  Timer? _streamThrottleTimer;

  // Modèle IA sélectionné manuellement (débloqué pour plans VIP & Black)
  String? _selectedModel;

  // Erreurs et rechargements
  String? _lastErrorMessage;
  String? _lastFailedPrompt;
  List<ChatAttachment> _lastFailedAttachments = [];

  // Statut Quotas et Entitlements Free / Premium
  UserQuota? _userQuota;


  @override
  void initState() {
    super.initState();
    SyncService.instance.initialize();
    SyncService.instance.addListener(_onSyncChanged);
    _checkBackendConnection();
    _loadUserQuota();
  }

  void _onSyncChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    SyncService.instance.removeListener(_onSyncChanged);
    _streamThrottleTimer?.cancel();
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
    await SyncService.instance.checkConnectionStatus();
    if (mounted) {
      setState(() {});
    }
  }

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final maxExtent = _scrollController.position.maxScrollExtent;
        final current = _scrollController.position.pixels;
        if (force || (maxExtent - current < 200)) {
          _scrollController.animateTo(
            maxExtent,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
          );
        }
      }
    });
  }

  void _startNewChat() {
    HapticFeedback.lightImpact();
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
      _streamThrottleTimer?.cancel();
      _streamThrottleTimer = null;
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
      _lastFailedAttachments = [];
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
    _scrollToBottom(force: true);

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
      model: _selectedModel ?? (_currentConversation?.model ?? AppConfig.defaultModel),
      onInit: (convId, title) {
        if (mounted) {
          setState(() {
            _currentConversation ??= Conversation(
              id: convId,
              userId: '',
              title: title ?? 'Nouvelle discussion',
              model: _selectedModel ?? AppConfig.defaultModel,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
          });
        }
      },
      onToken: (token) {
        assistantMessage.content += token;
        if (_streamThrottleTimer == null || !_streamThrottleTimer!.isActive) {
          _streamThrottleTimer = Timer(const Duration(milliseconds: 40), () {
            if (mounted) {
              setState(() {});
              _scrollToBottom();
            }
          });
        }
      },
      onDone: (messageId, title) {
        _streamThrottleTimer?.cancel();
        _streamThrottleTimer = null;
        if (mounted) {
          setState(() {
            assistantMessage.isStreaming = false;
            _isStreaming = false;
            _lastErrorMessage = null;
            _lastFailedPrompt = null;
            _lastFailedAttachments = [];
            if (title != null && _currentConversation != null) {
              _currentConversation = _currentConversation!.copyWith(title: title);
            }
          });
          _scrollToBottom();
          _loadUserQuota();
        }
      },
      onError: (errorMsg) {
        _streamThrottleTimer?.cancel();
        _streamThrottleTimer = null;
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
            _lastFailedAttachments = List<ChatAttachment>.from(attachments);
          });
          if (errorMsg.contains('Serveur temporairement indisponible')) {
            SyncService.instance.checkConnectionStatus();
          }
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
      final attachments = List<ChatAttachment>.from(_lastFailedAttachments);

      // Retirer le dernier message assistant (vide ou interrompu) pour éviter tout orphelin
      if (_messages.isNotEmpty && _messages.last.isAssistant) {
        _messages.removeLast();
      }
      // Retirer le dernier message utilisateur correspondant pour éviter un doublon
      if (_messages.isNotEmpty && _messages.last.isUser && _messages.last.content == prompt) {
        _messages.removeLast();
      }
      _sendMessage(prompt, attachments: attachments);
    }
  }

  String _formatModelShortName(String model) {
    if (model.contains('claude-3-5-sonnet')) return 'Claude 3.5';
    if (model.contains('claude-3-5-haiku')) return 'Haiku';
    if (model.contains('claude-3-opus')) return 'Opus 3';
    if (model.contains('gpt-4o-mini')) return 'GPT-4o mini';
    if (model.contains('gpt-4o')) return 'GPT-4o';
    if (model.contains('o3-mini')) return 'o3-mini';
    if (model.contains('grok-2')) return 'Grok-2';
    if (model.contains('deepseek')) return 'DeepSeek';
    if (model.contains('gemini-1.5-pro')) return 'Gemini Pro';
    if (model.contains('gemini-3.6-flash')) return 'Gemini 3.6';
    if (model.contains('gemini-2.5-flash')) return 'Gemini 2.5';
    return model.split('/').last.split('-').first;
  }

  void _openModelSelector() {
    HapticFeedback.selectionClick();
    final canSelect = _userQuota?.canSelectModel ?? false;
    if (!canSelect) {
      showModalBottomSheet(
        context: context,
        backgroundColor: SDChatColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: SDChatColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.hub_rounded, color: SDChatColors.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SD AI Gateway • Mode Auto',
                            style: TextStyle(
                              color: SDChatColors.textPrimary,
                              fontSize: 16.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Formule actuelle : ${_userQuota?.planName ?? "SD FREE"}',
                            style: const TextStyle(
                              color: SDChatColors.textSecondary,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: SDChatColors.canvas,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: SDChatColors.borderSubtle),
                  ),
                  child: const Text(
                    'Le SD AI Gateway optimise automatiquement chaque requête vers le meilleur modèle pour garantir rapidité, intelligence et résilience.\n\nPour débloquer la sélection manuelle de tous les modèles (Claude 3.5 Sonnet, GPT-4o, Gemini 1.5 Pro, Grok), passez au plan SD VIP ou SD BLACK ULTRA.',
                    style: TextStyle(
                      color: SDChatColors.textSecondary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PremiumScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SDChatColors.primary,
                    foregroundColor: SDChatColors.background,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Découvrir les plans SD VIP & Black Ultra',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    // Modal de sélection pour utilisateurs VIP / BLACK
    showModalBottomSheet(
      context: context,
      backgroundColor: SDChatColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune_rounded, color: SDChatColors.primary, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Sélection du Modèle IA (SD Gateway)',
                      style: TextStyle(
                        color: SDChatColors.textPrimary,
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: SDChatColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _userQuota?.isBlack == true ? 'BLACK ULTRA' : 'VIP',
                      style: const TextStyle(
                        color: SDChatColors.primary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Bascule automatique garantie : si le modèle choisi est indisponible, le SD AI Gateway prend le relais de secours.',
                style: TextStyle(color: SDChatColors.textMuted, fontSize: 11.5),
              ),
              const SizedBox(height: 14),
              const Divider(color: SDChatColors.borderSubtle, height: 1),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  children: [
                    _buildModelOptionTile(
                      ctx,
                      modelId: null,
                      displayName: 'SD AI Gateway (Auto)',
                      providerName: 'Routage automatique optimisé',
                      icon: Icons.auto_awesome_rounded,
                      isSpecial: true,
                    ),
                    _buildModelOptionTile(
                      ctx,
                      modelId: 'gemini-3.6-flash',
                      displayName: 'Gemini 3.6 Flash',
                      providerName: 'Google DeepMind • Vitesse & Raisonnement',
                      icon: Icons.bolt_rounded,
                    ),
                    _buildModelOptionTile(
                      ctx,
                      modelId: 'gemini-2.5-flash',
                      displayName: 'Gemini 2.5 Flash',
                      providerName: 'Google • Équilibré & Rapide',
                      icon: Icons.bolt_rounded,
                    ),
                    _buildModelOptionTile(
                      ctx,
                      modelId: 'gemini-1.5-pro',
                      displayName: 'Gemini 1.5 Pro',
                      providerName: 'Google • Contexte géant 2M tokens',
                      icon: Icons.psychology_rounded,
                    ),
                    _buildModelOptionTile(
                      ctx,
                      modelId: 'claude-3-5-sonnet-20241022',
                      displayName: 'Claude 3.5 Sonnet',
                      providerName: 'Anthropic • Code & Analyse avancée',
                      icon: Icons.auto_stories_rounded,
                    ),
                    _buildModelOptionTile(
                      ctx,
                      modelId: 'claude-3-5-haiku-20241022',
                      displayName: 'Claude 3.5 Haiku',
                      providerName: 'Anthropic • Ultra-rapide & Concis',
                      icon: Icons.speed_rounded,
                    ),
                    _buildModelOptionTile(
                      ctx,
                      modelId: 'gpt-4o',
                      displayName: 'GPT-4o',
                      providerName: 'OpenAI • Multimodal & Polyvalent',
                      icon: Icons.hub_outlined,
                    ),
                    _buildModelOptionTile(
                      ctx,
                      modelId: 'gpt-4o-mini',
                      displayName: 'GPT-4o mini',
                      providerName: 'OpenAI • Économique & Réactif',
                      icon: Icons.flash_on_rounded,
                    ),
                    _buildModelOptionTile(
                      ctx,
                      modelId: 'o3-mini',
                      displayName: 'o3-mini',
                      providerName: 'OpenAI • Raisonnement logique poussé',
                      icon: Icons.science_rounded,
                    ),
                    _buildModelOptionTile(
                      ctx,
                      modelId: 'grok-2-1212',
                      displayName: 'Grok-2',
                      providerName: 'xAI • Connaissances temps réel',
                      icon: Icons.explore_rounded,
                    ),
                    _buildModelOptionTile(
                      ctx,
                      modelId: 'deepseek/deepseek-chat',
                      displayName: 'DeepSeek V3',
                      providerName: 'OpenRouter • Efficacité & Mathématiques',
                      icon: Icons.terminal_rounded,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModelOptionTile(
    BuildContext ctx, {
    required String? modelId,
    required String displayName,
    required String providerName,
    required IconData icon,
    bool isSpecial = false,
  }) {
    final isSelected = (_selectedModel == modelId);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected
                ? SDChatColors.primary
                : SDChatColors.borderSubtle,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        tileColor: isSelected
            ? SDChatColors.primary.withValues(alpha: 0.1)
            : SDChatColors.canvas,
        leading: Icon(
          icon,
          color: isSelected ? SDChatColors.primary : SDChatColors.textSecondary,
          size: 22,
        ),
        title: Text(
          displayName,
          style: TextStyle(
            color: isSelected ? SDChatColors.primary : SDChatColors.textPrimary,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          ),
        ),
        subtitle: Text(
          providerName,
          style: const TextStyle(color: SDChatColors.textMuted, fontSize: 11.5),
        ),
        trailing: isSelected
            ? const Icon(Icons.check_circle_rounded, color: SDChatColors.primary, size: 20)
            : null,
        onTap: () {
          Navigator.pop(ctx);
          setState(() {
            _selectedModel = modelId;
          });
        },
      ),
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
          onPressed: () {
            HapticFeedback.selectionClick();
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: SDChatColors.textPrimary,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                SyncService.instance.syncAll(force: true);
                _checkBackendConnection();
              },
              borderRadius: BorderRadius.circular(4),
              child: AnimatedBuilder(
                animation: SyncService.instance,
                builder: (context, _) {
                  final sync = SyncService.instance;
                  final status = sync.status;

                  Color indicatorColor;
                  String statusText;
                  bool showSpinner = false;

                  switch (status) {
                    case SyncState.synced:
                      indicatorColor = SDChatColors.online;
                      statusText = 'Connecté • En ligne';
                      break;
                    case SyncState.syncing:
                      indicatorColor = SDChatColors.primary;
                      statusText = 'Synchronisation…';
                      showSpinner = true;
                      break;
                    case SyncState.serverUnavailable:
                      indicatorColor = SDChatColors.warning;
                      statusText = 'Serveur temporairement indisponible';
                      break;
                    case SyncState.offline:
                    case SyncState.error:
                      indicatorColor = SDChatColors.error;
                      statusText = 'Hors ligne • Données locales';
                      break;
                  }

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showSpinner)
                        const SizedBox(
                          width: 8,
                          height: 8,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: SDChatColors.primary,
                          ),
                        )
                      else
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: indicatorColor,
                            shape: BoxShape.circle,
                            boxShadow: (status == SyncState.synced)
                                ? [
                                    BoxShadow(
                                      color: SDChatColors.online.withValues(alpha: 0.5),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      const SizedBox(width: 5),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11,
                          color: (status == SyncState.serverUnavailable || status == SyncState.offline)
                              ? indicatorColor
                              : SDChatColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          // Sélecteur de Modèle IA (SD AI Gateway)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
            child: InkWell(
              onTap: _openModelSelector,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: (_userQuota?.canSelectModel == true && _selectedModel != null)
                      ? SDChatColors.primary.withValues(alpha: 0.18)
                      : SDChatColors.surfaceHighlight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (_userQuota?.canSelectModel == true && _selectedModel != null)
                        ? SDChatColors.primary.withValues(alpha: 0.6)
                        : SDChatColors.borderSubtle,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      (_userQuota?.canSelectModel == true && _selectedModel != null)
                          ? Icons.psychology_rounded
                          : Icons.hub_rounded,
                      size: 13,
                      color: (_userQuota?.canSelectModel == true && _selectedModel != null)
                          ? SDChatColors.primary
                          : SDChatColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _selectedModel != null
                          ? _formatModelShortName(_selectedModel!)
                          : 'Auto',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: (_userQuota?.canSelectModel == true && _selectedModel != null)
                            ? SDChatColors.primary
                            : SDChatColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 13, color: SDChatColors.textMuted),
                  ],
                ),
              ),
            ),
          ),
          if (_userQuota != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  QuotaDialog.show(context, _userQuota!, onRefresh: _loadUserQuota);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                    boxShadow: _userQuota!.isPremium
                        ? [
                            BoxShadow(
                              color: SDChatColors.primary.withValues(alpha: 0.15),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
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
                          fontWeight: FontWeight.w700,
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
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
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
                            return const RepaintBoundary(child: TypingIndicator());
                          }
                          return RepaintBoundary(
                            key: ValueKey(msg.id),
                            child: MessageBubble(
                              message: msg,
                              onEdit: msg.isUser ? _handleEditUserMessage : null,
                            ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SDChatColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SDChatColors.error.withValues(alpha: 0.45), width: 1),
        boxShadow: [
          BoxShadow(
            color: SDChatColors.error.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: SDChatColors.error.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline_rounded, color: SDChatColors.error, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Une erreur est survenue',
                  style: TextStyle(
                    color: SDChatColors.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: SDChatColors.primary, width: 0.8),
              ),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              _retryLastFailedMessage();
            },
            child: const Text('Réessayer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
