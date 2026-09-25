import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';
import '../../../core/services/auth_service.dart';

class SharedLinkItem {
  final String id;
  final String conversationId;
  final String title;
  final String shareToken;
  final bool isRevoked;
  final int viewsCount;
  final String createdAt;
  final String publicUrl;

  SharedLinkItem({
    required this.id,
    required this.conversationId,
    required this.title,
    required this.shareToken,
    required this.isRevoked,
    required this.viewsCount,
    required this.createdAt,
    required this.publicUrl,
  });

  factory SharedLinkItem.fromJson(Map<String, dynamic> json) {
    return SharedLinkItem(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      title: json['title'] as String? ?? 'Discussion partagée',
      shareToken: json['share_token'] as String,
      isRevoked: json['is_revoked'] as bool? ?? false,
      viewsCount: json['views_count'] as int? ?? 0,
      createdAt: json['created_at'] as String? ?? '',
      publicUrl: json['public_url'] as String? ?? '',
    );
  }
}

class ShareService {
  static final ShareService instance = ShareService._internal();
  factory ShareService() => instance;
  ShareService._internal();

  /// Crée un lien de partage public pour une conversation
  Future<Map<String, dynamic>?> createShareLink(String conversationId) async {
    final token = AuthService().accessToken;
    if (token == null || token.isEmpty) return null;

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/v1/conversations/$conversationId/share'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Error createShareLink: $e');
      return null;
    }
  }

  /// Récupère la liste de tous les liens partagés créés par l'utilisateur
  Future<List<SharedLinkItem>> fetchSharedLinks() async {
    final token = AuthService().accessToken;
    if (token == null || token.isEmpty) return [];

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/v1/conversations/shared/links'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        return list.map((item) => SharedLinkItem.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetchSharedLinks: $e');
      return [];
    }
  }

  /// Révoque l'accès à un lien partagé
  Future<bool> revokeSharedLink(String shareId) async {
    final token = AuthService().accessToken;
    if (token == null || token.isEmpty) return false;

    try {
      final response = await http.delete(
        Uri.parse('${AppConfig.apiBaseUrl}/v1/conversations/shared/$shareId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error revokeSharedLink: $e');
      return false;
    }
  }
}
