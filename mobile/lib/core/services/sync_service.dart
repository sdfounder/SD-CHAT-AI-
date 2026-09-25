import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../database/local_database_service.dart';
import 'chat_api_service.dart';
import 'auth_service.dart';

enum SyncState {
  synced,            // 🟢 Connecté & synchronisé
  syncing,           // 🟡 Synchronisation en cours
  serverUnavailable, // 🟠 Serveur temporairement indisponible (Internet OK, backend KO)
  offline,           // 🔴 Hors ligne (Pas de connexion Internet)
  error,             // Synchronisation partielle
}

class SyncService extends ChangeNotifier {
  static final SyncService instance = SyncService._internal();
  factory SyncService() => instance;
  SyncService._internal();

  final LocalDatabaseService _db = LocalDatabaseService.instance;
  final AuthService _auth = AuthService();

  SyncState _status = SyncState.synced;
  DateTime? _lastSyncTime;
  String? _lastErrorMessage;
  bool _isSyncing = false;
  Timer? _autoSyncTimer;

  bool _isInternetAvailable = true;
  bool _isBackendAvailable = true;
  String? activeModelName;

  SyncState get status => _status;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get lastErrorMessage => _lastErrorMessage;
  bool get isSyncing => _isSyncing;
  bool get isOffline => _status == SyncState.offline;
  bool get isServerUnavailable => _status == SyncState.serverUnavailable;
  bool get isOnline => _status == SyncState.synced;
  bool get isInternetAvailable => _isInternetAvailable;
  bool get isBackendAvailable => _isBackendAvailable;

  String get statusLabel {
    switch (_status) {
      case SyncState.synced:
        if (_lastSyncTime != null) {
          final diff = DateTime.now().difference(_lastSyncTime!);
          if (diff.inMinutes < 1) return 'Synchronisé à l\'instant';
          if (diff.inMinutes < 60) return 'Dernière sync : il y a ${diff.inMinutes} min';
          return 'Synchronisé';
        }
        return 'Connecté • En ligne';
      case SyncState.syncing:
        return 'Synchronisation…';
      case SyncState.serverUnavailable:
        return 'Serveur temporairement indisponible';
      case SyncState.offline:
        return 'Hors ligne • Données locales';
      case SyncState.error:
        return 'Synchronisation partielle';
    }
  }

  /// Vérifie si l'appareil a un accès Internet réel (distingue Wi-Fi/mobile seul d'un Internet fonctionnel)
  Future<bool> checkRealInternet() async {
    try {
      // Test TCP direct vers DNS public mondial (Google 8.8.8.8 / port 53)
      final socket = await Socket.connect('8.8.8.8', 53, timeout: const Duration(seconds: 2));
      socket.destroy();
      _isInternetAvailable = true;
      return true;
    } catch (_) {
      try {
        final result = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 2));
        final hasNet = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
        _isInternetAvailable = hasNet;
        return hasNet;
      } catch (_) {
        _isInternetAvailable = false;
        return false;
      }
    }
  }

  /// Vérifie l'état complet : Internet réel + Disponibilité du Backend Render
  Future<void> checkConnectionStatus() async {
    final hasNet = await checkRealInternet();
    if (!hasNet) {
      _isInternetAvailable = false;
      _isBackendAvailable = false;
      _status = SyncState.offline;
      notifyListeners();
      return;
    }

    _isInternetAvailable = true;
    final chatApi = ChatApiService();
    final health = await chatApi.checkHealth();
    if (health != null && health['status'] == 'online') {
      _isBackendAvailable = true;
      if (health.containsKey('ai_model')) {
        activeModelName = health['ai_model'] as String?;
      }
      if (_status != SyncState.syncing) {
        _status = SyncState.synced;
      }
    } else {
      _isBackendAvailable = false;
      _status = SyncState.serverUnavailable;
    }
    notifyListeners();
  }

  void startAutoSync() {
    _autoSyncTimer?.cancel();
    // Synchronisation automatique périodique discrète
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (!_isSyncing) {
        syncAll();
      }
    });
  }

  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  /// Initialise la synchronisation pour l'utilisateur actuel
  Future<void> initialize() async {
    final userId = _auth.currentUserId;
    if (userId != null) {
      _lastSyncTime = await _db.getLastSyncTime(userId);
    }
    await checkConnectionStatus();
    startAutoSync();
    notifyListeners();
  }

  /// Exécute la synchronisation intelligente :
  /// 1. Vérification Internet réel vs Backend
  /// 2. Envoi des mutations locales en attente
  /// 3. Téléchargement des conversations distantes
  /// 4. Mise à jour de la base SQLite locale
  Future<void> syncAll({bool force = false}) async {
    final userId = _auth.currentUserId;
    if (userId == null || _isSyncing) return;

    final hasNet = await checkRealInternet();
    if (!hasNet) {
      _isInternetAvailable = false;
      _isBackendAvailable = false;
      _status = SyncState.offline;
      notifyListeners();
      return;
    }

    _isInternetAvailable = true;
    _isSyncing = true;
    _status = SyncState.syncing;
    notifyListeners();

    try {
      final chatApi = ChatApiService();
      // 1. Vérifier si le backend est réellement joignable
      final health = await chatApi.checkHealth();
      final isBackendOnline = health != null && health['status'] == 'online';

      if (!isBackendOnline) {
        _isBackendAvailable = false;
        _status = SyncState.serverUnavailable;
        _isSyncing = false;
        notifyListeners();
        return;
      }

      _isBackendAvailable = true;
      if (health.containsKey('ai_model')) {
        activeModelName = health['ai_model'] as String?;
      }

      // 2. Traiter la file de mutations locales (Outbox)
      await _flushPendingMutations(userId, chatApi);

      // 3. Récupérer les conversations depuis le backend Cloud
      final remoteConvs = await chatApi.fetchConversationsRaw(includeArchived: true);

      if (remoteConvs != null) {
        await _db.upsertConversations(remoteConvs, userId);
        _lastSyncTime = DateTime.now();
        await _db.setLastSyncTime(userId, _lastSyncTime!);
        _status = SyncState.synced;
        _lastErrorMessage = null;
      } else {
        _status = SyncState.error;
      }
    } catch (e) {
      debugPrint('Sync exception: $e');
      final hasNetNow = await checkRealInternet();
      if (!hasNetNow) {
        _status = SyncState.offline;
      } else {
        _status = SyncState.serverUnavailable;
      }
      _lastErrorMessage = e.toString();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _flushPendingMutations(String userId, ChatApiService api) async {
    final mutations = await _db.getPendingMutations(userId);
    if (mutations.isEmpty) return;

    for (final mut in mutations) {
      final id = mut['id'] as int;
      final type = mut['mutation_type'] as String;
      final convId = mut['conversation_id'] as String?;
      final payloadStr = mut['payload'] as String;

      try {
        final Map<String, dynamic> payload = jsonDecode(payloadStr);

        bool success = false;
        if (type == 'rename_conversation' && convId != null) {
          success = await api.updateConversationRemote(convId, title: payload['title'] as String?);
        } else if (type == 'archive_conversation' && convId != null) {
          success = await api.updateConversationRemote(convId, isArchived: payload['is_archived'] as bool?);
        } else if (type == 'delete_conversation' && convId != null) {
          success = await api.deleteConversationRemote(convId);
        }

        if (success) {
          await _db.removePendingMutation(id);
        } else {
          await _db.incrementMutationRetry(id);
        }
      } catch (e) {
        debugPrint('Error flushing mutation $id: $e');
        await _db.incrementMutationRetry(id);
      }
    }
  }
}
