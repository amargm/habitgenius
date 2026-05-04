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
import '../utils/habit_helpers.dart';

// ── Service ───────────────────────────────────────────────

final dataServiceProvider = Provider<DataService>((_) => DataService());

// ── Notifier ──────────────────────────────────────────────

/// Holds the in-memory [AppData] and serialises every mutation to disk.
class DataNotifier extends StateNotifier<AsyncValue<AppData>> {
  final DataService _service;
  String? _filePath;
  bool? _isGuest;
  String? _customDir;

  DataNotifier(this._service) : super(const AsyncValue.loading());

  String? get filePath => _filePath;

  /// Resolves the file path and loads [AppData] from disk.
  /// Call this from [SplashScreen] after auth is resolved.
  Future<void> load({required bool isGuest, required String? customDir}) async {
    _isGuest = isGuest;
    _customDir = customDir;
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

  /// Re-reads the file from the same path used in [load].
  /// No-op if [load] was never called.
  Future<void> reload() async {
    if (_isGuest == null) return;
    await load(isGuest: _isGuest!, customDir: _customDir);
  }

  /// Applies [updater] to the current [AppData], updates state, and persists.
  Future<void> _save(AppData Function(AppData current) updater) async {
    final current = state.valueOrNull;
    if (current == null || _filePath == null) return;
    final next = updater(current);
    state = AsyncValue.data(next);
    try {
      await _service.saveData(next, _filePath!);
    } catch (e) {
      // Roll back the optimistic state update so the UI stays consistent.
      state = AsyncValue.data(current);
      // Non-fatal: surface via debugPrint — the in-memory state is still valid.
      debugPrint('[DataNotifier] Save failed (rolled back): $e');
    }
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

  Future<void> deleteHabit(String habitId) => _save(
    (d) => d.copyWith(habits: d.habits.where((h) => h.id != habitId).toList()),
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
      final habit = d.habits.firstWhere((h) => h.id == habitId);
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
                done && !existing.completed
                    ? DateTime.now().toUtc().toIso8601String()
                    : existing.completedAt,
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

/// Convenience provider — unwraps [AsyncValue] and throws if not yet loaded.
/// Only use after [DataNotifier.load] has completed successfully.
final appDataProvider = Provider<AppData>((ref) {
  return ref.watch(dataNotifierProvider).requireValue;
});
