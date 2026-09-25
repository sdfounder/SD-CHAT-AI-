import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/sd_chat_colors.dart';
import '../../../core/services/onboarding_service.dart';
import '../widgets/onboarding_illustration.dart';
import '../widgets/onboarding_progress_indicator.dart';
import '../widgets/onboarding_particles_painter.dart';

class OnboardingItem {
  final String title;
  final String description;

  const OnboardingItem({
    required this.title,
    required this.description,
  });
}

class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onCompleted;

  const OnboardingScreen({
    super.key,
    this.onCompleted,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  late final AnimationController _ambientController;

  int _currentPage = 0;
  bool _isTransitioning = false;

  static const List<OnboardingItem> _pages = [
    OnboardingItem(
      title: 'Discutez avec SD CHAT AI',
      description:
          'Posez vos questions et obtenez des réponses intelligentes en quelques secondes.',
    ),
    OnboardingItem(
      title: 'Images et documents',
      description:
          'Ajoutez vos fichiers directement dans vos conversations.',
    ),
    OnboardingItem(
      title: 'Utilisez votre voix',
      description:
          'Dictez vos messages rapidement grâce à la reconnaissance vocale.',
    ),
    OnboardingItem(
      title: 'Vos conversations restent avec vous',
      description:
          'Retrouvez vos conversations synchronisées après avoir fermé l\'application.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _ambientController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleComplete() async {
    if (_isTransitioning) return;
    _isTransitioning = true;
    HapticFeedback.mediumImpact();

    await OnboardingService.instance.completeOnboarding();
    widget.onCompleted?.call();
  }

  void _handleNext() {
    if (_isTransitioning) return;
    HapticFeedback.lightImpact();

    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
    } else {
      _handleComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: SDChatColors.background,
      body: Stack(
        children: [
          // 1. Fond particules et halo ambiant animé
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ambientController,
              builder: (context, _) {
                return CustomPaint(
                  painter: OnboardingParticlesPainter(
                    animationValue: _ambientController.value,
                  ),
                );
              },
            ),
          ),

          // 2. Contenu principal
          SafeArea(
            child: Column(
              children: [
                // Barre supérieure avec bouton « Passer »
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Badge souverain discret SD
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: SDChatColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: SDChatColors.borderSubtle,
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
                                color: SDChatColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'SD CHAT AI',
                              style: TextStyle(
                                color: SDChatColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Bouton Passer
                      TextButton(
                        onPressed: _handleComplete,
                        style: TextButton.styleFrom(
                          foregroundColor: SDChatColors.secondaryDim,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        child: const Text(
                          'Passer',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Carousel PageView des 4 écrans
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      final item = _pages[index];

                      return AnimatedBuilder(
                        animation: _ambientController,
                        builder: (context, _) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Spacer(flex: 1),

                                // Illustration animée
                                OnboardingIllustration(
                                  pageIndex: index,
                                  animationValue: _ambientController.value,
                                ),

                                const Spacer(flex: 1),

                                // Titre de l'écran
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    color: SDChatColors.textPrimary,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                    height: 1.25,
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                const SizedBox(height: 14),

                                // Phrase explicative
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    item.description,
                                    style: const TextStyle(
                                      color: SDChatColors.textSecondary,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w400,
                                      height: 1.45,
                                      letterSpacing: 0.1,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),

                                const Spacer(flex: 2),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // Section Navigation inférieure : Indicateurs + Bouton Action
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Indicateur discret de progression
                      OnboardingProgressIndicator(
                        count: _pages.length,
                        currentIndex: _currentPage,
                      ),

                      const SizedBox(height: 24),

                      // Bouton Suivant / Commencer avec SD CHAT AI
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _handleNext,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SDChatColors.primary,
                            foregroundColor: SDChatColors.background,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            shadowColor: SDChatColors.primary.withValues(alpha: 0.4),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isLastPage
                                    ? 'Commencer avec SD CHAT AI'
                                    : 'Suivant',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                isLastPage
                                    ? Icons.arrow_forward_rounded
                                    : Icons.chevron_right_rounded,
                                size: 20,
                              ),
                            ],
                          ),
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
    );
  }
}
