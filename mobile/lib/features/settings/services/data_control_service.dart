import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/services/auth_service.dart';

class DataControlService {
  static final DataControlService instance = DataControlService._internal();
  factory DataControlService() => instance;
  DataControlService._internal();

  /// Calcule la taille du cache local (fichiers temporaires)
  Future<int> getCacheSizeBytes() async {
    try {
      final tempDir = await getTemporaryDirectory();
      int totalBytes = 0;
      if (tempDir.existsSync()) {
        totalBytes = _getDirectorySize(tempDir);
      }
      return totalBytes;
    } catch (e) {
      debugPrint('Error getting cache size: $e');
      return 0;
    }
  }

  int _getDirectorySize(Directory dir) {
    int size = 0;
    try {
      if (!dir.existsSync()) return 0;
      final entities = dir.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is File) {
          try {
            size += entity.lengthSync();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return size;
  }

  /// Vide le cache local de l'application
  Future<bool> clearAppCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        final entities = tempDir.listSync(recursive: false);
        for (final entity in entities) {
          try {
            entity.deleteSync(recursive: true);
          } catch (_) {}
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error clearing cache: $e');
      return false;
    }
  }

  /// Efface les données locales SQLite de l'appareil
  Future<bool> clearLocalData() async {
    try {
      final userId = AuthService().currentUserId;
      await LocalDatabaseService.instance.clearAllLocalData(userId: userId);
      return true;
    } catch (e) {
      debugPrint('Error clearing local data: $e');
      return false;
    }
  }

  /// Supprime les conversations et messages cloud sur Supabase
  Future<bool> deleteCloudData() async {
    final token = AuthService().accessToken;
    if (token == null || token.isEmpty) return false;

    try {
      final response = await http.delete(
        Uri.parse('${AppConfig.apiBaseUrl}/v1/data/cloud'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // Nettoyer également le stockage local pour refléter la suppression
        await clearLocalData();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting cloud data: $e');
      return false;
    }
  }

  /// Supprime définitivement le compte utilisateur et déconnecte l'application
  Future<bool> deleteAccount() async {
    final token = AuthService().accessToken;
    if (token == null || token.isEmpty) return false;

    try {
      final response = await http.delete(
        Uri.parse('${AppConfig.apiBaseUrl}/v1/users/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        await clearLocalData();
        await clearAppCache();
        await AuthService().signOut();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting account: $e');
      return false;
    }
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 Ko';
    const suffixes = ['o', 'Ko', 'Mo', 'Go'];
    int i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(1)} ${suffixes[i]}';
  }
}
