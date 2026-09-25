import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/i18n/settings_strings.dart';
import '../../../core/theme/sd_chat_colors.dart';
import '../services/profile_service.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _nameController = TextEditingController();
  final _profileService = ProfileService.instance;
  final _auth = AuthService();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  String? _avatarUrl;
  String? _email;
  String? _authProvider;
  String? _subscriptionPlan;
  String? _role;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final data = await _profileService.fetchProfile();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (data != null) {
          _nameController.text = data['full_name'] as String? ?? _auth.currentUserName ?? '';
          _avatarUrl = data['avatar_url'] as String? ?? _auth.currentAvatarUrl;
          _email = data['email'] as String? ?? _auth.currentUserEmail;
          _authProvider = data['auth_provider'] as String? ?? 'Email';
          _subscriptionPlan = data['subscription_plan'] as String? ?? 'Gratuit';
          _role = data['role'] as String? ?? 'user';
        } else {
          _nameController.text = _auth.currentUserName ?? '';
          _avatarUrl = _auth.currentAvatarUrl;
          _email = _auth.currentUserEmail;
          _authProvider = 'Email';
          _subscriptionPlan = 'Gratuit';
          _role = 'user';
        }
      });
    }
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    Navigator.pop(context); // fermer la sheet
    final picked = await _profileService.pickImage(source);
    if (picked == null) return;

    setState(() {
      _isUploadingAvatar = true;
    });

    final newUrl = await _profileService.uploadAvatar(picked);
    if (mounted) {
      setState(() {
        _isUploadingAvatar = false;
        if (newUrl != null) {
          _avatarUrl = newUrl;
        }
      });

      final lang = SettingsService.instance.languageCode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newUrl != null
              ? SettingsStrings.t('avatar_updated', lang)
              : 'Échec de l\'envoi de la photo.'),
          backgroundColor: newUrl != null ? SDChatColors.success : SDChatColors.error,
        ),
      );
    }
  }

  void _showAvatarSourcePicker() {
    final lang = SettingsService.instance.languageCode;
    showModalBottomSheet(
      context: context,
      backgroundColor: SDChatColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                SettingsStrings.t('edit_avatar', lang),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: SDChatColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: SDChatColors.primary),
                title: Text(SettingsStrings.t('choose_gallery', lang), style: const TextStyle(color: SDChatColors.textPrimary)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: SDChatColors.surfaceElevated,
                onTap: () => _pickAndUploadAvatar(ImageSource.gallery),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: SDChatColors.primary),
                title: Text(SettingsStrings.t('take_photo', lang), style: const TextStyle(color: SDChatColors.textPrimary)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: SDChatColors.surfaceElevated,
                onTap: () => _pickAndUploadAvatar(ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    setState(() {
      _isSaving = true;
    });

    final success = await _profileService.updateProfile(fullName: newName);
    if (mounted) {
      setState(() {
        _isSaving = false;
      });

      final lang = SettingsService.instance.languageCode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? SettingsStrings.t('name_updated', lang)
              : 'Échec de la mise à jour.'),
          backgroundColor: success ? SDChatColors.success : SDChatColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = SettingsService.instance.languageCode;

    return Scaffold(
      backgroundColor: SDChatColors.background,
      appBar: AppBar(
        title: Text(
          SettingsStrings.t('account_title', lang),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: SDChatColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                children: [
                  // Photo de profil avec bouton d'édition
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: SDChatColors.primary, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: SDChatColors.primary.withValues(alpha: 0.25),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: _avatarUrl != null && _avatarUrl!.isNotEmpty
                                ? Image.network(
                                    _avatarUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Icon(
                                      Icons.person_rounded,
                                      size: 52,
                                      color: SDChatColors.primary,
                                    ),
                                  )
                                : const Icon(
                                    Icons.person_rounded,
                                    size: 52,
                                    color: SDChatColors.primary,
                                  ),
                          ),
                        ),
                        if (_isUploadingAvatar)
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black54,
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2, color: SDChatColors.primary),
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap: _showAvatarSourcePicker,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: SDChatColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 16,
                                color: SDChatColors.background,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _showAvatarSourcePicker,
                    icon: const Icon(Icons.edit_rounded, size: 16, color: SDChatColors.primary),
                    label: Text(
                      SettingsStrings.t('edit_avatar', lang),
                      style: const TextStyle(color: SDChatColors.primary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Carte Informations
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: SDChatColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: SDChatColors.borderSubtle, width: 0.8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          SettingsStrings.t('full_name', lang),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: SDChatColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _nameController,
                                style: const TextStyle(color: SDChatColors.textPrimary, fontSize: 14),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: SDChatColors.surfaceElevated,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: SDChatColors.borderMedium),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: SDChatColors.borderSubtle),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: SDChatColors.primary),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: SDChatColors.primary,
                                foregroundColor: SDChatColors.background,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _isSaving ? null : _saveName,
                              child: _isSaving
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: SDChatColors.background))
                                  : Text(SettingsStrings.t('save', lang), style: const TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(color: SDChatColors.borderSubtle, height: 1),
                        const SizedBox(height: 16),

                        // Email
                        Text(
                          SettingsStrings.t('email', lang),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: SDChatColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: SDChatColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: SDChatColors.borderSubtle),
                          ),
                          child: Text(
                            _email ?? 'Non renseigné',
                            style: const TextStyle(color: SDChatColors.textMuted, fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Méthode de connexion & Plan
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    SettingsStrings.t('auth_provider', lang),
                                    style: const TextStyle(fontSize: 12, color: SDChatColors.textSecondary, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: SDChatColors.surfaceElevated,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: SDChatColors.borderSubtle),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _authProvider?.toLowerCase().contains('google') == true
                                              ? Icons.g_mobiledata_rounded
                                              : Icons.mail_outline_rounded,
                                          color: SDChatColors.primary,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _authProvider ?? 'Email',
                                            style: const TextStyle(color: SDChatColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Plan actif',
                                    style: TextStyle(fontSize: 12, color: SDChatColors.textSecondary, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: SDChatColors.surfaceElevated,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: SDChatColors.borderSubtle),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.workspace_premium_rounded, color: SDChatColors.primary, size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _role == 'admin'
                                                ? 'Admin SD'
                                                : (_subscriptionPlan == 'premium' ? 'SD Premium' : 'SD Gratuit'),
                                            style: const TextStyle(color: SDChatColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
