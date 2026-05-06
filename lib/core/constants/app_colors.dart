import 'package:flutter/material.dart';

/// The 10 selectable primary theme colors for HabitGenius.
/// Index 0 is the default (Ember Orange #FF6B00 — per design guidelines).
/// Indices 1–5 available to Registered users.
/// Indices 6–9 are Pro-only.
class AppColors {
  AppColors._();

  // ── Background & surface (design guidelines §02) ──────────
  static const Color bg = Color(0xFF0D0D0F); // bg-base
  static const Color bgSurface = Color(0xFF161618); // bg-surface
  static const Color bgCard = Color(0xFF1E1E21); // bg-card
  static const Color bgCardHover = Color(0xFF252528);
  static const Color bgElevated = Color(0xFF2A2A2E); // modals, sheets

  // ── Text hierarchy (design guidelines §02) ────────────────
  static const Color text = Color(0xFFF0F0F2); // text-primary
  static const Color textSecondary = Color(0xFFA0A0A8); // text-secondary
  static const Color textMuted = Color(0xFF606068); // text-muted

  // ── Semantic ──────────────────────────────────────────────
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFFDCB6E);
  static const Color danger = Color(0xFFE17055);
  static const Color accent = Color(0xFF00CEC9); // secondary accent (charts)

  // ── Border (design guidelines §02) ───────────────────────
  static const Color border = Color(0xFF2E2E33);
  static const Color borderLight = Color(0xFF3A3A40);

  // ── Feature module accents (design guidelines §02) ────────
  static const Color featureHabit = Color(0xFFFF6B00);
  static const Color featureMood = Color(0xFF9B59B6);
  static const Color featureJournal = Color(0xFF3498DB);
  static const Color featureExpense = Color(0xFF2ECC71);
  static const Color featureFocus = Color(0xFFF39C12);
  static const Color featureWater = Color(0xFF1ABC9C);
  static const Color featurePeriod = Color(0xFFE91E8C);
  static const Color featureAffirmation = Color(0xFF8B6BE8);

  // ── Theme palette ─────────────────────────────────────────
  static const List<ThemeColor> themeColors = [
    ThemeColor(
      id: 'ember',
      name: 'Ember',
      primary: Color(0xFFFF6B00), // #FF6B00 — design guideline accent
      primaryLight: Color(0xFFFF8C3A), // accent-warm
      primaryDark: Color(0xFFC65C0E),
      requiredTier: UserTier.guest, // default — available to everyone
    ),
    ThemeColor(
      id: 'violet',
      name: 'Violet',
      primary: Color(0xFF6C5CE7),
      primaryLight: Color(0xFFA29BFE),
      primaryDark: Color(0xFF4A3DB5),
      requiredTier: UserTier.guest,
    ),
    ThemeColor(
      id: 'ocean',
      name: 'Ocean',
      primary: Color(0xFF0984E3),
      primaryLight: Color(0xFF74B9FF),
      primaryDark: Color(0xFF0652A8),
      requiredTier: UserTier.registered,
    ),
    ThemeColor(
      id: 'mint',
      name: 'Mint',
      primary: Color(0xFF00B894),
      primaryLight: Color(0xFF55EFC4),
      primaryDark: Color(0xFF007F67),
      requiredTier: UserTier.registered,
    ),
    ThemeColor(
      id: 'coral',
      name: 'Coral',
      primary: Color(0xFFE17055),
      primaryLight: Color(0xFFFAB1A0),
      primaryDark: Color(0xFFB84A30),
      requiredTier: UserTier.registered,
    ),
    ThemeColor(
      id: 'gold',
      name: 'Gold',
      primary: Color(0xFFFDCB6E),
      primaryLight: Color(0xFFFFE0A3),
      primaryDark: Color(0xFFD4A017),
      requiredTier: UserTier.registered,
    ),
    ThemeColor(
      id: 'rose',
      name: 'Rose',
      primary: Color(0xFFE84393),
      primaryLight: Color(0xFFFF7EB3),
      primaryDark: Color(0xFFB01E6B),
      requiredTier: UserTier.registered,
    ),
    // Previously Pro-only; now available to all signed-in users
    ThemeColor(
      id: 'sky',
      name: 'Sky',
      primary: Color(0xFF74B9FF),
      primaryLight: Color(0xFFB2D8FF),
      primaryDark: Color(0xFF3A8FD8),
      requiredTier: UserTier.guest,
    ),
    ThemeColor(
      id: 'lime',
      name: 'Lime',
      primary: Color(0xFF55EFC4),
      primaryLight: Color(0xFF9DFCE0),
      primaryDark: Color(0xFF2DC49A),
      requiredTier: UserTier.guest,
    ),
    ThemeColor(
      id: 'peach',
      name: 'Peach',
      primary: Color(0xFFFAB1A0),
      primaryLight: Color(0xFFFFD5CB),
      primaryDark: Color(0xFFD47A69),
      requiredTier: UserTier.guest,
    ),
    ThemeColor(
      id: 'slate',
      name: 'Slate',
      primary: Color(0xFF636E72),
      primaryLight: Color(0xFF95A5A6),
      primaryDark: Color(0xFF3D4547),
      requiredTier: UserTier.guest,
    ),
  ];

  /// Default accent: Ember Orange (#FF6B00) per design guidelines.
  static ThemeColor defaultTheme = themeColors.first;

  static ThemeColor? findById(String id) {
    try {
      return themeColors.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Build a [ThemeColor] from any arbitrary [color] chosen by the user.
  /// Computes lighter and darker variants via HSL adjustment.
  static ThemeColor makeCustom(Color color) {
    final hsl = HSLColor.fromColor(color);
    final light =
        hsl.withLightness((hsl.lightness + 0.15).clamp(0.0, 1.0)).toColor();
    final dark =
        hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    return ThemeColor(
      id: 'custom',
      name: 'Custom',
      primary: color,
      primaryLight: light,
      primaryDark: dark,
      requiredTier: UserTier.guest,
    );
  }
}

enum UserTier { guest, registered, pro }

class ThemeColor {
  final String id;
  final String name;
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final UserTier requiredTier;

  const ThemeColor({
    required this.id,
    required this.name,
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.requiredTier,
  });
}
