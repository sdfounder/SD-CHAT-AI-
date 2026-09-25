import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';
import '../../../core/services/auth_service.dart';

class SupportService {
  static final SupportService instance = SupportService._internal();
  factory SupportService() => instance;
  SupportService._internal();

  /// Envoie un rapport de bug, suggestion ou question au support SD
  Future<bool> submitFeedback({
    required String category,
    required String subject,
    required String description,
    String? email,
    Map<String, dynamic>? deviceInfo,
  }) async {
    final token = AuthService().accessToken;

    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final body = <String, dynamic>{
        'category': category,
        'subject': subject,
        'description': description,
      };
      if (email != null && email.isNotEmpty) {
        body['email'] = email;
      }
      if (deviceInfo != null) {
        body['device_info'] = deviceInfo;
      }

      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/v1/support/feedback'),
        headers: headers,
        body: jsonEncode(body),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error submitFeedback: $e');
      return false;
    }
  }

  /// Vérifie la version actuelle de l'application auprès de l'API / Play Store
  Future<Map<String, dynamic>?> checkVersion() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/v1/app/version-check'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Error checkVersion: $e');
      return null;
    }
  }

  /// Diagnostics système pour pré-remplir la fiche de support
  Map<String, dynamic> getDeviceDiagnostics() {
    return {
      'platform': kIsWeb ? 'Web' : Platform.operatingSystem,
      'os_version': kIsWeb ? 'Web Browser' : Platform.operatingSystemVersion,
      'app_version': '1.0.0',
      'app_build': '1',
      'package_name': 'com.sd.chat.sd_chat_ai',
      'backend_url': AppConfig.apiBaseUrl,
      'locale': Platform.localeName,
    };
  }
}
