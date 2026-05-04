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
}
