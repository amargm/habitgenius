import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/app_data.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/transaction.dart';
import '../utils/habit_helpers.dart';

/// Pushes compact snapshots for all home-screen widgets into SharedPreferences
/// via a single platform-channel call, then triggers a redraw for each widget
/// provider.  All operations are best-effort — a failure never affects the app.
///
/// SharedPreferences keys (Flutter prefix "flutter." applied by MainActivity):
///   hw_widget_habits  — habits list + weekly status + streaks
///   hw_mood           — today's mood + recent trend
///   hw_focus_stats    — today's focus time (runtime state owned by Kotlin)
///   hw_expenses       — account balances + today/month totals
class WidgetSyncService {
  WidgetSyncService._();
  static final WidgetSyncService instance = WidgetSyncService._();

  static const _channel = MethodChannel('com.habitgenius/widget');

  /// Pushes all four widget data payloads in one channel call.
  /// Safe to call with `.ignore()` — swallows all errors.
  Future<void> pushAll(AppData data) async {
    try {
      await _channel.invokeMethod<void>('pushAll', {
        'habits': _buildHabitsJson(data),
        'mood': _buildMoodJson(data),
        'focus': _buildFocusStatsJson(data),
        'expenses': _buildExpensesJson(data),
      });
    } catch (_) {
      // Widget push is best-effort — never crash the app.
    }
  }

  // ── Habits JSON (includes currentStreak for Streak widget) ───────────────

  String _buildHabitsJson(AppData data) {
    final today = DateTime.now();
    final todayStr = HabitHelpers.todayStr();

    final weekday = today.weekday; // 1=Mon … 7=Sun
    final monday = today.subtract(Duration(days: weekday - 1));
    final weekDates = List.generate(7, (i) {
      final d = monday.add(Duration(days: i));
      return _fmtDate(d);
    });
    final weekLabels = List.generate(7, (i) {
      final d = monday.add(Duration(days: i));
      const names = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
      return names[d.weekday - 1];
    });

    final activeHabits =
        data.habits.where((h) => h.archivedAt == null).toList();

    final habitsJson =
        activeHabits.map((h) {
          final weekStatus =
              weekDates.map((dateStr) {
                final date = DateTime.parse(dateStr);
                final scheduled = HabitHelpers.isScheduledOn(h, date);
                final log = HabitHelpers.logForDate(
                  data.habitLogs,
                  h.id,
                  dateStr,
                );
                final value = log?.value ?? 0;
                final completed = _isCompleted(h, log);
                final progress =
                    (h.progressType == HabitProgressType.counter ||
                            h.progressType == HabitProgressType.timer)
                        ? (h.targetValue > 0 ? value / h.targetValue : 0.0)
                            .clamp(0.0, 1.0)
                        : (completed ? 1.0 : 0.0);
                return {
                  'scheduled': scheduled,
                  'completed': completed,
                  'value': value,
                  'progress': progress,
                };
              }).toList();

          final todayLog = HabitHelpers.logForDate(
            data.habitLogs,
            h.id,
            todayStr,
          );
          final streak = HabitHelpers.currentStreak(h, data.habitLogs, today);
          return {
            'id': h.id,
            'name': h.name,
            'icon': h.icon,
            'colorHex': h.colorHex,
            'progressType': h.progressType.name,
            'targetValue': h.targetValue,
            'unit': h.unit,
            'scheduledToday': HabitHelpers.isScheduledOn(h, today),
            'todayCompleted': _isCompleted(h, todayLog),
            'todayValue': todayLog?.value ?? 0,
            'currentStreak': streak,
            'weekStatus': weekStatus,
          };
        }).toList();

    return jsonEncode({
      'todayStr': todayStr,
      'weekDates': weekDates,
      'weekLabels': weekLabels,
      'habits': habitsJson,
    });
  }

  // ── Mood JSON ─────────────────────────────────────────────────────────────

