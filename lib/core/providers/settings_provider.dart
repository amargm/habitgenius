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

  /// Master switch: whether any celebration feedback fires on habit completion
  /// (default: true).  Controls visibility of the three sub-toggles below.
  static const celebrationHaptic = 'celebration_haptic';

  /// Whether to vibrate (haptic) on completion (default: true).
  static const celebrationVibration = 'celebration_vibration';

  /// Whether to play a short click sound on completion (default: true).
  static const celebrationSound = 'celebration_sound';

  /// Whether to show the confetti visual effect on completion (default: true).
  static const celebrationVisual = 'celebration_visual';
}
