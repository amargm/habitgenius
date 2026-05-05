import 'package:flutter/material.dart';

/// The 10 selectable primary theme colors for HabitGenius.
/// Index 0 is the default (Violet), available to all tiers.
/// Indices 1–5 available to Registered users.
/// Indices 6–9 are Pro-only.
class AppColors {
  AppColors._();

  // ── Background & surface ──────────────────────────────────
  static const Color bg = Color(0xFF0D0D12);
  static const Color bgCard = Color(0xFF15151A);
  static const Color bgCardHover = Color(0xFF1C1C22);
  static const Color bgElevated = Color(0xFF1C1C22);

  // ── Text ──────────────────────────────────────────────────
  static const Color text = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8B8BA0);
  static const Color textMuted = Color(0xFF56566A);

  // ── Semantic ──────────────────────────────────────────────
  static const Color success = Color(0xFF00B894);
  static const Color warning = Color(0xFFFDCB6E);
  static const Color danger = Color(0xFFE17055);
  static const Color accent = Color(0xFF00CEC9);

  // ── Border ────────────────────────────────────────────────
  static const Color border = Colors.transparent; // shadow-based depth in dark mode

  // ── Theme palette ─────────────────────────────────────────
  static const List<ThemeColor> themeColors = [
    ThemeColor(
      id: 'ember',
      name: 'Ember',
      primary: Color(0xFFF47820),
      primaryLight: Color(0xFFFF9A4A),
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
    // Pro-only below
    ThemeColor(
      id: 'sky',
      name: 'Sky',
      primary: Color(0xFF74B9FF),
      primaryLight: Color(0xFFB2D8FF),
      primaryDark: Color(0xFF3A8FD8),
      requiredTier: UserTier.pro,
    ),
    ThemeColor(
      id: 'lime',
      name: 'Lime',
      primary: Color(0xFF55EFC4),
      primaryLight: Color(0xFF9DFCE0),
      primaryDark: Color(0xFF2DC49A),
      requiredTier: UserTier.pro,
    ),
    ThemeColor(
      id: 'peach',
      name: 'Peach',
      primary: Color(0xFFFAB1A0),
      primaryLight: Color(0xFFFFD5CB),
      primaryDark: Color(0xFFD47A69),
      requiredTier: UserTier.pro,
    ),
    ThemeColor(
      id: 'slate',
      name: 'Slate',
      primary: Color(0xFF636E72),
      primaryLight: Color(0xFF95A5A6),
      primaryDark: Color(0xFF3D4547),
      requiredTier: UserTier.pro,
    ),
  ];

  static ThemeColor defaultTheme = themeColors.first; // Ember Orange

  static ThemeColor? findById(String id) {
    try {
      return themeColors.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
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
