import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sd_chat_ai/core/services/settings_service.dart';
import 'package:sd_chat_ai/features/settings/screens/settings_screen.dart';
import 'package:sd_chat_ai/features/settings/widgets/language_selector_sheet.dart';
import 'package:sd_chat_ai/features/settings/widgets/appearance_selector_sheet.dart';
import 'package:sd_chat_ai/features/settings/widgets/font_size_slider_sheet.dart';
import 'package:sd_chat_ai/features/settings/widgets/accent_color_picker_sheet.dart';
import 'package:sd_chat_ai/features/settings/widgets/logout_confirm_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SD CHAT AI - Settings Hub Widget Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SettingsService.instance.initialize();
    });

    testWidgets('1. SettingsScreen renders all section titles and key tiles', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(),
        ),
      );
      await tester.pump();

      // Vérification du titre principal
      expect(find.text('Paramètres'), findsWidgets);

      // Vérification des sections supérieures visibles
      expect(find.text('COMPTE & DONNÉES'), findsOneWidget);
      expect(find.text('Paramètres du compte'), findsOneWidget);
      expect(find.text('Contrôle des données'), findsOneWidget);
      expect(find.text('EXPÉRIENCE & PRÉFÉRENCES'), findsOneWidget);

      // Défiler vers le bas pour révéler la signature officielle SD
      await tester.scrollUntilVisible(
        find.text('SD — Build the Future with AI'),
        150,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      // Vérification des sections inférieures
      expect(find.text('SYSTÈME & SUPPORT'), findsOneWidget);
      expect(find.text('Vérifier les mises à jour'), findsOneWidget);
      expect(find.text('Contrat de service'), findsOneWidget);
      expect(find.text('Aide et commentaires'), findsOneWidget);
      expect(find.text('Déconnexion'), findsOneWidget);

      // Signature officielle SD
      expect(find.text('SD — Build the Future with AI'), findsOneWidget);
      expect(find.textContaining('Sekou Diaby'), findsOneWidget);
    });

    testWidgets('2. LanguageSelectorSheet displays French and English options', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LanguageSelectorSheet(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Français (Par défaut)'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.textContaining('N\'Ko'), findsOneWidget);
    });

    testWidgets('3. AppearanceSelectorSheet displays Dark, Light and System options', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppearanceSelectorSheet(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Sombre'), findsOneWidget);
      expect(find.text('Clair'), findsOneWidget);
      expect(find.text('Système'), findsOneWidget);
    });

    testWidgets('4. FontSizeSliderSheet displays preview and slider', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FontSizeSliderSheet(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Slider), findsOneWidget);
      expect(find.textContaining('SD CHAT AI'), findsWidgets);
    });

    testWidgets('5. AccentColorPickerSheet renders 6 color options', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AccentColorPickerSheet(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Bleu'), findsOneWidget);
      expect(find.text('Vert'), findsOneWidget);
      expect(find.text('Rouge'), findsOneWidget);
      expect(find.text('Orange'), findsOneWidget);
      expect(find.text('Aura Amber'), findsOneWidget);
      expect(find.text('Violet'), findsOneWidget);
    });

    testWidgets('6. LogoutConfirmDialog renders cancel and confirm buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LogoutConfirmDialog(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Déconnexion'), findsWidgets);
      expect(find.text('Annuler'), findsOneWidget);
    });
  });
}
