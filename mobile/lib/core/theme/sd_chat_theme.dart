import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'sd_chat_colors.dart';

class SDChatTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: SDChatColors.background,
      colorScheme: const ColorScheme.dark(
        primary: SDChatColors.primary,
        onPrimary: SDChatColors.background,
        secondary: SDChatColors.secondary,
        onSecondary: SDChatColors.background,
        surface: SDChatColors.surface,
        onSurface: SDChatColors.textPrimary,
        error: SDChatColors.error,
        onError: SDChatColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: SDChatColors.background,
        foregroundColor: SDChatColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: SDChatColors.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      textTheme: TextTheme(
        headlineLarge: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: SDChatColors.textPrimary,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: SDChatColors.textPrimary,
          letterSpacing: -0.3,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: SDChatColors.textPrimary,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: SDChatColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: SDChatColors.textPrimary,
          height: 1.55,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: SDChatColors.textSecondary,
          height: 1.45,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: SDChatColors.textMuted,
        ),
      ),
    );
  }
}
