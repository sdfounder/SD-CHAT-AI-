import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/sd_chat_colors.dart';

class OnboardingParticlesPainter extends CustomPainter {
  final double animationValue;

  OnboardingParticlesPainter({required this.animationValue});

  static final List<ParticleModel> _particles = List.generate(
    18,
    (index) => ParticleModel(
      baseX: (index * 47) % 360 / 360.0,
      baseY: (index * 79) % 640 / 640.0,
      radius: 1.0 + ((index % 3) * 0.8),
      speed: 0.3 + ((index % 4) * 0.15),
      color: index % 2 == 0 ? SDChatColors.primary : SDChatColors.secondary,
      maxAlpha: 0.18 + ((index % 3) * 0.08),
    ),
  );

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final yOffset = math.sin((animationValue * 2 * math.pi * p.speed) + (p.baseX * 10)) * 14;
      final xOffset = math.cos((animationValue * 2 * math.pi * p.speed) + (p.baseY * 10)) * 10;

      final dx = (p.baseX * size.width + xOffset) % size.width;
      final dy = (p.baseY * size.height + yOffset) % size.height;

      final opacity = (math.sin(animationValue * 2 * math.pi * p.speed) * 0.5 + 0.5) * p.maxAlpha;

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(dx, dy), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant OnboardingParticlesPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class ParticleModel {
  final double baseX;
  final double baseY;
  final double radius;
  final double speed;
  final Color color;
  final double maxAlpha;

  const ParticleModel({
    required this.baseX,
    required this.baseY,
    required this.radius,
    required this.speed,
    required this.color,
    required this.maxAlpha,
  });
}
