import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';
import '../../shared/models/conversation.dart';
import '../../shared/models/chat_message.dart';

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

  /// Renommer une conversation
  Future<bool> updateConversation(String conversationId,
      {String? title}) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/v1/conversations/$conversationId',
    );
    try {
      final response = await http.patch(
        uri,
        headers: _headers,
        body: jsonEncode({'title': ?title}),
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

  /// Envoyer un message et recevoir les tokens en streaming Server-Sent Events (SSE)
  Future<void> streamChatMessage({
    String? conversationId,
    required String content,
    String model = AppConfig.defaultModel,
    required void Function(String convId, String? title) onInit,
    required void Function(String token) onToken,
    required void Function(String? messageId, String? title) onDone,
    required void Function(String error) onError,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/chat/stream');
    final client = http.Client();

    try {
      final request = http.Request('POST', uri)
        ..headers.addAll({
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
          'Authorization': 'Bearer ${_auth.accessToken ?? ""}',
        })
        ..body = jsonEncode({
          'conversation_id': ?conversationId,
          'content': content,
          'model': model,
        });

      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode != 200) {
        final errBody = await streamedResponse.stream.bytesToString();
        onError('Erreur serveur (${streamedResponse.statusCode}): $errBody');
        client.close();
        return;
      }

      String buffer = '';
      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
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

              if (token.isNotEmpty) {
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
      onError('Erreur de connexion: $e');
    } finally {
      client.close();
    }
  }
}
