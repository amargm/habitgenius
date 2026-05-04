import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers/data_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/sync_service.dart';
import 'core/theme/theme_provider.dart';

class HabitGeniusApp extends ConsumerStatefulWidget {
  const HabitGeniusApp({super.key});

  @override
  ConsumerState<HabitGeniusApp> createState() => _HabitGeniusAppState();
}

class _HabitGeniusAppState extends ConsumerState<HabitGeniusApp>
    with WidgetsBindingObserver {
  StreamSubscription<String>? _saveErrorSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Subscribe to disk-write failures so the user is always told when a
    // change couldn't be persisted (instead of silent data loss).
    _saveErrorSub = ref.read(dataNotifierProvider.notifier).saveErrors.listen((
      message,
    ) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red[700],
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }

  @override
  void dispose() {
    _saveErrorSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
