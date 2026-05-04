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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
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
