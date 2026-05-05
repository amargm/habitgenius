import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'app_theme_extension.dart';

/// Builds a [ThemeData] for HabitGenius given a [ThemeColor] and [Brightness].
/// Call [AppTheme.build] whenever the user changes color or mode.
class AppTheme {
  AppTheme._();

  static ThemeData build({
    required ThemeColor themeColor,
    required Brightness brightness,
  }) {
    final isDark = brightness == Brightness.dark;

    // Border: transparent in dark (depth via shadow); subtle black in light.
    final borderColor = isDark ? Colors.transparent : const Color(0x1A000000);
    // Input fields need a visible edge even in dark mode.
    final inputBorderColor =
        isDark ? const Color(0x18FFFFFF) : const Color(0x1A000000);

    // Compute onPrimary: use dark text for light primary colours (e.g. amber)
    // so text placed on primary-coloured buttons always has adequate contrast.
    final Color onPrimary =
        ThemeData.estimateBrightnessForColor(themeColor.primary) ==
                Brightness.light
            ? const Color(0xFF15151A)
            : Colors.white;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: themeColor.primary,
      brightness: brightness,
      primary: themeColor.primary,
      secondary: AppColors.accent,
      error: AppColors.danger,
      surface: isDark ? AppColors.bgCard : const Color(0xFFF5F5F5),
    ).copyWith(primaryContainer: themeColor.primaryDark, onPrimary: onPrimary);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
      scaffoldBackgroundColor: isDark ? AppColors.bg : const Color(0xFFF0F0F5),
      fontFamily: 'Inter',
      cardColor: isDark ? AppColors.bgCard : Colors.white,
      dividerColor: borderColor,
      extensions: [isDark ? AppColorsExtension.dark : AppColorsExtension.light],

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.bg : const Color(0xFFF0F0F5),
        foregroundColor: isDark ? AppColors.text : const Color(0xFF15151A),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: isDark ? AppColors.text : const Color(0xFF15151A),
          fontFamily: 'Inter',
        ),
      ),

      // Text
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: isDark ? AppColors.text : const Color(0xFF15151A),
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.text : const Color(0xFF15151A),
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.text : const Color(0xFF15151A),
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.text : const Color(0xFF15151A),
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

      // Card — shadow-based depth, no border stroke
      cardTheme: CardThemeData(
        color: isDark ? AppColors.bgCard : Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.only(bottom: 12),
      ),

      // BottomNavBar (we use a custom floating nav, but define fallback)
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? AppColors.bgCard : Colors.white,
        selectedItemColor: themeColor.primary,
        unselectedItemColor:
            isDark ? AppColors.textMuted : const Color(0xFF8E8EA0),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Input — keep a subtle border so fields are identifiable
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.bgElevated : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: inputBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: inputBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: themeColor.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: TextStyle(
          color: isDark ? AppColors.textMuted : const Color(0xFF8E8EA0),
        ),
      ),

      // ElevatedButton
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: themeColor.primary,
          foregroundColor: onPrimary,
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
        backgroundColor: isDark ? AppColors.bgElevated : const Color(0xFFF0F0F5),
        selectedColor: themeColor.primary,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          fontFamily: 'Inter',
        ),
        side: const BorderSide(color: Colors.transparent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      // Dialog (AlertDialog, SimpleDialog)
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.bgElevated : Colors.white,
        elevation: 24,
        shadowColor: const Color(0x50000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.text : const Color(0xFF15151A),
          fontFamily: 'Inter',
        ),
        contentTextStyle: TextStyle(
          fontSize: 14,
          height: 1.55,
          color:
              isDark ? AppColors.textSecondary : const Color(0xFF5C5C6E),
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}
