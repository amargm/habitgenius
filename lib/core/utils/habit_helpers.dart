import '../models/habit.dart';
import '../models/habit_log.dart';

/// Pure functions for habit queries used in the UI and providers.
class HabitHelpers {
  HabitHelpers._();

  // ── Scheduled today? ──────────────────────────────────────

  /// Returns true if [habit] is scheduled for [date] (defaults to today).
  static bool isScheduledOn(Habit habit, DateTime date) {
    switch (habit.schedule) {
      case HabitSchedule.daily:
        return true;
      case HabitSchedule.weekly:
        // scheduleDays: 0=Sun … 6=Sat
        return habit.scheduleDays.contains(date.weekday % 7);
      case HabitSchedule.monthly:
        return habit.scheduleDays.contains(date.day);
      case HabitSchedule.specific:
      case HabitSchedule.custom:
        return habit.scheduleDays.contains(date.weekday % 7);
    }
  }

  /// Returns all active (non-archived) habits scheduled for [date].
  static List<Habit> habitsForDate(List<Habit> habits, DateTime date) =>
      habits
          .where((h) => h.archivedAt == null && isScheduledOn(h, date))
          .toList();

  // ── Log lookup ────────────────────────────────────────────

  /// Finds the log for [habitId] on the given [dateStr] (YYYY-MM-DD).
  static HabitLog? logForDate(
    List<HabitLog> logs,
    String habitId,
    String dateStr,
  ) => logs.where((l) => l.habitId == habitId && l.date == dateStr).firstOrNull;

  // ── Completion ────────────────────────────────────────────

  /// Returns true if the habit is considered "done" for [dateStr].
  /// For counter/timer habits: value >= targetValue.
  static bool isCompletedOn(Habit habit, List<HabitLog> logs, String dateStr) {
    final log = logForDate(logs, habit.id, dateStr);
    if (log == null) return false;
    if (habit.progressType == HabitProgressType.checkbox ||
        habit.progressType == HabitProgressType.checklist ||
        habit.progressType == HabitProgressType.stopwatch) {
      return log.completed;
    }
    // counter / timer
    return log.value >= habit.targetValue;
  }

  // ── Streak ────────────────────────────────────────────────

  /// Calculates the current streak (consecutive completed scheduled days
  /// ending on [today] or the most recent scheduled day).
  ///
  /// A "missed" scheduled day that was not completed resets the streak to 0.
  static int currentStreak(Habit habit, List<HabitLog> logs, DateTime today) {
    int streak = 0;
    DateTime cursor = DateTime(today.year, today.month, today.day);

    // Walk backwards up to 365 days.
    for (int i = 0; i < 365; i++) {
      if (!isScheduledOn(habit, cursor)) {
        // Not scheduled — skip, don't break streak.
        cursor = cursor.subtract(const Duration(days: 1));
        continue;
      }
      final dateStr = _fmtDate(cursor);
      if (isCompletedOn(habit, logs, dateStr)) {
        streak++;
      } else {
        // Scheduled day was missed — break.
        // Exception: today itself not yet done should not break the streak.
        if (i == 0) {
          // Today is scheduled but not yet completed — keep counting past.
          cursor = cursor.subtract(const Duration(days: 1));
          continue;
        }
        break;
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // ── Weekly completion grid ────────────────────────────────

  /// Returns 7 booleans [Sun…Sat] indicating completion for the week
  /// containing [date].
  static List<bool> weeklyCompletion(
    Habit habit,
    List<HabitLog> logs,
    DateTime date,
  ) {
    // Find Sunday of this week.
    final weekday = date.weekday % 7; // 0=Sun
    final sunday = date.subtract(Duration(days: weekday));
    return List.generate(7, (i) {
      final day = sunday.add(Duration(days: i));
      if (!isScheduledOn(habit, day)) return false;
      return isCompletedOn(habit, logs, _fmtDate(day));
    });
  }

  // ── Heatmap data ──────────────────────────────────────────

  /// Returns a map of dateStr → completion level (0–4) for [habit] over the
  /// past 365 days ending on [today].
  static Map<String, int> yearlyHeatmap(
    Habit habit,
    List<HabitLog> logs,
    DateTime today,
  ) {
    final result = <String, int>{};
    for (int i = 0; i < 365; i++) {
      final day = today.subtract(Duration(days: i));
      if (!isScheduledOn(habit, day)) continue;
      final ds = _fmtDate(day);
      final log = logForDate(logs, habit.id, ds);
      if (log == null || !log.completed) {
        result[ds] = 0;
      } else if (habit.progressType == HabitProgressType.counter ||
          habit.progressType == HabitProgressType.timer) {
        final pct = (log.value / habit.targetValue).clamp(0.0, 1.0);
        result[ds] =
            pct < 0.25
                ? 1
                : pct < 0.50
                ? 2
                : pct < 0.75
                ? 3
                : 4;
      } else {
        result[ds] = 4;
      }
    }
    return result;
  }

  /// Returns a map of dateStr → completion level (0–4) for [habit] from its
  /// creation date up to [today]. Use this when multi-year navigation is needed.
  static Map<String, int> allTimeHeatmap(
    Habit habit,
    List<HabitLog> logs,
    DateTime today,
  ) {
    final result = <String, int>{};
    final createdAt = DateTime.tryParse(habit.createdAt)?.toLocal() ?? today;
    final start = DateTime(createdAt.year, createdAt.month, createdAt.day);
    final end = DateTime(today.year, today.month, today.day);
    for (
      DateTime day = start;
      !day.isAfter(end);
      day = day.add(const Duration(days: 1))
    ) {
      if (!isScheduledOn(habit, day)) continue;
      final ds = _fmtDate(day);
      final log = logForDate(logs, habit.id, ds);
      if (log == null || !log.completed) {
        result[ds] = 0;
      } else if (habit.progressType == HabitProgressType.counter ||
          habit.progressType == HabitProgressType.timer) {
        final pct = (log.value / habit.targetValue).clamp(0.0, 1.0);
        result[ds] =
            pct < 0.25
                ? 1
                : pct < 0.50
                ? 2
                : pct < 0.75
                ? 3
                : 4;
      } else {
        result[ds] = 4;
      }
    }
    return result;
  }

  // ── Formatting ────────────────────────────────────────────

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String todayStr() => _fmtDate(DateTime.now());
}
