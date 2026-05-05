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
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  // Exit animation — fades the whole screen out before navigation.
  late AnimationController _exitController;
  late Animation<double> _exitFade;

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

    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInCubic),
    );

    _controller.forward();
    _init();
  }

  Future<void> _init() async {
    try {
      // Run the minimum splash delay and session restore concurrently.
      await Future.wait([
        Future<void>.delayed(const Duration(milliseconds: 1800)),
        ref.read(authNotifierProvider.notifier).restore(),
      ]);

      if (!mounted) return;

      final auth = ref.read(authNotifierProvider);

      // No session at all → show welcome screen.
      if (auth.user == null) {
        await _goFaded(AppRoutes.welcome);
        return;
      }

      // Guest session → load from internal storage and go home.
      if (auth.isGuest) {
        final notifier = ref.read(dataNotifierProvider.notifier);
        await notifier.load(isGuest: true, customDir: null);
        await SyncService.instance.seedTimestamp(notifier.filePath);
        await _goFaded(AppRoutes.home);
        return;
      }

      // Registered user → always use internal app storage.
      final notifier = ref.read(dataNotifierProvider.notifier);
      await notifier.load(isGuest: false, customDir: null);
      await SyncService.instance.seedTimestamp(notifier.filePath);

      if (!mounted) return;
      final prefs = ref.read(sharedPreferencesProvider);
      final hasSeenOnboarding =
          prefs.getBool(PrefKeys.hasSeenOnboarding) ?? false;
      await _goFaded(hasSeenOnboarding ? AppRoutes.home : AppRoutes.onboarding);
    } catch (e, st) {
      debugPrint('[SplashScreen] Init error: $e\n$st');
      // Any unhandled exception during startup falls back to the welcome
      // screen so the user is never permanently stuck on the splash.
      await _goFaded(AppRoutes.welcome);
    }
  }

  /// Fades the splash out then navigates to [route].
  Future<void> _goFaded(String route) async {
    if (!mounted) return;
    await _exitController.forward();
    if (mounted) context.go(route);
  }

  @override
  void dispose() {
    _controller.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: FadeTransition(
        opacity: _exitFade,
        child: Center(
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
                      color: primary,
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
      ),
    );
  }
}
