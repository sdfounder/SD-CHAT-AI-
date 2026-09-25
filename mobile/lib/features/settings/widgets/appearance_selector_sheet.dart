import 'package:flutter/material.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/i18n/settings_strings.dart';
import '../../../core/theme/sd_chat_colors.dart';

class AppearanceSelectorSheet extends StatelessWidget {
  const AppearanceSelectorSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    final currentLang = settings.languageCode;
    final currentTheme = settings.themeMode;

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
                const Icon(Icons.palette_outlined, color: SDChatColors.primary, size: 22),
                const SizedBox(width: 10),
                Text(
                  SettingsStrings.t('appearance_title', currentLang),
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
              SettingsStrings.t('appearance_subtitle', currentLang),
              style: const TextStyle(
                fontSize: 13,
                color: SDChatColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            _buildOption(
              context: context,
              icon: Icons.dark_mode_rounded,
              title: SettingsStrings.t('theme_dark', currentLang),
              subtitle: 'Aura Obsidian — Confort visuel optimal',
              isSelected: currentTheme == ThemeMode.dark,
              onTap: () {
                settings.setThemeMode(ThemeMode.dark);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 10),

            _buildOption(
              context: context,
              icon: Icons.light_mode_rounded,
              title: SettingsStrings.t('theme_light', currentLang),
              subtitle: 'Titane Platine — Luminosité nette et sobre',
              isSelected: currentTheme == ThemeMode.light,
              onTap: () {
                settings.setThemeMode(ThemeMode.light);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 10),

            _buildOption(
              context: context,
              icon: Icons.brightness_auto_rounded,
              title: SettingsStrings.t('theme_system', currentLang),
              subtitle: 'Suit automatiquement les réglages de votre appareil',
              isSelected: currentTheme == ThemeMode.system,
              onTap: () {
                settings.setThemeMode(ThemeMode.system);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? SDChatColors.primary.withValues(alpha: 0.15) : SDChatColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: isSelected ? SDChatColors.primary : SDChatColors.textSecondary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? SDChatColors.textPrimary : SDChatColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: SDChatColors.textMuted),
                  ),
                ],
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
