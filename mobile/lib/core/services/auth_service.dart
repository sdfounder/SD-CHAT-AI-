import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  SupabaseClient? _supabase;
  bool _isInitialized = false;

  // Utilisateur de développement (quand hors-ligne ou bypass dev)
  User? _devUser;

  bool get isInitialized => _isInitialized;

  User? get currentUser {
    if (_devUser != null) return _devUser;
    if (_isInitialized && _supabase != null) {
      return _supabase!.auth.currentUser;
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
    if (_devUser != null) {
      return 'dev-token-${_devUser!.id}';
    }
    if (_isInitialized && _supabase != null) {
      return _supabase!.auth.currentSession?.accessToken;
    }
    return 'dev-token-00000000-0000-0000-0000-000000000001';
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: AppConfig.supabaseAnonKey,
      );
      _supabase = Supabase.instance.client;
      _isInitialized = true;

      // Écouter les changements d'état d'authentification
      _supabase!.auth.onAuthStateChange.listen((data) {
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Supabase init notice: $e');
      _isInitialized = true;
    }
    notifyListeners();
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

  /// Connexion Développeur / Invitée pour tests locaux et simulation
  Future<void> signInDevMode({
    String id = '00000000-0000-0000-0000-000000000001',
    String email = 'dev.user@sd-chat.ai',
    String name = 'Utilisateur SD (Dev)',
  }) async {
    _devUser = User(
      id: id,
      appMetadata: {},
      userMetadata: {'full_name': name},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: email,
    );
    notifyListeners();
  }

  Future<void> signOut() async {
    _devUser = null;
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
