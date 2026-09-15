import 'package:flutter/material.dart';
import '../../../core/theme/sd_chat_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/chat_api_service.dart';
import '../../../shared/models/conversation.dart';

class ConversationsDrawer extends StatefulWidget {
  final String? activeConversationId;
  final ValueChanged<Conversation> onSelectConversation;
  final VoidCallback onNewChat;

  const ConversationsDrawer({
    super.key,
    required this.activeConversationId,
    required this.onSelectConversation,
    required this.onNewChat,
  });

  @override
  State<ConversationsDrawer> createState() => _ConversationsDrawerState();
}

class _ConversationsDrawerState extends State<ConversationsDrawer> {
  final ChatApiService _chatApi = ChatApiService();
  final AuthService _auth = AuthService();

  List<Conversation> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    final list = await _chatApi.fetchConversations();
    if (mounted) {
      setState(() {
        _conversations = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteConversation(Conversation conv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SDChatColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer la conversation ?'),
        content: Text(
          'Cette action supprimera définitivement "${conv.title}" et tous ses messages.',
          style: const TextStyle(color: SDChatColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: SDChatColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: SDChatColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _chatApi.deleteConversation(conv.id);
      if (success && mounted) {
        setState(() {
          _conversations.removeWhere((c) => c.id == conv.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conversation supprimée'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: SDChatColors.canvas,
      child: SafeArea(
        child: Column(
          children: [
            // Bouton "+ Nouveau Chat"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  widget.onNewChat();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: SDChatColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: SDChatColors.primary.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded, color: SDChatColors.primary, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Nouveau chat',
                        style: TextStyle(
                          color: SDChatColors.primary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Divider(color: SDChatColors.borderSubtle),

            // Liste de l'historique
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: SDChatColors.primary,
                      ),
                    )
                  : _conversations.isEmpty
                      ? const Center(
                          child: Text(
                            'Aucune discussion enregistrée',
                            style: TextStyle(
                              color: SDChatColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          color: SDChatColors.primary,
                          backgroundColor: SDChatColors.surface,
                          onRefresh: _loadConversations,
                          child: ListView.builder(
                            itemCount: _conversations.length,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            itemBuilder: (context, index) {
                              final conv = _conversations[index];
                              final isActive = conv.id == widget.activeConversationId;

                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 2),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? SDChatColors.surfaceElevated
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: isActive
                                      ? const Border(
                                          left: BorderSide(
                                            color: SDChatColors.primary,
                                            width: 3,
                                          ),
                                        )
                                      : null,
                                ),
                                child: ListTile(
                                  dense: true,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  title: Text(
                                    conv.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isActive
                                          ? SDChatColors.textPrimary
                                          : SDChatColors.textSecondary,
                                      fontSize: 13.5,
                                      fontWeight: isActive
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                                    color: SDChatColors.textDisabled,
                                    tooltip: 'Supprimer',
                                    onPressed: () => _deleteConversation(conv),
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    widget.onSelectConversation(conv);
                                  },
                                ),
                              );
                            },
                          ),
                        ),
            ),

            const Divider(color: SDChatColors.borderSubtle),

            // Pied de page Utilisateur & Déconnexion
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: SDChatColors.surfaceHighlight,
                    backgroundImage: _auth.currentAvatarUrl != null
                        ? NetworkImage(_auth.currentAvatarUrl!)
                        : null,
                    child: _auth.currentAvatarUrl == null
                        ? const Icon(Icons.person_rounded, size: 18, color: SDChatColors.primary)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _auth.currentUserName ?? 'Utilisateur SD',
                          style: const TextStyle(
                            color: SDChatColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _auth.currentUserEmail ?? '',
                          style: const TextStyle(
                            color: SDChatColors.textMuted,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    color: SDChatColors.textMuted,
                    tooltip: 'Déconnexion',
                    onPressed: () => _auth.signOut(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
