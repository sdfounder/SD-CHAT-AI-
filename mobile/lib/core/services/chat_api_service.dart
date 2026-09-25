import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../database/local_database_service.dart';
import 'auth_service.dart';
import 'sync_service.dart';
import '../../shared/models/conversation.dart';
import '../../shared/models/chat_message.dart';
import '../../shared/models/chat_attachment.dart';
import '../../shared/models/user_quota.dart';

class ChatApiService {
  static final ChatApiService _instance = ChatApiService._internal();
  factory ChatApiService() => _instance;
  ChatApiService._internal();

  final AuthService _auth = AuthService();
  final LocalDatabaseService _db = LocalDatabaseService.instance;
  bool _lastFetchHadError = false;

  bool get lastFetchHadError => _lastFetchHadError;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer ${_auth.accessToken ?? ""}',
      };

  /// Récupération offline-first des conversations :
  /// 1. Retourne instantanément les conversations stockées en base locale SQLite (0ms wait).
  /// 2. Lance la synchronisation réseau en arrière-plan sans bloquer l'écran.
  Future<List<Conversation>> fetchConversations({
    bool includeArchived = false,
  }) async {
    final userId = _auth.currentUserId;

    // Étape 1 : Lecture immédiate depuis SQLite local
    List<Conversation> localConvs = [];
    if (userId != null) {
      try {
        localConvs = await _db.getConversations(userId, includeArchived: includeArchived);
      } catch (e) {
        debugPrint('Erreur lecture cache local SQLite: $e');
      }
    }

    // Si on a des conversations locales, on les renvoie immédiatement pour un rendu instantané
    if (localConvs.isNotEmpty) {
      _lastFetchHadError = false;
      // Synchronisation distante en tâche de fond
      _syncRemoteConversationsInBackground(userId, includeArchived);
      return localConvs;
    }

    // Étape 2 : Si la base locale est vide, interroger le serveur
    try {
      final remoteList = await fetchConversationsRaw(includeArchived: includeArchived);
      if (remoteList != null) {
        _lastFetchHadError = false;
        if (userId != null) {
          await _db.upsertConversations(remoteList, userId);
        }
        return remoteList;
      } else {
        _lastFetchHadError = true;
        return [];
      }
    } catch (e) {
      debugPrint('Exception fetching conversations: $e');
      _lastFetchHadError = true;
      return [];
    }
  }

  void _syncRemoteConversationsInBackground(String? userId, bool includeArchived) {
    if (userId == null) return;
    Future.microtask(() async {
      try {
        final remoteList = await fetchConversationsRaw(includeArchived: includeArchived);
        if (remoteList != null) {
          await _db.upsertConversations(remoteList, userId);
        }
      } catch (_) {}
    });
  }

  /// Appel HTTP brut pour les conversations
  Future<List<Conversation>?> fetchConversationsRaw({
    bool includeArchived = false,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/v1/conversations?include_archived=$includeArchived',
    );
    try {
      final response = await http.get(uri, headers: _headers).timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(response.bodyBytes));
        return list.map((item) => Conversation.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('Exception in fetchConversationsRaw: $e');
    }
    return null;
  }

  /// Récupérer le détail d'une conversation et ses messages (Offline-First)
  Future<Map<String, dynamic>?> fetchConversationDetail(
      String conversationId) async {
    final userId = _auth.currentUserId;

    // 1. Récupérer les messages en cache local SQLite
    Conversation? localConv;
    List<ChatMessage> localMessages = [];
    if (userId != null) {
      try {
        localConv = await _db.getConversation(conversationId, userId);
        localMessages = await _db.getMessages(conversationId, userId);
      } catch (e) {
        debugPrint('Erreur lecture messages locaux: $e');
      }
    }

    // 2. Tenter de récupérer les données distantes fraîches
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/v1/conversations/$conversationId',
    );
    try {
      final response = await http.get(uri, headers: _headers).timeout(
        const Duration(seconds: 8),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final convJson = data['conversation'];
        final messagesJson = data['messages'] as List<dynamic>;

        final remoteConv = Conversation.fromJson(convJson);
        final remoteMessages = messagesJson.map((m) => ChatMessage.fromJson(m)).toList();

        // Mettre à jour la base locale
        if (userId != null) {
          await _db.upsertConversation(remoteConv, userId);
          await _db.upsertMessages(conversationId, userId, remoteMessages);
        }

        return {
          'conversation': remoteConv,
          'messages': remoteMessages,
        };
      }
    } catch (e) {
      debugPrint('Exception fetching conversation detail remotely: $e');
    }

    // 3. Fallback complet sur le cache local si hors ligne ou erreur réseau
    if (localConv != null || localMessages.isNotEmpty) {
      return {
        'conversation': localConv ??
            Conversation(
              id: conversationId,
              userId: userId ?? '',
              title: 'Discussion',
              model: AppConfig.defaultModel,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
        'messages': localMessages,
      };
    }

    return null;
  }

  /// Créer une conversation (sauvegarde locale + distante)
  Future<Conversation?> createConversation({
    String title = 'Nouvelle conversation',
    String model = AppConfig.defaultModel,
  }) async {
    final userId = _auth.currentUserId;
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/conversations');

    try {
      final response = await http.post(
        uri,
        headers: _headers,
        body: jsonEncode({
          'title': title,
          'model': model,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final conv = Conversation.fromJson(data);
        if (userId != null) {
          await _db.upsertConversation(conv, userId);
        }
        return conv;
      }
    } catch (e) {
      debugPrint('Exception creating conversation remotely: $e');
    }

    // Si le réseau échoue, créer une conversation locale résiliente
    if (userId != null) {
      final localConv = Conversation(
        id: 'local-${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        title: title,
        model: model,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _db.upsertConversation(localConv, userId, syncStatus: 'pending_create');
      return localConv;
    }

    return null;
  }

  /// Renommer, archiver ou épingler une conversation avec synchronisation intelligente
  Future<bool> updateConversation(
    String conversationId, {
    String? title,
    bool? isArchived,
    bool? isPinned,
  }) async {
    final userId = _auth.currentUserId;

    // 1. Mise à jour immédiate en local pour une réactivité instantanée (Optimistic UI)
    if (userId != null) {
      if (title != null) {
        await _db.renameConversationLocally(conversationId, userId, title);
      }
      if (isArchived != null) {
        await _db.archiveConversationLocally(conversationId, userId, isArchived);
      }
    }

    // 2. Envoi distant
    final success = await updateConversationRemote(
      conversationId,
      title: title,
      isArchived: isArchived,
      isPinned: isPinned,
    );

    // 3. Si échec réseau, enregistrer dans la file d'attente hors ligne
    if (!success && userId != null) {
      final Map<String, dynamic> payload = {};
      String mutationType = 'update_conversation';
      if (title != null) {
        payload['title'] = title;
        mutationType = 'rename_conversation';
      }
      if (isArchived != null) {
        payload['is_archived'] = isArchived;
        mutationType = 'archive_conversation';
      }
      await _db.enqueueMutation(
        userId: userId,
        mutationType: mutationType,
        conversationId: conversationId,
        payload: payload,
      );
    }

    return true;
  }

  /// Mise à jour distante directe vers le serveur
  Future<bool> updateConversationRemote(
    String conversationId, {
    String? title,
    bool? isArchived,
    bool? isPinned,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/v1/conversations/$conversationId',
    );
    try {
      final Map<String, dynamic> body = {};
      if (title != null) body['title'] = title;
      if (isArchived != null) body['is_archived'] = isArchived;
      if (isPinned != null) body['is_pinned'] = isPinned;

      final response = await http.patch(
        uri,
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Exception updating conversation remotely: $e');
      return false;
    }
  }

  /// Supprimer une conversation (local + serveur)
  Future<bool> deleteConversation(String conversationId) async {
    final userId = _auth.currentUserId;

    // 1. Suppression immédiate locale
    if (userId != null) {
      await _db.deleteConversationLocally(conversationId, userId);
    }

    // 2. Suppression distante
    final success = await deleteConversationRemote(conversationId);

    // 3. File d'attente si hors ligne
    if (!success && userId != null) {
      await _db.enqueueMutation(
        userId: userId,
        mutationType: 'delete_conversation',
        conversationId: conversationId,
        payload: {'id': conversationId},
      );
    }

    return true;
  }

  /// Suppression distante directe
  Future<bool> deleteConversationRemote(String conversationId) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/v1/conversations/$conversationId',
    );
    try {
      final response = await http.delete(uri, headers: _headers).timeout(
        const Duration(seconds: 8),
      );
      return response.statusCode == 204;
    } catch (e) {
      debugPrint('Exception deleting conversation remotely: $e');
      return false;
    }
  }

  /// Vérifier l'état et la connectivité réelle du backend Cloud
  Future<Map<String, dynamic>?> checkHealth() async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/health');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Health check exception: $e');
    }
    return null;
  }

  /// Récupérer l'état du quota journalier et le statut d'abonnement (Free vs Premium)
  Future<UserQuota?> fetchUserQuota() async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/quota');
    try {
      final response = await http.get(uri, headers: _headers).timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return UserQuota.fromJson(data);
      }
    } catch (e) {
      debugPrint('Exception fetching quota: $e');
    }
    return null;
  }

  /// Téléverser une pièce jointe (Image ou Fichier texte)
  Future<ChatAttachment?> uploadAttachment({
    required String filePath,
    required String fileName,
    String? conversationId,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/attachments/upload');
    try {
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer ${_auth.accessToken ?? ""}';
      if (conversationId != null) {
        request.fields['conversation_id'] = conversationId;
      }
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        filePath,
        filename: fileName,
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return ChatAttachment.fromJson(data);
      } else {
        String errorMsg = 'Échec du téléversement (${response.statusCode})';
        try {
          final errJson = jsonDecode(utf8.decode(response.bodyBytes));
          if (errJson is Map && errJson.containsKey('detail')) {
            final detail = errJson['detail'];
            if (detail is Map && detail.containsKey('message')) {
              errorMsg = detail['message'] as String;
            } else if (detail is String) {
              errorMsg = detail;
            }
          }
        } catch (_) {}
        debugPrint('Upload failed: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('Exception uploading attachment: $e');
      rethrow;
    }
  }

  /// Supprimer une pièce jointe
  Future<bool> deleteAttachment(String attachmentId) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/attachments/$attachmentId');
    try {
      final response = await http.delete(uri, headers: _headers);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Exception deleting attachment: $e');
      return false;
    }
  }

  /// URL de visualisation / téléchargement direct
  String getAttachmentUrl(String attachmentId) {
    return '${AppConfig.apiBaseUrl}/v1/attachments/$attachmentId/raw';
  }

  /// Envoyer un message et recevoir les tokens en streaming Server-Sent Events (SSE)
  /// Enregistre automatiquement les messages en base SQLite locale.
  ChatStreamHandle streamChatMessage({
    String? conversationId,
    required String content,
    String? editMessageId,
    List<String>? attachmentIds,
    List<ChatAttachment> attachments = const [],
    String model = AppConfig.defaultModel,
    required void Function(String convId, String? title) onInit,
    required void Function(String token) onToken,
    required void Function(String? messageId, String? title) onDone,
    required void Function(String error) onError,
  }) {
    final client = http.Client();
    final handle = ChatStreamHandle(client);
    final userId = _auth.currentUserId ?? '';

    // Enregistrement local du message utilisateur immédiatement
    final userMessageId = editMessageId ?? 'user-${DateTime.now().millisecondsSinceEpoch}';
    final userMsg = ChatMessage(
      id: userMessageId,
      conversationId: conversationId ?? '',
      userId: userId,
      role: MessageRole.user,
      content: content,
      createdAt: DateTime.now(),
      attachments: attachments,
    );

    if (userId.isNotEmpty && conversationId != null && conversationId.isNotEmpty) {
      _db.saveLocalMessage(userMsg, userId);
    }

    () async {
      try {
        final uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/chat/stream');
        final Map<String, dynamic> body = {
          'conversation_id': conversationId,
          'content': content,
          'model': model,
        };
        if (editMessageId != null) {
          body['edit_message_id'] = editMessageId;
        }
        if (attachmentIds != null && attachmentIds.isNotEmpty) {
          body['attachment_ids'] = attachmentIds;
        }

        final request = http.Request('POST', uri)
          ..headers.addAll({
            'Content-Type': 'application/json',
            'Accept': 'text/event-stream',
            'Authorization': 'Bearer ${_auth.accessToken ?? ""}',
          })
          ..body = jsonEncode(body);

        final streamedResponse = await client.send(request);

        if (streamedResponse.statusCode != 200) {
          if (!handle.isCancelled) {
            final errBody = await streamedResponse.stream.bytesToString();
            String errorMsg = 'Erreur serveur (${streamedResponse.statusCode})';
            try {
              final errJson = jsonDecode(errBody);
              if (errJson is Map && errJson.containsKey('detail')) {
                final detail = errJson['detail'];
                if (detail is Map && detail.containsKey('message')) {
                  errorMsg = detail['message'] as String;
                } else if (detail is String) {
                  errorMsg = detail;
                }
              }
            } catch (_) {
              if (errBody.isNotEmpty) errorMsg = errBody;
            }

            if (streamedResponse.statusCode == 401) {
              errorMsg = 'Session expirée ou non autorisée. Veuillez vous reconnecter.';
            } else if (streamedResponse.statusCode == 403 && !errorMsg.toLowerCase().contains('suspendu')) {
              errorMsg = 'Accès non autorisé pour cette opération.';
            } else if (streamedResponse.statusCode == 429) {
              errorMsg = 'Quota journalier atteint. Passez à la formule Premium pour continuer.';
            } else if (streamedResponse.statusCode >= 500) {
              errorMsg = 'Le service IA Google Gemini ou le serveur backend est momentanément indisponible.';
            }

            onError(errorMsg);
          }
          client.close();
          return;
        }

        String buffer = '';
        String accumulatedContent = '';
        String? activeConvId = conversationId;

        await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
          if (handle.isCancelled) break;
          buffer += chunk;
          while (buffer.contains('\n\n')) {
            final eventEnd = buffer.indexOf('\n\n');
            final eventString = buffer.substring(0, eventEnd).trim();
            buffer = buffer.substring(eventEnd + 2);

            if (eventString.startsWith('data: ')) {
              final jsonStr = eventString.substring(6).trim();
              if (jsonStr.isEmpty) continue;

              try {
                final data = jsonDecode(jsonStr) as Map<String, dynamic>;
                final String? convId = data['conversation_id'] as String?;
                final String? title = data['title'] as String?;
                final String token = data['token'] as String? ?? '';
                final bool isDone = data['done'] as bool? ?? false;
                final String? messageId = data['message_id'] as String?;

                if (convId != null) {
                  activeConvId = convId;
                  onInit(convId, title);

                  // Si c'est une nouvelle conversation, s'assurer que le message utilisateur a le bon convId
                  if (userId.isNotEmpty && (conversationId == null || conversationId.isEmpty)) {
                    final updatedUserMsg = ChatMessage(
                      id: userMessageId,
                      conversationId: convId,
                      userId: userId,
                      role: MessageRole.user,
                      content: content,
                      createdAt: userMsg.createdAt,
                      attachments: attachments,
                    );
                    _db.saveLocalMessage(updatedUserMsg, userId);
                  }
                }

                if (token.isNotEmpty && !handle.isCancelled) {
                  accumulatedContent += token;
                  onToken(token);
                }

                if (isDone) {
                  // Sauvegarder le message de l'assistant localement
                  if (userId.isNotEmpty && activeConvId != null) {
                    final assistantMsg = ChatMessage(
                      id: messageId ?? 'asst-${DateTime.now().millisecondsSinceEpoch}',
                      conversationId: activeConvId,
                      userId: userId,
                      role: MessageRole.assistant,
                      content: accumulatedContent,
                      createdAt: DateTime.now(),
                    );
                    await _db.saveLocalMessage(assistantMsg, userId);
                  }
                  onDone(messageId, title);
                }
              } catch (e) {
                debugPrint('Error parsing SSE event: $e');
              }
            }
          }
        }
      } catch (e) {
        if (!handle.isCancelled) {
          final hasInternet = await SyncService.instance.checkRealInternet();
          if (!hasInternet) {
            onError('Hors ligne : aucune connexion Internet active. Votre message est conservé localement.');
          } else {
            final isServerErr = e.toString().contains('SocketException') ||
                e.toString().contains('Failed host lookup') ||
                e.toString().contains('Connection refused') ||
                e.toString().contains('Network is unreachable') ||
                e.toString().contains('ClientException') ||
                e.toString().contains('TimeoutException');

            if (isServerErr) {
              onError('Serveur temporairement indisponible. Impossible de joindre le backend SD.');
            } else {
              onError('Erreur de communication : $e');
            }
          }
        }
      } finally {
        client.close();
      }
    }();

    return handle;
  }
}

/// Handle permettant d'annuler ou d'arrêter une génération SSE en cours
class ChatStreamHandle {
  final http.Client _client;
  bool _isCancelled = false;

  ChatStreamHandle(this._client);

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
    _client.close();
  }
}
