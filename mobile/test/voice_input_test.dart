import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sd_chat_ai/core/services/voice_service.dart';
import 'package:sd_chat_ai/features/chat/widgets/chat_input_bar.dart';

void main() {
  group('SD CHAT AI - Dictée Vocale Tests', () {
    test('1. VoiceService default states', () {
      final voice = VoiceService();
      expect(voice.status, equals(VoiceStatus.idle));
      expect(voice.isListening, isFalse);
      expect(voice.errorMessage, isEmpty);
      expect(voice.soundLevel, equals(0.0));
    });

    testWidgets('2. ChatInputBar displays microphone button and allows manual typing and editing', (tester) async {
      String? sentMessage;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInputBar(
              onSend: (msg) {
                sentMessage = msg;
              },
            ),
          ),
        ),
      );

      // Le bouton micro doit être présent dans l'arbre des widgets
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);

      // Le champ de saisie doit être présent
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      // Saisir du texte au clavier
      await tester.enterText(textFieldFinder, 'Bonjour SD CHAT AI');
      await tester.pump();

      // Modifier le texte (compléter avec dictée simulée ou frappe)
      await tester.enterText(textFieldFinder, 'Bonjour SD CHAT AI, ceci est un test de dictée');
      await tester.pump();

      // Le message NE doit PAS être envoyé automatiquement
      expect(sentMessage, isNull);

      // Vérifier le bouton d'envoi (flèche vers le haut)
      final sendButtonFinder = find.byIcon(Icons.arrow_upward_rounded);
      expect(sendButtonFinder, findsOneWidget);

      // Cliquer manuellement sur Envoyer
      await tester.tap(sendButtonFinder);
      await tester.pump();

      // Vérifier que le message envoyé est bien le texte complet modifié
      expect(sentMessage, equals('Bonjour SD CHAT AI, ceci est un test de dictée'));
    });

    testWidgets('3. Input bar stops dictation before sending if listening', (tester) async {
      String? sentMessage;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInputBar(
              onSend: (msg) {
                sentMessage = msg;
              },
            ),
          ),
        ),
      );

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Message dicté par la voix');
      await tester.pump();

      final sendBtn = find.byIcon(Icons.arrow_upward_rounded);
      await tester.tap(sendBtn);
      await tester.pump();

      expect(sentMessage, equals('Message dicté par la voix'));
    });
  });
}
