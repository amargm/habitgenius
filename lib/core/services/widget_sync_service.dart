import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/app_data.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../utils/habit_helpers.dart';

/// Pushes a compact snapshot of today's habit data into SharedPreferences so
/// the native Android home-screen widget can read it without spinning up the
/// Flutter engine.
///
/// The data is written under the key `"flutter.hw_widget_habits"` (the
/// `"flutter."` prefix is added automatically by [SharedPreferences] on
/// Android when the platform channel writes it; the Kotlin side reads the key
/// `"hw_widget_habits"` from the Flutter-shared-preferences file).
///
/// After writing the prefs, a platform channel call fires
/// `AppWidgetManager.updateAppWidget()` on the Android side so the widget
/// refreshes immediately.
class WidgetSyncService {
  WidgetSyncService._();
  static final WidgetSyncService instance = WidgetSyncService._();

  static const _channel = MethodChannel('com.habitgenius/widget');

  /// Serializes habit data for today + the surrounding 7-day week into
  /// SharedPreferences and triggers a widget redraw.
  ///
  /// Safe to call without `await` (errors are swallowed so a widget-push
  /// failure never disrupts the main app).
  Future<void> push(AppData data, String filePath) async {
    try {
      final json = _buildWidgetJson(data);
      await _channel.invokeMethod<void>('updateWidget', {'data': json});
    } catch (_) {
      // Widget push is best-effort — never crash the app.
    }
  }

  // ── JSON builder ─────────────────────────────────────────

  String _buildWidgetJson(AppData data) {
    final today = DateTime.now();
    final todayStr = HabitHelpers.todayStr();

    // Build the 7-day window: Mon → Sun of the current ISO week.
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
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
