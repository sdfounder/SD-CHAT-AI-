import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/sd_chat_theme.dart';
import 'core/theme/sd_chat_colors.dart';
import 'core/services/auth_service.dart';
import 'core/services/onboarding_service.dart';
import 'core/services/settings_service.dart';
import 'features/chat/screens/chat_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/onboarding/screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Style de la barre d'état système transparente et sombre
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: SDChatColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final authService = AuthService();
  await authService.initialize();

  final onboardingService = OnboardingService.instance;
  await onboardingService.initialize();

  final settingsService = SettingsService.instance;
  await settingsService.initialize();

  runApp(const SDChatApp());
}

class SDChatApp extends StatelessWidget {
  const SDChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final onboarding = OnboardingService.instance;
    final settings = SettingsService.instance;

    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return MaterialApp(
          title: 'SD CHAT AI',
          debugShowCheckedModeBanner: false,
          theme: SDChatTheme.buildTheme(
            brightness: Brightness.light,
            accentColor: settings.accentColor,
          ),
          darkTheme: SDChatTheme.buildTheme(
            brightness: Brightness.dark,
            accentColor: settings.accentColor,
          ),
          themeMode: settings.themeMode,
          home: AnimatedBuilder(
            animation: Listenable.merge([auth, onboarding]),
            builder: (context, _) {
          if (!auth.isInitialized || !onboarding.isInitialized) {
            return const Scaffold(
              backgroundColor: SDChatColors.background,
              body: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: SDChatColors.primary,
                ),
              ),
            );
          }

          // 1. Premier lancement sur cet appareil : Onboarding Premium
          if (!onboarding.isOnboardingCompleted) {
            return const OnboardingScreen();
          }

          // 2. Déjà complété : Authentifié -> ChatScreen, Sinon -> LoginScreen
          if (auth.isAuthenticated) {
            return const ChatScreen();
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  },
);
  }
}
