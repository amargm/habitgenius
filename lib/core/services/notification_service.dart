import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
  static Future<void> init() async {
    if (_initialised) return;

    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));

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

    _initialised = true;
  }

  /// Schedules (or reschedules) a daily reminder for a habit.
  ///
  /// [habitId] is used as the notification ID seed (hashed to int).
  /// [timeOfDay] is the local time at which to fire each day.
  /// Pass [scheduleDays] (0=Sun … 6=Sat) to restrict to specific weekdays;
  /// passing an empty list schedules daily.
  static Future<void> scheduleHabitReminder({
    required String habitId,
    required String habitName,
    required TimeOfDay timeOfDay,
    List<int> scheduleDays = const [],
  }) async {
    assert(_initialised, 'Call NotificationService.init() first');

    final id = habitId.hashCode.abs() % 100000;

    const androidDetails = AndroidNotificationDetails(
      _habitChannelId,
      _habitChannelName,
      channelDescription: 'Daily reminders for your tracked habits',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    final scheduledDate = _nextInstanceOfTime(timeOfDay);

    await _plugin.zonedSchedule(
      id,
      'Time for: $habitName',
      'Tap to log your progress',
      scheduledDate,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Cancels the reminder for a specific habit.
  static Future<void> cancelHabitReminder(String habitId) async {
    final id = habitId.hashCode.abs() % 100000;
    await _plugin.cancel(id);
  }

  /// Cancels all scheduled notifications.
  static Future<void> cancelAll() => _plugin.cancelAll();

  // ── Helpers ───────────────────────────────────────────────

  static tz.TZDateTime _nextInstanceOfTime(TimeOfDay tod) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      tod.hour,
      tod.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
