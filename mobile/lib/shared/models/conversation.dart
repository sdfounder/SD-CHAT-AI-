class Conversation {
  final String id;
  final String userId;
  final String title;
  final String model;
  final String? systemPrompt;
  final bool isArchived;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int messageCount;
  final String? lastMessagePreview;

  const Conversation({
    required this.id,
    required this.userId,
    required this.title,
    required this.model,
    this.systemPrompt,
    this.isArchived = false,
    this.isPinned = false,
    required this.createdAt,
    required this.updatedAt,
    this.messageCount = 0,
    this.lastMessagePreview,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      title: json['title'] as String? ?? 'Nouvelle conversation',
      model: json['model'] as String? ?? 'gemini-3.6-flash',
      systemPrompt: json['system_prompt'] as String?,
      isArchived: json['is_archived'] as bool? ?? false,
      isPinned: json['is_pinned'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      messageCount: json['message_count'] as int? ?? 0,
      lastMessagePreview: json['last_message_preview'] as String?,
    );
  }

  Conversation copyWith({
    String? title,
    bool? isArchived,
    bool? isPinned,
    DateTime? updatedAt,
    int? messageCount,
    String? lastMessagePreview,
  }) {
    return Conversation(
      id: id,
      userId: userId,
      title: title ?? this.title,
      model: model,
      systemPrompt: systemPrompt,
      isArchived: isArchived ?? this.isArchived,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messageCount: messageCount ?? this.messageCount,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
    );
  }
}
