import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/data_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/services/sync_service.dart';

/// Splash screen: animates logo, restores auth session, then routes to the
/// correct destination based on session state.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _scaleAnim = Tween<double>(
      begin: 0.85,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
    _init();
  }

  Future<void> _init() async {
    // Run the minimum splash delay and session restore concurrently.
    await Future.wait([
      Future<void>.delayed(const Duration(milliseconds: 1800)),
      ref.read(authNotifierProvider.notifier).restore(),
    ]);

    if (!mounted) return;

    final auth = ref.read(authNotifierProvider);
    final prefs = ref.read(sharedPreferencesProvider);

    // No session at all → show welcome screen.
    if (auth.user == null) {
      context.go(AppRoutes.welcome);
      return;
    }

    // Guest session → load from internal storage and go home.
    if (auth.isGuest) {
      final notifier = ref.read(dataNotifierProvider.notifier);
      await notifier.load(isGuest: true, customDir: null);
      await SyncService.instance.seedTimestamp(notifier.filePath);
      if (mounted) context.go(AppRoutes.home);
      return;
    }

    // Registered user: check whether the data folder has been configured.
    final dataDir = prefs.getString(PrefKeys.dataFilePath);
    if (dataDir == null || dataDir.isEmpty) {
      if (mounted) context.go(AppRoutes.fileSetup);
      return;
    }

    // Load data then decide whether to show onboarding.
    final notifier = ref.read(dataNotifierProvider.notifier);
    await notifier.load(isGuest: false, customDir: dataDir);
    await SyncService.instance.seedTimestamp(notifier.filePath);

    if (!mounted) return;
    final hasSeenOnboarding =
        prefs.getBool(PrefKeys.hasSeenOnboarding) ?? false;
    context.go(hasSeenOnboarding ? AppRoutes.home : AppRoutes.onboarding);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [primary, const Color(0xFF00CEC9)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.4),
                        blurRadius: 32,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'HabitGenius',
                  style: Theme.of(
                    context,
                  ).textTheme.displayLarge?.copyWith(letterSpacing: -1),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your life, organised.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
