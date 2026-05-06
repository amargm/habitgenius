import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/habit.dart';
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
  // Fixed notification ID for the global daily reminder (Settings toggle).
  static const _globalReminderId = 999997;

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
    HabitSchedule schedule = HabitSchedule.daily,
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

    if (scheduleDays.isEmpty || schedule == HabitSchedule.daily) {
      // ── Daily ──────────────────────────────────────────────────────────
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
    } else if (schedule == HabitSchedule.monthly) {
      // ── Monthly — one notification per selected day-of-month ───────────
      // scheduleDays contains day-of-month values (1–31).
      for (final dom in scheduleDays) {
        // Use a different ID multiplier to avoid collision with weekday IDs.
        final id = (habitId.hashCode.abs() + dom * 200002) % 2000000000;
        final scheduledDate = _nextInstanceOfDayOfMonth(timeOfDay, dom);
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
            matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
          );
        } catch (e) {
          debugPrint(
            '[NotificationService] scheduleHabitReminder (monthly dom=$dom) failed: $e',
          );
        }
      }
    } else {
      // ── Specific weekdays (weekly / weekdays / weekends / custom) ──────
      // scheduleDays: 0=Sun, 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat.
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
            '[NotificationService] scheduleHabitReminder (weekday=$weekday) failed: $e',
          );
        }
      }
    }
  }

  /// Cancels all reminders for a specific habit (daily + per-weekday + monthly).
  static Future<void> cancelHabitReminder(String habitId) async {
    final base = habitId.hashCode.abs();
    // Daily ID.
    try { await _plugin.cancel(base % 100000); } catch (_) {}
    // Per-weekday IDs: scheduleDays values are 0=Sun..6=Sat.
    for (int d = 0; d <= 6; d++) {
      try { await _plugin.cancel((base + d * 100001) % 2000000000); } catch (_) {}
    }
    // Per-day-of-month IDs: dom values are 1..31.
    for (int d = 1; d <= 31; d++) {
      try { await _plugin.cancel((base + d * 200002) % 2000000000); } catch (_) {}
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
  /// Returns the next [tz.TZDateTime] for [tod].
  ///
  /// [weekdaySun0]: the habit's weekday value in the 0=Sun,1=Mon…6=Sat
  /// convention stored in [Habit.scheduleDays]. Pass null for daily.
  static tz.TZDateTime _nextInstanceOfTime(TimeOfDay tod, int? weekdaySun0) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      tod.hour,
      tod.minute,
    );
    if (weekdaySun0 == null) {
      // Daily: if today's slot already passed, move to tomorrow.
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
    } else {
      // Convert from app convention (0=Sun…6=Sat) to DateTime.weekday
      // convention (1=Mon…6=Sat, 7=Sun) used by tz.TZDateTime.
      final tzWeekday = weekdaySun0 == 0 ? 7 : weekdaySun0;
      // Advance day by day until we land on the correct weekday.
      // The loop body is guaranteed to terminate within 7 iterations.
      int safety = 0;
      while ((scheduled.weekday != tzWeekday || scheduled.isBefore(now)) &&
          safety < 8) {
        scheduled = scheduled.add(const Duration(days: 1));
        safety++;
      }
    }
    return scheduled;
  }

  /// Returns the next [tz.TZDateTime] for [tod] on the given [dayOfMonth].
  static tz.TZDateTime _nextInstanceOfDayOfMonth(
    TimeOfDay tod,
    int dayOfMonth,
  ) {
    final now = tz.TZDateTime.now(tz.local);
    // Try this calendar month first.
    final daysThis = DateUtils.getDaysInMonth(now.year, now.month);
    final clampedThis = dayOfMonth.clamp(1, daysThis);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      clampedThis,
      tod.hour,
      tod.minute,
    );
    // If that date/time has already passed, move to next month.
    if (scheduled.isBefore(now)) {
      int year = now.year;
      int month = now.month + 1;
      if (month > 12) {
        month = 1;
        year++;
      }
      final daysNext = DateUtils.getDaysInMonth(year, month);
      final clampedNext = dayOfMonth.clamp(1, daysNext);
      scheduled = tz.TZDateTime(
        tz.local,
        year,
        month,
        clampedNext,
        tod.hour,
        tod.minute,
      );
    }
    return scheduled;
  }

  // ── Global (settings-level) reminder ─────────────────────

  /// Schedules a single daily notification for users who prefer a global
  /// reminder rather than per-habit ones. Triggered from Settings.
  static Future<void> scheduleGlobalReminder(TimeOfDay tod) async {
    if (!_initialised) return;
    await cancelGlobalReminder();
    const androidDetails = AndroidNotificationDetails(
      _habitChannelId,
      _habitChannelName,
      channelDescription: 'Daily reminders for your tracked habits',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    final scheduledDate = _nextInstanceOfTime(tod, null);
    try {
      await _plugin.zonedSchedule(
        _globalReminderId,
        'Time to check your habits',
        'How are your habits going today?',
        scheduledDate,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('[NotificationService] scheduleGlobalReminder failed: $e');
    }
  }

  /// Cancels the global daily reminder (from Settings).
  static Future<void> cancelGlobalReminder() async {
    try {
      await _plugin.cancel(_globalReminderId);
    } catch (_) {}
  }
}
