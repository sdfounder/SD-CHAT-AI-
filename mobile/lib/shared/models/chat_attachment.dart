class ChatAttachment {
  final String id;
  final String? conversationId;
  final String? messageId;
  final String userId;
  final String fileName;
  final String fileType; // 'image' ou 'text'
  final String storagePath;
  final String mimeType;
  final int fileSizeBytes;
  final DateTime createdAt;
  final String? url;

  // Propriétés UI locales (avant envoi / upload en cours)
  final String? localPath;
  bool isUploading;
  bool hasError;
  String? errorMessage;

  ChatAttachment({
    required this.id,
    this.conversationId,
    this.messageId,
    required this.userId,
    required this.fileName,
    required this.fileType,
    required this.storagePath,
    required this.mimeType,
    required this.fileSizeBytes,
    required this.createdAt,
    this.url,
    this.localPath,
    this.isUploading = false,
    this.hasError = false,
    this.errorMessage,
  });

  bool get isImage => fileType == 'image' || mimeType.startsWith('image/');
  bool get isText => fileType == 'text' || mimeType.startsWith('text/') || fileName.endsWith('.txt') || fileName.endsWith('.md');

  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes o';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} Ko';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} Mo';
  }

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String?,
      messageId: json['message_id'] as String?,
      userId: json['user_id'] as String? ?? '',
      fileName: json['file_name'] as String? ?? 'fichier',
      fileType: json['file_type'] as String? ?? 'text',
      storagePath: json['storage_path'] as String? ?? '',
      mimeType: json['mime_type'] as String? ?? 'application/octet-stream',
      fileSizeBytes: json['file_size_bytes'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      url: json['url'] as String?,
      isUploading: false,
      hasError: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'message_id': messageId,
      'user_id': userId,
      'file_name': fileName,
      'file_type': fileType,
      'storage_path': storagePath,
      'mime_type': mimeType,
      'file_size_bytes': fileSizeBytes,
      'created_at': createdAt.toIso8601String(),
      'url': url,
    };
  }
}
