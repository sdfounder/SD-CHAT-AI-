import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/sd_chat_colors.dart';

class EmptyChatHero extends StatefulWidget {
  final ValueChanged<String> onSelectPrompt;

  const EmptyChatHero({super.key, required this.onSelectPrompt});

  @override
  State<EmptyChatHero> createState() => _EmptyChatHeroState();
}

class _EmptyChatHeroState extends State<EmptyChatHero> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Emblème Glowing Aura avec respiration discrète
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final glow = 0.12 + 0.14 * _pulseController.value;
                return Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: SDChatColors.surfaceElevated,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: SDChatColors.primary.withValues(alpha: 0.4 + 0.3 * _pulseController.value),
                      width: 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: SDChatColors.primary.withValues(alpha: glow),
                        blurRadius: 32,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.auto_awesome,
                      size: 30,
                      color: SDChatColors.primary,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 22),

            // Titre & Sous-titre
            const Text(
              'Que souhaitez-vous explorer ?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: SDChatColors.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'SD CHAT AI analyse, résume, rédige et conçoit avec vous en haute précision.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: SDChatColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),

            // Suggestions de prompts structurées
            _buildPromptCard(
              category: 'RAISONNEMENT',
              icon: Icons.lightbulb_outline_rounded,
              title: 'Explique un concept complexe',
              subtitle: 'Comprendre l\'informatique quantique simplement',
              prompt: 'Peux-tu m\'expliquer les principes de l\'informatique quantique de manière simple et intuitive ?',
            ),
            const SizedBox(height: 10),
            _buildPromptCard(
              category: 'CODE & ARCHITECTURE',
              icon: Icons.code_rounded,
              title: 'Architecture backend & API',
              subtitle: 'Concevoir une architecture FastAPI propre et scalable',
              prompt: 'Propose-moi une architecture propre et modulaire pour une API FastAPI en Python.',
            ),
            const SizedBox(height: 10),
            _buildPromptCard(
              category: 'RÉDACTION & SYNTHÈSE',
              icon: Icons.auto_stories_rounded,
              title: 'Synthèse exécutive',
              subtitle: 'Rédiger une synthèse de projet technologique',
              prompt: 'Rédige une synthèse exécutive structurée pour un projet d\'intelligence artificielle.',
            ),
            const SizedBox(height: 10),
            _buildPromptCard(
              category: 'STRATÉGIE & INNOVATION',
              icon: Icons.rocket_launch_rounded,
              title: 'Plan d\'action technologique',
              subtitle: 'Feuille de route pour déployer une solution IA',
              prompt: 'Établis une feuille de route par étapes pour déployer une solution IA sécurisée en entreprise.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptCard({
    required String category,
    required IconData icon,
    required String title,
    required String subtitle,
    required String prompt,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onSelectPrompt(prompt);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: SDChatColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SDChatColors.borderSubtle, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: SDChatColors.surfaceHighlight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SDChatColors.borderMedium, width: 0.6),
              ),
              child: Icon(icon, size: 20, color: SDChatColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: SDChatColors.primary,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
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
