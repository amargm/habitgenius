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
  // Auto-save guard for the focus timer.
  bool _focusAutoSaved = false;

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
      // If data is already loaded (e.g. hot restart), reschedule now.
      if (ref.read(dataNotifierProvider).hasValue) {
        _rescheduleHabitReminders();
      }
    });
    // Subscribe to the data provider so we reschedule notifications as soon
    // as habits finish loading on a cold start (avoids the race condition
    // where valueOrNull is null during the first postFrameCallback).
    _dataSub = ref.listenManual(dataNotifierProvider, (prev, next) {
      if (next.hasValue && (prev == null || !prev.hasValue)) {
        _rescheduleHabitReminders();
      }
      // After every mutation (value → value), schedule a debounced upload.
      if (prev?.hasValue == true && next.hasValue) {
        _scheduleCloudUpload();
      }
    });
  }

  @override
  void dispose() {
    _saveErrorSub?.cancel();
    _dataSub?.close();
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
      // Cloud sync: download-first check so any change made on another device
      // is reflected immediately when the user opens the app.
      _checkCloudSyncOnResume(notifier);
      // Re-push widget data: catches any habit logs the widget wrote while
      // the app was backgrounded, so the widget reflects the latest state.
      _pushWidgetData();
    }
  }

  void _scheduleCloudUpload() {
    final authState = ref.read(authNotifierProvider);
    if (authState.isGuest) return;
    ref
        .read(cloudSyncProvider.notifier)
        .scheduleUpload(
          dataNotifier: ref.read(dataNotifierProvider.notifier),
          googleSignIn: ref.read(authServiceProvider).googleSignIn,
        );
  }

  void _checkCloudSyncOnResume(DataNotifier dataNotifier) {
    final authState = ref.read(authNotifierProvider);
    if (authState.isGuest) return;
    ref
        .read(cloudSyncProvider.notifier)
        .checkOnResume(
          dataNotifier: dataNotifier,
          googleSignIn: ref.read(authServiceProvider).googleSignIn,
        );
  }

  void _pushWidgetData() {
    final data = ref.read(dataNotifierProvider).valueOrNull;
    final path = ref.read(dataNotifierProvider.notifier).filePath;
    if (data == null || path == null) return;
    WidgetSyncService.instance.push(data, path).ignore();
  }

  /// Re-registers all habit reminders so they survive OS reboots and
  /// notification permission changes.
  Future<void> _rescheduleHabitReminders() async {
    final data = ref.read(dataNotifierProvider).valueOrNull;
    if (data == null) return;
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
