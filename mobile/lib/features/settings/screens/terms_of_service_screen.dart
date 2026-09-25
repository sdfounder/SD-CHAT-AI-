import 'package:flutter/material.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/i18n/settings_strings.dart';
import '../../../core/theme/sd_chat_colors.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = SettingsService.instance.languageCode;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: SDChatColors.background,
        appBar: AppBar(
          title: Text(
            SettingsStrings.t('terms_title', lang),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: SDChatColors.primary,
            labelColor: SDChatColors.primary,
            unselectedLabelColor: SDChatColors.textMuted,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: [
              Tab(text: SettingsStrings.t('tab_privacy', lang)),
              Tab(text: SettingsStrings.t('tab_license', lang)),
              Tab(text: SettingsStrings.t('tab_about_sd', lang)),
              Tab(text: SettingsStrings.t('tab_subscription_rules', lang)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDocView(
              title: 'Politique de Confidentialité de SD CHAT AI',
              updatedAt: 'Dernière mise à jour : Septembre 2026',
              sections: [
                _DocSection(
                  title: '1. Collecte et protection des données',
                  content:
                      'SD CHAT AI s\'engage à protéger rigoureusement vos données personnelles. Les données d\'identification (nom, adresse email, identifiant unique) sont strictement nécessaires au fonctionnement du service et à la synchronisation multi-appareils.',
                ),
                _DocSection(
                  title: '2. Conversations et isolation stricte',
                  content:
                      'Vos conversations, messages et pièces jointes sont chiffrés en transit (TLS 1.3) et au repos dans l\'infrastructure Supabase PostgreSQL sécurisée par des règles RLS (Row Level Security). Aucun autre utilisateur ne peut accéder à vos échanges privés, sauf si vous choisissez explicitement de générer un lien public de partage.',
                ),
                _DocSection(
                  title: '3. Modèles d\'Intelligence Artificielle',
                  content:
                      'Les requêtes transmises aux modèles via notre passerelle SD AI Gateway (Google Gemini, modèles haute performance) sont traitées en temps réel. Vos données et requêtes privées ne sont jamais utilisées pour entraîner de futurs modèles d\'IA fondationnels sans votre consentement explicite.',
                ),
                _DocSection(
                  title: '4. Droit à l\'oubli et suppression',
                  content:
                      'Conformément aux normes internationales et au RGPD, vous disposez du contrôle total de vos données. Vous pouvez à tout moment vider votre cache, supprimer toutes vos conversations cloud ou supprimer définitivement votre compte dans la section « Contrôle des données » de l\'application.',
                ),
              ],
            ),
            _buildDocView(
              title: 'Licence Logicielle et Conditions d\'Usage',
              updatedAt: 'Version 1.0 — 2026',
              sections: [
                _DocSection(
                  title: '1. Propriété Intellectuelle',
                  content:
                      'L\'ensemble du code source, de la conception visuelle Aura Obsidian, du logo officiel, de la marque SD et de la marque SD CHAT AI sont la propriété exclusive de Sekou Diaby et de l\'écosystème SD (« SD — Build the Future with AI »).',
                ),
                _DocSection(
                  title: '2. Licence d\'Utilisation Personnelle',
                  content:
                      'Une licence personnelle, non exclusive, révocable et non transférable vous est accordée pour utiliser l\'application SD CHAT AI sur vos terminaux compatibles à des fins personnelles ou professionnelles autorisées.',
                ),
                _DocSection(
                  title: '3. Restrictions d\'Usage',
                  content:
                      'Il est strictement interdit de procéder à l\'ingénierie inverse, au décompilage, à la reproduction frauduleuse de l\'API, à la tentative de contournement des quotas ou à l\'utilisation du service pour générer du contenu illégal, malveillant ou diffamatoire.',
                ),
              ],
            ),
            _buildDocView(
              title: 'À Propos de SD et de Sekou Diaby',
              updatedAt: 'Vision Officielle 2026',
              sections: [
                _DocSection(
                  title: '1. La Vision SD — Build the Future with AI',
                  content:
                      'Fondé par Sekou Diaby, l\'écosystème SD a pour mission d\'apporter des solutions d\'intelligence artificielle concrètes, ultra-rapides et accessibles à l\'échelle mondiale, en intégrant nativement les réalités linguistiques et technologiques africaines et internationales.',
                ),
                _DocSection(
                  title: '2. Le Créateur : Sekou Diaby',
                  content:
                      'Sekou Diaby est le concepteur et architecte de l\'écosystème SD (SD CHAT AI, SD MEDIA, SD AI Gateway). Il pilote le développement technologique pour offrir des outils modernes alliant esthétique noble (Aura Obsidian, Titane brossé) et puissance de calcul de pointe.',
                ),
                _DocSection(
                  title: '3. Contact et Support',
                  content:
                      'Pour toute question relative aux partenariats, investissements ou intégrations : sd.ai.founder@gmail.com.',
                ),
              ],
            ),
            _buildDocView(
              title: 'Règles relatives aux Abonnements et Paiements',
              updatedAt: 'Applicable dès la souscription',
              sections: [
                _DocSection(
                  title: '1. Formules et Tarifs',
                  content:
                      'SD CHAT AI propose une formule Gratuite avec quotas quotidiens et une formule SD Premium (19,99 € / mois) débloquant l\'accès illimité aux modèles d\'IA d\'élite, la vitesse de streaming maximale et la priorité sur les serveurs.',
                ),
                _DocSection(
                  title: '2. Modalités de Règlement',
                  content:
                      'Les paiements par carte bancaire sont traités de façon sécurisée par Stripe conformément à la norme PCI-DSS. Les modes de paiement mobiles (Orange Money, MTN MoMo, Wave) sont pris en charge selon les zones géographiques éligibles.',
                ),
                _DocSection(
                  title: '3. Renouvellement et Résiliation',
                  content:
                      'Les abonnements se renouvellent tacitement chaque mois. L\'utilisateur peut résilier son abonnement à tout moment depuis son tableau de bord de facturation sans frais supplémentaires. La période en cours reste active jusqu\'à son terme.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocView({
    required String title,
    required String updatedAt,
    required List<_DocSection> sections,
  }) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: SDChatColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          updatedAt,
          style: const TextStyle(fontSize: 12, color: SDChatColors.textMuted),
        ),
        const SizedBox(height: 20),
        for (final sec in sections) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SDChatColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SDChatColors.borderSubtle, width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sec.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: SDChatColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  sec.content,
                  style: const TextStyle(
                    fontSize: 13,
                    color: SDChatColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _DocSection {
  final String title;
  final String content;

  _DocSection({required this.title, required this.content});
}
