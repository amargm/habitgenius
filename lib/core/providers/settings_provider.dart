import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app-wide [SharedPreferences] instance.
/// Must be overridden in [ProviderScope] before [runApp]:
/// ```dart
/// ProviderScope(
///   overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
///   child: const HabitGeniusApp(),
/// )
/// ```
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) =>
      throw UnimplementedError(
        'sharedPreferencesProvider must be overridden in ProviderScope',
      ),
  name: 'sharedPreferencesProvider',
);

/// SharedPreferences keys shared across the app.
class PrefKeys {
  PrefKeys._();

  /// Full path to the user-chosen data directory (registered users only).
  static const dataFilePath = 'data_file_path';

  /// Set to true after the registered-user onboarding is completed.
  static const hasSeenOnboarding = 'has_seen_onboarding';

  // ── Notifications ─────────────────────────────────────────
  /// Whether global daily reminders are enabled.
  static const notificationsEnabled = 'notifications_enabled';

  /// Hour part of the global default reminder time (0-23).
  static const reminderHour = 'reminder_hour';

  /// Minute part of the global default reminder time (0-59).
  static const reminderMinute = 'reminder_minute';

  // ── General ───────────────────────────────────────────────
  /// 0 = Sunday, 1 = Monday (first day of the week for habit views).
  static const firstDayOfWeek = 'first_day_of_week';

  /// ISO 4217 currency code used as default in the Expenses feature.
  static const defaultCurrency = 'default_currency';

  /// Whether to play haptic celebration when a habit is completed (default: true).
  static const celebrationHaptic = 'celebration_haptic';
}
