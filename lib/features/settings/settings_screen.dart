import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/data_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/services/purchase_service.dart';
import '../../core/theme/theme_provider.dart';
import 'package:go_router/go_router.dart';

// ── Settings screen ───────────────────────────────────────

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final themeState = ref.watch(themeProvider);
    final tier = authState.tier;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            Text(
              'Settings',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),

            // ── Profile card ──────────────────────────────
            _ProfileCard(authState: authState, tier: tier),
            const SizedBox(height: 24),

            // ── Pro upgrade ───────────────────────────────
            if (tier != UserTier.pro) ...[
              _ProCard(tier: tier),
              const SizedBox(height: 24),
            ],

            // ── Appearance ────────────────────────────────
            _SectionHeader(label: 'Appearance'),
            const SizedBox(height: 12),
            _ThemeModeRow(themeState: themeState),
            const SizedBox(height: 12),
            _ThemeColorGrid(themeState: themeState, tier: tier),
            const SizedBox(height: 24),

            // ── Data ──────────────────────────────────────
            _SectionHeader(label: 'Data'),
            const SizedBox(height: 12),
            _DataSection(tier: tier),
            const SizedBox(height: 24),

            // ── Account ───────────────────────────────────
            _SectionHeader(label: 'Account'),
            const SizedBox(height: 12),
            _AccountSection(authState: authState),
            const SizedBox(height: 40),

            // Version
            Center(
              child: Text(
                'HabitGenius · v1.0.0',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Profile card ──────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final AuthState authState;
  final UserTier tier;

  const _ProfileCard({required this.authState, required this.tier});

  @override
  Widget build(BuildContext context) {
    final user = authState.user;
    final initials =
        user?.displayName != null
            ? user!.displayName!
                .split(' ')
                .map((w) => w.isNotEmpty ? w[0] : '')
                .take(2)
                .join()
                .toUpperCase()
            : '?';

    final tierLabel = switch (tier) {
      UserTier.guest => 'Guest',
      UserTier.registered => 'Free',
      UserTier.pro => 'Pro ⭐',
    };

    final tierColor = switch (tier) {
      UserTier.pro => const Color(0xFFFDCB6E),
      UserTier.registered => Theme.of(context).colorScheme.primary,
      UserTier.guest => AppColors.textSecondary,
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ??
                      (authState.isGuest ? 'Guest User' : 'User'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                if (user?.email != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    user!.email!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tierLabel,
                    style: TextStyle(
                      color: tierColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pro upgrade card ──────────────────────────────────────

class _ProCard extends ConsumerStatefulWidget {
  final UserTier tier;
  const _ProCard({required this.tier});

  @override
  ConsumerState<_ProCard> createState() => _ProCardState();
}

class _ProCardState extends ConsumerState<_ProCard> {
  bool _loading = false;
  String? _error;

  Future<void> _onUpgrade() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final svc = ref.read(purchaseServiceProvider);
    final result = await svc.buyPro();
    if (!mounted) return;

    switch (result) {
      case PurchaseResult.success:
      case PurchaseResult.alreadyOwned:
        ref.read(authNotifierProvider.notifier).upgradeToPro();
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Welcome to Pro! ⭐')));
      case PurchaseResult.cancelled:
        break;
      case PurchaseResult.error:
        setState(() => _error = svc.error ?? 'Purchase failed');
    }
    setState(() => _loading = false);
  }

  Future<void> _onRestore() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(purchaseServiceProvider).restore();
      // Give the purchase stream up to 3 seconds to deliver the result.
      await Future.delayed(const Duration(seconds: 3));
    } catch (_) {}
    if (!mounted) return;
    final isPro = ref.read(purchaseServiceProvider).isPro;
    if (isPro) {
      ref.read(authNotifierProvider.notifier).upgradeToPro();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pro restored! ⭐')));
    } else {
      setState(() => _error = 'No previous Pro purchase found');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    const gold = Color(0xFFFDCB6E);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            gold.withValues(alpha: 0.12),
            primary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('⭐', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              const Text(
                'Upgrade to Pro',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...[
            '✓ Unlimited habits',
            '✓ Unlimited journal entries',
            '✓ Unlimited transactions & accounts',
            '✓ 4 exclusive Pro theme colors',
            '✓ Custom focus durations',
            '✓ One-time payment, forever',
          ].map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                b,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _loading ? null : _onUpgrade,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      _loading
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                          : const Text(
                            'Upgrade to Pro',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: _loading ? null : _onRestore,
                child: const Text(
                  'Restore',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Theme mode row ────────────────────────────────────────

class _ThemeModeRow extends ConsumerWidget {
  final ThemeState themeState;
  const _ThemeModeRow({required this.themeState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const modes = [
      (ThemeMode.dark, Icons.dark_mode_rounded, 'Dark'),
      (ThemeMode.light, Icons.light_mode_rounded, 'Light'),
      (ThemeMode.system, Icons.brightness_auto_rounded, 'System'),
    ];
    final primary = Theme.of(context).colorScheme.primary;

    return Row(
      children:
          modes.map((m) {
            final sel = themeState.themeMode == m.$1;
            return Expanded(
              child: GestureDetector(
                onTap:
                    () => ref.read(themeProvider.notifier).setThemeMode(m.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color:
                        sel
                            ? primary.withValues(alpha: 0.15)
                            : AppColors.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: sel ? primary : AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        m.$2,
                        size: 20,
                        color: sel ? primary : AppColors.textSecondary,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        m.$3,
                        style: TextStyle(
                          fontSize: 11,
                          color: sel ? primary : AppColors.textSecondary,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }
}

// ── Theme color grid ──────────────────────────────────────

class _ThemeColorGrid extends ConsumerWidget {
  final ThemeState themeState;
  final UserTier tier;

  const _ThemeColorGrid({required this.themeState, required this.tier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Accent color',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children:
                AppColors.themeColors.map((tc) {
                  final locked =
                      tc.requiredTier == UserTier.pro && tier != UserTier.pro;
                  final sel = themeState.themeColor.id == tc.id;

                  return GestureDetector(
                    onTap: () {
                      if (locked) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Upgrade to Pro to unlock this color',
                            ),
                          ),
                        );
                        return;
                      }
                      ref.read(themeProvider.notifier).setThemeColor(tc);
                    },
                    child: Stack(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color:
                                locked
                                    ? tc.primary.withValues(alpha: 0.3)
                                    : tc.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: sel ? Colors.white : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow:
                                sel
                                    ? [
                                      BoxShadow(
                                        color: tc.primary.withValues(
                                          alpha: 0.5,
                                        ),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                    : null,
                          ),
                        ),
                        if (locked)
                          const Positioned.fill(
                            child: Center(
                              child: Icon(
                                Icons.lock_rounded,
                                size: 14,
                                color: Colors.white60,
                              ),
                            ),
                          ),
                        if (sel && !locked)
                          const Positioned.fill(
                            child: Center(
                              child: Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Data section ──────────────────────────────────────────

class _DataSection extends ConsumerWidget {
  final UserTier tier;
  const _DataSection({required this.tier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appData = ref.watch(appDataProvider);
    final habitCount = appData.habits.length;
    final entryCount = appData.journal.length;
    final txCount = appData.transactions.length;
    final moodCount = appData.moods.length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _DataRow(label: 'Habits', value: '$habitCount'),
          _DataRow(label: 'Journal entries', value: '$entryCount'),
          _DataRow(label: 'Transactions', value: '$txCount'),
          _DataRow(label: 'Mood logs', value: '$moodCount'),
          if (tier != UserTier.guest)
            _DataRow(label: 'Storage', value: 'Local JSON file', isLast: true),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _DataRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 14)),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
      if (!isLast) const Divider(height: 1, indent: 16, endIndent: 16),
    ],
  );
}

// ── Account section ───────────────────────────────────────

class _AccountSection extends ConsumerWidget {
  final AuthState authState;
  const _AccountSection({required this.authState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          if (authState.isGuest) ...[
            _ActionRow(
              icon: Icons.login_rounded,
              label: 'Sign in with Google',
              onTap: () => context.go(AppRoutes.welcome),
            ),
          ] else ...[
            _ActionRow(
              icon: Icons.logout_rounded,
              label: 'Sign out',
              color: AppColors.danger,
              onTap: () => _confirmSignOut(context, ref),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Sign out?'),
            content: const Text(
              'Your data file will remain intact. You can sign back in any time.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sign out'),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      await ref.read(authNotifierProvider.notifier).signOut();
      if (context.mounted) context.go(AppRoutes.welcome);
    }
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: color, size: 22),
    title: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w500, fontSize: 15),
    ),
    trailing: const Icon(
      Icons.chevron_right_rounded,
      color: AppColors.textMuted,
      size: 20,
    ),
    onTap: onTap,
  );
}

// ── Section header ────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: const TextStyle(
      color: AppColors.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.0,
    ),
  );
}
