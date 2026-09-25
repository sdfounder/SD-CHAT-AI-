import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'sd_chat_colors.dart';

class SDChatTheme {
  static ThemeData get darkTheme => buildTheme(brightness: Brightness.dark);
  static ThemeData get lightTheme => buildTheme(brightness: Brightness.light);

  static ThemeData buildTheme({
    required Brightness brightness,
    Color? accentColor,
  }) {
    final primary = accentColor ?? SDChatColors.primary;
    final isDark = brightness == Brightness.dark;

    final bg = isDark ? SDChatColors.background : const Color(0xFFF8FAFC);
    final surface = isDark ? SDChatColors.surface : const Color(0xFFFFFFFF);
    final surfaceElevated = isDark ? SDChatColors.surfaceElevated : const Color(0xFFF1F5F9);
    final borderSubtle = isDark ? SDChatColors.borderSubtle : const Color(0xFFE2E8F0);
    final borderMedium = isDark ? SDChatColors.borderMedium : const Color(0xFFCBD5E1);
    final textPrimary = isDark ? SDChatColors.textPrimary : const Color(0xFF0F172A);
    final textSecondary = isDark ? SDChatColors.textSecondary : const Color(0xFF475569);
    final textMuted = isDark ? SDChatColors.textMuted : const Color(0xFF94A3B8);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: primary,
              onPrimary: SDChatColors.background,
              secondary: SDChatColors.secondary,
              onSecondary: SDChatColors.background,
              surface: surface,
              onSurface: textPrimary,
              error: SDChatColors.error,
              onError: Colors.white,
            )
          : ColorScheme.light(
              primary: primary,
              onPrimary: Colors.white,
              secondary: const Color(0xFF475569),
              onSecondary: Colors.white,
              surface: surface,
              onSurface: textPrimary,
              error: SDChatColors.error,
              onError: Colors.white,
            ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: borderSubtle,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: borderMedium, width: 0.8),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        elevation: 12,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceElevated,
        contentTextStyle: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderMedium, width: 0.8),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderMedium, width: 0.6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        textStyle: GoogleFonts.inter(
          color: primary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: borderSubtle, width: 0.8),
        ),
        margin: EdgeInsets.zero,
      ),
      splashColor: primary.withValues(alpha: 0.15),
      highlightColor: Colors.transparent,
      textTheme: TextTheme(
        headlineLarge: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.6,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.4,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.2,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 1.55,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          height: 1.45,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textMuted,
        ),
      ),
    );
  }
}
