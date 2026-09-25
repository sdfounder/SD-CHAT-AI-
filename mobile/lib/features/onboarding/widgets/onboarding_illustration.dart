import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/sd_chat_colors.dart';

class OnboardingIllustration extends StatelessWidget {
  final int pageIndex;
  final double animationValue;

  const OnboardingIllustration({
    super.key,
    required this.pageIndex,
    required this.animationValue,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 260,
        height: 260,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Halo respirant d'arrière-plan (Aura Obsidian)
            _buildAmbientAura(),

            // Contenu thématique spécifique selon la page
            switch (pageIndex) {
              0 => _buildChatAiIllustration(),
              1 => _buildMediaDocsIllustration(),
              2 => _buildVoiceAudioIllustration(),
              _ => _buildOfflineSyncIllustration(),
            },
          ],
        ),
      ),
    );
  }

  Widget _buildAmbientAura() {
    final scale = 1.0 + (math.sin(animationValue * 2 * math.pi) * 0.06);
    final glowAlpha = 0.14 + (math.sin(animationValue * 2 * math.pi) * 0.06);

    return Transform.scale(
      scale: scale,
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              SDChatColors.primary.withValues(alpha: glowAlpha),
              SDChatColors.primaryGlow.withValues(alpha: glowAlpha * 0.4),
              Colors.transparent,
            ],
            stops: const [0.2, 0.6, 1.0],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ÉCRAN 1 : Chat & IA Générative (« Discutez avec SD CHAT AI »)
  // ---------------------------------------------------------------------------
  Widget _buildChatAiIllustration() {
    final pulse = math.sin(animationValue * 2 * math.pi);
    final rotation = animationValue * 2 * math.pi;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Anneau orbital extérieur avec repères
        Transform.rotate(
          angle: rotation * 0.4,
          child: Container(
            width: 210,
            height: 210,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: SDChatColors.primary.withValues(alpha: 0.22),
                width: 1.2,
              ),
            ),
          ),
        ),

        // Anneau intermédiaire en pointillés ou segments
        Transform.rotate(
          angle: -rotation * 0.6,
          child: Container(
            width: 165,
            height: 165,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: SDChatColors.secondaryLight.withValues(alpha: 0.18),
                width: 1.0,
              ),
            ),
          ),
        ),

        // Boîtier central hexagonal / circulaire glassmorphic
        Container(
          width: 115,
          height: 115,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E242C), Color(0xFF12151A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: SDChatColors.primary.withValues(alpha: 0.65),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: SDChatColors.primary.withValues(alpha: 0.25 + (pulse * 0.08)),
                blurRadius: 22,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 48,
              color: SDChatColors.primaryBright,
            ),
          ),
        ),

        // 3 Petits satellites orbitaux
        Positioned(
          top: 35 + (pulse * 4),
          right: 42,
          child: _buildSatelliteDot(SDChatColors.primary, 8),
        ),
        Positioned(
          bottom: 40 - (pulse * 4),
          left: 38,
          child: _buildSatelliteDot(SDChatColors.secondaryLight, 6),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ÉCRAN 2 : Médias & Documents (« Images et documents »)
  // ---------------------------------------------------------------------------
  Widget _buildMediaDocsIllustration() {
    final float = math.sin(animationValue * 2 * math.pi) * 6;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Carte document arrière (inclinée)
        Transform.translate(
          offset: Offset(26, -14 - (float * 0.5)),
          child: Transform.rotate(
            angle: 0.12,
            child: Container(
              width: 130,
              height: 155,
              decoration: BoxDecoration(
                color: SDChatColors.surfaceHighlight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: SDChatColors.secondaryDim.withValues(alpha: 0.4),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(4, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.description_rounded, size: 16, color: SDChatColors.primary),
                      const SizedBox(width: 6),
                      Container(width: 40, height: 4, decoration: BoxDecoration(color: SDChatColors.secondaryDim, borderRadius: BorderRadius.circular(2))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(width: 80, height: 4, decoration: BoxDecoration(color: SDChatColors.borderHighlight, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 8),
                  Container(width: 60, height: 4, decoration: BoxDecoration(color: SDChatColors.borderHighlight, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 8),
                  Container(width: 70, height: 4, decoration: BoxDecoration(color: SDChatColors.borderHighlight, borderRadius: BorderRadius.circular(2))),
                ],
              ),
            ),
          ),
        ),

        // Carte image avant (principale avec cadre photo & gradient bento)
        Transform.translate(
          offset: Offset(-18, 12 + float),
          child: Transform.rotate(
            angle: -0.06,
            child: Container(
              width: 150,
              height: 154,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF222933), Color(0xFF14171D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: SDChatColors.primary.withValues(alpha: 0.7),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: SDChatColors.primary.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(-2, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cadre image preview
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            SDChatColors.primary.withValues(alpha: 0.25),
                            SDChatColors.surfaceElevated,
                          ],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.image_rounded,
                          size: 38,
                          color: SDChatColors.primaryBright,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: SDChatColors.primary.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'IMG • 10 Mo',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: SDChatColors.primary,
                              fontSize: 9.0,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.check_circle_rounded, size: 14, color: SDChatColors.success),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ÉCRAN 3 : Voix & STT (« Utilisez votre voix »)
  // ---------------------------------------------------------------------------
  Widget _buildVoiceAudioIllustration() {
    final wave1 = 1.0 + (math.sin(animationValue * 2 * math.pi) * 0.12);
    final wave2 = 1.0 + (math.sin((animationValue * 2 * math.pi) + 1.2) * 0.16);

    return Stack(
      alignment: Alignment.center,
      children: [
        // Onde sonore concentrique 2
        Transform.scale(
          scale: wave2,
          child: Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: SDChatColors.primary.withValues(alpha: 0.18),
                width: 1.2,
              ),
            ),
          ),
        ),

        // Onde sonore concentrique 1
        Transform.scale(
          scale: wave1,
          child: Container(
            width: 145,
            height: 145,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: SDChatColors.primary.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
          ),
        ),

        // Capsule microphone centrale
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF261F13), Color(0xFF14120D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: SDChatColors.primary,
              width: 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: SDChatColors.primary.withValues(alpha: 0.35),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.mic_rounded,
              size: 44,
              color: SDChatColors.primaryBright,
            ),
          ),
        ),

        // Barres de fréquence audio animées en bas
        Positioned(
          bottom: 25,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (index) {
              final barH = 10.0 + (math.sin((animationValue * 2 * math.pi) + (index * 0.8)).abs() * 18);
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: 3.5,
                height: barH,
                decoration: BoxDecoration(
                  color: index == 2 ? SDChatColors.primary : SDChatColors.secondary,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ÉCRAN 4 : Offline & Synchronisation (« Vos conversations restent avec vous »)
  // ---------------------------------------------------------------------------
  Widget _buildOfflineSyncIllustration() {
    final rotation = animationValue * 2 * math.pi;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Cercle orbital avec flèches de synchronisation
        Transform.rotate(
          angle: rotation,
          child: Container(
            width: 185,
            height: 185,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: SDChatColors.primary.withValues(alpha: 0.28),
                width: 1.2,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 85,
                  child: Icon(Icons.sync_rounded, size: 16, color: SDChatColors.primary),
                ),
                Positioned(
                  bottom: 0,
                  right: 85,
                  child: Icon(Icons.sync_rounded, size: 16, color: SDChatColors.secondary),
                ),
              ],
            ),
          ),
        ),

        // Bouclier / Base de données centrale
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B232D), Color(0xFF0F141A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: SDChatColors.primary.withValues(alpha: 0.8),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: SDChatColors.primary.withValues(alpha: 0.28),
                blurRadius: 22,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.offline_bolt_rounded,
              size: 46,
              color: SDChatColors.primaryBright,
            ),
          ),
        ),

        // Badge « Hors ligne & Cloud »
        Positioned(
          bottom: 22,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: SDChatColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: SDChatColors.primary.withValues(alpha: 0.5),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: SDChatColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  'SQLite Local • Cloud Sync',
                  style: TextStyle(
                    color: SDChatColors.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSatelliteDot(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.6),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
