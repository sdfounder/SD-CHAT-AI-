import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/i18n/settings_strings.dart';
import '../../../core/theme/sd_chat_colors.dart';
import '../services/profile_service.dart';
import '../widgets/language_selector_sheet.dart';
import '../widgets/appearance_selector_sheet.dart';
import '../widgets/font_size_slider_sheet.dart';
import '../widgets/accent_color_picker_sheet.dart';
import '../widgets/version_check_dialog.dart';
import '../widgets/logout_confirm_dialog.dart';
import 'account_settings_screen.dart';
import 'data_control_screen.dart';
import 'terms_of_service_screen.dart';
import 'help_feedback_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = AuthService();
  final _settings = SettingsService.instance;
  final _profileService = ProfileService.instance;

  String? _avatarUrl;
  String? _fullName;
  String? _email;
  String? _plan;

  @override
  void initState() {
    super.initState();
    _loadUserHeader();
  }

  Future<void> _loadUserHeader() async {
    final profile = await _profileService.fetchProfile();
    if (mounted) {
      setState(() {
        if (profile != null) {
          _fullName = profile['full_name'] as String? ?? _auth.currentUserName;
          _avatarUrl = profile['avatar_url'] as String? ?? _auth.currentAvatarUrl;
          _email = profile['email'] as String? ?? _auth.currentUserEmail;
          _plan = profile['subscription_plan'] as String? ?? 'Gratuit';
        } else {
          _fullName = _auth.currentUserName;
          _avatarUrl = _auth.currentAvatarUrl;
          _email = _auth.currentUserEmail;
          _plan = 'Gratuit';
        }
      });
    }
  }

  String _getThemeLabel(ThemeMode mode, String lang) {
    switch (mode) {
      case ThemeMode.light:
        return SettingsStrings.t('theme_light', lang);
      case ThemeMode.system:
        return SettingsStrings.t('theme_system', lang);
      case ThemeMode.dark:
        return SettingsStrings.t('theme_dark', lang);
    }
  }

  String _getFontLabel(double scale, String lang) {
    if (scale <= 0.90) return SettingsStrings.t('font_small', lang);
    if (scale <= 1.05) return SettingsStrings.t('font_normal', lang);
    if (scale <= 1.20) return SettingsStrings.t('font_large', lang);
    return SettingsStrings.t('font_huge', lang);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) {
        final lang = _settings.languageCode;
        final accent = _settings.accentColor;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              SettingsStrings.t('settings_hub_title', lang),
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            centerTitle: false,
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // En-tête profil cliquable menant vers Paramètres du compte
              InkWell(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
                  );
                  _loadUserHeader();
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: SDChatColors.surfaceHighlight,
                            backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                                ? NetworkImage(_avatarUrl!)
                                : null,
                            child: _avatarUrl == null || _avatarUrl!.isEmpty
                                ? Icon(Icons.person_rounded, size: 28, color: accent)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.edit, size: 10, color: Colors.black),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _fullName ?? 'Utilisateur SD',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: SDChatColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _plan == 'premium' ? 'PREMIUM' : 'FREE',
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _email ?? '',
                              style: const TextStyle(fontSize: 13, color: SDChatColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Gérer le profil et les identifiants →',
                              style: TextStyle(fontSize: 11.5, color: accent, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: SDChatColors.textMuted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // SECTION : COMPTE & DONNÉES
              _buildSectionTitle(SettingsStrings.t('section_account_data', lang)),
              const SizedBox(height: 8),
              _buildSettingTile(
                icon: Icons.person_outline_rounded,
                title: SettingsStrings.t('account_title', lang),
                subtitle: SettingsStrings.t('account_subtitle', lang),
                accentColor: accent,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
                  );
                  _loadUserHeader();
                },
              ),
              _buildSettingTile(
                icon: Icons.shield_outlined,
                title: SettingsStrings.t('data_title', lang),
                subtitle: SettingsStrings.t('data_subtitle', lang),
                accentColor: accent,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DataControlScreen()),
                  );
                },
              ),
              const SizedBox(height: 18),

              // SECTION : EXPÉRIENCE & PRÉFÉRENCES
              _buildSectionTitle(SettingsStrings.t('section_preferences', lang)),
              const SizedBox(height: 8),
              _buildSettingTile(
                icon: Icons.language_rounded,
                title: SettingsStrings.t('language_title', lang),
                subtitle: lang == 'fr'
                    ? SettingsStrings.t('lang_french', lang)
                    : SettingsStrings.t('lang_english', lang),
                accentColor: accent,
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const LanguageSelectorSheet(),
                  );
                },
              ),
              _buildSettingTile(
                icon: Icons.palette_outlined,
                title: SettingsStrings.t('appearance_title', lang),
                subtitle: _getThemeLabel(_settings.themeMode, lang),
                accentColor: accent,
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const AppearanceSelectorSheet(),
                  );
                },
              ),
              _buildSettingTile(
                icon: Icons.format_size_rounded,
                title: SettingsStrings.t('font_size_title', lang),
                subtitle: _getFontLabel(_settings.fontScale, lang),
                accentColor: accent,
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const FontSizeSliderSheet(),
                  );
                },
              ),
              _buildSettingTile(
                icon: Icons.color_lens_outlined,
                title: SettingsStrings.t('customization_title', lang),
                subtitle: _settings.accentColorKey == 'yellow' ? 'Aura Amber (Jaune)' : _settings.accentColorKey,
                accentColor: accent,
                trailing: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 1.5),
                  ),
                ),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const AccentColorPickerSheet(),
                  );
                },
              ),
              const SizedBox(height: 18),

              // SECTION : SYSTÈME & SUPPORT
              _buildSectionTitle(SettingsStrings.t('section_about_support', lang)),
              const SizedBox(height: 8),
              _buildSettingTile(
                icon: Icons.system_update_rounded,
                title: SettingsStrings.t('updates_title', lang),
                subtitle: SettingsStrings.t('updates_subtitle', lang),
                accentColor: accent,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => const VersionCheckDialog(),
                  );
                },
              ),
              _buildSettingTile(
                icon: Icons.description_outlined,
                title: SettingsStrings.t('terms_title', lang),
                subtitle: SettingsStrings.t('terms_subtitle', lang),
                accentColor: accent,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
                  );
                },
              ),
              _buildSettingTile(
                icon: Icons.help_outline_rounded,
                title: SettingsStrings.t('help_title', lang),
                subtitle: SettingsStrings.t('help_subtitle', lang),
                accentColor: accent,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HelpFeedbackScreen()),
                  );
                },
              ),
              const SizedBox(height: 22),

              // 10. BOUTON DÉCONNEXION OFFICIEL (ROUGE DISTINCT)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: SDChatColors.error.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    tileColor: SDChatColors.error.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: SDChatColors.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.logout_rounded, color: SDChatColors.error, size: 20),
                    ),
                    title: Text(
                      SettingsStrings.t('logout_title', lang),
                      style: const TextStyle(
                        color: SDChatColors.error,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      SettingsStrings.t('logout_subtitle', lang),
                      style: TextStyle(
                        color: SDChatColors.error.withValues(alpha: 0.75),
                        fontSize: 12,
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: SDChatColors.error),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => const LogoutConfirmDialog(),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Mention officielle obligatoire du créateur et de l'écosystème
              Center(
                child: Column(
                  children: [
                    Text(
                      'SD — Build the Future with AI',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: accent,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Conçu et développé par Sekou Diaby • v1.0.0 (Release)',
                      style: TextStyle(
                        fontSize: 11,
                        color: SDChatColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: SDChatColors.textMuted,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: SDChatColors.borderSubtle,
          width: 0.8,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: SDChatColors.textPrimary,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: SDChatColors.textSecondary,
            ),
          ),
          trailing: trailing ?? const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: SDChatColors.textMuted),
          onTap: onTap,
        ),
      ),
    );
  }
}
