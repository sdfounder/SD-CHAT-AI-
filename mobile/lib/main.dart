import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/sd_chat_theme.dart';
import 'core/theme/sd_chat_colors.dart';
import 'core/services/auth_service.dart';
import 'features/chat/screens/chat_screen.dart';
import 'features/auth/screens/login_screen.dart';

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

  runApp(const SDChatApp());
}

class SDChatApp extends StatelessWidget {
  const SDChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();

    return MaterialApp(
      title: 'SD CHAT AI',
      debugShowCheckedModeBanner: false,
      theme: SDChatTheme.darkTheme,
      home: AnimatedBuilder(
        animation: auth,
        builder: (context, _) {
          if (auth.isAuthenticated) {
            return const ChatScreen();
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}
