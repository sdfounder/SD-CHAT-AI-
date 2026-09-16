import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';
import '../../shared/models/conversation.dart';
import '../../shared/models/chat_message.dart';
import '../../shared/models/chat_attachment.dart';

class ChatApiService {
  static final ChatApiService _instance = ChatApiService._internal();
  factory ChatApiService() => _instance;
  ChatApiService._internal();

  final AuthService _auth = AuthService();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer ${_auth.accessToken ?? ""}',
      };

  /// Récupérer la liste des conversations de l'utilisateur
  Future<List<Conversation>> fetchConversations({
    bool includeArchived = false,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/v1/conversations?include_archived=$includeArchived',
    );
    try {
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(response.bodyBytes));
        return list.map((item) => Conversation.fromJson(item)).toList();
      } else {
        debugPrint('Error fetching conversations: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Exception fetching conversations: $e');
      return [];
    }
  }

  /// Récupérer le détail d'une conversation et ses messages
  Future<Map<String, dynamic>?> fetchConversationDetail(
      String conversationId) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/v1/conversations/$conversationId',
    );
    try {
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final convJson = data['conversation'];
        final messagesJson = data['messages'] as List<dynamic>;

        return {
          'conversation': Conversation.fromJson(convJson),
          'messages':
              messagesJson.map((m) => ChatMessage.fromJson(m)).toList(),
        };
      }
    } catch (e) {
      debugPrint('Exception fetching conversation detail: $e');
    }
    return null;
  }

  /// Créer une conversation
  Future<Conversation?> createConversation({
    String title = 'Nouvelle conversation',
    String model = AppConfig.defaultModel,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/conversations');
    try {
      final response = await http.post(
        uri,
        headers: _headers,
        body: jsonEncode({
          'title': title,
          'model': model,
        }),
      );
      if (response.statusCode == 201) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return Conversation.fromJson(data);
      }
    } catch (e) {
      debugPrint('Exception creating conversation: $e');
    }
    return null;
  }

  /// Renommer, archiver ou épingler une conversation
  Future<bool> updateConversation(
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
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Exception updating conversation: $e');
      return false;
    }
  }

  /// Supprimer une conversation
  Future<bool> deleteConversation(String conversationId) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/v1/conversations/$conversationId',
    );
    try {
      final response = await http.delete(uri, headers: _headers);
      return response.statusCode == 204;
    } catch (e) {
      debugPrint('Exception deleting conversation: $e');
      return false;
    }
  }

  /// Vérifier l'état et la connectivité du backend Cloud
  Future<Map<String, dynamic>?> checkHealth() async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/health');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Health check exception: $e');
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
        debugPrint('Upload failed ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('Exception uploading attachment: $e');
    }
    return null;
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
  /// Retourne un [ChatStreamHandle] permettant d'interrompre la génération à tout moment.
  ChatStreamHandle streamChatMessage({
    String? conversationId,
    required String content,
    String? editMessageId,
    List<String>? attachmentIds,
    String model = AppConfig.defaultModel,
    required void Function(String convId, String? title) onInit,
    required void Function(String token) onToken,
    required void Function(String? messageId, String? title) onDone,
    required void Function(String error) onError,
  }) {
    final client = http.Client();
    final handle = ChatStreamHandle(client);

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
            onError('Erreur serveur (${streamedResponse.statusCode}): $errBody');
          }
          client.close();
          return;
        }

        String buffer = '';
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
                  onInit(convId, title);
                }

                if (token.isNotEmpty && !handle.isCancelled) {
                  onToken(token);
                }

                if (isDone) {
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
          onError('Erreur de connexion: $e');
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
