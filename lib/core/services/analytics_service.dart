import 'package:firebase_analytics/firebase_analytics.dart';

/// Thin wrapper around Firebase Analytics.
///
/// Call these methods at key user-action points.  All calls are
/// fire-and-forget (no await needed at call sites).
///
/// Firebase also auto-tracks:
///   • Session start / end
///   • First open
///   • App foreground / background
///   • In-app purchases (via Google Play)
class AnalyticsService {
  AnalyticsService._();

  static final FirebaseAnalytics _fa = FirebaseAnalytics.instance;

  // ── Auth ──────────────────────────────────────────────────

  /// Call after a successful Google Sign-In.
  static Future<void> logLogin() =>
      _fa.logLogin(loginMethod: 'google').catchError((_) {});

  /// Call after a successful Google Sign-Up (new account).
  static Future<void> logSignUp() =>
      _fa.logSignUp(signUpMethod: 'google').catchError((_) {});

  /// Call when the user chooses "Continue as Guest".
  static Future<void> logGuestSession() =>
      _fa.logEvent(name: 'guest_session_start').catchError((_) {});

  // ── Habits ────────────────────────────────────────────────

  /// Call after a new habit is saved.
  static Future<void> logHabitCreated() =>
      _fa.logEvent(name: 'habit_created').catchError((_) {});

  /// Call when a habit is marked complete for the day.
  static Future<void> logHabitCompleted() =>
      _fa.logEvent(name: 'habit_completed').catchError((_) {});

  // ── Journal ───────────────────────────────────────────────

  /// Call when a new journal entry is saved.
  static Future<void> logJournalEntry() =>
      _fa.logEvent(name: 'journal_entry_created').catchError((_) {});

  // ── Focus ─────────────────────────────────────────────────

  /// Call when a focus session is completed.
  static Future<void> logFocusSession(int durationSeconds) =>
      _fa.logEvent(
        name: 'focus_session_completed',
        parameters: {'duration_seconds': durationSeconds},
      ).catchError((_) {});

  // ── Purchases ─────────────────────────────────────────────

  /// Call when the Pro upgrade purchase is confirmed.
  static Future<void> logProPurchase() => _fa
      .logPurchase(
        currency: 'USD',
        value: 0,
        items: [AnalyticsEventItem(itemName: 'habitgenius_pro_lifetime')],
      )
      .catchError((_) {});

  // ── Generic ───────────────────────────────────────────────

  /// Log any custom event by name.
  static Future<void> log(
    String name, {
    Map<String, Object>? parameters,
  }) => _fa.logEvent(name: name, parameters: parameters).catchError((_) {});
}
