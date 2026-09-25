import 'package:flutter/material.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/i18n/settings_strings.dart';
import '../../../core/theme/sd_chat_colors.dart';

class FontSizeSliderSheet extends StatefulWidget {
  const FontSizeSliderSheet({super.key});

  @override
  State<FontSizeSliderSheet> createState() => _FontSizeSliderSheetState();
}

class _FontSizeSliderSheetState extends State<FontSizeSliderSheet> {
  late double _currentScale;

  @override
  void initState() {
    super.initState();
    _currentScale = SettingsService.instance.fontScale;
  }

  String _getScaleLabel(double scale, String lang) {
    if (scale <= 0.90) return SettingsStrings.t('font_small', lang);
    if (scale <= 1.05) return SettingsStrings.t('font_normal', lang);
    if (scale <= 1.20) return SettingsStrings.t('font_large', lang);
    return SettingsStrings.t('font_huge', lang);
  }

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
                const Icon(Icons.format_size_rounded, color: SDChatColors.primary, size: 22),
                const SizedBox(width: 10),
                Text(
                  SettingsStrings.t('font_size_title', currentLang),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: SDChatColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: SDChatColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getScaleLabel(_currentScale, currentLang),
                    style: const TextStyle(
                      color: SDChatColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              SettingsStrings.t('font_size_subtitle', currentLang),
              style: const TextStyle(
                fontSize: 13,
                color: SDChatColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            // Aperçu dynamique du texte
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SDChatColors.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: SDChatColors.borderMedium, width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: SDChatColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Aperçu SD CHAT AI',
                        style: TextStyle(
                          fontSize: 11 * _currentScale,
                          fontWeight: FontWeight.w600,
                          color: SDChatColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    SettingsStrings.t('font_size_sample', currentLang),
                    style: TextStyle(
                      fontSize: 14 * _currentScale,
                      color: SDChatColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Slider
            Row(
              children: [
                const Text('A', style: TextStyle(fontSize: 12, color: SDChatColors.textMuted)),
                Expanded(
                  child: Slider(
                    value: _currentScale,
                    min: 0.85,
                    max: 1.30,
                    divisions: 3,
                    activeColor: SDChatColors.primary,
                    inactiveColor: SDChatColors.borderMedium,
                    onChanged: (val) {
                      setState(() {
                        _currentScale = val;
                      });
                      settings.setFontScale(val);
                    },
                  ),
                ),
                const Text('A', style: TextStyle(fontSize: 20, color: SDChatColors.textPrimary, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: SDChatColors.primary,
                  foregroundColor: SDChatColors.background,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  SettingsStrings.t('close', currentLang),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
