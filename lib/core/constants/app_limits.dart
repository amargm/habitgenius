import 'app_colors.dart';

/// Tier-based feature limits for 1Habit Tracker.
/// All limit checks in the app should reference this class.
class AppLimits {
  AppLimits._();

  // ── Habits ────────────────────────────────────────────────
  static const int guestMaxHabits = 1;
  static const int registeredMaxHabits = 3;
  static const int proMaxHabits = 999999; // effectively unlimited

  // ── Journal ───────────────────────────────────────────────
  static const int guestMaxJournalEntries = 5;
  static const int registeredMaxJournalEntries =
      30; // active entries at any time
  static const int proMaxJournalEntries = 999999;

  // ── Expenses ──────────────────────────────────────────────
  static const int registeredMaxTransactionsPerDay =
      4; // resets at midnight local
  static const int proMaxTransactionsPerDay = 999999;

  // ── Accounts ──────────────────────────────────────────────
  static const int registeredMaxAccounts = 2;
  static const int proMaxAccounts = 999999;

  // ── Theme colors ──────────────────────────────────────────
  /// Number of theme colors accessible to registered users (including default)
  static const int registeredThemeColorCount = 6; // colors 0–5

  // ── Focus ─────────────────────────────────────────────────
  /// Guest cannot set custom duration (locked to presets)
  static const List<int> presetFocusMinutes = [25, 45, 60];

  // ── Helper ────────────────────────────────────────────────
  static int maxHabits(UserTier tier) {
    switch (tier) {
      case UserTier.guest:
        return guestMaxHabits;
      case UserTier.registered:
        return registeredMaxHabits;
      case UserTier.pro:
        return proMaxHabits;
    }
  }

  static int maxJournalEntries(UserTier tier) {
    switch (tier) {
      case UserTier.guest:
        return guestMaxJournalEntries;
      case UserTier.registered:
        return registeredMaxJournalEntries;
      case UserTier.pro:
        return proMaxJournalEntries;
    }
  }

  static int maxTransactionsPerDay(UserTier tier) {
    switch (tier) {
      case UserTier.guest:
      case UserTier.registered:
        return registeredMaxTransactionsPerDay;
      case UserTier.pro:
        return proMaxTransactionsPerDay;
    }
  }

  static int maxAccounts(UserTier tier) {
    switch (tier) {
      case UserTier.guest:
      case UserTier.registered:
        return registeredMaxAccounts;
      case UserTier.pro:
        return proMaxAccounts;
    }
  }

  static bool canAccessMood(UserTier tier) =>
      tier == UserTier.registered || tier == UserTier.pro;

  static bool canAccessExpenses(UserTier tier) =>
      tier == UserTier.registered || tier == UserTier.pro;

  static bool canUseCustomFocusDuration(UserTier tier) =>
      tier == UserTier.registered || tier == UserTier.pro;

  static bool canUseCloudSync(UserTier tier) =>
      tier == UserTier.registered || tier == UserTier.pro;
}
