import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sd_chat_ai/core/services/auth_service.dart';
import 'package:sd_chat_ai/features/auth/screens/login_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SD CHAT AI - Email & Password Authentication Tests', () {
    late AuthService authService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      authService = AuthService();
      authService.signOut();
    });

    test('1. AuthService signUpWithEmail creates session with clean email and name', () async {
      expect(authService.isAuthenticated, isFalse);

      await authService.signUpWithEmail(
        email: 'test.user@sd-studio.ai',
        password: 'Password123!',
        fullName: 'Sekou Diaby Fan',
      );

      expect(authService.isAuthenticated, isTrue);
      expect(authService.currentUserEmail, equals('test.user@sd-studio.ai'));
      expect(authService.currentUserName, equals('Sekou Diaby Fan'));
      expect(authService.accessToken, isNotNull);
      expect(authService.accessToken, contains('usr-'));
    });

    test('2. AuthService signInWithEmail logs in with given credentials', () async {
      expect(authService.isAuthenticated, isFalse);

      await authService.signInWithEmail(
        email: 'login.test@sd-chat.ai',
        password: 'SecurePassword2026',
      );

      expect(authService.isAuthenticated, isTrue);
      expect(authService.currentUserEmail, equals('login.test@sd-chat.ai'));
      expect(authService.accessToken, isNotNull);
    });

    testWidgets('3. LoginScreen renders email & password fields and toggle tabs',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      // Verify title and branding
      expect(find.text('SD CHAT AI'), findsOneWidget);
      expect(find.text('Connexion'), findsWidgets);
      expect(find.text('Créer un compte'), findsOneWidget);

      // Verify input fields
      expect(find.byType(TextFormField), findsNWidgets(2)); // Email + Password in login mode
      expect(find.text('Adresse email'), findsOneWidget);
      expect(find.text('Mot de passe (min. 6 caractères)'), findsOneWidget);
      expect(find.text('Se connecter'), findsOneWidget);

      // Switch to 'Créer un compte'
      await tester.tap(find.text('Créer un compte'));
      await tester.pumpAndSettle();

      // Now 4 text fields (Full Name, Email, Password, Confirm Password)
      expect(find.byType(TextFormField), findsNWidgets(4));
      expect(find.text('Nom complet ou pseudonyme'), findsOneWidget);
      expect(find.text('Confirmer le mot de passe'), findsOneWidget);
      expect(find.text('Créer mon compte'), findsOneWidget);
    });

    testWidgets('4. LoginScreen form validation triggers on empty submission',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      // Tap submit without entering data
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();

      // Validation errors should appear
      expect(find.text('Veuillez saisir votre adresse email'), findsOneWidget);
      expect(find.text('Veuillez saisir votre mot de passe'), findsOneWidget);
    });
  });
}
