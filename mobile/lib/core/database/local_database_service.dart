import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../shared/models/conversation.dart';
import '../../shared/models/chat_message.dart';
import '../../shared/models/chat_attachment.dart';

class LocalDatabaseService {
  static final LocalDatabaseService instance = LocalDatabaseService._internal();
  factory LocalDatabaseService() => instance;
  LocalDatabaseService._internal();

  static const String _dbName = 'sd_chat_ai_offline.db';
  static const int _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String path;
    if (kIsWeb) {
      path = _dbName;
    } else {
      try {
        final dir = await getApplicationDocumentsDirectory();
        path = p.join(dir.path, _dbName);
      } catch (_) {
        final dbDir = await getDatabasesPath();
        path = p.join(dbDir, _dbName);
      }
    }

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE offline_conversations (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            title TEXT NOT NULL,
            model TEXT NOT NULL,
            system_prompt TEXT,
            is_archived INTEGER NOT NULL DEFAULT 0,
            is_pinned INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            last_synced_at TEXT,
            sync_status TEXT NOT NULL DEFAULT 'synced',
            message_count INTEGER NOT NULL DEFAULT 0,
            last_message_preview TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE offline_messages (
            id TEXT PRIMARY KEY,
            conversation_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            tokens_used INTEGER NOT NULL DEFAULT 0,
            model TEXT,
            created_at TEXT NOT NULL,
            sync_status TEXT NOT NULL DEFAULT 'synced',
            attachments_json TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE offline_mutations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            mutation_type TEXT NOT NULL,
            conversation_id TEXT,
            payload TEXT NOT NULL,
            created_at TEXT NOT NULL,
            retry_count INTEGER NOT NULL DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE sync_metadata (
            key TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            value TEXT,
            updated_at TEXT NOT NULL
          )
        ''');

        await db.execute('CREATE INDEX idx_conv_user ON offline_conversations(user_id, updated_at DESC)');
        await db.execute('CREATE INDEX idx_msg_conv ON offline_messages(conversation_id, created_at ASC)');
        await db.execute('CREATE INDEX idx_mut_user ON offline_mutations(user_id, created_at ASC)');
      },
    );
  }

  // =========================================================================
  // CONVERSATIONS
  // =========================================================================

  Future<List<Conversation>> getConversations(
    String userId, {
    bool includeArchived = false,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> rows;

    if (includeArchived) {
      rows = await db.query(
        'offline_conversations',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'is_pinned DESC, updated_at DESC',
      );
    } else {
      rows = await db.query(
        'offline_conversations',
        where: 'user_id = ? AND is_archived = 0',
        whereArgs: [userId],
        orderBy: 'is_pinned DESC, updated_at DESC',
      );
    }

    return rows.map((row) => _mapToConversation(row)).toList();
  }

  Future<Conversation?> getConversation(String conversationId, String userId) async {
    final db = await database;
    final rows = await db.query(
      'offline_conversations',
      where: 'id = ? AND user_id = ?',
      whereArgs: [conversationId, userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mapToConversation(rows.first);
  }

  Future<void> upsertConversations(List<Conversation> convs, String userId) async {
    if (convs.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    final nowIso = DateTime.now().toIso8601String();

    for (final conv in convs) {
      batch.insert(
        'offline_conversations',
        {
          'id': conv.id,
          'user_id': userId,
          'title': conv.title,
          'model': conv.model,
          'system_prompt': conv.systemPrompt,
          'is_archived': conv.isArchived ? 1 : 0,
          'is_pinned': conv.isPinned ? 1 : 0,
          'created_at': conv.createdAt.toIso8601String(),
          'updated_at': conv.updatedAt.toIso8601String(),
          'last_synced_at': nowIso,
          'sync_status': 'synced',
          'message_count': conv.messageCount,
          'last_message_preview': conv.lastMessagePreview,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> upsertConversation(
    Conversation conv,
    String userId, {
    String syncStatus = 'synced',
  }) async {
    final db = await database;
    await db.insert(
      'offline_conversations',
      {
        'id': conv.id,
        'user_id': userId,
        'title': conv.title,
        'model': conv.model,
        'system_prompt': conv.systemPrompt,
        'is_archived': conv.isArchived ? 1 : 0,
        'is_pinned': conv.isPinned ? 1 : 0,
        'created_at': conv.createdAt.toIso8601String(),
        'updated_at': conv.updatedAt.toIso8601String(),
        'last_synced_at': DateTime.now().toIso8601String(),
        'sync_status': syncStatus,
        'message_count': conv.messageCount,
        'last_message_preview': conv.lastMessagePreview,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> renameConversationLocally(
    String conversationId,
    String userId,
    String newTitle,
  ) async {
    final db = await database;
    await db.update(
      'offline_conversations',
      {
        'title': newTitle,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND user_id = ?',
      whereArgs: [conversationId, userId],
    );
  }

  Future<void> archiveConversationLocally(
    String conversationId,
    String userId,
    bool isArchived,
  ) async {
    final db = await database;
    await db.update(
      'offline_conversations',
      {
        'is_archived': isArchived ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND user_id = ?',
      whereArgs: [conversationId, userId],
    );
  }

  Future<void> deleteConversationLocally(String conversationId, String userId) async {
    final db = await database;
    await db.delete(
      'offline_conversations',
      where: 'id = ? AND user_id = ?',
      whereArgs: [conversationId, userId],
    );
    await db.delete(
      'offline_messages',
      where: 'conversation_id = ? AND user_id = ?',
      whereArgs: [conversationId, userId],
    );
  }

  // =========================================================================
  // MESSAGES
  // =========================================================================

  Future<List<ChatMessage>> getMessages(String conversationId, String userId) async {
    final db = await database;
    final rows = await db.query(
      'offline_messages',
      where: 'conversation_id = ? AND user_id = ?',
      whereArgs: [conversationId, userId],
      orderBy: 'created_at ASC',
    );
    return rows.map((row) => _mapToChatMessage(row)).toList();
  }

  Future<void> upsertMessages(
    String conversationId,
    String userId,
    List<ChatMessage> messages,
  ) async {
    if (messages.isEmpty) return;
    final db = await database;
    final batch = db.batch();

    for (final msg in messages) {
      final attachmentsJson = jsonEncode(
        msg.attachments.map((a) => a.toJson()).toList(),
      );
      batch.insert(
        'offline_messages',
        {
          'id': msg.id,
          'conversation_id': conversationId,
          'user_id': userId,
          'role': msg.role.name,
          'content': msg.content,
          'tokens_used': msg.tokensUsed,
          'model': msg.model,
          'created_at': msg.createdAt.toIso8601String(),
          'sync_status': 'synced',
          'attachments_json': attachmentsJson,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> saveLocalMessage(
    ChatMessage message,
    String userId, {
    String syncStatus = 'synced',
  }) async {
    final db = await database;
    final attachmentsJson = jsonEncode(
      message.attachments.map((a) => a.toJson()).toList(),
    );
    await db.insert(
      'offline_messages',
      {
        'id': message.id,
        'conversation_id': message.conversationId,
        'user_id': userId,
        'role': message.role.name,
        'content': message.content,
        'tokens_used': message.tokensUsed,
        'model': message.model,
        'created_at': message.createdAt.toIso8601String(),
        'sync_status': syncStatus,
        'attachments_json': attachmentsJson,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Mettre à jour last_message_preview et updated_at sur la conversation
    if (message.conversationId.isNotEmpty) {
      await db.update(
        'offline_conversations',
        {
          'updated_at': message.createdAt.toIso8601String(),
          'last_message_preview': message.content.length > 60
              ? '${message.content.substring(0, 57)}...'
              : message.content,
        },
        where: 'id = ? AND user_id = ?',
        whereArgs: [message.conversationId, userId],
      );
    }
  }

  // =========================================================================
  // MUTATIONS QUEUE (OUTBOX PATTERN FOR OFFLINE RESILIENCE)
  // =========================================================================

  Future<void> enqueueMutation({
    required String userId,
    required String mutationType,
    String? conversationId,
    required Map<String, dynamic> payload,
  }) async {
    final db = await database;
    await db.insert(
      'offline_mutations',
      {
        'user_id': userId,
        'mutation_type': mutationType,
        'conversation_id': conversationId,
        'payload': jsonEncode(payload),
        'created_at': DateTime.now().toIso8601String(),
        'retry_count': 0,
      },
    );
  }

  Future<List<Map<String, dynamic>>> getPendingMutations(String userId) async {
    final db = await database;
    return await db.query(
      'offline_mutations',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at ASC',
    );
  }

  Future<void> removePendingMutation(int id) async {
    final db = await database;
    await db.delete('offline_mutations', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementMutationRetry(int id) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE offline_mutations SET retry_count = retry_count + 1 WHERE id = ?',
      [id],
    );
  }

  // =========================================================================
  // SYNC METADATA & LAST SYNC TIME
  // =========================================================================

  Future<DateTime?> getLastSyncTime(String userId) async {
    final db = await database;
    final rows = await db.query(
      'sync_metadata',
      where: 'key = ? AND user_id = ?',
      whereArgs: ['last_full_sync', userId],
      limit: 1,
    );
    if (rows.isEmpty || rows.first['value'] == null) return null;
    try {
      return DateTime.parse(rows.first['value'] as String);
    } catch (_) {
      return null;
    }
  }

  Future<void> setLastSyncTime(String userId, DateTime time) async {
    final db = await database;
    await db.insert(
      'sync_metadata',
      {
        'key': 'last_full_sync',
        'user_id': userId,
        'value': time.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // =========================================================================
  // SÉCURITÉ : ISOLATION UTILISATEUR & EFFACEMENT AU LOGOUT
  // =========================================================================

  Future<void> clearUserData(String userId) async {
    final db = await database;
    await db.delete('offline_conversations', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('offline_messages', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('offline_mutations', where: 'user_id = ?', whereArgs: [userId]);
    await db.delete('sync_metadata', where: 'user_id = ?', whereArgs: [userId]);
  }

  /// Supprime toutes les données locales stockées en SQLite (conversations, messages, mutations)
  Future<void> clearAllLocalData({String? userId}) async {
    final db = await database;
    if (userId != null && userId.isNotEmpty) {
      await db.delete('offline_messages', where: 'user_id = ?', whereArgs: [userId]);
      await db.delete('offline_conversations', where: 'user_id = ?', whereArgs: [userId]);
      await db.delete('offline_mutations', where: 'user_id = ?', whereArgs: [userId]);
      await db.delete('sync_metadata', where: 'user_id = ?', whereArgs: [userId]);
    } else {
      await db.delete('offline_messages');
      await db.delete('offline_conversations');
      await db.delete('offline_mutations');
      await db.delete('sync_metadata');
    }
  }

  // =========================================================================
  // CONVERTEURS PRIVÉS
  // =========================================================================

  Conversation _mapToConversation(Map<String, dynamic> row) {
    return Conversation(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      title: row['title'] as String,
      model: row['model'] as String,
      systemPrompt: row['system_prompt'] as String?,
      isArchived: (row['is_archived'] as int? ?? 0) == 1,
      isPinned: (row['is_pinned'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      messageCount: row['message_count'] as int? ?? 0,
      lastMessagePreview: row['last_message_preview'] as String?,
    );
  }

  ChatMessage _mapToChatMessage(Map<String, dynamic> row) {
    final roleStr = row['role'] as String? ?? 'user';
    MessageRole role = MessageRole.user;
    if (roleStr == 'assistant') {
      role = MessageRole.assistant;
    } else if (roleStr == 'system') {
      role = MessageRole.system;
    }

    List<ChatAttachment> attachments = [];
    if (row['attachments_json'] != null) {
      try {
        final list = jsonDecode(row['attachments_json'] as String) as List<dynamic>;
        attachments = list.map((a) => ChatAttachment.fromJson(a as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    return ChatMessage(
      id: row['id'] as String,
      conversationId: row['conversation_id'] as String,
      userId: row['user_id'] as String,
      role: role,
      content: row['content'] as String,
      tokensUsed: row['tokens_used'] as int? ?? 0,
      model: row['model'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      attachments: attachments,
      isStreaming: false,
    );
  }
}
