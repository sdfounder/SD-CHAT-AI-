import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/i18n/settings_strings.dart';
import '../../../core/theme/sd_chat_colors.dart';

class LogoutConfirmDialog extends StatelessWidget {
  const LogoutConfirmDialog({super.key});

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
              color: SDChatColors.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.logout_rounded, color: SDChatColors.error, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              SettingsStrings.t('logout_title', lang),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: SDChatColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        SettingsStrings.t('logout_confirm_msg', lang),
        style: const TextStyle(
          fontSize: 14,
          color: SDChatColors.textSecondary,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            SettingsStrings.t('cancel', lang),
            style: const TextStyle(color: SDChatColors.textMuted),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: SDChatColors.error,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () async {
            Navigator.pop(context); // ferme le dialogue
            Navigator.of(context).popUntil((route) => route.isFirst); // revient à la racine
            await AuthService().signOut();
          },
          child: Text(
            SettingsStrings.t('logout_title', lang),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
