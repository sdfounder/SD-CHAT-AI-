import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/i18n/settings_strings.dart';
import '../../../core/theme/sd_chat_colors.dart';
import '../services/support_service.dart';

class HelpFeedbackScreen extends StatefulWidget {
  const HelpFeedbackScreen({super.key});

  @override
  State<HelpFeedbackScreen> createState() => _HelpFeedbackScreenState();
}

class _HelpFeedbackScreenState extends State<HelpFeedbackScreen> {
  final _supportService = SupportService.instance;
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _emailController = TextEditingController();

  String _selectedCategory = 'bug';
  XFile? _attachedScreenshot;
  bool _isSubmitting = false;
  late Map<String, dynamic> _diagnostics;

  @override
  void initState() {
    super.initState();
    _emailController.text = AuthService().currentUserEmail ?? '';
    _diagnostics = _supportService.getDeviceDiagnostics();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 80,
    );
    if (picked != null && mounted) {
      setState(() {
        _attachedScreenshot = picked;
      });
    }
  }

  Future<void> _submit() async {
    final lang = SettingsService.instance.languageCode;
    final subject = _subjectController.text.trim();
    final description = _descriptionController.text.trim();

    if (subject.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(SettingsStrings.t('feedback_error_fill', lang)),
          backgroundColor: SDChatColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final success = await _supportService.submitFeedback(
      category: _selectedCategory,
      subject: subject,
      description: description,
      email: _emailController.text.trim(),
      deviceInfo: _diagnostics,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(SettingsStrings.t('feedback_success', lang)),
            backgroundColor: SDChatColors.success,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Échec de l\'envoi du rapport. Veuillez réessayer.'),
            backgroundColor: SDChatColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = SettingsService.instance.languageCode;

    final categories = [
      {'key': 'bug', 'label': SettingsStrings.t('feedback_type_bug', lang), 'icon': Icons.bug_report_rounded},
      {'key': 'suggestion', 'label': SettingsStrings.t('feedback_type_suggestion', lang), 'icon': Icons.lightbulb_rounded},
      {'key': 'billing', 'label': SettingsStrings.t('feedback_type_billing', lang), 'icon': Icons.credit_card_rounded},
      {'key': 'other', 'label': SettingsStrings.t('feedback_type_other', lang), 'icon': Icons.help_outline_rounded},
    ];

    return Scaffold(
      backgroundColor: SDChatColors.background,
      appBar: AppBar(
        title: Text(
          SettingsStrings.t('help_title', lang),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              SettingsStrings.t('feedback_type', lang),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SDChatColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: SDChatColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SDChatColors.borderMedium, width: 0.8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  dropdownColor: SDChatColors.surfaceElevated,
                  icon: const Icon(Icons.arrow_drop_down, color: SDChatColors.primary),
                  isExpanded: true,
                  items: categories.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat['key'] as String,
                      child: Row(
                        children: [
                          Icon(cat['icon'] as IconData, size: 18, color: SDChatColors.primary),
                          const SizedBox(width: 10),
                          Text(cat['label'] as String, style: const TextStyle(color: SDChatColors.textPrimary, fontSize: 14)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 18),

            Text(
              SettingsStrings.t('feedback_subject', lang),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SDChatColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _subjectController,
              style: const TextStyle(color: SDChatColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Ex: Problème de rendu de formule mathématique',
                hintStyle: const TextStyle(color: SDChatColors.textDisabled, fontSize: 13),
                filled: true,
                fillColor: SDChatColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: SDChatColors.borderMedium)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: SDChatColors.borderSubtle)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: SDChatColors.primary)),
              ),
            ),
            const SizedBox(height: 18),

            Text(
              SettingsStrings.t('feedback_desc', lang),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SDChatColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              style: const TextStyle(color: SDChatColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Décrivez précisément la situation rencontrée ou votre suggestion...',
                hintStyle: const TextStyle(color: SDChatColors.textDisabled, fontSize: 13),
                filled: true,
                fillColor: SDChatColors.surface,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: SDChatColors.borderMedium)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: SDChatColors.borderSubtle)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: SDChatColors.primary)),
              ),
            ),
            const SizedBox(height: 18),

            // Capture d'écran
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: SDChatColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SDChatColors.borderSubtle),
              ),
              child: Row(
                children: [
                  const Icon(Icons.image_outlined, color: SDChatColors.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          SettingsStrings.t('feedback_attach_image', lang),
                          style: const TextStyle(color: SDChatColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _attachedScreenshot != null ? _attachedScreenshot!.name : 'Facultatif',
                          style: TextStyle(color: _attachedScreenshot != null ? SDChatColors.success : SDChatColors.textMuted, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SDChatColors.primary,
                      side: const BorderSide(color: SDChatColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _pickScreenshot,
                    child: Text(_attachedScreenshot != null ? 'Modifier' : 'Ajouter', style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Diagnostic système automatique
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: SDChatColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SDChatColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: SDChatColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        SettingsStrings.t('feedback_diag_title', lang),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SDChatColors.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    SettingsStrings.t('feedback_diag_info', lang),
                    style: const TextStyle(fontSize: 11, color: SDChatColors.textMuted),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'OS: ${_diagnostics['platform']} • Ver: ${_diagnostics['app_version']} • Dest: sd.ai.founder@gmail.com',
                    style: const TextStyle(fontSize: 11, color: SDChatColors.textSecondary, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Bouton Envoyer
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: SDChatColors.primary,
                  foregroundColor: SDChatColors.background,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: SDChatColors.background))
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  _isSubmitting ? 'Envoi en cours...' : SettingsStrings.t('feedback_send_btn', lang),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