  String _buildMoodJson(AppData data) {
    final todayStr = HabitHelpers.todayStr();
    final tier = data.settings.userTier.name; // guest | registered | pro

    final todayMood = data.moods.where((m) => m.date == todayStr).firstOrNull;

    // Up to 4 most-recent past moods for trend display.
    final pastMoods =
        data.moods.where((m) => m.date != todayStr).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final recentLevels = pastMoods.take(4).map((m) => m.level).toList();

    return jsonEncode({
      'tier': tier,
      'todayLogged': todayMood != null,
      'todayLevel': todayMood?.level ?? 0,
      'todayEmoji': todayMood?.emoji ?? '',
      'recentLevels': recentLevels,
    });
  }

  // ── Focus stats JSON (static stats; runtime timer state managed by Kotlin) ─

  String _buildFocusStatsJson(AppData data) {
    // Compare session start times in local time to avoid UTC/local boundary
    // mismatches (e.g. a session at 11:30 PM local stored as a previous UTC date).
    final today = DateTime.now();
    final todaySeconds = data.focusSessions.where((s) {
      final d = DateTime.tryParse(s.startedAt)?.toLocal();
      return d != null &&
          d.year == today.year &&
          d.month == today.month &&
          d.day == today.day;
    }).fold<int>(0, (sum, s) => sum + s.actualDuration);

    return jsonEncode({
      'todayFocusSeconds': todaySeconds,
      'tier': data.settings.userTier.name,
    });
  }

  // ── Expenses JSON ─────────────────────────────────────────────────────────

  String _buildExpensesJson(AppData data) {
    final tier = data.settings.userTier.name;

    if (tier == 'guest') {
      return jsonEncode({
        'tier': tier,
        'accounts': [],
        'todayExpense': 0,
        'monthExpense': 0,
        'monthIncome': 0,
        'currency': 'USD',
      });
    }

    final todayStr = HabitHelpers.todayStr();
    final now = DateTime.now();
    final monthStart = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';

    // Compute current balance for each account from starting balance +
    // all transactions.
    final accountBalances =
        data.accounts.map((acc) {
          double balance = acc.startingBalance;
          for (final t in data.transactions) {
            if (t.type == TransactionType.expense && t.accountId == acc.id) {
              balance -= t.amount;
            } else if (t.type == TransactionType.income &&
                t.accountId == acc.id) {
              balance += t.amount;
            } else if (t.type == TransactionType.transfer) {
              if (t.accountId == acc.id) balance -= t.amount;
              if (t.toAccountId == acc.id) balance += t.amount;
            }
          }
          return {
            'name': acc.name,
            'balance': balance,
            'currency': acc.currency,
          };
        }).toList();

    final todayExpense = data.transactions
        .where((t) => t.date == todayStr && t.type == TransactionType.expense)
        .fold<double>(0, (s, t) => s + t.amount);

    final monthExpense = data.transactions
        .where(
          (t) =>
              t.date.compareTo(monthStart) >= 0 &&
              t.type == TransactionType.expense,
        )
        .fold<double>(0, (s, t) => s + t.amount);

    final monthIncome = data.transactions
        .where(
          (t) =>
              t.date.compareTo(monthStart) >= 0 &&
              t.type == TransactionType.income,
        )
        .fold<double>(0, (s, t) => s + t.amount);

    final currency =
        data.accounts.isNotEmpty ? data.accounts.first.currency : 'USD';

    return jsonEncode({
      'tier': tier,
      'accounts': accountBalances,
      'todayExpense': todayExpense,
      'monthExpense': monthExpense,
      'monthIncome': monthIncome,
      'currency': currency,
      'currencySymbol': data.settings.currencySymbol,
    });
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  static bool _isCompleted(Habit h, HabitLog? log) {
    if (log == null) return false;
    if (h.progressType == HabitProgressType.checkbox ||
        h.progressType == HabitProgressType.checklist ||
        h.progressType == HabitProgressType.stopwatch) {
      return log.completed;
    }
    return log.value >= h.targetValue;
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
