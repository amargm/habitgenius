import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/app_data.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/data_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/habit_helpers.dart';
import '../../core/services/permission_service.dart';
import '../../shared/widgets/empty_state_widget.dart';

// ── Home screen ───────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  // 5 staggered slots: greeting, ring-card, stats-row, quick-actions, insight
  static const int _slots = 5;
  late List<Animation<double>> _fadeSl;
  late List<Animation<Offset>> _slideSl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeSl = List.generate(_slots, (i) {
      final start = i * 0.12;
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(
            start,
            (start + 0.35).clamp(0, 1),
            curve: Curves.easeOut,
          ),
        ),
      );
    });

    _slideSl = List.generate(_slots, (i) {
      final start = i * 0.12;
      return Tween<Offset>(
        begin: const Offset(0, 0.14),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(
            start,
            (start + 0.35).clamp(0, 1),
            curve: Curves.easeOut,
          ),
        ),
      );
    });

    _ctrl.forward();

    // Ask for notification + exact-alarm permissions once, after the first
    // frame so the screen is visible when the rationale sheet appears.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Only prompt if not already granted (PermissionService checks first).
      final granted = await PermissionService.instance.notificationsGranted;
      if (!granted && mounted) {
        await PermissionService.instance.requestAllRequired(context);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _slot(int i, Widget child) => FadeTransition(
    opacity: _fadeSl[i],
    child: SlideTransition(position: _slideSl[i], child: child),
  );

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final dataAsync = ref.watch(dataNotifierProvider);

    return Scaffold(
      body: SafeArea(
        child: dataAsync.when(
          loading: () => const _Skeleton(),
          error:
              (e, _) => DataErrorWidget(
                error: e,
                onRetry: () => ref.read(dataNotifierProvider.notifier).reload(),
              ),
          data:
              (data) => _Body(
                data: data,
                auth: auth,
                slots: (i, child) => _slot(i, child),
              ),
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────

class _Body extends StatelessWidget {
  final AppData data;
  final AuthState auth;
  final Widget Function(int, Widget) slots;

  const _Body({required this.data, required this.auth, required this.slots});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayStr = HabitHelpers.todayStr();

    // ── Compute stats ──────────────────────────────────────
    final todayHabits = HabitHelpers.habitsForDate(data.habits, today);
    final doneCount =
        todayHabits
            .where(
              (h) => HabitHelpers.isCompletedOn(h, data.habitLogs, todayStr),
            )
            .length;
    final total = todayHabits.length;

    // Today's mood
    final todayMood = data.moods.where((m) => m.date == todayStr).firstOrNull;

    // Focus minutes this week (Mon–Sun)
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekFocusMinutes = data.focusSessions
        .where((s) {
          final d = DateTime.tryParse(s.startedAt);
          return d != null && !d.isBefore(weekStart);
        })
        .fold<int>(0, (sum, s) => sum + (s.actualDuration ~/ 60));

    // Active journal entries
    final journalCount = data.journal.length;

    // Best streak across all habits
    final bestStreak =
        data.habits.isEmpty
            ? 0
            : data.habits
                .map(
                  (h) => HabitHelpers.currentStreak(h, data.habitLogs, today),
                )
                .reduce(math.max);

    // Insight
    final insight = _buildInsight(
      doneCount,
      total,
      todayMood,
      weekFocusMinutes,
      bestStreak,
    );

    // User name
    final firstName =
        auth.user?.displayName?.split(' ').first ??
        (auth.isGuest ? 'there' : 'you');
    final initials =
        auth.user?.displayName != null
            ? auth.user!.displayName!
                .split(' ')
                .map((w) => w.isNotEmpty ? w[0] : '')
                .take(2)
                .join()
                .toUpperCase()
            : '?';

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Greeting ──────────────────────────────
                slots(
                  0,
                  _GreetingHeader(
                    greeting: _greeting(),
                    firstName: firstName,
                    initials: initials,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Today's progress ring ─────────────────
                slots(1, _TodayRingCard(done: doneCount, total: total)),
                const SizedBox(height: 16),

                // ── Quick stats ───────────────────────────
                slots(
                  2,
                  _QuickStatsRow(
                    moodEmoji: todayMood?.emoji,
                    focusMinutes: weekFocusMinutes,
                    journalCount: journalCount,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Quick actions ─────────────────────────
                slots(3, _QuickActionsGrid(tier: auth.tier)),
                const SizedBox(height: 20),

                // ── Insight card ──────────────────────────
                slots(4, _InsightCard(text: insight)),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String _buildInsight(
    int done,
    int total,
    dynamic mood,
    int focusMin,
    int streak,
  ) {
    if (total > 0 && done == total) {
      return '🎉 All habits done today — great consistency!';
    }
    if (streak > 7) {
      return '🔥 $streak-day streak! Keep the momentum going.';
    }
    if (focusMin >= 60) {
      return '⏱ ${focusMin}m of focus this week — you\'re in the zone.';
    }
    if (mood != null) {
      return '${mood.emoji} Mood logged — keeping track is half the battle.';
    }
    if (total > 0) {
      return '📋 $done of $total habits done today — stay on it!';
    }
    return '👋 Add your first habit to start building great routines.';
  }
}

// ── Greeting header ───────────────────────────────────────

class _GreetingHeader extends StatelessWidget {
  final String greeting;
  final String firstName;
  final String initials;

  const _GreetingHeader({
    required this.greeting,
    required this.firstName,
    required this.initials,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final now = DateTime.now();
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final dateLabel =
        '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, $firstName',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 26,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dateLabel,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => GoRouter.of(context).go(AppRoutes.settings),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primary, AppColors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Today's progress ring card ────────────────────────────

class _TodayRingCard extends StatelessWidget {
  final int done;
  final int total;

  const _TodayRingCard({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final progress = total == 0 ? 0.0 : done / total;
    final pct = (progress * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: CustomPaint(
              painter: _RingPainter(progress: progress, color: primary),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$pct%',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: primary,
                      ),
                    ),
                    const Text(
                      'today',
                      style: TextStyle(fontSize: 9, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  total == 0
                      ? 'No habits today'
                      : done == total
                      ? 'All done! 🎉'
                      : '$done of $total habits done',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  total == 0
                      ? 'Add habits to track your progress'
                      : done == total
                      ? 'Amazing consistency today!'
                      : '${total - done} habit${total - done == 1 ? '' : 's'} remaining',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: primary.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(primary),
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

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (size.width / 2) - 8;
    final stroke = 9.0;

    final trackPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = color.withValues(alpha: 0.12)
          ..strokeCap = StrokeCap.round;

    final arcPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = color
          ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(cx, cy), radius, trackPaint);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

// ── Quick stats row ───────────────────────────────────────

class _QuickStatsRow extends StatelessWidget {
  final String? moodEmoji;
  final int focusMinutes;
  final int journalCount;

  const _QuickStatsRow({
    required this.moodEmoji,
    required this.focusMinutes,
    required this.journalCount,
  });

  @override
  Widget build(BuildContext context) {
    final focusLabel =
        focusMinutes >= 60
            ? '${(focusMinutes / 60).toStringAsFixed(1)}h'
            : '${focusMinutes}m';

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.sentiment_satisfied_alt_rounded,
            label: 'Mood',
            value: moodEmoji ?? '--',
            isEmoji: moodEmoji != null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.timer_rounded,
            label: 'Focus (wk)',
            value: focusMinutes == 0 ? '--' : focusLabel,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.menu_book_rounded,
            label: 'Journal',
            value: journalCount == 0 ? '--' : '$journalCount',
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isEmoji;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.isEmoji = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: primary),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: isEmoji ? 22 : 17,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Quick actions grid ────────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  final UserTier tier;
  const _QuickActionsGrid({required this.tier});

  @override
  Widget build(BuildContext context) {
    final actions = _buildActions(tier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick actions',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.1,
          ),
          itemBuilder: (ctx, i) => _ActionTile(item: actions[i]),
        ),
      ],
    );
  }

  List<_ActionItem> _buildActions(UserTier tier) {
    return [
      _ActionItem(
        label: 'Add habit',
        icon: Icons.add_circle_outline_rounded,
        route: AppRoutes.addHabit,
        color: const Color(0xFF6C5CE7),
      ),
      _ActionItem(
        label: 'Log mood',
        icon: Icons.sentiment_satisfied_alt_rounded,
        route: AppRoutes.mood,
        color: const Color(0xFFFF7675),
        hidden: tier == UserTier.guest,
      ),
      _ActionItem(
        label: 'Start focus',
        icon: Icons.timer_rounded,
        route: AppRoutes.focus,
        color: const Color(0xFF00B894),
      ),
      _ActionItem(
        label: 'Journal',
        icon: Icons.menu_book_rounded,
        route: AppRoutes.journal,
        color: const Color(0xFFE17055),
      ),
      _ActionItem(
        label: 'Expenses',
        icon: Icons.account_balance_wallet_rounded,
        route: AppRoutes.expenses,
        color: const Color(0xFF0984E3),
        hidden: tier == UserTier.guest,
      ),
      _ActionItem(
        label: 'Settings',
        icon: Icons.settings_rounded,
        route: AppRoutes.settings,
        color: AppColors.textSecondary,
      ),
    ].where((a) => !a.hidden).toList();
  }
}

class _ActionItem {
  final String label;
  final IconData icon;
  final String route;
  final Color color;
  final bool hidden;

  const _ActionItem({
    required this.label,
    required this.icon,
    required this.route,
    required this.color,
    this.hidden = false,
  });
}

class _ActionTile extends StatelessWidget {
  final _ActionItem item;
  const _ActionTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.go(item.route);
      },
      child: Container(
        decoration: BoxDecoration(
          color: item.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: item.color.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, color: item.color, size: 26),
            const SizedBox(height: 6),
            Text(
              item.label,
              style: TextStyle(
                color: item.color,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Insight card ──────────────────────────────────────────

class _InsightCard extends StatelessWidget {
  final String text;
  const _InsightCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary.withValues(alpha: 0.12),
            AppColors.accent.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Skeleton loader ───────────────────────────────────────

class _Skeleton extends StatefulWidget {
  const _Skeleton();

  @override
  State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, __) {
        final opacity = 0.04 + _shimmer.value * 0.08;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _shimmerBox(height: 40, opacity: opacity),
              const SizedBox(height: 24),
              _shimmerBox(height: 120, opacity: opacity, radius: 24),
              const SizedBox(height: 16),
              Row(
                children: List.generate(
                  3,
                  (_) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _shimmerBox(
                        height: 80,
                        opacity: opacity,
                        radius: 16,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _shimmerBox(height: 180, opacity: opacity, radius: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _shimmerBox({
    required double height,
    required double opacity,
    double radius = 12,
  }) => Container(
    height: height,
    margin: const EdgeInsets.only(bottom: 0),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}
