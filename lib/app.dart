import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/cloud_sync_provider.dart';
import 'core/providers/data_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/services/sync_service.dart';
import 'core/services/widget_sync_service.dart';
import 'core/theme/theme_provider.dart';
import 'core/utils/app_toast.dart';
import 'features/focus/focus_screen.dart';
import 'core/services/focus_session_service.dart';
import 'package:uuid/uuid.dart';

class HabitGeniusApp extends ConsumerStatefulWidget {
  const HabitGeniusApp({super.key});

  @override
  ConsumerState<HabitGeniusApp> createState() => _HabitGeniusAppState();
}

class _HabitGeniusAppState extends ConsumerState<HabitGeniusApp>
    with WidgetsBindingObserver {
  StreamSubscription<String>? _saveErrorSub;
  // Riverpod subscription used to trigger first-run notification scheduling
  // once the data provider finishes its initial async load.
  // ignore: cancel_subscriptions
  ProviderSubscription? _dataSub;
  // Listens for auth tier changes so widgets reflect sign-in/out immediately.
  // ignore: cancel_subscriptions
  ProviderSubscription? _authSub;
  // Auto-save guard for the focus timer.
  bool _focusAutoSaved = false;
  // Hash of reminder-relevant habit fields — used to skip reschedule when
  // nothing changed since the last time we scheduled notifications.
  String? _lastReminderHash;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _saveErrorSub = ref.read(dataNotifierProvider.notifier).saveErrors.listen((
      message,
    ) {
      if (!mounted) return;
      AppToast.show(context, message, type: ToastType.error);
    });
    // Global focus auto-save: fires regardless of which screen is active.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(focusSvcProvider).addListener(_onFocusSvcChange);
      // If data is already loaded (e.g. hot restart), push widget data and
      // reschedule reminders now — the _dataSub listener won't fire for
      // an already-loaded state.
      if (ref.read(dataNotifierProvider).hasValue) {
        _rescheduleHabitReminders();
        _pushWidgetData();
      }
    });
    // Subscribe to auth state changes so widgets refresh when the user signs
    // in, signs out, or Pro entitlement loads.
    _authSub = ref.listenManual(authNotifierProvider, (prev, next) {
      if (prev?.tier != next.tier) {
        _pushWidgetData();
      }
    });
    // Subscribe to the data provider so we reschedule notifications as soon
    // as habits finish loading on a cold start (avoids the race condition
    // where valueOrNull is null during the first postFrameCallback).
    _dataSub = ref.listenManual(dataNotifierProvider, (prev, next) {
      if (next.hasValue && (prev == null || !prev.hasValue)) {
        _rescheduleHabitReminders();
        // Push widget data immediately on the first successful data load so
        // widgets are populated right after a cold start / process kill.
        _pushWidgetData();
        // Auto-populate any recurring transactions that are due today.
        ref
            .read(dataNotifierProvider.notifier)
            .applyRecurringTransactions()
            .ignore();
      }
      // After a user mutation (meta.lastModified changed), schedule a
      // debounced upload AND refresh widgets immediately. Guard against
      // sync reloads (which reload the same data) to avoid re-uploading
      // data we just downloaded from Drive.
      if (prev?.hasValue == true && next.hasValue) {
        final prevModified = prev?.value?.meta.lastModified;
        final nextModified = next.value?.meta.lastModified;
        if (nextModified != null && nextModified != prevModified) {
          _scheduleCloudUpload();
          _pushWidgetData();
        }
      }
    });
  }

  @override
  void dispose() {
    _saveErrorSub?.cancel();
    _dataSub?.close();
    _authSub?.close();
    ref.read(focusSvcProvider).removeListener(_onFocusSvcChange);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onFocusSvcChange() {
    final svc = ref.read(focusSvcProvider);
    if (svc.isFinished && !_focusAutoSaved) {
      _focusAutoSaved = true;
      _autoSaveFocusSession(svc);
    } else if (svc.isIdle) {
      _focusAutoSaved = false;
    }
  }

  Future<void> _autoSaveFocusSession(FocusSessionService svc) async {
    final id = const Uuid().v4();
    final session = svc.buildSession(id);
    if (session == null) return;
    try {
      await ref.read(dataNotifierProvider.notifier).addFocusSession(session);
      svc.reset();
    } catch (_) {
      // Silent: error stream will notify user.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final notifier = ref.read(dataNotifierProvider.notifier);
      SyncService.instance.checkAndReload(notifier);
      _rescheduleHabitReminders();
      // Abort any hung sync, then do a fresh download-first check.
      ref.read(cloudSyncProvider.notifier).abortIfHanging();
      _checkCloudSyncOnResume(notifier);
      _pushWidgetData();
    } else if (state == AppLifecycleState.paused) {
      // App is going to background — flush any pending debounced upload
      // immediately so data isn't lost if the process is killed.
      _flushCloudSync();
    }
  }

  void _scheduleCloudUpload() {
    final authState = ref.read(authNotifierProvider);
    if (authState.isGuest) return;
    ref
        .read(cloudSyncProvider.notifier)
        .scheduleUpload(
          dataNotifier: ref.read(dataNotifierProvider.notifier),
          googleSignIn: ref.read(authServiceProvider).driveGoogleSignIn,
        );
  }

  /// Flushes any pending debounced upload immediately (called on app pause).
  void _flushCloudSync() {
    final authState = ref.read(authNotifierProvider);
    if (authState.isGuest) return;
    ref.read(cloudSyncProvider.notifier).flushPendingUpload().ignore();
  }

  void _checkCloudSyncOnResume(DataNotifier dataNotifier) {
    final authState = ref.read(authNotifierProvider);
    if (authState.isGuest) return;
    ref
        .read(cloudSyncProvider.notifier)
        .checkOnResume(
          dataNotifier: dataNotifier,
          googleSignIn: ref.read(authServiceProvider).driveGoogleSignIn,
        );
  }

  void _pushWidgetData() {
    final data = ref.read(dataNotifierProvider).valueOrNull;
    if (data == null) return;
    // Use the RUNTIME auth tier so widgets correctly show registered vs guest
    // state (data.settings.userTier defaults to guest for non-Pro users).
    final tier = ref.read(authNotifierProvider).tier;
    WidgetSyncService.instance.pushAll(data, tier: tier).ignore();
  }

  /// Re-registers all habit reminders so they survive OS reboots and
  /// notification permission changes.
  Future<void> _rescheduleHabitReminders() async {
    final data = ref.read(dataNotifierProvider).valueOrNull;
    if (data == null) return;
    // Build a hash of reminder-relevant fields. Skip the expensive
    // cancel+reschedule cycle if nothing has changed since the last run.
    final hash = data.habits
        .where((h) => h.reminderTime != null && h.archivedAt == null)
        .map(
          (h) =>
              '${h.id}|${h.reminderTime}|${h.schedule.name}|${h.scheduleDays}',
        )
        .join(',');
    if (hash == _lastReminderHash) return;
    _lastReminderHash = hash;
    for (final habit in data.habits) {
      if (habit.reminderTime == null || habit.archivedAt != null) continue;
      final parts = habit.reminderTime!.split(':');
      if (parts.length != 2) continue;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) continue;
      await NotificationService.scheduleHabitReminder(
        habitId: habit.id,
        habitName: habit.name,
        timeOfDay: TimeOfDay(hour: h, minute: m),
        scheduleDays: habit.scheduleDays,
        schedule: habit.schedule,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final darkTheme = ref.watch(darkThemeProvider);
    final lightTheme = ref.watch(lightThemeProvider);

    return MaterialApp.router(
      title: 'HabitGenius',
      debugShowCheckedModeBanner: false,
      themeMode: themeState.themeMode,
      theme: lightTheme,
      darkTheme: darkTheme,
      routerConfig: appRouter,
    );
  }
}
