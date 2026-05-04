import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Builds a [ThemeData] for HabitGenius given a [ThemeColor] and [Brightness].
/// Call [AppTheme.build] whenever the user changes color or mode.
class AppTheme {
  AppTheme._();

  static ThemeData build({
    required ThemeColor themeColor,
    required Brightness brightness,
  }) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: themeColor.primary,
      brightness: brightness,
      primary: themeColor.primary,
      secondary: AppColors.accent,
      error: AppColors.danger,
      surface: isDark ? AppColors.bgCard : const Color(0xFFF5F5F5),
    ).copyWith(
      primaryContainer: themeColor.primaryDark,
      onPrimary: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
      scaffoldBackgroundColor: isDark ? AppColors.bg : const Color(0xFFF0F0F5),
      fontFamily: 'Inter',
      cardColor: isDark ? AppColors.bgCard : Colors.white,
      dividerColor: AppColors.border,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.bg : const Color(0xFFF0F0F5),
        foregroundColor: isDark ? AppColors.text : const Color(0xFF1A1A24),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: isDark ? AppColors.text : const Color(0xFF1A1A24),
          fontFamily: 'Inter',
        ),
      ),

      // Text
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: isDark ? AppColors.text : const Color(0xFF1A1A24),
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.text : const Color(0xFF1A1A24),
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.text : const Color(0xFF1A1A24),
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.text : const Color(0xFF1A1A24),
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: isDark ? AppColors.textSecondary : const Color(0xFF5C5C6E),
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          color: isDark ? AppColors.textMuted : const Color(0xFF8E8EA0),
          letterSpacing: 0.5,
        ),
      ),

      // Card
      cardTheme: CardThemeData(
        color: isDark ? AppColors.bgCard : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: const EdgeInsets.only(bottom: 12),
      ),

      // BottomNavBar (we use a custom floating nav, but define fallback)
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? AppColors.bgCard : Colors.white,
        selectedItemColor: themeColor.primary,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.bgCard : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: themeColor.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted),
      ),

      // ElevatedButton
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: themeColor.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.bgCard : const Color(0xFFF0F0F5),
        selectedColor: themeColor.primary,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          fontFamily: 'Inter',
        ),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }
}
