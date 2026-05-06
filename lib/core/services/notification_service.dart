import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Wraps [FlutterLocalNotificationsPlugin] for habit reminders.
///
/// Call [NotificationService.init] once at startup before using any other
/// method.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialised = false;

  // Channel IDs
  static const _habitChannelId = 'habit_reminders';
  static const _habitChannelName = 'Habit Reminders';

  /// Initialise the plugin and timezone data. Safe to call multiple times.
  /// All failures are non-fatal — the app runs without notifications rather
  /// than crashing.
  static Future<void> init() async {
    if (_initialised) return;

    try {
      tz_data.initializeTimeZones();
      // Set tz.local to the device's actual IANA timezone so zonedSchedule
      // fires at the correct local time (default is UTC if not set).
      try {
        final tzName = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(tzName));
      } catch (_) {
        // Fallback: keep tz.local as UTC — notifications will fire at the
        // wrong time but the app won't crash.
        debugPrint('[NotificationService] Could not set local timezone.');
      }
    } catch (e) {
      debugPrint('[NotificationService] Timezone init failed: $e');
      return;
    }

    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(const InitializationSettings(android: android));
    } catch (e) {
      debugPrint('[NotificationService] Plugin init failed: $e');
      return;
    }

    try {
      // Create the Android notification channel.
      const channel = AndroidNotificationChannel(
        _habitChannelId,
        _habitChannelName,
        description: 'Daily reminders for your tracked habits',
        importance: Importance.high,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    } catch (e) {
      debugPrint('[NotificationService] Channel creation failed: $e');
    }

    _initialised = true;
  }

  /// Schedules (or reschedules) a daily reminder for a habit.
  ///
  /// [habitId] is used as the notification ID seed (hashed to int).
  /// [timeOfDay] is the local time at which to fire each day.
  /// Pass [scheduleDays] (1=Mon … 7=Sun, matching DateTime.weekday) to
  /// restrict to specific weekdays; passing an empty list schedules daily.
  static Future<void> scheduleHabitReminder({
    required String habitId,
    required String habitName,
    required TimeOfDay timeOfDay,
    List<int> scheduleDays = const [],
  }) async {
    if (!_initialised) {
      debugPrint(
        '[NotificationService] scheduleHabitReminder called before init; skipping.',
      );
      return;
    }

    // Cancel existing notifications for this habit first (cleans up old ones).
    await cancelHabitReminder(habitId);

    const androidDetails = AndroidNotificationDetails(
      _habitChannelId,
      _habitChannelName,
      channelDescription: 'Daily reminders for your tracked habits',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    final notifDetails = const NotificationDetails(android: androidDetails);

    if (scheduleDays.isEmpty) {
      // Daily — one notification that repeats every day at the given time.
      final id = habitId.hashCode.abs() % 100000;
      final scheduledDate = _nextInstanceOfTime(timeOfDay, null);
      try {
        await _plugin.zonedSchedule(
          id,
          'Time for: $habitName',
          'Tap to log your progress',
          scheduledDate,
          notifDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (e) {
        debugPrint(
          '[NotificationService] scheduleHabitReminder (daily) failed: $e',
        );
      }
    } else {
      // Specific weekdays — schedule one repeating notification per day.
      // IDs are derived from habitId + day so they don't collide.
      for (final weekday in scheduleDays) {
        final id = (habitId.hashCode.abs() + weekday * 100001) % 2000000000;
        final scheduledDate = _nextInstanceOfTime(timeOfDay, weekday);
        try {
          await _plugin.zonedSchedule(
            id,
            'Time for: $habitName',
            'Tap to log your progress',
            scheduledDate,
            notifDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        } catch (e) {
          debugPrint(
            '[NotificationService] scheduleHabitReminder (day=$weekday) failed: $e',
          );
        }
      }
    }
  }

  /// Cancels the reminder for a specific habit (all per-day IDs included).
  static Future<void> cancelHabitReminder(String habitId) async {
    // Cancel the daily ID.
    final dailyId = habitId.hashCode.abs() % 100000;
    try {
      await _plugin.cancel(dailyId);
    } catch (_) {}
    // Cancel per-weekday IDs (1–7).
    for (int d = 1; d <= 7; d++) {
      final id = (habitId.hashCode.abs() + d * 100001) % 2000000000;
      try {
        await _plugin.cancel(id);
      } catch (_) {}
    }
  }

  /// Cancels all scheduled notifications.
  static Future<void> cancelAll() => _plugin.cancelAll();

  // ── Helpers ───────────────────────────────────────────────

  /// Returns the next TZDateTime for [tod].
  ///
  /// When [weekday] is given (1=Mon … 7=Sun), the returned datetime is the
  /// next occurrence of that weekday at [tod]. Otherwise it is today or
  /// tomorrow at [tod].
  static tz.TZDateTime _nextInstanceOfTime(TimeOfDay tod, int? weekday) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      tod.hour,
      tod.minute,
    );
    if (weekday == null) {
      // Daily: if today's slot already passed, move to tomorrow.
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
    } else {
      // Specific weekday: advance until the correct day (and time hasn't passed).
      while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
    }
    return scheduled;
  }
}
