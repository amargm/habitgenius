import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../theme/app_theme_extension.dart';
import '../providers/auth_provider.dart';
import '../router/app_router.dart';

/// The main navigation shell that wraps all tab screens with the
/// floating bottom navigation bar that matches the prototype design.
class MainShell extends ConsumerWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  static const _tabs = [
    _TabItem(
      label: 'Home',
      icon: Icons.home_rounded,
      route: AppRoutes.home,
      minTier: UserTier.guest,
    ),
    _TabItem(
      label: 'Habits',
      icon: Icons.check_circle_outline_rounded,
      route: AppRoutes.habits,
      minTier: UserTier.guest,
    ),
    _TabItem(
      label: 'Mood',
      icon: Icons.sentiment_satisfied_alt_rounded,
      route: AppRoutes.mood,
      minTier: UserTier.registered,
    ),
    _TabItem(
      label: 'Focus',
      icon: Icons.timer_rounded,
      route: AppRoutes.focus,
      minTier: UserTier.guest,
    ),
    _TabItem(
      label: 'Journal',
      icon: Icons.menu_book_rounded,
      route: AppRoutes.journal,
      minTier: UserTier.guest,
    ),
    _TabItem(
      label: 'Money',
      icon: Icons.account_balance_wallet_rounded,
      route: AppRoutes.expenses,
      minTier: UserTier.registered,
    ),
  ];

  String _currentRoute(BuildContext context) {
    return GoRouterState.of(context).matchedLocation;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTier = ref.watch(authNotifierProvider).tier;
    final currentRoute = _currentRoute(context);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    final visibleTabs =
        _tabs
            .where((t) => _tierIndex(currentTier) >= _tierIndex(t.minTier))
            .toList();

    return Scaffold(
      body: child,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: context.appColors.bgCard,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 40,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children:
                  visibleTabs.map((tab) {
                    final isActive = currentRoute == tab.route;
                    return GestureDetector(
                      onTap: () => context.go(tab.route),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeInOutCubic,
                        padding: EdgeInsets.symmetric(
                          horizontal: isActive ? 18 : 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isActive ? primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow:
                              isActive
                                  ? [
                                    BoxShadow(
                                      color: primary.withValues(alpha: 0.35),
                                      blurRadius: 12,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                  : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              tab.icon,
                              size: 22,
                              color:
                                  isActive
                                      ? Colors.white
                                      : context.appColors.textMuted,
                            ),
                            if (isActive) ...[
                              const SizedBox(width: 7),
                              Text(
                                tab.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  int _tierIndex(UserTier tier) {
    switch (tier) {
      case UserTier.guest:
        return 0;
      case UserTier.registered:
        return 1;
      case UserTier.pro:
        return 2;
    }
  }
}

class _TabItem {
  final String label;
  final IconData icon;
  final String route;
  final UserTier minTier;

  const _TabItem({
    required this.label,
    required this.icon,
    required this.route,
    required this.minTier,
  });
}
