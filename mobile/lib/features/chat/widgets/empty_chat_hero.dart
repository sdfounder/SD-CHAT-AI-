import 'package:flutter/material.dart';
import '../../../core/theme/sd_chat_colors.dart';

class EmptyChatHero extends StatelessWidget {
  final ValueChanged<String> onSelectPrompt;

  const EmptyChatHero({super.key, required this.onSelectPrompt});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Emblème Glowing Aura
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: SDChatColors.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(
                  color: SDChatColors.primary.withValues(alpha: 0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: SDChatColors.primary.withValues(alpha: 0.12),
                    blurRadius: 28,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.auto_awesome,
                  size: 28,
                  color: SDChatColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Titre & Sous-titre
            const Text(
              'Que souhaitez-vous explorer ?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: SDChatColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'SD CHAT AI est prêt à analyser, rédiger, coder et raisonner à vos côtés.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: SDChatColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),

            // Suggestions de prompts prédéfinis
            _buildPromptCard(
              icon: Icons.lightbulb_outline_rounded,
              title: 'Explique un concept complexe',
              subtitle: 'Comprendre l\'informatique quantique simplement',
              prompt: 'Peux-tu m\'expliquer les principes de l\'informatique quantique de manière simple et intuitive ?',
            ),
            const SizedBox(height: 10),
            _buildPromptCard(
              icon: Icons.code_rounded,
              title: 'Architecture & Code',
              subtitle: 'Créer une API REST performante avec FastAPI',
              prompt: 'Propose-moi une architecture propre et modulaire pour une API FastAPI en Python.',
            ),
            const SizedBox(height: 10),
            _buildPromptCard(
              icon: Icons.edit_note_rounded,
              title: 'Rédaction & Stratégie',
              subtitle: 'Rédiger une synthèse de projet technologique',
              prompt: 'Rédige une synthèse exécutive structurée pour un projet d\'intelligence artificielle.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String prompt,
  }) {
    return InkWell(
      onTap: () => onSelectPrompt(prompt),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: SDChatColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SDChatColors.borderSubtle, width: 0.8),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: SDChatColors.surfaceHighlight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: SDChatColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: SDChatColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: SDChatColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13,
              color: SDChatColors.textDisabled,
            ),
          ],
        ),
      ),
    );
  }
}
