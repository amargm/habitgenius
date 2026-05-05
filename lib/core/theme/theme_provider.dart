import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import 'app_theme.dart';

// ── Keys used in SharedPreferences ────────────────────────
const _kThemeColorId = 'theme_color_id';
const _kThemeMode = 'theme_mode'; // 'dark' | 'light' | 'system'
const _kCustomAccentColor = 'custom_accent_color'; // int (Color.value)

// ── State class ───────────────────────────────────────────
class ThemeState {
  final ThemeColor themeColor;
  final ThemeMode themeMode;

  /// Non-null when the user has chosen a custom (free-pick) accent color.
  final Color? customAccentColor;

  const ThemeState({
    required this.themeColor,
    required this.themeMode,
    this.customAccentColor,
  });

  ThemeState copyWith({
    ThemeColor? themeColor,
    ThemeMode? themeMode,
    Color? customAccentColor,
    bool clearCustom = false,
  }) {
    return ThemeState(
      themeColor: themeColor ?? this.themeColor,
      themeMode: themeMode ?? this.themeMode,
      customAccentColor:
          clearCustom ? null : (customAccentColor ?? this.customAccentColor),
    );
  }
}

// ── Notifier ──────────────────────────────────────────────
class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier()
    : super(
        ThemeState(
          themeColor: AppColors.defaultTheme,
          themeMode: ThemeMode.dark,
        ),
      ) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final colorId = prefs.getString(_kThemeColorId) ?? 'ember';
    final modeStr = prefs.getString(_kThemeMode) ?? 'dark';
    final customValue = prefs.getInt(_kCustomAccentColor);

    final mode = _modeFromString(modeStr);

    if (colorId == 'custom' && customValue != null) {
      final customColor = Color(customValue);
      state = ThemeState(
        themeColor: AppColors.makeCustom(customColor),
        themeMode: mode,
        customAccentColor: customColor,
      );
    } else {
      final color = AppColors.findById(colorId) ?? AppColors.defaultTheme;
      state = ThemeState(themeColor: color, themeMode: mode);
    }
  }

  Future<void> setThemeColor(ThemeColor color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeColorId, color.id);
    await prefs.remove(_kCustomAccentColor);
    state = state.copyWith(themeColor: color, clearCustom: true);
  }

  /// Set a free-pick accent [color] chosen via the color picker.
  Future<void> setCustomAccentColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeColorId, 'custom');
    await prefs.setInt(_kCustomAccentColor, color.toARGB32());
    state = ThemeState(
      themeColor: AppColors.makeCustom(color),
      themeMode: state.themeMode,
      customAccentColor: color,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, _modeToString(mode));
    state = state.copyWith(themeMode: mode);
  }

  static ThemeMode _modeFromString(String s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }

  static String _modeToString(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'system';
      default:
        return 'dark';
    }
  }
}

// ── Provider ──────────────────────────────────────────────
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>(
  (ref) => ThemeNotifier(),
);

// ── Convenience derived providers ─────────────────────────
final darkThemeProvider = Provider<ThemeData>((ref) {
  final color = ref.watch(themeProvider).themeColor;
  return AppTheme.build(themeColor: color, brightness: Brightness.dark);
});

final lightThemeProvider = Provider<ThemeData>((ref) {
  final color = ref.watch(themeProvider).themeColor;
  return AppTheme.build(themeColor: color, brightness: Brightness.light);
});
