import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/i18n/settings_strings.dart';
import '../../../core/theme/sd_chat_colors.dart';
import '../services/share_service.dart';

class SharedLinksScreen extends StatefulWidget {
  const SharedLinksScreen({super.key});

  @override
  State<SharedLinksScreen> createState() => _SharedLinksScreenState();
}

class _SharedLinksScreenState extends State<SharedLinksScreen> {
  final _shareService = ShareService.instance;
  bool _isLoading = true;
  List<SharedLinkItem> _links = [];

  @override
  void initState() {
    super.initState();
    _loadLinks();
  }

  Future<void> _loadLinks() async {
    final list = await _shareService.fetchSharedLinks();
    if (mounted) {
      setState(() {
        _links = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _revoke(SharedLinkItem item) async {
    final lang = SettingsService.instance.languageCode;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SDChatColors.surface,
        title: Text(SettingsStrings.t('revoke', lang)),
        content: const Text(
          'Voulez-vous vraiment désactiver ce lien public ? Toute personne essayant d\'y accéder recevra un message d\'expiration.',
          style: TextStyle(color: SDChatColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(SettingsStrings.t('cancel', lang), style: const TextStyle(color: SDChatColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SDChatColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(SettingsStrings.t('revoke', lang), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _shareService.revokeSharedLink(item.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(SettingsStrings.t('link_revoked_success', lang)),
            backgroundColor: SDChatColors.success,
          ),
        );
        _loadLinks();
      }
    }
  }

  void _copyLink(String url) {
    final lang = SettingsService.instance.languageCode;
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(SettingsStrings.t('link_copied', lang)),
        backgroundColor: SDChatColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openLink(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Cannot launch link: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = SettingsService.instance.languageCode;

    return Scaffold(
      backgroundColor: SDChatColors.background,
      appBar: AppBar(
        title: Text(
          SettingsStrings.t('shared_links', lang),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: SDChatColors.primary))
          : _links.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: SDChatColors.surfaceElevated,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.share_outlined, size: 40, color: SDChatColors.textMuted),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          SettingsStrings.t('no_shared_links', lang),
                          style: const TextStyle(color: SDChatColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          SettingsStrings.t('no_shared_links_desc', lang),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: SDChatColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _links.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _links[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: SDChatColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: item.isRevoked ? SDChatColors.borderSubtle : SDChatColors.borderMedium,
                          width: 0.8,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: item.isRevoked ? SDChatColors.textMuted : SDChatColors.textPrimary,
                                    decoration: item.isRevoked ? TextDecoration.lineThrough : null,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: item.isRevoked
                                      ? SDChatColors.error.withValues(alpha: 0.12)
                                      : SDChatColors.success.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.isRevoked ? 'Révoqué' : 'Actif',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: item.isRevoked ? SDChatColors.error : SDChatColors.success,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.remove_red_eye_outlined, size: 14, color: SDChatColors.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                '${item.viewsCount} vue${item.viewsCount > 1 ? 's' : ''}',
                                style: const TextStyle(fontSize: 12, color: SDChatColors.textMuted),
                              ),
                              const SizedBox(width: 12),
                              const Icon(Icons.link_rounded, size: 14, color: SDChatColors.textMuted),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  item.publicUrl,
                                  style: const TextStyle(fontSize: 11, color: SDChatColors.textMuted),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (!item.isRevoked) ...[
                                TextButton.icon(
                                  onPressed: () => _copyLink(item.publicUrl),
                                  icon: const Icon(Icons.copy_rounded, size: 14),
                                  label: const Text('Copier', style: TextStyle(fontSize: 12)),
                                  style: TextButton.styleFrom(foregroundColor: SDChatColors.primary),
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: () => _openLink(item.publicUrl),
                                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                                  label: const Text('Ouvrir', style: TextStyle(fontSize: 12)),
                                  style: TextButton.styleFrom(foregroundColor: SDChatColors.secondary),
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: () => _revoke(item),
                                  icon: const Icon(Icons.link_off_rounded, size: 14),
                                  label: Text(SettingsStrings.t('revoke', lang), style: const TextStyle(fontSize: 12)),
                                  style: TextButton.styleFrom(foregroundColor: SDChatColors.error),
                                ),
                              ] else ...[
                                const Text(
                                  'Accès public révoqué',
                                  style: TextStyle(color: SDChatColors.textDisabled, fontSize: 12),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
