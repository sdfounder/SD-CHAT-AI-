import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sd_chat_ai/main.dart';
import 'package:sd_chat_ai/core/services/onboarding_service.dart';
import 'package:sd_chat_ai/core/services/auth_service.dart';
import 'package:sd_chat_ai/features/onboarding/screens/onboarding_screen.dart';
import 'package:sd_chat_ai/features/auth/screens/login_screen.dart';

import 'package:sd_chat_ai/core/services/sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await OnboardingService.instance.resetForTesting();
    await OnboardingService.instance.initialize();
    await AuthService().initialize();
  });

  tearDown(() {
    SyncService.instance.stopAutoSync();
  });

  group('SD CHAT AI - Mission 19 : Onboarding Premium Animé Tests', () {
    testWidgets('1. First launch displays OnboardingScreen with Screen 1 content', (tester) async {
      await tester.pumpWidget(const SDChatApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('Discutez avec SD CHAT AI'), findsOneWidget);
      expect(
        find.text('Posez vos questions et obtenez des réponses intelligentes en quelques secondes.'),
        findsOneWidget,
      );
      expect(find.text('Passer'), findsOneWidget);
      expect(find.text('Suivant'), findsOneWidget);
    });

    testWidgets('2. Navigation with Suivant cycles through all 4 screens and reaches Commencer button', (tester) async {
      await tester.pumpWidget(const SDChatApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Écran 1
      expect(find.text('Discutez avec SD CHAT AI'), findsOneWidget);

      // Clic Suivant -> Écran 2
      await tester.tap(find.text('Suivant'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Images et documents'), findsOneWidget);
      expect(
        find.text('Ajoutez vos fichiers directement dans vos conversations.'),
        findsOneWidget,
      );

      // Clic Suivant -> Écran 3
      await tester.tap(find.text('Suivant'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Utilisez votre voix'), findsOneWidget);
      expect(
        find.text('Dictez vos messages rapidement grâce à la reconnaissance vocale.'),
        findsOneWidget,
      );

      // Clic Suivant -> Écran 4
      await tester.tap(find.text('Suivant'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Vos conversations restent avec vous'), findsOneWidget);
      expect(
        find.text('Retrouvez vos conversations synchronisées après avoir fermé l\'application.'),
        findsOneWidget,
      );
      expect(find.text('Commencer avec SD CHAT AI'), findsOneWidget);
    });

    testWidgets('3. Clicking Passer immediately completes onboarding and transitions away', (tester) async {
      await tester.pumpWidget(const SDChatApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(OnboardingScreen), findsOneWidget);

      // Clic sur Passer
      await tester.tap(find.text('Passer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Onboarding terminé et persisté
      expect(OnboardingService.instance.isOnboardingCompleted, isTrue);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('4. Completing on Screen 4 persists completion state', (tester) async {
      await tester.pumpWidget(const SDChatApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Avancer jusqu'au dernier écran
      await tester.tap(find.text('Suivant'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Suivant'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Suivant'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Commencer avec SD CHAT AI'), findsOneWidget);
      await tester.tap(find.text('Commencer avec SD CHAT AI'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(OnboardingService.instance.isOnboardingCompleted, isTrue);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('5. Relaunching app when onboarding is completed does NOT show OnboardingScreen', (tester) async {
      // Simuler une réouverture après completion
      SharedPreferences.setMockInitialValues({
        'sd_chat_onboarding_completed_v1': true,
      });
      final onboarding = OnboardingService.instance;
      await onboarding.initialize(force: true);
      expect(onboarding.isOnboardingCompleted, isTrue);

      await tester.pumpWidget(const SDChatApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('6. User signOut does NOT reset onboarding completed status on the device', (tester) async {
      SharedPreferences.setMockInitialValues({
        'sd_chat_onboarding_completed_v1': true,
      });
      final onboarding = OnboardingService.instance;
      await onboarding.initialize(force: true);

      // Déconnexion explicite
      final auth = AuthService();
      try {
        await auth.signOut().timeout(const Duration(seconds: 3));
      } catch (_) {}


      // L'onboarding doit toujours être complété sur cet appareil
      expect(onboarding.isOnboardingCompleted, isTrue);

      await tester.pumpWidget(const SDChatApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });
}
