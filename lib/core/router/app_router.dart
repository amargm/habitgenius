import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/auth/welcome_screen.dart';
import '../../features/auth/file_setup_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/habits/habits_screen.dart';
import '../../features/habits/add_habit_screen.dart';
import '../../features/mood/mood_screen.dart';
import '../../features/focus/focus_screen.dart';
import '../../features/journal/journal_screen.dart';
import '../../features/expenses/expenses_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../shell/main_shell.dart';

// ── Route names ───────────────────────────────────────────
class AppRoutes {
  static const splash = '/';
  static const welcome = '/welcome';
  static const fileSetup = '/file-setup';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const habits = '/habits';
  static const addHabit = '/habits/add';
  static const mood = '/mood';
  static const focus = '/focus';
  static const journal = '/journal';
  static const expenses = '/expenses';
  static const settings = '/settings';
}

// ── Slide transition helper ───────────────────────────────

CustomTransitionPage<void> _slidePage(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    transitionsBuilder: (ctx, animation, secondaryAnimation, child) {
      final tween = Tween(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeInOutCubic));
      final secondary = Tween(
        begin: Offset.zero,
        end: const Offset(-0.3, 0.0),
      ).chain(CurveTween(curve: Curves.easeInOutCubic));

      return SlideTransition(
        position: animation.drive(tween),
        child: SlideTransition(
          position: secondaryAnimation.drive(secondary),
          child: child,
        ),
      );
    },
  );
}

// ── Router ────────────────────────────────────────────────
final appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.welcome,
      pageBuilder:
          (context, state) => _slidePage(context, state, const WelcomeScreen()),
    ),
    GoRoute(
      path: AppRoutes.fileSetup,
      pageBuilder:
          (context, state) =>
              _slidePage(context, state, const FileSetupScreen()),
    ),
    GoRoute(
      path: AppRoutes.onboarding,
      pageBuilder:
          (context, state) =>
              _slidePage(context, state, const OnboardingScreen()),
    ),
    GoRoute(
      path: AppRoutes.settings,
      pageBuilder:
          (context, state) =>
              _slidePage(context, state, const SettingsScreen()),
    ),
    GoRoute(
      path: AppRoutes.addHabit,
      pageBuilder:
          (context, state) =>
              _slidePage(context, state, const AddHabitScreen()),
    ),
    // ── Main shell with bottom nav ─────────────────────────
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.home,
          pageBuilder:
              (context, state) => const NoTransitionPage(child: HomeScreen()),
        ),
        GoRoute(
          path: AppRoutes.habits,
          pageBuilder:
              (context, state) => const NoTransitionPage(child: HabitsScreen()),
        ),
        GoRoute(
          path: AppRoutes.mood,
          pageBuilder:
              (context, state) => const NoTransitionPage(child: MoodScreen()),
        ),
        GoRoute(
          path: AppRoutes.focus,
          pageBuilder:
              (context, state) => const NoTransitionPage(child: FocusScreen()),
        ),
        GoRoute(
          path: AppRoutes.journal,
          pageBuilder:
              (context, state) =>
                  const NoTransitionPage(child: JournalScreen()),
        ),
        GoRoute(
          path: AppRoutes.expenses,
          pageBuilder:
              (context, state) =>
                  const NoTransitionPage(child: ExpensesScreen()),
        ),
      ],
    ),
  ],
);
