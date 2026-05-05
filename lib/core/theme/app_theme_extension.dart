import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Provides adaptive colour tokens that automatically switch between the app's
/// dark-mode and light-mode palettes depending on [ThemeData.brightness].
///
/// Registered as a [ThemeExtension] in [AppTheme.build] so it is always
/// available via `Theme.of(context).extension<AppColorsExtension>()!`.
///
/// Prefer the [BuildContext.appColors] convenience getter:
/// ```dart
/// color: context.appColors.bgCard,
/// ```
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  const AppColorsExtension({
    required this.bgCard,
    required this.bgElevated,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
  });

  final Color bgCard;
  final Color bgElevated;

  /// Subtle separator / outline colour (transparent in dark — depth via shadow).
  final Color border;

  /// High-emphasis body text.
  final Color textPrimary;

  /// Secondary / caption text — readable but not dominant.
  final Color textSecondary;

  /// De-emphasised / hint text — intentionally low contrast.
  final Color textMuted;

  /// Standard card shadow. Adapts to brightness: prominent in dark, soft in light.
  List<BoxShadow> get cardShadow {
    final isDarkMode =
        ThemeData.estimateBrightnessForColor(bgCard) == Brightness.dark;
    return [
      BoxShadow(
        color:
            isDarkMode
                ? const Color(0x40000000) // 25% black — depth on dark bg
                : const Color(0x12000000), // 7% black — subtle on light bg
        blurRadius: isDarkMode ? 24 : 12,
        offset: const Offset(0, 6),
      ),
    ];
  }

  // ── Pre-built instances ────────────────────────────────────

  static const AppColorsExtension dark = AppColorsExtension(
    bgCard: AppColors.bgCard,
    bgElevated: AppColors.bgElevated,
    border: AppColors.border,
    textPrimary: AppColors.text,
    textSecondary: AppColors.textSecondary,
    textMuted: AppColors.textMuted,
  );

  static const AppColorsExtension light = AppColorsExtension(
    bgCard: Colors.white,
    bgElevated: Color(0xFFEEEEF5),
    border: Color(0x1A000000), // black 10%
    textPrimary: Color(0xFF15151A),
    textSecondary: Color(0xFF5C5C6E),
    textMuted: Color(0xFF8E8EA0),
  );

  // ── Retrieval ──────────────────────────────────────────────

  static AppColorsExtension of(BuildContext context) =>
      Theme.of(context).extension<AppColorsExtension>()!;

  // ── ThemeExtension overrides ───────────────────────────────

  @override
  AppColorsExtension copyWith({
    Color? bgCard,
    Color? bgElevated,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
  }) => AppColorsExtension(
    bgCard: bgCard ?? this.bgCard,
    bgElevated: bgElevated ?? this.bgElevated,
    border: border ?? this.border,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textMuted: textMuted ?? this.textMuted,
  );

  @override
  AppColorsExtension lerp(AppColorsExtension? other, double t) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      bgCard: Color.lerp(bgCard, other.bgCard, t)!,
      bgElevated: Color.lerp(bgElevated, other.bgElevated, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
    );
  }
}

/// Convenience extension so any [BuildContext] can access adaptive colours
/// without a verbose `Theme.of(context).extension<AppColorsExtension>()!`.
extension AppThemeX on BuildContext {
  AppColorsExtension get appColors => AppColorsExtension.of(this);

  /// Standard card [BoxDecoration]: card background + shadow, radius 16.
  BoxDecoration get cardDecoration => BoxDecoration(
    color: appColors.bgCard,
    borderRadius: BorderRadius.circular(16),
    boxShadow: appColors.cardShadow,
  );

  /// Card decoration with a custom [radius].
  BoxDecoration cardDecorationR(double radius) => BoxDecoration(
    color: appColors.bgCard,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: appColors.cardShadow,
  );
}
