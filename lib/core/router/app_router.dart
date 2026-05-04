import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/auth/welcome_screen.dart';
import '../../features/auth/file_setup_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/habits/habits_screen.dart';
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
  static const mood = '/mood';
  static const focus = '/focus';
  static const journal = '/journal';
  static const expenses = '/expenses';
  static const settings = '/settings';
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
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.fileSetup,
      builder: (context, state) => const FileSetupScreen(),
    ),
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (context, state) => const SettingsScreen(),
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
