import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import 'app_theme.dart';

// ── Keys used in SharedPreferences ────────────────────────
const _kThemeColorId = 'theme_color_id';
const _kThemeMode = 'theme_mode'; // 'dark' | 'light' | 'system'

// ── State class ───────────────────────────────────────────
class ThemeState {
  final ThemeColor themeColor;
  final ThemeMode themeMode;

  const ThemeState({
    required this.themeColor,
    required this.themeMode,
  });

  ThemeState copyWith({ThemeColor? themeColor, ThemeMode? themeMode}) {
    return ThemeState(
      themeColor: themeColor ?? this.themeColor,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────
class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier()
      : super(ThemeState(
          themeColor: AppColors.defaultTheme,
          themeMode: ThemeMode.dark,
        )) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final colorId = prefs.getString(_kThemeColorId) ?? 'violet';
    final modeStr = prefs.getString(_kThemeMode) ?? 'dark';

    final color = AppColors.findById(colorId) ?? AppColors.defaultTheme;
    final mode = _modeFromString(modeStr);

    state = ThemeState(themeColor: color, themeMode: mode);
  }

  Future<void> setThemeColor(ThemeColor color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeColorId, color.id);
    state = state.copyWith(themeColor: color);
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
