import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers/data_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/sync_service.dart';
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
    });
  }

  @override
  void dispose() {
    _saveErrorSub?.cancel();
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
