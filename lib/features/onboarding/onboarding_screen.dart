import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/data_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/services/permission_service.dart';

/// 3-slide onboarding shown once to new registered/pro users.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _slides = [
    _Slide(
      icon: Icons.bolt_rounded,
      title: 'Everything in one app',
      body:
          'Habits, mood, focus sessions, journal and expenses — all tracked in a single beautiful app.',
    ),
    _Slide(
      icon: Icons.lock_outlined,
      title: 'Your data stays on device',
      body:
          'All habits, journal entries, mood logs and expenses are stored in a local file on your device.\n\n'
          'Sign-in uses Google to keep your account secure. Your app data is never analysed or sold.',
    ),
    _Slide(
      icon: Icons.workspace_premium_rounded,
      title: 'Free & Pro plans',
      body:
          'Start free with core features. Upgrade to Pro for unlimited habits, themes, and more.',
    ),
    _Slide(
      icon: Icons.notifications_active_rounded,
      title: 'Stay on track',
      body:
          'Enable reminders to get a daily nudge for your habits.\n\n'
          'You can change this at any time in Settings.',
    ),
  ];

  Future<void> _finish() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(PrefKeys.hasSeenOnboarding, true);
    // Load data for the newly signed-in registered user so the home screen
    // is fully populated immediately (fixes first-login skeleton issue).
    await ref
        .read(dataNotifierProvider.notifier)
        .load(isGuest: false, customDir: null);
    if (!mounted) return;
    // Request notification + exact-alarm permissions with a Play Store-compliant
    // contextual rationale (shown after the "Stay on track" slide).
    await PermissionService.instance.requestAllRequired(context);
    // Mark that we've asked so the home-screen fallback doesn't ask again.
    await prefs.setBool(PrefKeys.hasAskedNotificationPermission, true);
    if (mounted) context.go(AppRoutes.home);
  }

  void _next() {
    if (_page < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
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
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text(
                  'Skip',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _slides.length,
                itemBuilder: (context, i) => _SlidePage(slide: _slides[i]),
              ),
            ),
            // Dots + button
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _page ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page ? primary : AppColors.textMuted,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _next,
                      child: Text(
                        _page == _slides.length - 1 ? 'Get Started' : 'Next',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlidePage extends StatelessWidget {
  final _Slide slide;
  const _SlidePage({required this.slide});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(slide.icon, size: 48, color: primary),
          ),
          const SizedBox(height: 32),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.6, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _Slide {
  final IconData icon;
  final String title;
  final String body;
  const _Slide({required this.icon, required this.title, required this.body});
}
