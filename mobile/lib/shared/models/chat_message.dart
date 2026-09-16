import 'chat_attachment.dart';

enum MessageRole { user, assistant, system }

class ChatMessage {
  final String id;
  final String conversationId;
  final String userId;
  final MessageRole role;
  String content;
  final int tokensUsed;
  final String? model;
  final DateTime createdAt;
  final List<ChatAttachment> attachments;
  bool isStreaming;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.role,
    required this.content,
    this.tokensUsed = 0,
    this.model,
    required this.createdAt,
    this.attachments = const [],
    this.isStreaming = false,
  });

  bool get isUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final roleStr = json['role'] as String? ?? 'user';
    MessageRole parsedRole = MessageRole.user;
    if (roleStr == 'assistant') {
      parsedRole = MessageRole.assistant;
    } else if (roleStr == 'system') {
      parsedRole = MessageRole.system;
    }

    final rawAtts = json['attachments'] as List<dynamic>? ?? [];
    final parsedAtts = rawAtts
        .map((a) => ChatAttachment.fromJson(a as Map<String, dynamic>))
        .toList();

    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      userId: json['user_id'] as String? ?? '',
      role: parsedRole,
      content: json['content'] as String? ?? '',
      tokensUsed: json['tokens_used'] as int? ?? 0,
      model: json['model'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      attachments: parsedAtts,
      isStreaming: false,
    );
  }
}
