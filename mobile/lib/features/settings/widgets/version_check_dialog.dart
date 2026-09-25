import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/i18n/settings_strings.dart';
import '../../../core/theme/sd_chat_colors.dart';
import '../services/support_service.dart';

class VersionCheckDialog extends StatefulWidget {
  const VersionCheckDialog({super.key});

  @override
  State<VersionCheckDialog> createState() => _VersionCheckDialogState();
}

class _VersionCheckDialogState extends State<VersionCheckDialog> {
  bool _isLoading = true;
  bool _isUpToDate = true;
  String _currentVersion = '1.0.0';
  String _latestVersion = '1.0.0';
  String _changelog = '';
  String _storeUrl = 'https://play.google.com/store/apps/details?id=com.sd.chat.sd_chat_ai';

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final res = await SupportService.instance.checkVersion();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res != null) {
          _currentVersion = res['current_version'] as String? ?? '1.0.0';
          _latestVersion = res['latest_version'] as String? ?? '1.0.0';
          _isUpToDate = res['is_up_to_date'] as bool? ?? true;
          _changelog = res['changelog'] as String? ?? '';
          _storeUrl = res['play_store_url'] as String? ?? _storeUrl;
        }
      });
    }
  }

  Future<void> _openPlayStore() async {
    final uri = Uri.parse(_storeUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Cannot open Play Store: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = SettingsService.instance.languageCode;

    return AlertDialog(
      backgroundColor: SDChatColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: SDChatColors.borderMedium, width: 0.8),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: SDChatColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.system_update_rounded, color: SDChatColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              SettingsStrings.t('updates_title', lang),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: SDChatColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: _isLoading
          ? const SizedBox(
              height: 120,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(strokeWidth: 2, color: SDChatColors.primary),
                    SizedBox(height: 14),
                    Text(
                      'Vérification auprès des serveurs...',
                      style: TextStyle(fontSize: 13, color: SDChatColors.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isUpToDate
                        ? SDChatColors.success.withValues(alpha: 0.1)
                        : SDChatColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isUpToDate ? SDChatColors.success : SDChatColors.primary,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isUpToDate ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                        color: _isUpToDate ? SDChatColors.success : SDChatColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isUpToDate
                              ? SettingsStrings.t('up_to_date_desc', lang)
                              : 'Une mise à jour plus récente ($_latestVersion) est disponible.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _isUpToDate ? SDChatColors.success : SDChatColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Version installée :', style: TextStyle(color: SDChatColors.textSecondary, fontSize: 13)),
                    Text('v$_currentVersion', style: const TextStyle(color: SDChatColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Package officiel :', style: TextStyle(color: SDChatColors.textSecondary, fontSize: 13)),
                    Text('com.sd.chat.sd_chat_ai', style: TextStyle(color: SDChatColors.textMuted, fontSize: 12)),
                  ],
                ),
                if (_changelog.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Nouveautés : $_changelog',
                    style: const TextStyle(fontSize: 12, color: SDChatColors.textSecondary),
                  ),
                ],
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            SettingsStrings.t('close', lang),
            style: const TextStyle(color: SDChatColors.textMuted),
          ),
        ),
        if (!_isLoading && !_isUpToDate)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: SDChatColors.primary,
              foregroundColor: SDChatColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _openPlayStore,
            icon: const Icon(Icons.shop_rounded, size: 16),
            label: Text(SettingsStrings.t('open_store', lang)),
          ),
      ],
    );
  }
}
