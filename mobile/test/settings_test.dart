import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sd_chat_ai/core/services/settings_service.dart';
import 'package:sd_chat_ai/core/i18n/settings_strings.dart';
import 'package:sd_chat_ai/core/theme/sd_chat_theme.dart';
import 'package:sd_chat_ai/features/settings/services/data_control_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SD CHAT AI - Settings Hub Unit & Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. SettingsService defaults to French, Dark Aura Obsidian, and Aura Amber color', () async {
      final settings = SettingsService.instance;
      await settings.initialize();

      expect(settings.languageCode, equals('fr'));
      expect(settings.themeMode, equals(ThemeMode.dark));
      expect(settings.fontScale, equals(1.0));
      expect(settings.accentColorKey, equals('yellow'));
    });

    test('2. SettingsService state transitions (Theme, Lang, Scale, Accent Color)', () async {
      final settings = SettingsService.instance;

      await settings.setThemeMode(ThemeMode.light);
      expect(settings.themeMode, equals(ThemeMode.light));

      await settings.setLanguage('en');
      expect(settings.languageCode, equals('en'));

      await settings.setFontScale(1.25);
      expect(settings.fontScale, equals(1.25));

      await settings.setAccentColor('blue');
      expect(settings.accentColorKey, equals('blue'));
      expect(settings.accentColor, equals(const Color(0xFF3B82F6)));

      // Reset
      await settings.setThemeMode(ThemeMode.dark);
      await settings.setLanguage('fr');
      await settings.setFontScale(1.0);
      await settings.setAccentColor('yellow');
    });

    test('3. SettingsStrings internationalization dictionary test', () {
      expect(SettingsStrings.t('settings_hub_title', 'fr'), equals('Paramètres'));
      expect(SettingsStrings.t('settings_hub_title', 'en'), equals('Settings'));

      expect(SettingsStrings.t('account_title', 'fr'), equals('Paramètres du compte'));
      expect(SettingsStrings.t('account_title', 'en'), equals('Account Settings'));

      expect(SettingsStrings.t('data_title', 'fr'), equals('Contrôle des données'));
      expect(SettingsStrings.t('data_title', 'en'), equals('Data Control'));

      expect(SettingsStrings.t('delete_account_btn', 'fr'), contains('Supprimer'));
      expect(SettingsStrings.t('delete_account_btn', 'en'), contains('Delete'));

      // Fallback
      expect(SettingsStrings.t('non_existing_key', 'fr'), equals('non_existing_key'));
    });

    test('4. DataControlService formatBytes utility test', () {
      expect(DataControlService.formatBytes(0), equals('0 Ko'));
      expect(DataControlService.formatBytes(512), equals('512.0 o'));
      expect(DataControlService.formatBytes(1024), equals('1.0 Ko'));
      expect(DataControlService.formatBytes(1048576), equals('1.0 Mo'));
      expect(DataControlService.formatBytes(1073741824), equals('1.0 Go'));
    });

    test('5. SDChatTheme dynamic theme builder with custom accent color', () {
      final darkTheme = SDChatTheme.buildTheme(
        brightness: Brightness.dark,
        accentColor: const Color(0xFF10B981), // Emerald Green
      );
      expect(darkTheme.brightness, equals(Brightness.dark));
      expect(darkTheme.colorScheme.primary, equals(const Color(0xFF10B981)));

      final lightTheme = SDChatTheme.buildTheme(
        brightness: Brightness.light,
        accentColor: const Color(0xFF8B5CF6), // Purple
      );
      expect(lightTheme.brightness, equals(Brightness.light));
      expect(lightTheme.colorScheme.primary, equals(const Color(0xFF8B5CF6)));
    });
  });
}
