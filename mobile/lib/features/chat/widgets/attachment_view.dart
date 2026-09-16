import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/theme/sd_chat_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/chat_api_service.dart';
import '../../../shared/models/chat_attachment.dart';

class MessageAttachmentsView extends StatelessWidget {
  final List<ChatAttachment> attachments;
  final bool isUser;

  const MessageAttachmentsView({
    super.key,
    required this.attachments,
    this.isUser = true,
  });

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    final images = attachments.where((a) => a.isImage).toList();
    final texts = attachments.where((a) => a.isText).toList();

    return Column(
      crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // Rendu des images
        if (images.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: isUser ? WrapAlignment.end : WrapAlignment.start,
              children: images.map((att) => _buildImageThumbnail(context, att)).toList(),
            ),
          ),

        // Rendu des fichiers texte
        if (texts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: texts.map((att) => _buildTextFileCard(context, att)).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildImageThumbnail(BuildContext context, ChatAttachment att) {
    Widget imageWidget;
    final auth = AuthService();
    final headers = <String, String>{
      if (auth.accessToken != null) 'Authorization': 'Bearer ${auth.accessToken}',
    };

    if (att.localPath != null && File(att.localPath!).existsSync()) {
      imageWidget = Image.file(
        File(att.localPath!),
        fit: BoxFit.cover,
        width: 160,
        height: 160,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    } else {
      final url = ChatApiService().getAttachmentUrl(att.id);
      imageWidget = Image.network(
        url,
        headers: headers,
        fit: BoxFit.cover,
        width: 160,
        height: 160,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: 160,
            height: 160,
            color: SDChatColors.surface,
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: SDChatColors.primary,
                ),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }

    return GestureDetector(
      onTap: () => _openFullScreenImage(context, att),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: SDChatColors.borderMedium,
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              imageWidget,
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    att.formattedSize,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 160,
      height: 160,
      color: SDChatColors.surfaceHighlight,
      child: const Center(
        child: Icon(
          Icons.broken_image_rounded,
          color: SDChatColors.textMuted,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildTextFileCard(BuildContext context, ChatAttachment att) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openTextFileViewer(context, att),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: SDChatColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: SDChatColors.borderMedium,
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: SDChatColors.surfaceHighlight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: SDChatColors.primary.withValues(alpha: 0.4),
                      width: 0.6,
                    ),
                  ),
                  child: const Icon(
                    Icons.description_rounded,
                    color: SDChatColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        att.fileName,
                        style: const TextStyle(
                          color: SDChatColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Document texte • ${att.formattedSize}',
                        style: const TextStyle(
                          color: SDChatColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.visibility_outlined,
                  size: 16,
                  color: SDChatColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openFullScreenImage(BuildContext context, ChatAttachment att) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(
              att.fileName,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    att.formattedSize,
                    style: const TextStyle(color: SDChatColors.textMuted, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: att.localPath != null && File(att.localPath!).existsSync()
                  ? Image.file(File(att.localPath!))
                  : Image.network(
                      ChatApiService().getAttachmentUrl(att.id),
                      headers: {
                        if (AuthService().accessToken != null)
                          'Authorization': 'Bearer ${AuthService().accessToken}',
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }

  void _openTextFileViewer(BuildContext context, ChatAttachment att) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SDChatColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _TextFileViewerSheet(attachment: att),
    );
  }
}

class _TextFileViewerSheet extends StatefulWidget {
  final ChatAttachment attachment;

  const _TextFileViewerSheet({required this.attachment});

  @override
  State<_TextFileViewerSheet> createState() => _TextFileViewerSheetState();
}

class _TextFileViewerSheetState extends State<_TextFileViewerSheet> {
  String? _content;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFileContent();
  }

  Future<void> _loadFileContent() async {
    try {
      if (widget.attachment.localPath != null &&
          File(widget.attachment.localPath!).existsSync()) {
        final text = await File(widget.attachment.localPath!).readAsString();
        if (mounted) setState(() => _content = text);
      } else {
        final url = ChatApiService().getAttachmentUrl(widget.attachment.id);
        final token = AuthService().accessToken;
        final response = await http.get(
          Uri.parse(url),
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
        );
        if (response.statusCode == 200) {
          if (mounted) setState(() => _content = response.body);
        } else {
          if (mounted) setState(() => _errorMessage = 'Erreur HTTP ${response.statusCode}');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Erreur de lecture: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          // Poignée et entête
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: SDChatColors.borderMedium,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.description_rounded, color: SDChatColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.attachment.fileName,
                    style: const TextStyle(
                      color: SDChatColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  widget.attachment.formattedSize,
                  style: const TextStyle(color: SDChatColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const Divider(color: SDChatColors.borderSubtle, height: 1),
          // Contenu du document
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: SDChatColors.primary,
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: SDChatColors.error),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(18),
                        child: SelectableText(
                          _content ?? '',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            height: 1.5,
                            color: SDChatColors.textPrimary,
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
