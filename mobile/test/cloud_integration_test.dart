import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sd_chat_ai/core/config/app_config.dart';
import 'package:sd_chat_ai/core/services/chat_api_service.dart';
import 'package:sd_chat_ai/core/services/auth_service.dart';

void main() {
  setUpAll(() {
    // Permet à flutter_test de faire des appels réseau HTTPS réels vers le cloud
    HttpOverrides.global = null;
  });

  group('SD CHAT AI Cloud Integration Tests', () {
    final authService = AuthService();
    final chatApiService = ChatApiService();

    setUp(() async {
      // Connecter en mode Dev pour obtenir un Bearer dev-token valide
      await authService.signInDevMode(
        id: '00000000-0000-0000-0000-000000000001',
        email: 'test.mobile@sd-chat.ai',
        name: 'Testeur Mobile SD',
      );
    });

    test('1. AppConfig points to real HTTPS cloud endpoint', () {
      expect(AppConfig.apiBaseUrl, startsWith('https://'));
      expect(AppConfig.apiBaseUrl, isNot(contains('localhost')));
      expect(AppConfig.apiBaseUrl, isNot(contains('127.0.0.1')));
    });

    test('2. Fetch conversations via HTTPS Cloud URL', () async {
      final conversations = await chatApiService.fetchConversations();
      expect(conversations, isNotNull);
      expect(conversations, isA<List>());
    });

    test('3. Real SSE Streaming Flutter <-> Backend Cloud <-> Supabase <-> Gemini', () async {
      final completer = Completer<void>();
      final tokens = <String>[];
      String? conversationId;
      String? returnedMessageId;
      String? errorMessage;

      chatApiService.streamChatMessage(
        content: 'Donne-moi 3 mots inspirants pour SD.',
        onInit: (convId, title) {
          conversationId = convId;
        },
        onToken: (token) {
          tokens.add(token);
        },
        onDone: (messageId, title) {
          returnedMessageId = messageId;
          if (!completer.isCompleted) completer.complete();
        },
        onError: (err) {
          errorMessage = err;
          if (!completer.isCompleted) completer.completeError(err);
        },
      );

      // Attendre la fin du streaming avec un timeout de 45 secondes
      await completer.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          fail('Timeout en attente du flux de streaming SSE cloud');
        },
      );

      expect(errorMessage, isNull);
      expect(conversationId, isNotNull);
      expect(returnedMessageId, isNotNull);
      expect(tokens, isNotEmpty);
      final fullResponse = tokens.join('');
      expect(fullResponse.trim().length, greaterThan(3));
    });

    test('4. Rename and Archive conversation on Supabase SD-DEV', () async {
      // Créer une conversation
      final created = await chatApiService.createConversation(
        title: 'Discussion Temporaire Test',
      );
      expect(created, isNotNull);
      final convId = created!.id;

      // Renommer
      final renameSuccess = await chatApiService.updateConversation(
        convId,
        title: 'Discussion Renommée SD',
      );
      expect(renameSuccess, isTrue);

      // Archiver
      final archiveSuccess = await chatApiService.updateConversation(
        convId,
        isArchived: true,
      );
      expect(archiveSuccess, isTrue);

      // Supprimer
      final deleteSuccess = await chatApiService.deleteConversation(convId);
      expect(deleteSuccess, isTrue);
    });

    test('5. Stop generation handle cancels client connection', () async {
      final handle = chatApiService.streamChatMessage(
        content: 'Raconte une longue histoire détaillée de 10 paragraphes sur la conquête spatiale.',
        onInit: (convId, title) {},
        onToken: (token) {},
        onDone: (msgId, title) {},
        onError: (err) {},
      );

      expect(handle.isCancelled, isFalse);
      handle.cancel();
      expect(handle.isCancelled, isTrue);
    });
  });
}
