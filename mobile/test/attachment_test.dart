import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sd_chat_ai/shared/models/chat_attachment.dart';
import 'package:sd_chat_ai/shared/models/chat_message.dart';
import 'package:sd_chat_ai/features/chat/widgets/chat_input_bar.dart';
import 'package:sd_chat_ai/features/chat/widgets/attachment_view.dart';

void main() {
  group('SD CHAT AI - Attachments Tests (Mission 5)', () {
    test('1. ChatAttachment model parsing and helper properties', () {
      final imgJson = {
        'id': 'att-1234',
        'user_id': 'user-1',
        'file_name': 'screenshot.png',
        'file_type': 'image',
        'storage_path': 'user-1/att-1234/screenshot.png',
        'mime_type': 'image/png',
        'file_size_bytes': 2048 * 1024, // 2 Mo
        'created_at': '2026-09-16T12:00:00.000Z',
      };

      final imgAtt = ChatAttachment.fromJson(imgJson);
      expect(imgAtt.id, equals('att-1234'));
      expect(imgAtt.fileName, equals('screenshot.png'));
      expect(imgAtt.isImage, isTrue);
      expect(imgAtt.isText, isFalse);
      expect(imgAtt.formattedSize, equals('2.00 Mo'));

      final txtJson = {
        'id': 'att-5678',
        'user_id': 'user-1',
        'file_name': 'notes.txt',
        'file_type': 'text',
        'storage_path': 'user-1/att-5678/notes.txt',
        'mime_type': 'text/plain',
        'file_size_bytes': 1536, // 1.5 Ko
        'created_at': '2026-09-16T12:05:00.000Z',
      };

      final txtAtt = ChatAttachment.fromJson(txtJson);
      expect(txtAtt.id, equals('att-5678'));
      expect(txtAtt.isText, isTrue);
      expect(txtAtt.isImage, isFalse);
      expect(txtAtt.formattedSize, equals('1.5 Ko'));
    });

    test('2. ChatMessage model parses attachments list correctly', () {
      final msgJson = {
        'id': 'msg-1',
        'conversation_id': 'conv-1',
        'user_id': 'user-1',
        'role': 'user',
        'content': 'Regarde ce document',
        'created_at': '2026-09-16T12:10:00.000Z',
        'attachments': [
          {
            'id': 'att-100',
            'user_id': 'user-1',
            'file_name': 'data.csv',
            'file_type': 'text',
            'storage_path': 'user-1/att-100/data.csv',
            'mime_type': 'text/csv',
            'file_size_bytes': 512,
            'created_at': '2026-09-16T12:10:00.000Z',
          }
        ],
      };

      final msg = ChatMessage.fromJson(msgJson);
      expect(msg.isUser, isTrue);
      expect(msg.attachments.length, equals(1));
      expect(msg.attachments.first.fileName, equals('data.csv'));
      expect(msg.attachments.first.isText, isTrue);
    });

    testWidgets('3. ChatInputBar displays paperclip attachment button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInputBar(
              onSend: (text, atts) {},
            ),
          ),
        ),
      );

      // Le bouton trombone 📎 pour les pièces jointes doit être affiché
      final attachBtn = find.byIcon(Icons.attach_file_rounded);
      expect(attachBtn, findsOneWidget);
    });

    testWidgets('4. MessageAttachmentsView renders text file card and size badge', (tester) async {
      final testAtt = ChatAttachment(
        id: 'test-text-id',
        userId: 'user-1',
        fileName: 'bilan_financier.txt',
        fileType: 'text',
        storagePath: 'user-1/test.txt',
        mimeType: 'text/plain',
        fileSizeBytes: 4096,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageAttachmentsView(
              attachments: [testAtt],
              isUser: true,
            ),
          ),
        ),
      );

      // Nom du fichier et type
      expect(find.text('bilan_financier.txt'), findsOneWidget);
      expect(find.text('Document texte • 4.0 Ko'), findsOneWidget);
      expect(find.byIcon(Icons.description_rounded), findsOneWidget);
    });
  });
}
