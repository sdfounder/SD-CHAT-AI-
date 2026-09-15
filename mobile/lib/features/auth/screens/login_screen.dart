import 'package:flutter/material.dart';
import '../../../core/theme/sd_chat_colors.dart';
import '../../../core/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    await _auth.signInWithGoogle();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleDevSignIn() async {
    setState(() => _isLoading = true);
    await _auth.signInDevMode();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SDChatColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Emblème Glowing Aura
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: SDChatColors.surfaceElevated,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: SDChatColors.primary.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: SDChatColors.primary.withValues(alpha: 0.18),
                        blurRadius: 36,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.auto_awesome,
                      size: 34,
                      color: SDChatColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Titre & Signature
                const Text(
                  'SD CHAT AI',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: SDChatColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'L\'intelligence conversationnelle souveraine et avancée',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    color: SDChatColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 48),

                // Bouton Google Authentication
                if (_isLoading)
                  const CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: SDChatColors.primary,
                  )
                else ...[
                  InkWell(
                    onTap: _handleGoogleSignIn,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: SDChatColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: SDChatColors.borderMedium,
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.g_mobiledata_rounded,
                            size: 28,
                            color: Colors.white,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Continuer avec Google',
                            style: TextStyle(
                              color: SDChatColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bouton Accès Test / Développeur
                  TextButton.icon(
                    onPressed: _handleDevSignIn,
                    icon: const Icon(Icons.bolt_rounded, size: 16, color: SDChatColors.primary),
                    label: const Text(
                      'Accès Direct Développeur (Test Local)',
                      style: TextStyle(
                        color: SDChatColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 64),

                // Footer Institutionnel SD
                const Text(
                  'SD — Build the Future with AI',
                  style: TextStyle(
                    color: SDChatColors.textMuted,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Fondateur : Sekou Diaby',
                  style: TextStyle(
                    color: SDChatColors.textDisabled,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
