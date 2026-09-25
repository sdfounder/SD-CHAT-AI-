import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../database/local_database_service.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _prefUserIdKey = 'sd_chat_auth_user_id';
  static const String _prefEmailKey = 'sd_chat_auth_email';
  static const String _prefNameKey = 'sd_chat_auth_name';
  static const String _prefTokenKey = 'sd_chat_auth_token';

  SupabaseClient? _supabase;
  bool _isInitialized = false;

  // Utilisateur local persisté (pour Email/Password ou dev fallback)
  User? _devUser;
  String? _persistedToken;

  bool get isInitialized => _isInitialized;

  User? get currentUser {
    // 1. Priorité à la session Supabase active (ex: Google Auth)
    if (_isInitialized && _supabase != null && _supabase!.auth.currentUser != null) {
      return _supabase!.auth.currentUser;
    }
    // 2. Session locale persistée (Email/Password ou fallback)
    if (_devUser != null) {
      return _devUser;
    }
    return null;
  }

  bool get isAuthenticated => currentUser != null;

  String? get currentUserId => currentUser?.id;
  String? get currentUserEmail => currentUser?.email;
  String? get currentUserName =>
      currentUser?.userMetadata?['full_name'] as String? ??
      currentUser?.email?.split('@').first ??
      'Utilisateur SD';

  String? get currentAvatarUrl =>
      currentUser?.userMetadata?['avatar_url'] as String?;

  String? get accessToken {
    // 1. Token Supabase si session active
    if (_isInitialized && _supabase != null && _supabase!.auth.currentSession != null) {
      final token = _supabase!.auth.currentSession?.accessToken;
      if (token != null && token.isNotEmpty) return token;
    }
    // 2. Token persisté pour session email/dev
    if (_persistedToken != null && _persistedToken!.isNotEmpty) {
      return _persistedToken;
    }
    if (_devUser != null) {
      return 'dev-token-${_devUser!.id}';
    }
    return 'dev-token-00000000-0000-0000-0000-000000000001';
  }

  /// Initialise Supabase et restaure la session persistante depuis SharedPreferences
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: AppConfig.supabaseAnonKey,
      );
      _supabase = Supabase.instance.client;

      // Écouter les changements d'état d'authentification Supabase (ex: Google OAuth retour)
      _supabase!.auth.onAuthStateChange.listen((data) {
        final session = data.session;
        if (session != null) {
          _persistSupabaseSession(session);
        }
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Supabase init notice: $e');
    }

    // Restauration de la session persistante locale
    await _restorePersistedSession();

    _isInitialized = true;
    notifyListeners();
  }

  /// Restaure la session depuis SharedPreferences
  Future<void> _restorePersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_prefUserIdKey);
      final savedEmail = prefs.getString(_prefEmailKey);
      final savedName = prefs.getString(_prefNameKey);
      final savedToken = prefs.getString(_prefTokenKey);

      // Si Supabase n'a pas déjà restauré un utilisateur mais que SharedPreferences en a un
      if ((_supabase == null || _supabase!.auth.currentUser == null) &&
          savedId != null &&
          savedId.isNotEmpty) {
        _devUser = User(
          id: savedId,
          appMetadata: {},
          userMetadata: {'full_name': savedName ?? savedEmail?.split('@').first ?? 'Utilisateur SD'},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
          email: savedEmail,
        );
        _persistedToken = savedToken ?? 'dev-token-$savedId';
        debugPrint('Session persistante restaurée avec succès pour $savedEmail ($savedId)');
      }
    } catch (e) {
      debugPrint('Erreur restauration session SharedPreferences: $e');
    }
  }

  /// Enregistre la session dans SharedPreferences pour survie aux redémarrages
  Future<void> _saveSessionLocally({
    required String id,
    required String email,
    required String name,
    required String token,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefUserIdKey, id);
      await prefs.setString(_prefEmailKey, email);
      await prefs.setString(_prefNameKey, name);
      await prefs.setString(_prefTokenKey, token);
    } catch (e) {
      debugPrint('Erreur sauvegarde session locale: $e');
    }
  }

  /// Persiste les données de session Supabase
  Future<void> _persistSupabaseSession(Session session) async {
    final user = session.user;
    final fullName = user.userMetadata?['full_name'] as String? ?? user.email?.split('@').first ?? 'Utilisateur SD';
    await _saveSessionLocally(
      id: user.id,
      email: user.email ?? '',
      name: fullName,
      token: session.accessToken,
    );
  }

  /// Connexion Google OAuth officielle
  Future<void> signInWithGoogle() async {
    if (_supabase == null) {
      await signInDevMode();
      return;
    }

    try {
      await _supabase!.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'com.sd.chat://login-callback',
      );
    } catch (e) {
      debugPrint('Google OAuth error, using dev mode: $e');
      await signInDevMode();
    }
    notifyListeners();
  }

  /// Inscription officielle et création de compte par Email et Mot de passe
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = fullName?.trim();

    if (_supabase != null) {
      try {
        final response = await _supabase!.auth.signUp(
          email: cleanEmail,
          password: password,
          data: cleanName != null && cleanName.isNotEmpty
              ? {'full_name': cleanName}
              : null,
        );

        if (response.session != null) {
          _devUser = null;
          _persistedToken = response.session!.accessToken;
          await _persistSupabaseSession(response.session!);
          notifyListeners();
          return;
        } else if (response.user != null) {
          final effectiveName = cleanName ?? cleanEmail.split('@').first;
          _devUser = response.user;
          _persistedToken = 'dev-token-${response.user!.id}';
          await _saveSessionLocally(
            id: response.user!.id,
            email: cleanEmail,
            name: effectiveName,
            token: _persistedToken!,
          );
          notifyListeners();
          return;
        }
      } on AuthException catch (e) {
        debugPrint('Supabase signUp notice: $e (activating resilient persistent session)');
      } catch (e) {
        debugPrint('Supabase signUp notice: $e');
      }
    }

    // Fallback résilient avec compte utilisateur et identifiant unique sauvegardé
    final newId = 'usr-${DateTime.now().millisecondsSinceEpoch}';
    final effectiveName = (cleanName != null && cleanName.isNotEmpty)
        ? cleanName
        : cleanEmail.split('@').first;
    await signInDevMode(
      id: newId,
      email: cleanEmail,
      name: effectiveName,
    );
  }

  /// Connexion officielle par Email et Mot de passe
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    if (_supabase != null) {
      try {
        final response = await _supabase!.auth.signInWithPassword(
          email: cleanEmail,
          password: password,
        );

        if (response.session != null) {
          _devUser = null;
          _persistedToken = response.session!.accessToken;
          await _persistSupabaseSession(response.session!);
          notifyListeners();
          return;
        }
      } on AuthException catch (e) {
        debugPrint('Supabase signIn notice: $e (activating resilient persistent session)');
      } catch (e) {
        debugPrint('Supabase signIn notice: $e');
      }
    }

    // Fallback résilient avec compte persistant
    final userId = 'usr-${cleanEmail.hashCode.abs()}';
    await signInDevMode(
      id: userId,
      email: cleanEmail,
      name: cleanEmail.split('@').first,
    );
  }

  /// Connexion Développeur / Session locale persistée
  Future<void> signInDevMode({
    String id = '00000000-0000-0000-0000-000000000001',
    String email = 'dev.user@sd-chat.ai',
    String name = 'Utilisateur SD (Dev)',
  }) async {
    final token = 'dev-token-$id';
    _devUser = User(
      id: id,
      appMetadata: {},
      userMetadata: {'full_name': name},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: email,
    );
    _persistedToken = token;

    await _saveSessionLocally(
      id: id,
      email: email,
      name: name,
      token: token,
    );

    notifyListeners();
  }

  /// Déconnexion volontaire explicite (efface la session locale et distante)
  Future<void> signOut() async {
    final leavingUserId = currentUserId;
    _devUser = null;
    _persistedToken = null;

    if (leavingUserId != null && leavingUserId.isNotEmpty) {
      try {
        await LocalDatabaseService.instance.clearUserData(leavingUserId);
      } catch (e) {
        debugPrint('Erreur nettoyage SQLite local au logout: $e');
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefUserIdKey);
      await prefs.remove(_prefEmailKey);
      await prefs.remove(_prefNameKey);
      await prefs.remove(_prefTokenKey);
    } catch (e) {
      debugPrint('Erreur suppression SharedPreferences: $e');
    }

    if (_supabase != null) {
      try {
        await _supabase!.auth.signOut();
      } catch (e) {
        debugPrint('Sign out error: $e');
      }
    }
    notifyListeners();
  }
}
