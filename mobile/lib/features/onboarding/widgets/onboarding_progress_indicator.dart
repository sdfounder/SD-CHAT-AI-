import 'package:flutter/material.dart';
import '../../../core/theme/sd_chat_colors.dart';

class OnboardingProgressIndicator extends StatelessWidget {
  final int count;
  final int currentIndex;

  const OnboardingProgressIndicator({
    super.key,
    required this.count,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (index) {
        final bool isActive = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 6,
          width: isActive ? 28 : 7,
          decoration: BoxDecoration(
            color: isActive ? SDChatColors.primary : SDChatColors.borderHighlight,
            borderRadius: BorderRadius.circular(4),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: SDChatColors.primary.withValues(alpha: 0.45),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}
