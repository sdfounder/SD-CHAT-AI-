import 'package:flutter/material.dart';
import '../../../core/theme/sd_chat_colors.dart';

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: SDChatColors.surfaceHighlight,
              shape: BoxShape.circle,
              border: Border.all(color: SDChatColors.borderMedium, width: 0.8),
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 14,
              color: SDChatColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Row(
                children: List.generate(3, (index) {
                  final delay = index * 0.2;
                  final progress = (_controller.value + delay) % 1.0;
                  final opacity = 0.3 + 0.7 * (1.0 - (progress - 0.5).abs() * 2);

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: SDChatColors.primary.withValues(alpha: opacity.clamp(0.2, 1.0)),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(width: 8),
          const Text(
            'Réflexion...',
            style: TextStyle(
              fontSize: 12,
              color: SDChatColors.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
