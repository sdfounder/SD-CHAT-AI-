import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/auth_service.dart';

class ProfileService {
  static final ProfileService instance = ProfileService._internal();
  factory ProfileService() => instance;
  ProfileService._internal();

  final ImagePicker _picker = ImagePicker();

  Future<Map<String, dynamic>?> fetchProfile() async {
    final token = AuthService().accessToken;
    if (token == null || token.isEmpty) return null;

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/v1/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      } else {
        debugPrint('Fetch profile failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetchProfile: $e');
      return null;
    }
  }

  Future<bool> updateProfile({String? fullName, Map<String, dynamic>? preferences}) async {
    final token = AuthService().accessToken;
    if (token == null || token.isEmpty) return false;

    try {
      final body = <String, dynamic>{};
      if (fullName != null) body['full_name'] = fullName;
      if (preferences != null) body['preferences'] = preferences;

      final response = await http.patch(
        Uri.parse('${AppConfig.apiBaseUrl}/v1/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updateProfile: $e');
      return false;
    }
  }

  Future<XFile?> pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      return picked;
    } catch (e) {
      debugPrint('Error pickImage: $e');
      return null;
    }
  }

  Future<String?> uploadAvatar(XFile file) async {
    final token = AuthService().accessToken;
    if (token == null || token.isEmpty) return null;

    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/profile/avatar');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      final bytes = await file.readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: file.name.isNotEmpty ? file.name : 'avatar.jpg',
      );
      request.files.add(multipartFile);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final newUrl = data['avatar_url'] as String?;
        return newUrl;
      } else {
        debugPrint('Upload avatar failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploadAvatar: $e');
      return null;
    }
  }
}
