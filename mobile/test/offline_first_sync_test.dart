import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sd_chat_ai/core/database/local_database_service.dart';
import 'package:sd_chat_ai/core/services/sync_service.dart';
import 'package:sd_chat_ai/core/services/chat_api_service.dart';
import 'package:sd_chat_ai/shared/models/conversation.dart';
import 'package:sd_chat_ai/shared/models/chat_message.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SD CHAT AI - Mission 18 : Offline-First & Smart Sync Tests', () {
    final db = LocalDatabaseService.instance;
    const testUserId = 'test-user-offline-18';
    const testUserId2 = 'test-user-offline-other';

    test('1. SQLite Local Database saves and retrieves conversations offline', () async {
      final now = DateTime.now();
      final conv1 = Conversation(
        id: 'conv-offline-1',
        userId: testUserId,
        title: 'Discussion Architecture Offline',
        model: 'gemini-2.5-flash',
        createdAt: now,
        updatedAt: now,
        isArchived: false,
        isPinned: true,
      );
      final conv2 = Conversation(
        id: 'conv-offline-2',
        userId: testUserId,
        title: 'Discussion Archivée Locale',
        model: 'gemini-2.5-flash',
        createdAt: now,
        updatedAt: now,
        isArchived: true,
      );

      await db.upsertConversations([conv1, conv2], testUserId);

      // Récupération des conversations actives (hors archives)
      final active = await db.getConversations(testUserId, includeArchived: false);
      expect(active.length, 1);
      expect(active.first.id, 'conv-offline-1');
      expect(active.first.title, 'Discussion Architecture Offline');
      expect(active.first.isPinned, isTrue);

      // Récupération avec archives
      final all = await db.getConversations(testUserId, includeArchived: true);
      expect(all.length, 2);
    });

    test('2. SQLite Local Database saves and retrieves messages offline', () async {
      final now = DateTime.now();
      final msg1 = ChatMessage(
        id: 'msg-local-1',
        conversationId: 'conv-offline-1',
        userId: testUserId,
        role: MessageRole.user,
        content: 'Comment fonctionne le cache local Flutter ?',
        createdAt: now,
      );
      final msg2 = ChatMessage(
        id: 'msg-local-2',
        conversationId: 'conv-offline-1',
        userId: testUserId,
        role: MessageRole.assistant,
        content: 'Il utilise SQLite via sqflite pour persister conversations et messages sans Internet.',
        createdAt: now.add(const Duration(seconds: 1)),
      );

      await db.saveLocalMessage(msg1, testUserId);
      await db.saveLocalMessage(msg2, testUserId);

      final messages = await db.getMessages('conv-offline-1', testUserId);
      expect(messages.length, 2);
      expect(messages[0].isUser, isTrue);
      expect(messages[0].content, 'Comment fonctionne le cache local Flutter ?');
      expect(messages[1].isAssistant, isTrue);
      expect(messages[1].content, contains('SQLite via sqflite'));
    });

    test('3. Local conversation update, archive and rename operate instantly', () async {
      await db.renameConversationLocally('conv-offline-1', testUserId, 'Titre Renommé en Local');
      var updated = await db.getConversation('conv-offline-1', testUserId);
      expect(updated?.title, 'Titre Renommé en Local');

      await db.archiveConversationLocally('conv-offline-1', testUserId, true);
      updated = await db.getConversation('conv-offline-1', testUserId);
      expect(updated?.isArchived, isTrue);
    });

    test('4. Offline mutations queue (Outbox) records pending operations', () async {
      await db.enqueueMutation(
        userId: testUserId,
        mutationType: 'rename_conversation',
        conversationId: 'conv-offline-1',
        payload: {'title': 'Nouveau Titre Offline'},
      );

      final mutations = await db.getPendingMutations(testUserId);
      expect(mutations.isNotEmpty, isTrue);
      expect(mutations.first['mutation_type'], 'rename_conversation');
      expect(mutations.first['conversation_id'], 'conv-offline-1');

      final mutationId = mutations.first['id'] as int;
      await db.removePendingMutation(mutationId);
      final afterRemove = await db.getPendingMutations(testUserId);
      expect(afterRemove.isEmpty, isTrue);
    });

    test('5. Strict user data isolation: clearUserData wipes private data on logout', () async {
      // Créer des données pour un 2ème utilisateur
      final convOther = Conversation(
        id: 'conv-other-user',
        userId: testUserId2,
        title: 'Discussion Compte Secondaire',
        model: 'gemini-2.5-flash',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await db.upsertConversation(convOther, testUserId2);

      // Effacement du testUserId
      await db.clearUserData(testUserId);

      final user1Convs = await db.getConversations(testUserId, includeArchived: true);
      expect(user1Convs.isEmpty, isTrue);

      final user1Msgs = await db.getMessages('conv-offline-1', testUserId);
      expect(user1Msgs.isEmpty, isTrue);

      // Vérifier que testUserId2 n'a pas été affecté (isolation multi-tenant)
      final user2Convs = await db.getConversations(testUserId2, includeArchived: true);
      expect(user2Convs.length, 1);
      expect(user2Convs.first.id, 'conv-other-user');
    });

    test('6. SyncService manages sync states and displays premium labels', () async {
      final sync = SyncService.instance;
      expect(sync.status, isNotNull);
      expect(sync.statusLabel, isNotEmpty);

      // Vérifier le label de synchronisation/connexion
      expect(sync.statusLabel, anyOf(
        contains('Connecté'),
        contains('Synchronisé'),
        contains('Hors ligne'),
        contains('hors ligne'),
        contains('Synchronisation'),
        contains('Serveur indisponible'),
      ));
    });

    test('7. ChatApiService fetchConversations loads cached data offline without error', () async {
      final api = ChatApiService();
      // Même si le backend distant est inaccessible en mode test, la méthode ne plante pas
      final convs = await api.fetchConversations();
      expect(convs, isNotNull);
    });
  });
}
