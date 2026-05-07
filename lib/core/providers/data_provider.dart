import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/app_data.dart';
import '../models/app_settings.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/mood.dart';
import '../models/focus_session.dart';
import '../models/journal_entry.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../services/data_service.dart';
import '../services/sync_service.dart';
import '../services/widget_sync_service.dart';
import '../utils/habit_helpers.dart';
import 'settings_provider.dart';

// ── Service ───────────────────────────────────────────────

final dataServiceProvider = Provider<DataService>((_) => DataService());

// ── Notifier ──────────────────────────────────────────────

/// Holds the in-memory [AppData] and serialises every mutation to disk.
class DataNotifier extends StateNotifier<AsyncValue<AppData>> {
  final DataService _service;
  String? _filePath;
  bool? _isGuest;

  /// Broadcast stream that emits a human-readable message whenever a disk
  /// write fails.  Listeners (e.g. [HabitGeniusApp]) show a snackbar so the
  /// user knows their latest change was not persisted.
  final StreamController<String> _saveErrors =
      StreamController<String>.broadcast();
  Stream<String> get saveErrors => _saveErrors.stream;

  DataNotifier(this._service) : super(const AsyncValue.loading());

  String? get filePath => _filePath;

  /// Resolves the file path and loads [AppData] from disk.
  /// Call this from [SplashScreen] after auth is resolved.
  Future<void> load({required bool isGuest, required String? customDir}) async {
    _isGuest = isGuest;
    state = const AsyncValue.loading();
    try {
      _filePath = await _service.resolveFilePath(
        isGuest: isGuest,
        customDirPath: customDir,
      );
      final data = await _service.loadData(_filePath!);
      state = AsyncValue.data(data);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Re-reads the file from the same path used in [load] WITHOUT
  /// transitioning through [AsyncValue.loading].
  ///
  /// Skipping the loading state prevents all feature screens (which use
  /// [appDataProvider]) from briefly flashing empty content on every refresh.
  /// No-op if [load] was never called or the file path is unknown.
  Future<void> reload() async {
    if (_isGuest == null || _filePath == null) return;
    try {
      final data = await _service.loadData(_filePath!);
      state = AsyncValue.data(data);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Clears all in-memory state and stored file-path metadata.
  /// Must be called on sign-out so the previous user's data is not
  /// accessible to the next session before a fresh [load] is performed.
  void reset() {
    _filePath = null;
    _isGuest = null;
    state = const AsyncValue.loading();
    // Clear the sync timestamp so the next user's file is compared fresh.
    SyncService.instance.reset();
  }

  /// Erases all user content (habits, journal, moods, focus sessions,
  /// transactions, accounts) while preserving settings and account meta.
  /// The wiped state is immediately persisted to disk.
  Future<void> clearAllData() => _save(
    (current) => AppData(
      meta: current.meta,
      settings: current.settings,
      habits: const [],
      habitLogs: const [],
      moods: const [],
      focusSessions: const [],
      journal: const [],
      accounts: const [],
      transactions: const [],
    ),
  );

  /// Loads data from [newPath] and updates [_filePath].
  ///
  /// Used by Settings when the user reconfigures the data folder.
  /// Transitions through [AsyncValue.loading] while reading the new file.
  Future<void> reconfigurePath(String newPath) async {
    state = const AsyncValue.loading();
    try {
      final data = await _service.loadData(newPath);
      _filePath = newPath;
      state = AsyncValue.data(data);
      await SyncService.instance.seedTimestamp(_filePath);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Attempts to load from [customPath]; if that throws a [FileSystemException]
  /// (storage access error), falls back to the internal documents directory.
  ///
  /// Called by the retry flow when the original path is inaccessible (e.g.
  /// Android 11+ scoped storage blocking writes to external user-picked paths).
  /// Returns the path that succeeded, or throws if both paths fail.
  Future<String> loadWithFallback({
    required bool isGuest,
    required String? customPath,
  }) async {
    state = const AsyncValue.loading();
    // Try the provided path first.
    if (customPath != null && customPath.isNotEmpty) {
      try {
        final data = await _service.loadData(customPath);
        _isGuest = isGuest;
        _filePath = customPath;
        state = AsyncValue.data(data);
        await SyncService.instance.seedTimestamp(_filePath);
        return customPath;
      } on FileSystemException {
        // Storage access denied — fall through to internal fallback below.
        debugPrint(
          '[DataNotifier] External path inaccessible ($customPath), '
          'falling back to internal storage.',
        );
      }
    }
    // Fallback: use internal app documents directory.
    final internalPath = await _service.resolveFilePath(
      isGuest: true, // guest path = internal documents dir
      customDirPath: null,
    );
    final data = await _service.loadData(internalPath);
    _isGuest = isGuest;
    _filePath = internalPath;
    state = AsyncValue.data(data);
    await SyncService.instance.seedTimestamp(_filePath);
    return internalPath;
  }

  ///
  /// Throws [StateError] if the data is not loaded yet (loading state) or if
  /// the file path has not been configured (never called [load]).  These
  /// failures are propagated so every mutation caller (addHabit, upsertMood,
  /// etc.) can show a meaningful error instead of silently doing nothing.
  Future<void> _save(AppData Function(AppData current) updater) async {
    // Explicit precondition check — fail loudly so callers always know.
    if (_filePath == null) {
      throw StateError(
        'Data file path is not configured. '
        'Please sign out and sign back in, or restart the app.',
      );
    }
    final current = state.valueOrNull;
    if (current == null) {
      throw StateError(
        'Data is not ready (state: ${state.runtimeType}). '
        'Please wait for the app to finish loading, then try again.',
      );
    }
    final next = updater(current);
    state = AsyncValue.data(next);
    try {
      await _service.saveData(next, _filePath!);
      // Update the SyncService baseline so a resume immediately after a save
      // does NOT trigger a spurious reload (the file mtime just changed but
      // the change originated from this app, not an external source).
      SyncService.instance.markUpdated();
      // Push an updated snapshot to the home-screen widget (best-effort).
      WidgetSyncService.instance.push(next, _filePath!).ignore();
    } catch (e) {
      // Roll back the optimistic state update so the UI stays consistent.
      state = AsyncValue.data(current);
      debugPrint('[DataNotifier] Save failed (rolled back): $e');
      // Notify listeners (e.g. global snackbar in HabitGeniusApp).
      if (!_saveErrors.isClosed) {
        _saveErrors.add(
          'Could not save your changes — please check your storage.',
        );
      }
    }
  }

  @override
  void dispose() {
    _saveErrors.close();
    super.dispose();
  }

  // ── Settings ──────────────────────────────────────────────

  Future<void> updateSettings(AppSettings settings) =>
      _save((d) => d.copyWith(settings: settings));

  // ── Habits ────────────────────────────────────────────────

  Future<void> addHabit(Habit habit) =>
      _save((d) => d.copyWith(habits: [...d.habits, habit]));

  Future<void> updateHabit(Habit habit) => _save(
    (d) => d.copyWith(
      habits: d.habits.map((h) => h.id == habit.id ? habit : h).toList(),
    ),
  );

  Future<void> reorderHabits(List<Habit> reordered) =>
      _save((d) => d.copyWith(habits: reordered));

  Future<void> deleteHabit(String habitId) => _save(
    (d) => d.copyWith(
      habits: d.habits.where((h) => h.id != habitId).toList(),
      // Also remove orphaned logs — deleted habit logs bloat the file and
      // would corrupt streak / stats if a new habit reused the same ID.
      habitLogs: d.habitLogs.where((l) => l.habitId != habitId).toList(),
    ),
  );

  // ── Habit Logs ────────────────────────────────────────────

  /// Toggles checkbox completion OR increments counter/timer value by [delta].
  /// Creates a new log if none exists for today. Writes a completedAt timestamp
  /// when the habit transitions to completed.
  Future<void> toggleHabit({
    required String habitId,
    String? dateStr, // defaults to today
    int delta = 1, // for counter / timer increments
  }) async {
    final today = dateStr ?? HabitHelpers.todayStr();
    return _save((d) {
      final habitIdx = d.habits.indexWhere((h) => h.id == habitId);
      if (habitIdx == -1) return d; // habit deleted since toggle was tapped
      final habit = d.habits[habitIdx];
      final existing = HabitHelpers.logForDate(d.habitLogs, habitId, today);

      final HabitLog updated;
      if (existing == null) {
        // New log for today.
        if (habit.progressType == HabitProgressType.checkbox ||
            habit.progressType == HabitProgressType.checklist ||
            habit.progressType == HabitProgressType.stopwatch) {
          updated = HabitLog(
            id: const Uuid().v4(),
            habitId: habitId,
            date: today,
            completed: true,
            value: 1,
            completedAt: DateTime.now().toUtc().toIso8601String(),
          );
        } else {
          // counter / timer — increment toward target
          final newValue = delta.clamp(0, habit.targetValue);
          final done = newValue >= habit.targetValue;
          updated = HabitLog(
            id: const Uuid().v4(),
            habitId: habitId,
            date: today,
            completed: done,
            value: newValue,
            completedAt: done ? DateTime.now().toUtc().toIso8601String() : null,
          );
        }
      } else {
        // Update existing log.
        if (habit.progressType == HabitProgressType.checkbox ||
            habit.progressType == HabitProgressType.checklist ||
            habit.progressType == HabitProgressType.stopwatch) {
          final toggled = !existing.completed;
          updated = existing.copyWith(
            completed: toggled,
            completedAt:
                toggled ? DateTime.now().toUtc().toIso8601String() : null,
          );
        } else {
          final newValue = (existing.value + delta).clamp(
            0,
            habit.targetValue * 2,
          );
          final done = newValue >= habit.targetValue;
          updated = existing.copyWith(
            value: newValue,
            completed: done,
            completedAt:
                done
                    ? (existing.completed
                        ? existing
                            .completedAt // keep original time if still done
                        : DateTime.now()
                            .toUtc()
                            .toIso8601String()) // newly done
                    : null, // clear when no longer done (undo / decrement)
          );
        }
      }

      final idx = d.habitLogs.indexWhere(
        (l) => l.habitId == habitId && l.date == today,
      );
      final logs = [...d.habitLogs];
      if (idx >= 0) {
        logs[idx] = updated;
      } else {
        logs.add(updated);
      }
      return d.copyWith(habitLogs: logs);
    });
  }

  /// Inserts or replaces the log entry for a given habit + date.
  Future<void> upsertHabitLog(HabitLog log) => _save((d) {
    final idx = d.habitLogs.indexWhere(
      (l) => l.habitId == log.habitId && l.date == log.date,
    );
    final updated = [...d.habitLogs];
    if (idx >= 0) {
      updated[idx] = log;
    } else {
      updated.add(log);
    }
    return d.copyWith(habitLogs: updated);
  });

  // ── Mood ──────────────────────────────────────────────────

  /// Inserts or replaces the mood entry for a given date.
  Future<void> upsertMood(Mood mood) => _save((d) {
    final idx = d.moods.indexWhere((m) => m.date == mood.date);
    final updated = [...d.moods];
    if (idx >= 0) {
      updated[idx] = mood;
    } else {
      updated.add(mood);
    }
    return d.copyWith(moods: updated);
  });

  // ── Focus ─────────────────────────────────────────────────

  Future<void> addFocusSession(FocusSession session) =>
      _save((d) => d.copyWith(focusSessions: [...d.focusSessions, session]));

  // ── Journal ───────────────────────────────────────────────

  Future<void> addJournalEntry(JournalEntry entry) =>
      _save((d) => d.copyWith(journal: [...d.journal, entry]));

  Future<void> updateJournalEntry(JournalEntry entry) => _save(
    (d) => d.copyWith(
      journal: d.journal.map((e) => e.id == entry.id ? entry : e).toList(),
    ),
  );

  Future<void> deleteJournalEntry(String entryId) => _save(
    (d) =>
        d.copyWith(journal: d.journal.where((e) => e.id != entryId).toList()),
  );

  // ── Accounts ──────────────────────────────────────────────

  Future<void> addAccount(Account account) =>
      _save((d) => d.copyWith(accounts: [...d.accounts, account]));

  Future<void> deleteAccount(String accountId) => _save(
    (d) => d.copyWith(
      accounts: d.accounts.where((a) => a.id != accountId).toList(),
    ),
  );

  // ── Transactions ──────────────────────────────────────────

  Future<void> addTransaction(Transaction tx) =>
      _save((d) => d.copyWith(transactions: [...d.transactions, tx]));

  Future<void> deleteTransaction(String txId) => _save(
    (d) => d.copyWith(
      transactions: d.transactions.where((t) => t.id != txId).toList(),
    ),
  );
}

// ── Provider ──────────────────────────────────────────────

final dataNotifierProvider =
    StateNotifierProvider<DataNotifier, AsyncValue<AppData>>((ref) {
      return DataNotifier(ref.watch(dataServiceProvider));
    });

/// Convenience provider — unwraps [AsyncValue].
/// Returns [AppData.empty] when data is still loading or in an error state
/// so that feature screens never crash even if the file is temporarily
/// unavailable (the HomeScreen handles the error state visually).
final appDataProvider = Provider<AppData>((ref) {
  return ref.watch(dataNotifierProvider).valueOrNull ?? AppData.empty();
});

/// The resolved file path used by [DataNotifier] for the current session.
///
/// Reads from SharedPreferences via [settingsProvider] so this is cheap and
/// does not require [DataNotifier] to expose a public getter.
final dataFilePathProvider = Provider<String?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getString(PrefKeys.dataFilePath);
});
