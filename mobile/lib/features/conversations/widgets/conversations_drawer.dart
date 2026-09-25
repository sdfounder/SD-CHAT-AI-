import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/sd_chat_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/chat_api_service.dart';
import '../../../core/services/sync_service.dart';
import '../../../shared/models/conversation.dart';
import '../../../shared/models/user_quota.dart';
import '../../chat/widgets/quota_dialog.dart';
import '../../premium/screens/premium_screen.dart';
import '../../settings/screens/settings_screen.dart';

class ConversationsDrawer extends StatefulWidget {
  final String? activeConversationId;
  final ValueChanged<Conversation> onSelectConversation;
  final VoidCallback onNewChat;
  final ValueChanged<String>? onConversationRenamed;

  const ConversationsDrawer({
    super.key,
    required this.activeConversationId,
    required this.onSelectConversation,
    required this.onNewChat,
    this.onConversationRenamed,
  });

  @override
  State<ConversationsDrawer> createState() => _ConversationsDrawerState();
}

class _ConversationsDrawerState extends State<ConversationsDrawer> {
  final ChatApiService _chatApi = ChatApiService();
  final AuthService _auth = AuthService();

  List<Conversation> _allConversations = [];
  UserQuota? _userQuota;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _chatApi.fetchConversations(includeArchived: true),
        _chatApi.fetchUserQuota(),
      ]);

      if (mounted) {
        final convs = results[0] as List<Conversation>;
        final quota = results[1] as UserQuota?;
        final failed = _chatApi.lastFetchHadError && convs.isEmpty;

        setState(() {
          _allConversations = convs;
          _userQuota = quota;
          _isLoading = false;
          _hasError = failed;
          if (failed) {
            _errorMessage = SyncService.instance.isOffline
                ? 'Mode hors ligne : aucune discussion locale enregistrée.'
                : 'Connexion au serveur impossible.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = _allConversations.isEmpty;
          _errorMessage = SyncService.instance.isOffline
              ? 'Mode hors ligne (données locales)'
              : 'Erreur réseau temporaire.';
        });
      }
    }
  }

  List<Conversation> get _displayedConversations {
    return _allConversations
        .where((c) => c.isArchived == _showArchived)
        .toList();
  }

  Future<void> _renameConversation(Conversation conv) async {
    final controller = TextEditingController(text: conv.title);

    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SDChatColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Renommer la conversation',
          style: TextStyle(color: SDChatColors.textPrimary, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: SDChatColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Titre de la conversation',
            hintStyle: const TextStyle(color: SDChatColors.textMuted),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: SDChatColors.primary.withValues(alpha: 0.5)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: SDChatColors.primary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Annuler', style: TextStyle(color: SDChatColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Enregistrer', style: TextStyle(color: SDChatColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle.isNotEmpty && newTitle != conv.title) {
      final success = await _chatApi.updateConversation(conv.id, title: newTitle);
      if (success && mounted) {
        setState(() {
          final index = _allConversations.indexWhere((c) => c.id == conv.id);
          if (index != -1) {
            _allConversations[index] = _allConversations[index].copyWith(title: newTitle);
          }
        });
        widget.onConversationRenamed?.call(newTitle);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conversation renommée'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _toggleArchive(Conversation conv) async {
    final newArchivedState = !conv.isArchived;
    final success = await _chatApi.updateConversation(conv.id, isArchived: newArchivedState);
    if (success && mounted) {
      setState(() {
        final index = _allConversations.indexWhere((c) => c.id == conv.id);
        if (index != -1) {
          _allConversations[index] = _allConversations[index].copyWith(isArchived: newArchivedState);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newArchivedState ? 'Discussion archivée' : 'Discussion désarchivée'),
          duration: const Duration(seconds: 1),
        ),
      );
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
          'Cette action supprimera définitivement "${conv.title}" et tous ses messages de Supabase.',
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
          _allConversations.removeWhere((c) => c.id == conv.id);
        });
        if (widget.activeConversationId == conv.id) {
          widget.onNewChat();
        }
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
    final displayedList = _displayedConversations;
    final archivedCount = _allConversations.where((c) => c.isArchived).length;
    final activeCount = _allConversations.where((c) => !c.isArchived).length;

    return Drawer(
      backgroundColor: SDChatColors.canvas,
      child: SafeArea(
        child: Column(
          children: [
            // Bouton "+ Nouveau Chat"
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                  widget.onNewChat();
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: SDChatColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: SDChatColors.primary.withValues(alpha: 0.55),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: SDChatColors.primary.withValues(alpha: 0.12),
                        blurRadius: 14,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded, color: SDChatColors.primary, size: 21),
                      SizedBox(width: 8),
                      Text(
                        'Nouveau chat',
                        style: TextStyle(
                          color: SDChatColors.primary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Indicateur de synchronisation discret & premium
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: AnimatedBuilder(
                animation: SyncService.instance,
                builder: (context, _) {
                  final sync = SyncService.instance;
                  final isSyncing = sync.status == SyncState.syncing;

                  Color dotColor;
                  switch (sync.status) {
                    case SyncState.synced:
                      dotColor = SDChatColors.online;
                      break;
                    case SyncState.syncing:
                      dotColor = SDChatColors.primary;
                      break;
                    case SyncState.serverUnavailable:
                      dotColor = SDChatColors.warning;
                      break;
                    case SyncState.offline:
                    case SyncState.error:
                      dotColor = SDChatColors.error;
                      break;
                  }

                  return Row(
                    children: [
                      Container(
                        width: 6.5,
                        height: 6.5,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          sync.statusLabel,
                          style: TextStyle(
                            color: (sync.isServerUnavailable || sync.isOffline) ? dotColor : SDChatColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isSyncing)
                        InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            sync.syncAll(force: true);
                            _loadConversations();
                          },
                          child: const Icon(
                            Icons.sync_rounded,
                            size: 14,
                            color: SDChatColors.textMuted,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),

            // Sélecteur Onglets : Discussions Actives / Archives
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
              child: Row(
                children: [
                  Expanded(
                    child: _buildFilterChip(
                      label: 'Actives ($activeCount)',
                      isSelected: !_showArchived,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _showArchived = false);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFilterChip(
                      label: 'Archives ($archivedCount)',
                      isSelected: _showArchived,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _showArchived = true);
                      },
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: SDChatColors.borderSubtle, height: 16),

            // Liste de l'historique
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: SDChatColors.primary,
                      ),
                    )
                  : _hasError && _allConversations.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.cloud_off_rounded,
                                  size: 36,
                                  color: SDChatColors.error,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _errorMessage ?? 'Erreur de synchronisation',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: SDChatColors.textMuted,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: SDChatColors.primary,
                                    foregroundColor: SDChatColors.background,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                  onPressed: _loadConversations,
                                  icon: const Icon(Icons.refresh_rounded, size: 16),
                                  label: const Text('Réessayer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        )
                      : displayedList.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _showArchived ? Icons.archive_outlined : Icons.chat_bubble_outline_rounded,
                                    size: 32,
                                    color: SDChatColors.borderHighlight,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _showArchived
                                        ? 'Aucune discussion archivée'
                                        : 'Aucune discussion pour l\'instant',
                                    style: const TextStyle(
                                      color: SDChatColors.textMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            )
                      : RefreshIndicator(
                          color: SDChatColors.primary,
                          backgroundColor: SDChatColors.surface,
                          onRefresh: _loadConversations,
                          child: ListView.builder(
                            itemCount: displayedList.length,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            itemBuilder: (context, index) {
                              final conv = displayedList[index];
                              final isActive = conv.id == widget.activeConversationId;

                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 2.5),
                                decoration: BoxDecoration(
                                  gradient: isActive
                                      ? LinearGradient(
                                          colors: [
                                            SDChatColors.primary.withValues(alpha: 0.14),
                                            SDChatColors.surfaceElevated,
                                          ],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        )
                                      : null,
                                  color: isActive ? null : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: isActive
                                      ? const Border(
                                          left: BorderSide(
                                            color: SDChatColors.primary,
                                            width: 3.5,
                                          ),
                                        )
                                      : null,
                                ),
                                child: ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.only(left: 12, right: 4),
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
                                  trailing: PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert_rounded, size: 18, color: SDChatColors.textMuted),
                                    color: SDChatColors.surface,
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: const BorderSide(color: SDChatColors.borderMedium, width: 0.8),
                                    ),
                                    onSelected: (value) {
                                      switch (value) {
                                        case 'rename':
                                          _renameConversation(conv);
                                          break;
                                        case 'archive':
                                          _toggleArchive(conv);
                                          break;
                                        case 'delete':
                                          _deleteConversation(conv);
                                          break;
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(
                                        value: 'rename',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit_outlined, size: 16, color: SDChatColors.textSecondary),
                                            SizedBox(width: 8),
                                            Text('Renommer', style: TextStyle(color: SDChatColors.textPrimary, fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'archive',
                                        child: Row(
                                          children: [
                                            Icon(
                                              conv.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                                              size: 16,
                                              color: SDChatColors.textSecondary,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              conv.isArchived ? 'Désarchiver' : 'Archiver',
                                              style: const TextStyle(color: SDChatColors.textPrimary, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline_rounded, size: 16, color: SDChatColors.error),
                                            SizedBox(width: 8),
                                            Text('Supprimer', style: TextStyle(color: SDChatColors.error, fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                    ],
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
            if (_userQuota != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    QuotaDialog.show(context, _userQuota!, onRefresh: _loadConversations);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _userQuota!.isPremium
                          ? SDChatColors.primary.withValues(alpha: 0.12)
                          : SDChatColors.surfaceHighlight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _userQuota!.isPremium
                            ? SDChatColors.primary.withValues(alpha: 0.5)
                            : SDChatColors.borderSubtle,
                        width: 0.8,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _userQuota!.isPremium
                                  ? Icons.workspace_premium_rounded
                                  : Icons.bolt_rounded,
                              size: 16,
                              color: _userQuota!.isPremium
                                  ? SDChatColors.primary
                                  : SDChatColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _userQuota!.isPremium ? 'Plan Premium' : 'Plan Free',
                              style: TextStyle(
                                color: _userQuota!.isPremium
                                    ? SDChatColors.primary
                                    : SDChatColors.textPrimary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_userQuota!.messagesRemaining}/${_userQuota!.messagesLimit} msg',
                              style: TextStyle(
                                color: _userQuota!.isQuotaExceeded
                                    ? SDChatColors.error
                                    : SDChatColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: _userQuota!.messageUsageRatio,
                            minHeight: 4,
                            backgroundColor: SDChatColors.background,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _userQuota!.isQuotaExceeded
                                  ? SDChatColors.error
                                  : (_userQuota!.isPremium
                                      ? SDChatColors.primary
                                      : SDChatColors.secondary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                tileColor: SDChatColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: SDChatColors.borderSubtle, width: 0.8),
                ),
                leading: const Icon(Icons.workspace_premium_rounded, color: SDChatColors.primary, size: 20),
                title: Text(
                  _userQuota?.isPremium == true ? 'Gérer mon abonnement' : 'Passer à Premium (19,99 €)',
                  style: const TextStyle(
                    color: SDChatColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: SDChatColors.textMuted),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PremiumScreen()),
                  ).then((_) => _loadConversations());
                },
              ),
            ),

            // Entrée Officielle : ⚙️ Paramètres
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 2.0),
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                tileColor: SDChatColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: SDChatColors.borderSubtle, width: 0.8),
                ),
                leading: const Icon(Icons.settings_outlined, color: SDChatColors.primary, size: 20),
                title: const Text(
                  'Paramètres',
                  style: TextStyle(
                    color: SDChatColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: SDChatColors.textMuted),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ).then((_) => _loadConversations());
                },
              ),
            ),
            const Divider(color: SDChatColors.borderSubtle, height: 1),

            // Pied de page Utilisateur cliquable -> Paramètres
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ).then((_) => _loadConversations());
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
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
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _auth.signOut();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8, top: 2),
              child: Text(
                'SD — Build the Future with AI • Sekou Diaby',
                style: TextStyle(
                  color: SDChatColors.textDisabled,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? SDChatColors.surfaceHighlight : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? SDChatColors.primary.withValues(alpha: 0.5) : SDChatColors.borderSubtle,
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? SDChatColors.primary : SDChatColors.textMuted,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
