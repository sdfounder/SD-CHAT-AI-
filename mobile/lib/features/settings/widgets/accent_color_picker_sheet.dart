import 'package:flutter/material.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/i18n/settings_strings.dart';
import '../../../core/theme/sd_chat_colors.dart';

class AccentColorPickerSheet extends StatelessWidget {
  const AccentColorPickerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    final currentLang = settings.languageCode;
    final currentKey = settings.accentColorKey;

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
                const Icon(Icons.color_lens_rounded, color: SDChatColors.primary, size: 22),
                const SizedBox(width: 10),
                Text(
                  SettingsStrings.t('customization_title', currentLang),
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
              SettingsStrings.t('customization_subtitle', currentLang),
              style: const TextStyle(
                fontSize: 13,
                color: SDChatColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // Grille des 6 couleurs
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: SettingsService.accentColors.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.15,
              ),
              itemBuilder: (context, index) {
                final item = SettingsService.accentColors[index];
                final String name = item['name'] as String;
                final String key = item['key'] as String;
                final Color color = item['color'] as Color;
                final bool isSelected = key == currentKey;

                return InkWell(
                  onTap: () {
                    settings.setAccentColor(key);
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? color.withValues(alpha: 0.15) : SDChatColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? color : SDChatColors.borderSubtle,
                        width: isSelected ? 2 : 0.8,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 18)
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          key == 'yellow' ? 'Aura Amber' : name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? SDChatColors.textPrimary : SDChatColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
