/// Dictionnaire officiel de chaînes internationalisées pour le centre « Paramètres » de SD CHAT AI.
/// Conçu pour supporter nativement le Français (par défaut) et l'Anglais,
/// et préparé structurellement pour les langues ouest-africaines (N'Ko, ADLaM, Susu).
class SettingsStrings {
  static const Map<String, Map<String, String>> _localizedValues = {
    'fr': {
      // Hub & Sections
      'settings_hub_title': 'Paramètres',
      'section_account_data': 'Compte & Données',
      'section_preferences': 'Expérience & Préférences',
      'section_about_support': 'Système & Support',

      // 1. Paramètres du compte
      'account_title': 'Paramètres du compte',
      'account_subtitle': 'Profil, photo, identifiants et sécurité',
      'full_name': 'Nom complet',
      'email': 'Adresse email',
      'auth_provider': 'Méthode de connexion',
      'edit_avatar': 'Modifier la photo',
      'choose_gallery': 'Choisir depuis la galerie',
      'take_photo': 'Prendre une photo',
      'save': 'Enregistrer',
      'name_updated': 'Nom mis à jour avec succès.',
      'avatar_updated': 'Photo de profil mise à jour avec succès.',

      // 2. Contrôle des données
      'data_title': 'Contrôle des données',
      'data_subtitle': 'Gestion du cache, stockage local et cloud',
      'cache_title': 'Cache de l\'application',
      'cache_desc': 'Libérez de l\'espace temporaire sans affecter votre historique.',
      'cache_size': 'Taille actuelle',
      'clear_cache_btn': 'Vider le cache',
      'cache_cleared': 'Le cache a été vidé avec succès.',
      'clear_local_title': 'Effacer les données locales',
      'clear_local_desc': 'Supprime le cache de conversations et messages SQLite de cet appareil.',
      'clear_local_btn': 'Effacer les données locales',
      'clear_local_confirm': 'Voulez-vous supprimer les discussions téléchargées hors ligne ? Vos conversations cloud restent préservées.',
      'local_cleared_success': 'Données locales supprimées de cet appareil.',
      'delete_cloud_title': 'Supprimer les données cloud',
      'delete_cloud_desc': 'Supprime définitivement toutes vos conversations et messages stockés sur Supabase.',
      'delete_cloud_btn': 'Supprimer toutes mes discussions',
      'delete_cloud_confirm': 'Attention : Cette action effacera irrévocablement toutes vos conversations et messages du cloud.',
      'cloud_deleted_success': 'Toutes les données cloud ont été supprimées.',
      'delete_account_title': 'Supprimer mon compte',
      'delete_account_desc': 'Supprime irréversiblement votre compte, vos quotas et l\'ensemble de vos données.',
      'delete_account_btn': 'Supprimer définitivement mon compte',
      'delete_account_confirm': 'Cette action est irréversible. Toutes vos données seront détruites et vous serez immédiatement déconnecté.',
      'delete_account_type_confirm': 'Tapez « SUPPRIMER » pour confirmer :',
      'shared_links': 'Liens partagés',
      'shared_links_desc': 'Consultez et révoquez les liens publics créés pour vos discussions.',
      'manage_links': 'Gérer les liens partagés',
      'no_shared_links': 'Aucun lien partagé',
      'no_shared_links_desc': 'Vous n\'avez pas encore partagé de conversation publiquement.',
      'link_copied': 'Lien copié dans le presse-papiers.',
      'link_revoked_success': 'Lien public révoqué avec succès.',
      'revoke': 'Révoquer',

      // 3. Langue
      'language_title': 'Langue',
      'language_subtitle': 'Choisissez la langue de l\'interface',
      'lang_french': 'Français (Par défaut)',
      'lang_english': 'English',

      // 4. Apparence
      'appearance_title': 'Apparence',
      'appearance_subtitle': 'Thème visuel et luminosité',
      'theme_dark': 'Sombre',
      'theme_light': 'Clair',
      'theme_system': 'Système',

      // 5. Taille de la police
      'font_size_title': 'Taille de la police',
      'font_size_subtitle': 'Ajustez la taille du texte des réponses IA',
      'font_small': 'Petit',
      'font_normal': 'Normal',
      'font_large': 'Grand',
      'font_huge': 'Très grand',
      'font_size_sample': 'L\'intelligence artificielle de SD CHAT AI s\'adapte à votre confort de lecture. « SD — Build the Future with AI »',

      // 6. Personnalisation
      'customization_title': 'Personnalisation',
      'customization_subtitle': 'Choisissez votre couleur d\'accentuation',

      // 7. Mises à jour
      'updates_title': 'Vérifier les mises à jour',
      'updates_subtitle': 'Version actuelle et disponibilité Play Store',
      'up_to_date_desc': 'Vous utilisez la dernière version officielle de SD CHAT AI.',
      'open_store': 'Google Play Store',

      // 8. Contrat de service
      'terms_title': 'Contrat de service',
      'terms_subtitle': 'Confidentialité, licences et informations légales',
      'tab_privacy': 'Confidentialité',
      'tab_license': 'Licence',
      'tab_about_sd': 'À propos de SD',
      'tab_subscription_rules': 'Abonnements',

      // 9. Aide et commentaires
      'help_title': 'Aide et commentaires',
      'help_subtitle': 'Signalez un problème ou envoyez une suggestion',
      'feedback_type': 'Type de demande',
      'feedback_type_bug': 'Signaler un bug',
      'feedback_type_suggestion': 'Suggestion ou idée',
      'feedback_type_billing': 'Abonnement & Facturation',
      'feedback_type_other': 'Autre demande',
      'feedback_subject': 'Sujet',
      'feedback_desc': 'Description détaillée',
      'feedback_attach_image': 'Capture d\'écran',
      'feedback_diag_title': 'Diagnostics système inclus',
      'feedback_diag_info': 'Ces informations techniques aident l\'équipe de Sekou Diaby à résoudre rapidement les anomalies.',
      'feedback_send_btn': 'Envoyer au support SD',
      'feedback_error_fill': 'Veuillez remplir le sujet et la description.',
      'feedback_success': 'Votre message a été transmis au support SD (sd.ai.founder@gmail.com).',

      // 10. Déconnexion
      'logout_title': 'Déconnexion',
      'logout_subtitle': 'Fermer la session sur cet appareil',
      'logout_confirm_msg': 'Voulez-vous vraiment vous déconnecter de votre compte SD CHAT AI ? Vos discussions enregistrées sur le cloud restent protégées.',

      // Génériques
      'cancel': 'Annuler',
      'confirm': 'Confirmer',
      'close': 'Fermer',
    },
    'en': {
      // Hub & Sections
      'settings_hub_title': 'Settings',
      'section_account_data': 'Account & Data',
      'section_preferences': 'Experience & Preferences',
      'section_about_support': 'System & Support',

      // 1. Account Settings
      'account_title': 'Account Settings',
      'account_subtitle': 'Profile, photo, credentials and security',
      'full_name': 'Full name',
      'email': 'Email address',
      'auth_provider': 'Sign-in method',
      'edit_avatar': 'Change photo',
      'choose_gallery': 'Choose from gallery',
      'take_photo': 'Take a photo',
      'save': 'Save',
      'name_updated': 'Name updated successfully.',
      'avatar_updated': 'Profile photo updated successfully.',

      // 2. Data Control
      'data_title': 'Data Control',
      'data_subtitle': 'Cache management, local and cloud storage',
      'cache_title': 'App Cache',
      'cache_desc': 'Free up temporary space without affecting your history.',
      'cache_size': 'Current size',
      'clear_cache_btn': 'Clear Cache',
      'cache_cleared': 'Cache cleared successfully.',
      'clear_local_title': 'Clear Local Data',
      'clear_local_desc': 'Removes cached offline SQLite messages from this device.',
      'clear_local_btn': 'Clear Local Data',
      'clear_local_confirm': 'Do you want to delete locally cached chats? Your cloud chats will remain intact.',
      'local_cleared_success': 'Local data cleared from this device.',
      'delete_cloud_title': 'Delete Cloud Data',
      'delete_cloud_desc': 'Permanently deletes all your chats and messages stored on Supabase.',
      'delete_cloud_btn': 'Delete all my chats',
      'delete_cloud_confirm': 'Warning: This action will permanently delete all your cloud chats. This cannot be undone.',
      'cloud_deleted_success': 'All cloud data has been deleted.',
      'delete_account_title': 'Delete Account',
      'delete_account_desc': 'Irreversibly deletes your account, quotas and all associated data.',
      'delete_account_btn': 'Delete my account permanently',
      'delete_account_confirm': 'This action is irreversible. All your data will be erased and you will be signed out immediately.',
      'delete_account_type_confirm': 'Type "DELETE" to confirm:',
      'shared_links': 'Shared Links',
      'shared_links_desc': 'View and revoke public links created for your conversations.',
      'manage_links': 'Manage shared links',
      'no_shared_links': 'No shared links',
      'no_shared_links_desc': 'You have not shared any conversation publicly yet.',
      'link_copied': 'Link copied to clipboard.',
      'link_revoked_success': 'Public link revoked successfully.',
      'revoke': 'Revoke',

      // 3. Language
      'language_title': 'Language',
      'language_subtitle': 'Choose interface language',
      'lang_french': 'Français (Default)',
      'lang_english': 'English',

      // 4. Appearance
      'appearance_title': 'Appearance',
      'appearance_subtitle': 'Visual theme and brightness',
      'theme_dark': 'Dark',
      'theme_light': 'Light',
      'theme_system': 'System',

      // 5. Font Size
      'font_size_title': 'Font Size',
      'font_size_subtitle': 'Adjust reading size for AI responses',
      'font_small': 'Small',
      'font_normal': 'Regular',
      'font_large': 'Large',
      'font_huge': 'Extra Large',
      'font_size_sample': 'SD CHAT AI adapts to your reading comfort. "SD — Build the Future with AI"',

      // 6. Customization
      'customization_title': 'Customization',
      'customization_subtitle': 'Choose your accent highlight color',

      // 7. Updates
      'updates_title': 'Check for Updates',
      'updates_subtitle': 'Current version and Play Store availability',
      'up_to_date_desc': 'You are using the latest official version of SD CHAT AI.',
      'open_store': 'Google Play Store',

      // 8. Terms of Service
      'terms_title': 'Terms of Service',
      'terms_subtitle': 'Privacy, licenses and legal information',
      'tab_privacy': 'Privacy Policy',
      'tab_license': 'License',
      'tab_about_sd': 'About SD',
      'tab_subscription_rules': 'Subscriptions',

      // 9. Help and Feedback
      'help_title': 'Help & Feedback',
      'help_subtitle': 'Report an issue or send a suggestion',
      'feedback_type': 'Request type',
      'feedback_type_bug': 'Report a bug',
      'feedback_type_suggestion': 'Suggestion or idea',
      'feedback_type_billing': 'Subscription & Billing',
      'feedback_type_other': 'Other request',
      'feedback_subject': 'Subject',
      'feedback_desc': 'Detailed description',
      'feedback_attach_image': 'Screenshot',
      'feedback_diag_title': 'System diagnostics included',
      'feedback_diag_info': 'These technical details help Sekou Diaby\'s team fix bugs faster.',
      'feedback_send_btn': 'Send to SD Support',
      'feedback_error_fill': 'Please enter both a subject and a description.',
      'feedback_success': 'Your message has been sent to SD Support (sd.ai.founder@gmail.com).',

      // 10. Logout
      'logout_title': 'Sign Out',
      'logout_subtitle': 'Close session on this device',
      'logout_confirm_msg': 'Are you sure you want to sign out of SD CHAT AI? Your cloud-saved conversations remain secure.',

      // Generic
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'close': 'Close',
    },
  };

  static String get(String key, {String lang = 'fr'}) {
    final values = _localizedValues[lang] ?? _localizedValues['fr']!;
    return values[key] ?? _localizedValues['fr']![key] ?? key;
  }

  static String t(String key, [String lang = 'fr']) {
    return get(key, lang: lang);
  }
}
