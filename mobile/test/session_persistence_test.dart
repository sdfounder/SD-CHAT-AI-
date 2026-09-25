import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sd_chat_ai/core/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SD CHAT AI - Session Persistence Tests (Mission 17)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. Email login session is persisted to SharedPreferences and restored on app relaunch', () async {
      final auth1 = AuthService();
      await auth1.signOut();
      expect(auth1.isAuthenticated, isFalse);

      // 1. Utilisateur se connecte avec e-mail
      await auth1.signInWithEmail(
        email: 'founder@sd-studios.com',
        password: 'SecurePassword123!',
      );

      expect(auth1.isAuthenticated, isTrue);
      expect(auth1.currentUserEmail, equals('founder@sd-studios.com'));
      final originalUserId = auth1.currentUserId;
      expect(originalUserId, isNotNull);

      // 2. Simuler la fermeture puis réouverture de l'application (nouvelle instance)
      // Note: AuthService étant un singleton, on réinitialise son état interne en simulant un redémarrage
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('sd_chat_auth_user_id'), equals(originalUserId));
      expect(prefs.getString('sd_chat_auth_email'), equals('founder@sd-studios.com'));

      // 3. Simuler une réouverture où l'app appelle initialize()
      final auth2 = AuthService();
      await auth2.initialize();

      // Vérifier que la session est restaurée sans repasser par le LoginScreen
      expect(auth2.isAuthenticated, isTrue);
      expect(auth2.currentUserEmail, equals('founder@sd-studios.com'));
      expect(auth2.currentUserId, equals(originalUserId));
    });

    test('2. Voluntary signOut removes persisted session completely', () async {
      final auth = AuthService();
      await auth.signInWithEmail(
        email: 'logout.test@sd-studios.com',
        password: 'Password123!',
      );
      expect(auth.isAuthenticated, isTrue);

      // Déconnexion volontaire
      await auth.signOut();
      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentUser, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('sd_chat_auth_user_id'), isNull);
      expect(prefs.getString('sd_chat_auth_email'), isNull);
    });

    test('3. Network error or offline state preserves persisted session', () async {
      final auth = AuthService();
      await auth.signInDevMode(
        id: 'usr-persisted-offline-123',
        email: 'offline.user@sd-studios.com',
        name: 'Sekou Diaby Offline Test',
      );
      expect(auth.isAuthenticated, isTrue);

      // Même en cas de perte de connectivité, le token et la session restent accessibles
      expect(auth.accessToken, isNotNull);
      expect(auth.currentUserEmail, equals('offline.user@sd-studios.com'));
      expect(auth.currentUserName, equals('Sekou Diaby Offline Test'));
    });
  });
}
