import 'package:flutter/material.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/i18n/settings_strings.dart';
import '../../../core/theme/sd_chat_colors.dart';
import '../services/data_control_service.dart';
import 'shared_links_screen.dart';

class DataControlScreen extends StatefulWidget {
  const DataControlScreen({super.key});

  @override
  State<DataControlScreen> createState() => _DataControlScreenState();
}

class _DataControlScreenState extends State<DataControlScreen> {
  final _dataService = DataControlService.instance;
  int _cacheSizeBytes = 0;
  bool _isLoadingCache = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _refreshCacheSize();
  }

  Future<void> _refreshCacheSize() async {
    final size = await _dataService.getCacheSizeBytes();
    if (mounted) {
      setState(() {
        _cacheSizeBytes = size;
        _isLoadingCache = false;
      });
    }
  }

  Future<void> _clearCache() async {
    setState(() => _isProcessing = true);
    final success = await _dataService.clearAppCache();
    await _refreshCacheSize();
    if (mounted) {
      setState(() => _isProcessing = false);
      final lang = SettingsService.instance.languageCode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? SettingsStrings.t('cache_cleared', lang) : 'Échec du vidage du cache.'),
          backgroundColor: success ? SDChatColors.success : SDChatColors.error,
        ),
      );
    }
  }

  Future<void> _clearLocalData() async {
    final lang = SettingsService.instance.languageCode;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SDChatColors.surface,
        title: Text(SettingsStrings.t('clear_local_title', lang)),
        content: Text(
          SettingsStrings.t('clear_local_confirm', lang),
          style: const TextStyle(color: SDChatColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(SettingsStrings.t('cancel', lang), style: const TextStyle(color: SDChatColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SDChatColors.warning),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(SettingsStrings.t('confirm', lang), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isProcessing = true);
      final success = await _dataService.clearLocalData();
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? SettingsStrings.t('local_cleared_success', lang) : 'Erreur lors de la suppression.'),
            backgroundColor: success ? SDChatColors.success : SDChatColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteCloudData() async {
    final lang = SettingsService.instance.languageCode;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SDChatColors.surface,
        title: Text(SettingsStrings.t('delete_cloud_title', lang), style: const TextStyle(color: SDChatColors.error)),
        content: Text(
          SettingsStrings.t('delete_cloud_confirm', lang),
          style: const TextStyle(color: SDChatColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(SettingsStrings.t('cancel', lang), style: const TextStyle(color: SDChatColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SDChatColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(SettingsStrings.t('delete_cloud_btn', lang), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isProcessing = true);
      final success = await _dataService.deleteCloudData();
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? SettingsStrings.t('cloud_deleted_success', lang) : 'Erreur lors de la suppression.'),
            backgroundColor: success ? SDChatColors.success : SDChatColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    final lang = SettingsService.instance.languageCode;
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isMatch = controller.text.trim().toUpperCase() == 'SUPPRIMER' ||
              controller.text.trim().toUpperCase() == 'DELETE';

          return AlertDialog(
            backgroundColor: SDChatColors.surface,
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: SDChatColors.error, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    SettingsStrings.t('delete_account_title', lang),
                    style: const TextStyle(color: SDChatColors.error, fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  SettingsStrings.t('delete_account_confirm', lang),
                  style: const TextStyle(color: SDChatColors.textSecondary, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                Text(
                  SettingsStrings.t('delete_account_type_confirm', lang),
                  style: const TextStyle(color: SDChatColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  onChanged: (_) => setDialogState(() {}),
                  style: const TextStyle(color: SDChatColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'SUPPRIMER',
                    hintStyle: const TextStyle(color: SDChatColors.textDisabled),
                    filled: true,
                    fillColor: SDChatColors.surfaceElevated,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: SDChatColors.error)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: SDChatColors.error, width: 1.5)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(SettingsStrings.t('cancel', lang), style: const TextStyle(color: SDChatColors.textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: SDChatColors.error),
                onPressed: isMatch ? () => Navigator.pop(ctx, true) : null,
                child: Text(SettingsStrings.t('delete_account_btn', lang), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true) {
      setState(() => _isProcessing = true);
      final success = await _dataService.deleteAccount();
      if (mounted) {
        setState(() => _isProcessing = false);
        if (success) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Échec de la suppression du compte.'),
              backgroundColor: SDChatColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = SettingsService.instance.languageCode;

    return Scaffold(
      backgroundColor: SDChatColors.background,
      appBar: AppBar(
        title: Text(
          SettingsStrings.t('data_title', lang),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              // A. Vider le cache
              _buildCard(
                icon: Icons.cleaning_services_rounded,
                iconColor: SDChatColors.primary,
                title: SettingsStrings.t('cache_title', lang),
                description: SettingsStrings.t('cache_desc', lang),
                trailingWidget: _isLoadingCache
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: SDChatColors.primary))
                    : Text(
                        '${SettingsStrings.t('cache_size', lang)} : ${DataControlService.formatBytes(_cacheSizeBytes)}',
                        style: const TextStyle(color: SDChatColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                actionButton: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SDChatColors.surfaceHighlight,
                    foregroundColor: SDChatColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _clearCache,
                  icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                  label: Text(SettingsStrings.t('clear_cache_btn', lang)),
                ),
              ),
              const SizedBox(height: 16),

              // B. Effacer les données locales
              _buildCard(
                icon: Icons.phone_android_rounded,
                iconColor: SDChatColors.secondary,
                title: SettingsStrings.t('clear_local_title', lang),
                description: SettingsStrings.t('clear_local_desc', lang),
                actionButton: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SDChatColors.surfaceHighlight,
                    foregroundColor: SDChatColors.textPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _clearLocalData,
                  icon: const Icon(Icons.phonelink_erase_rounded, size: 18),
                  label: Text(SettingsStrings.t('clear_local_btn', lang)),
                ),
              ),
              const SizedBox(height: 16),

              // E. Liens partagés
              _buildCard(
                icon: Icons.share_rounded,
                iconColor: SDChatColors.primary,
                title: SettingsStrings.t('shared_links', lang),
                description: SettingsStrings.t('shared_links_desc', lang),
                actionButton: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SDChatColors.surfaceHighlight,
                    foregroundColor: SDChatColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SharedLinksScreen()),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(SettingsStrings.t('manage_links', lang)),
                ),
              ),
              const SizedBox(height: 24),

              // Zone de Danger
              Text(
                'ZONE DE DANGER',
                style: TextStyle(
                  color: SDChatColors.error.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),

              // C. Supprimer les données cloud
              _buildDangerCard(
                icon: Icons.cloud_off_rounded,
                title: SettingsStrings.t('delete_cloud_title', lang),
                description: SettingsStrings.t('delete_cloud_desc', lang),
                buttonLabel: SettingsStrings.t('delete_cloud_btn', lang),
                onTap: _deleteCloudData,
              ),
              const SizedBox(height: 16),

              // D. Supprimer mon compte
              _buildDangerCard(
                icon: Icons.person_remove_rounded,
                title: SettingsStrings.t('delete_account_title', lang),
                description: SettingsStrings.t('delete_account_desc', lang),
                buttonLabel: SettingsStrings.t('delete_account_btn', lang),
                onTap: _deleteAccount,
              ),
            ],
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: SDChatColors.primary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    Widget? trailingWidget,
    required Widget actionButton,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SDChatColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SDChatColors.borderSubtle, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: SDChatColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(description, style: const TextStyle(fontSize: 13, color: SDChatColors.textSecondary, height: 1.4)),
          if (trailingWidget != null) ...[
            const SizedBox(height: 10),
            trailingWidget,
          ],
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: actionButton),
        ],
      ),
    );
  }

  Widget _buildDangerCard({
    required IconData icon,
    required String title,
    required String description,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SDChatColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SDChatColors.error.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: SDChatColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: SDChatColors.error, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: SDChatColors.error),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(description, style: const TextStyle(fontSize: 13, color: SDChatColors.textSecondary, height: 1.4)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: SDChatColors.error.withValues(alpha: 0.15),
                foregroundColor: SDChatColors.error,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: BorderSide(color: SDChatColors.error.withValues(alpha: 0.4), width: 0.8),
              ),
              onPressed: onTap,
              icon: const Icon(Icons.delete_forever_rounded, size: 18),
              label: Text(buttonLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
