import 'package:flutter/material.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/i18n/settings_strings.dart';
import '../../../core/theme/sd_chat_colors.dart';

class LanguageSelectorSheet extends StatelessWidget {
  const LanguageSelectorSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    final currentLang = settings.languageCode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: const BoxDecoration(
        color: SDChatColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: SDChatColors.borderMedium,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.language_rounded, color: SDChatColors.primary, size: 22),
                const SizedBox(width: 10),
                Text(
                  SettingsStrings.t('language_title', currentLang),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: SDChatColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              SettingsStrings.t('language_subtitle', currentLang),
              style: const TextStyle(
                fontSize: 13,
                color: SDChatColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            // Option 1: Français
            _buildLanguageOption(
              context: context,
              flag: '🇫🇷',
              title: SettingsStrings.t('lang_french', currentLang),
              code: 'fr',
              isSelected: currentLang == 'fr',
              onTap: () {
                settings.setLanguage('fr');
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 10),

            // Option 2: English
            _buildLanguageOption(
              context: context,
              flag: '🇬🇧',
              title: SettingsStrings.t('lang_english', currentLang),
              code: 'en',
              isSelected: currentLang == 'en',
              onTap: () {
                settings.setLanguage('en');
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),

            // Indication langues régionales préparées
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SDChatColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SDChatColors.borderSubtle, width: 0.8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: SDChatColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bientôt disponibles : N\'Ko (ߒߞߏ), ADLaM (𞤀𞤣𞤤𞤢𞤥) et Susu (Sosoxui)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: SDChatColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption({
    required BuildContext context,
    required String flag,
    required String title,
    required String code,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? SDChatColors.surfaceHighlight : SDChatColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? SDChatColors.primary : SDChatColors.borderSubtle,
            width: isSelected ? 1.4 : 0.8,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? SDChatColors.textPrimary : SDChatColors.textSecondary,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: SDChatColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
