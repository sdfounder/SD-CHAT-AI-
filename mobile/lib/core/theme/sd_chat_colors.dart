import 'package:flutter/material.dart';

/// Palette de couleurs unique de SD CHAT AI (Design Moderne 2026)
/// Inspiration : Esthétique futuriste sobre, surfaces mates sombres,
/// accent chaud ambré lumineux (Aura Amber) et titane brossé.
/// Distincte du bleu/violet et du SD Design System standard.
class SDChatColors {
  // Arrière-plans profonds (Obsidian / Titanium Noir)
  static const Color background = Color(0xFF08090A);
  static const Color canvas = Color(0xFF0E1013);

  // Surfaces & cartes
  static const Color surface = Color(0xFF14171B);
  static const Color surfaceElevated = Color(0xFF1C2026);
  static const Color surfaceHighlight = Color(0xFF242A33);

  // Bordures nettes et discrètes
  static const Color borderSubtle = Color(0xFF1F242B);
  static const Color borderMedium = Color(0xFF2D333D);
  static const Color borderHighlight = Color(0xFF404855);

  // Accent Principal : Aura Amber (Intelligence lumineuse chaleureuse)
  static const Color primary = Color(0xFFE5A93C);
  static const Color primaryGlow = Color(0xFFF5B744);
  static const Color primaryBright = Color(0xFFF5C058);
  static const Color primaryDim = Color(0x33E5A93C);
  static const Color auraGlow = Color(0x28E5A93C);

  // Accent Secondaire : Titane / Platinum
  static const Color secondary = Color(0xFFCBD5E1);
  static const Color secondaryDim = Color(0xFF64748B);
  static const Color secondaryLight = Color(0xFFE2E8F0);

  // Textes & Typographie (contraste renforcé WCAG AA / AAA)
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textDisabled = Color(0xFF475569);

  // Bulles de message & surfaces interactives
  static const Color userBubble = Color(0xFF1B2028);
  static const Color userBubbleBorder = Color(0xFF2D3542);
  static const Color assistantBackground = Colors.transparent;

  // Blocs de code & Markdown
  static const Color codeBackground = Color(0xFF0D0F12);
  static const Color codeBorder = Color(0xFF222832);

  // Statuts fonctionnels
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color online = Color(0xFF10B981);

  // Dégradés Aura Obsidian & Amber-Platinum
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFE5A93C), Color(0xFFF5C058)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient obsidianCardGradient = LinearGradient(
    colors: [Color(0xFF181C22), Color(0xFF121418)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient userBubbleGradient = LinearGradient(
    colors: [Color(0xFF1F252F), Color(0xFF171B22)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
