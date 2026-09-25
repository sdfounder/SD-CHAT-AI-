import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/sd_chat_colors.dart';
import '../../../core/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _toggleAuthMode(bool isSignUp) {
    if (_isSignUp == isSignUp) return;
    HapticFeedback.selectionClick();
    setState(() {
      _isSignUp = isSignUp;
      _errorMessage = null;
      _successMessage = null;
    });
  }

  Future<void> _handleEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.lightImpact();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      if (_isSignUp) {
        await _auth.signUpWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
          fullName: _fullNameController.text,
        );
      } else {
        await _auth.signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (mounted) {
        setState(() {
          _errorMessage = msg;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    HapticFeedback.lightImpact();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      await _auth.signInWithGoogle();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Erreur de connexion Google : $e";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleDevSignIn() async {
    HapticFeedback.lightImpact();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    await _auth.signInDevMode();
    if (mounted) setState(() => _isLoading = false);
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: SDChatColors.surfaceElevated,
      hintText: hintText,
      hintStyle: const TextStyle(
        color: SDChatColors.textMuted,
        fontSize: 14,
      ),
      prefixIcon: Icon(prefixIcon, color: SDChatColors.secondaryDim, size: 20),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: SDChatColors.borderMedium, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: SDChatColors.borderMedium, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: SDChatColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: SDChatColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: SDChatColors.error, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SDChatColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Emblème Glowing Aura
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: SDChatColors.surfaceElevated,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: SDChatColors.primary.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: SDChatColors.primary.withValues(alpha: 0.2),
                        blurRadius: 36,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.auto_awesome,
                      size: 32,
                      color: SDChatColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Titre & Signature
                const Text(
                  'SD CHAT AI',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: SDChatColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'L\'intelligence conversationnelle souveraine et avancée',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: SDChatColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),

                // Sélecteur Mode : Connexion / Créer un compte
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: SDChatColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: SDChatColors.borderMedium, width: 0.8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _toggleAuthMode(false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !_isSignUp
                                  ? SDChatColors.surfaceHighlight
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: !_isSignUp
                                  ? Border.all(
                                      color: SDChatColors.primary.withValues(alpha: 0.3),
                                      width: 1,
                                    )
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                'Connexion',
                                style: TextStyle(
                                  color: !_isSignUp
                                      ? SDChatColors.primary
                                      : SDChatColors.textSecondary,
                                  fontWeight: !_isSignUp
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _toggleAuthMode(true),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _isSignUp
                                  ? SDChatColors.surfaceHighlight
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: _isSignUp
                                  ? Border.all(
                                      color: SDChatColors.primary.withValues(alpha: 0.3),
                                      width: 1,
                                    )
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                'Créer un compte',
                                style: TextStyle(
                                  color: _isSignUp
                                      ? SDChatColors.primary
                                      : SDChatColors.textSecondary,
                                  fontWeight: _isSignUp
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Formulaire Email / Mot de passe
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Champ Nom Complet (Inscription uniquement)
                      if (_isSignUp) ...[
                        TextFormField(
                          controller: _fullNameController,
                          style: const TextStyle(color: SDChatColors.textPrimary, fontSize: 14),
                          decoration: _buildInputDecoration(
                            hintText: 'Nom complet ou pseudonyme',
                            prefixIcon: Icons.person_outline_rounded,
                          ),
                          validator: (value) {
                            if (_isSignUp && (value == null || value.trim().isEmpty)) {
                              return 'Veuillez saisir votre nom ou pseudo';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Champ Email
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: SDChatColors.textPrimary, fontSize: 14),
                        decoration: _buildInputDecoration(
                          hintText: 'Adresse email',
                          prefixIcon: Icons.alternate_email_rounded,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Veuillez saisir votre adresse email';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                            return 'Adresse email invalide';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Champ Mot de Passe
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: SDChatColors.textPrimary, fontSize: 14),
                        decoration: _buildInputDecoration(
                          hintText: 'Mot de passe (min. 6 caractères)',
                          prefixIcon: Icons.lock_outline_rounded,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: SDChatColors.textMuted,
                              size: 19,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez saisir votre mot de passe';
                          }
                          if (value.length < 6) {
                            return 'Le mot de passe doit comporter au moins 6 caractères';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Champ Confirmation Mot de Passe (Inscription uniquement)
                      if (_isSignUp) ...[
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          style: const TextStyle(color: SDChatColors.textPrimary, fontSize: 14),
                          decoration: _buildInputDecoration(
                            hintText: 'Confirmer le mot de passe',
                            prefixIcon: Icons.lock_reset_rounded,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: SDChatColors.textMuted,
                                size: 19,
                              ),
                              onPressed: () => setState(
                                  () => _obscureConfirmPassword = !_obscureConfirmPassword),
                            ),
                          ),
                          validator: (value) {
                            if (_isSignUp) {
                              if (value == null || value.isEmpty) {
                                return 'Veuillez confirmer votre mot de passe';
                              }
                              if (value != _passwordController.text) {
                                return 'Les mots de passe ne correspondent pas';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Message d'erreur
                      if (_errorMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: SDChatColors.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: SDChatColors.error.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: SDChatColors.error, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: SDChatColors.error,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Message de succès
                      if (_successMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: SDChatColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: SDChatColors.success.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline_rounded,
                                  color: SDChatColors.success, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _successMessage!,
                                  style: const TextStyle(
                                    color: SDChatColors.success,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Bouton Principal Email
                      InkWell(
                        onTap: _isLoading ? null : _handleEmailAuth,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: SDChatColors.primaryGradient,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: SDChatColors.primary.withValues(alpha: 0.25),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.black87,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _isSignUp
                                            ? Icons.person_add_rounded
                                            : Icons.login_rounded,
                                        size: 18,
                                        color: Colors.black87,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _isSignUp
                                            ? 'Créer mon compte'
                                            : 'Se connecter',
                                        style: const TextStyle(
                                          color: Colors.black87,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Séparateur Visuel "OU"
                Row(
                  children: [
                    const Expanded(child: Divider(color: SDChatColors.borderSubtle)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        'OU',
                        style: TextStyle(
                          color: SDChatColors.textMuted.withValues(alpha: 0.8),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: SDChatColors.borderSubtle)),
                  ],
                ),

                const SizedBox(height: 20),

                // Bouton Google Authentication
                InkWell(
                  onTap: _isLoading ? null : _handleGoogleSignIn,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: SDChatColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(14),
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
                        SizedBox(width: 6),
                        Text(
                          'Continuer avec Google',
                          style: TextStyle(
                            color: SDChatColors.textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Bouton Accès Test / Développeur
                TextButton.icon(
                  onPressed: _isLoading ? null : _handleDevSignIn,
                  icon: const Icon(Icons.bolt_rounded, size: 16, color: SDChatColors.primary),
                  label: const Text(
                    'Accès Direct Développeur (Test Local)',
                    style: TextStyle(
                      color: SDChatColors.primary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 36),

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
