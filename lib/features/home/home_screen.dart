import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme_extension.dart';
import '../../core/models/app_data.dart';
import '../../core/models/mood.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/data_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/habit_helpers.dart';
import '../../core/services/permission_service.dart';
import '../../shared/widgets/empty_state_widget.dart';

// ── Filter period ─────────────────────────────────────────

enum _HomeFilter { today, week, month }

// ── Stat card data ─────────────────────────────────────────

class _CardData {
  final String value;
  final String sub;
  final double progress; // 0.0–1.0 for mini progress bar
  final bool isEmoji;
  final bool isActive;

  const _CardData({
    required this.value,
    required this.sub,
    this.progress = 0.0,
    this.isEmoji = false,
    this.isActive = false,
  });
}

// ── Screen ────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final already = await PermissionService.instance.notificationsGranted;
      if (already) return;
      final data = ref.read(appDataProvider);
      if (data.habits.isNotEmpty && mounted) {
        await PermissionService.instance.requestAllRequired(context);
      }
    });
  }

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
          data: (data) => _Body(data: data, auth: auth),
        ),
      ),
    );
  }
}

// ── Body (holds filter state) ─────────────────────────────

class _Body extends StatefulWidget {
  final AppData data;
  final AuthState auth;

  const _Body({required this.data, required this.auth});

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  _HomeFilter _filter = _HomeFilter.today;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final auth = widget.auth;
    final primary = Theme.of(context).colorScheme.primary;

    final today = DateTime.now();
    final todayStr = HabitHelpers.todayStr();

    // ── User display info ─────────────────────────────────
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
    final hour = today.hour;
    final greeting =
        hour < 12
            ? 'Good morning'
            : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    // ── Period boundaries ─────────────────────────────────
    final activeHabits =
        data.habits.where((h) => h.archivedAt == null).toList();
    final weekStart = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: today.weekday - 1));
    final monthStart = DateTime(today.year, today.month, 1);

    // ── Today's habits ────────────────────────────────────
    final todayHabits = HabitHelpers.habitsForDate(activeHabits, today);
    final doneToday =
        todayHabits
            .where(
              (h) => HabitHelpers.isCompletedOn(h, data.habitLogs, todayStr),
            )
            .length;

    // ── Focus minutes helper ──────────────────────────────
    int focusFrom(DateTime from) => data.focusSessions
        .where((s) {
          final d = DateTime.tryParse(s.startedAt)?.toLocal();
          return d != null && !d.isBefore(from);
        })
        .fold(0, (sum, s) => sum + (s.actualDuration ~/ 60));

    final todayFocusMin = data.focusSessions
        .where((s) {
          final d = DateTime.tryParse(s.startedAt)?.toLocal();
          return d != null &&
              d.year == today.year &&
              d.month == today.month &&
              d.day == today.day;
        })
        .fold<int>(0, (sum, s) => sum + (s.actualDuration ~/ 60));
    final weekFocusMin = focusFrom(weekStart);
    final monthFocusMin = focusFrom(monthStart);

    // ── Mood helpers ──────────────────────────────────────
    final todayMood = data.moods.where((m) => m.date == todayStr).firstOrNull;

    List<Mood> moodsFrom(DateTime from) =>
        data.moods.where((m) {
          final d = DateTime.tryParse(m.date);
          return d != null && !d.isBefore(from);
        }).toList();

    final weekMoods = moodsFrom(weekStart);
    final monthMoods = moodsFrom(monthStart);

    // ── Journal helpers ───────────────────────────────────
    int journalFrom(DateTime from) =>
        data.journal.where((e) {
          final d = DateTime.tryParse(e.createdAt)?.toLocal();
          return d != null && !d.isBefore(from);
        }).length;

    final journalTotal = data.journal.length;
    final weekJournalCount = journalFrom(weekStart);
    final monthJournalCount = journalFrom(monthStart);

    // ── Best streak ───────────────────────────────────────
    final bestStreak =
        activeHabits.isEmpty
            ? 0
            : activeHabits
                .map(
                  (h) => HabitHelpers.currentStreak(h, data.habitLogs, today),
                )
                .reduce(math.max);

    // ── Expenses count ────────────────────────────────────
    final monthStr = '${today.year}-${today.month.toString().padLeft(2, '0')}';
    final monthTxCount =
        data.transactions.where((t) => t.date.startsWith(monthStr)).length;

    // ── Per-filter card data ──────────────────────────────
    late final _CardData habitsCard;
    late final _CardData focusCard;
    late final _CardData moodCard;
    late final _CardData journalCard;

    switch (_filter) {
      case _HomeFilter.today:
        habitsCard = _CardData(
          value:
              todayHabits.isEmpty ? '--' : '$doneToday / ${todayHabits.length}',
          sub:
              todayHabits.isEmpty
                  ? 'No habits today'
                  : doneToday == todayHabits.length
                  ? 'All done! 🎉'
                  : '${todayHabits.length - doneToday} remaining',
          progress: todayHabits.isEmpty ? 0.0 : doneToday / todayHabits.length,
          isActive: doneToday > 0,
        );
        focusCard = _CardData(
          value: todayFocusMin == 0 ? '--' : '${todayFocusMin}m',
          sub: todayFocusMin == 0 ? 'Not started' : 'focused today',
          isActive: todayFocusMin > 0,
        );
        moodCard = _CardData(
          value: todayMood?.emoji ?? '--',
          sub: todayMood != null ? _moodLabel(todayMood.level) : 'Not logged',
          isEmoji: todayMood != null,
          isActive: todayMood != null,
        );
        journalCard = _CardData(
          value: '$journalTotal',
          sub: journalTotal == 0 ? 'No entries yet' : 'total entries',
          isActive: journalTotal > 0,
        );

      case _HomeFilter.week:
        habitsCard = _CardData(
          value: bestStreak > 0 ? '🔥 $bestStreak' : '--',
          sub: bestStreak > 0 ? 'day streak' : 'Start a streak!',
          progress: bestStreak > 0 ? (bestStreak / 7.0).clamp(0.0, 1.0) : 0.0,
          isEmoji: bestStreak > 0,
          isActive: bestStreak > 0,
        );
        final wFocusLabel =
            weekFocusMin >= 60
                ? '${(weekFocusMin / 60).toStringAsFixed(1)}h'
                : '${weekFocusMin}m';
        focusCard = _CardData(
          value: weekFocusMin == 0 ? '--' : wFocusLabel,
          sub: weekFocusMin == 0 ? 'No sessions' : 'this week',
          isActive: weekFocusMin > 0,
        );
        final avgWkLevel =
            weekMoods.isEmpty
                ? null
                : weekMoods.map((m) => m.level).reduce((a, b) => a + b) /
                    weekMoods.length;
        moodCard = _CardData(
          value: avgWkLevel == null ? '--' : _moodEmoji(avgWkLevel.round()),
          sub: weekMoods.isEmpty ? 'No logs' : 'avg · ${weekMoods.length} days',
          isEmoji: avgWkLevel != null,
          isActive: weekMoods.isNotEmpty,
        );
        journalCard = _CardData(
          value: '$weekJournalCount',
          sub: weekJournalCount == 0 ? 'No entries' : 'this week',
          isActive: weekJournalCount > 0,
        );

      case _HomeFilter.month:
        habitsCard = _CardData(
          value: '${activeHabits.length}',
          sub:
              activeHabits.isEmpty
                  ? 'No habits'
                  : '${activeHabits.length} active',
          progress: (activeHabits.length / 5.0).clamp(0.0, 1.0),
          isActive: activeHabits.isNotEmpty,
        );
        final mFocusLabel =
            monthFocusMin >= 60
                ? '${(monthFocusMin / 60).toStringAsFixed(1)}h'
                : '${monthFocusMin}m';
        focusCard = _CardData(
          value: monthFocusMin == 0 ? '--' : mFocusLabel,
          sub: monthFocusMin == 0 ? 'No sessions' : 'this month',
          isActive: monthFocusMin > 0,
        );
        final posPct =
            monthMoods.isEmpty
                ? null
                : (monthMoods.where((m) => m.level >= 4).length /
                        monthMoods.length *
                        100)
                    .round();
        moodCard = _CardData(
          value: posPct == null ? '--' : '$posPct%',
          sub: monthMoods.isEmpty ? 'No logs' : 'positive days',
          isActive: monthMoods.isNotEmpty,
        );
        journalCard = _CardData(
          value: '$monthJournalCount',
          sub: monthJournalCount == 0 ? 'No entries' : 'this month',
          isActive: monthJournalCount > 0,
        );
    }

    final insight = _buildInsight(
      doneToday,
      todayHabits.length,
      todayMood,
      weekFocusMin,
      bestStreak,
    );

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ────────────────────────────────
                _Header(
                  greeting: greeting,
                  firstName: firstName,
                  initials: initials,
                  primary: primary,
                  onSettings: () => context.push(AppRoutes.settings),
                ),
                const SizedBox(height: 24),

                // ── Filter chips ──────────────────────────
                _FilterChips(
                  filter: _filter,
                  onChanged: (f) {
                    HapticFeedback.selectionClick();
                    setState(() => _filter = f);
                  },
                ),
                const SizedBox(height: 24),

                // ── Progress banner ───────────────────────
                _ProgressBanner(
                  done: doneToday,
                  total: todayHabits.length,
                  insight: insight,
                  primary: primary,
                  onTap: () => context.go(AppRoutes.habits),
                ),
                const SizedBox(height: 28),

                // ── Pinned section ────────────────────────
                const _SectionHeader(label: 'Pinned'),
                const SizedBox(height: 14),
                _PinnedGrid(
                  habitsCard: habitsCard,
                  focusCard: focusCard,
                  moodCard: moodCard,
                  journalCard: journalCard,
                  tier: auth.tier,
                  primary: primary,
                ),
                const SizedBox(height: 28),

                // ── All features section ──────────────────
                const _SectionHeader(label: 'All Features'),
                const SizedBox(height: 14),
                _FeaturesSection(
                  tier: auth.tier,
                  monthTxCount: monthTxCount,
                  accountCount: data.accounts.length,
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _moodLabel(int level) {
    const labels = ['Awful', 'Bad', 'Okay', 'Good', 'Great'];
    return labels[(level - 1).clamp(0, 4)];
  }

  static String _moodEmoji(int level) {
    const emojis = ['😣', '😔', '😐', '😊', '🤩'];
    return emojis[(level - 1).clamp(0, 4)];
  }

  static String _buildInsight(
    int done,
    int total,
    Mood? mood,
    int focusMin,
    int streak,
  ) {
    if (total > 0 && done == total) return 'All habits done today!';
    if (streak > 7) return '$streak-day streak — keep the momentum.';
    if (focusMin >= 60) return '${focusMin}m of focus this week.';
    if (mood != null) return 'Mood logged — keep tracking.';
    if (total > 0) return '$done of $total habits done today.';
    return 'Add your first habit to start building routines.';
  }
}

// ── Header ────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String greeting;
  final String firstName;
  final String initials;
  final Color primary;
  final VoidCallback onSettings;

  const _Header({
    required this.greeting,
    required this.firstName,
    required this.initials,
    required this.primary,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, $firstName',
                style: TextStyle(
                  color: context.appColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'HabitGenius',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Notification bell
        GestureDetector(
          onTap: onSettings,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.appColors.bgCard,
              shape: BoxShape.circle,
              boxShadow: context.appColors.cardShadow,
            ),
            child: Icon(
              Icons.notifications_outlined,
              size: 20,
              color: context.appColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Avatar / settings
        GestureDetector(
          onTap: onSettings,
          child: Container(
            width: 40,
            height: 40,
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
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Filter chips ──────────────────────────────────────────

class _FilterChips extends StatelessWidget {
  final _HomeFilter filter;
  final ValueChanged<_HomeFilter> onChanged;

  const _FilterChips({required this.filter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    const items = [
      (_HomeFilter.today, 'Today'),
      (_HomeFilter.week, 'This Week'),
      (_HomeFilter.month, 'This Month'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            items.map((item) {
              final sel = filter == item.$1;
              return GestureDetector(
                onTap: () => onChanged(item.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: sel ? primary : context.appColors.bgCard,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow:
                        sel
                            ? [
                              BoxShadow(
                                color: primary.withValues(alpha: 0.35),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ]
                            : context.appColors.cardShadow,
                  ),
                  child: Text(
                    item.$2,
                    style: TextStyle(
                      color:
                          sel ? Colors.white : context.appColors.textSecondary,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}

// ── Progress banner ───────────────────────────────────────

class _ProgressBanner extends StatelessWidget {
  final int done;
  final int total;
  final String insight;
  final Color primary;
  final VoidCallback onTap;

  const _ProgressBanner({
    required this.done,
    required this.total,
    required this.insight,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final allDone = total > 0 && done == total;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.appColors.bgCard,
          borderRadius: BorderRadius.circular(18),
          border:
              allDone
                  ? Border.all(color: primary.withValues(alpha: 0.3))
                  : null,
          boxShadow: context.appColors.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color:
                    allDone
                        ? primary.withValues(alpha: 0.18)
                        : context.appColors.bgElevated,
                shape: BoxShape.circle,
              ),
              child: Icon(
                allDone
                    ? Icons.check_circle_rounded
                    : total == 0
                    ? Icons.add_circle_outline_rounded
                    : Icons.pending_actions_rounded,
                color: allDone ? primary : context.appColors.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    total == 0
                        ? 'No habits scheduled today'
                        : allDone
                        ? 'All habits done! 🎉'
                        : '$done of $total habits done',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    insight,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color:
                    allDone
                        ? primary.withValues(alpha: 0.15)
                        : context.appColors.bgElevated,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                total == 0 ? '--' : '$done/$total',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: allDone ? primary : context.appColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        const Spacer(),
        Icon(
          Icons.more_horiz_rounded,
          color: context.appColors.textMuted,
          size: 22,
        ),
      ],
    );
  }
}

// ── Pinned 2×2 grid ───────────────────────────────────────

class _PinnedGrid extends StatelessWidget {
  final _CardData habitsCard;
  final _CardData focusCard;
  final _CardData moodCard;
  final _CardData journalCard;
  final UserTier tier;
  final Color primary;

  const _PinnedGrid({
    required this.habitsCard,
    required this.focusCard,
    required this.moodCard,
    required this.journalCard,
    required this.tier,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column: Habits (highlighted) + Mood
        Expanded(
          child: Column(
            children: [
              _PinnedCard(
                title: 'Habits',
                icon: Icons.check_circle_outline_rounded,
                iconColor: primary,
                cardData: habitsCard,
                isHighlighted: true,
                route: AppRoutes.habits,
              ),
              const SizedBox(height: 14),
              _PinnedCard(
                title: 'Mood',
                icon: Icons.sentiment_satisfied_alt_rounded,
                iconColor: const Color(0xFFFF7675),
                cardData: moodCard,
                isHighlighted: false,
                route: AppRoutes.mood,
                locked: tier == UserTier.guest,
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        // Right column: Focus + Journal
        Expanded(
          child: Column(
            children: [
              _PinnedCard(
                title: 'Focus',
                icon: Icons.timer_rounded,
                iconColor: const Color(0xFF00B894),
                cardData: focusCard,
                isHighlighted: false,
                route: AppRoutes.focus,
              ),
              const SizedBox(height: 14),
              _PinnedCard(
                title: 'Journal',
                icon: Icons.menu_book_rounded,
                iconColor: const Color(0xFF74B9FF),
                cardData: journalCard,
                isHighlighted: false,
                route: AppRoutes.journal,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Pinned card ───────────────────────────────────────────

class _PinnedCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final _CardData cardData;
  final bool isHighlighted;
  final String route;
  final bool locked;

  const _PinnedCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.cardData,
    required this.isHighlighted,
    required this.route,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final effectiveColor = isHighlighted ? primary : iconColor;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (locked) {
          // Guest: take them to sign-in rather than showing a "Upgrade to Pro"
          // sheet — guests need an account before they can upgrade.
          context.go(AppRoutes.welcome);
          return;
        }
        context.go(route);
      },
      child: Container(
        height: 168,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient:
              isHighlighted
                  ? LinearGradient(
                    colors: [
                      primary.withValues(alpha: 0.28),
                      primary.withValues(alpha: 0.10),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                  : null,
          color: isHighlighted ? null : context.appColors.bgCard,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color:
                isHighlighted
                    ? primary.withValues(alpha: 0.40)
                    : Colors.white.withValues(alpha: 0.05),
            width: 1.5,
          ),
          boxShadow:
              isHighlighted
                  ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.22),
                      blurRadius: 28,
                      spreadRadius: 1,
                      offset: const Offset(0, 8),
                    ),
                  ]
                  : context.appColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: icon + toggle
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color:
                        isHighlighted
                            ? Colors.white.withValues(alpha: 0.16)
                            : effectiveColor.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child:
                      locked
                          ? const Icon(
                            Icons.lock_rounded,
                            size: 16,
                            color: AppColors.textMuted,
                          )
                          : Icon(
                            icon,
                            size: 18,
                            color:
                                isHighlighted ? Colors.white : effectiveColor,
                          ),
                ),
                const Spacer(),
                _StatusToggle(
                  isOn: !locked && cardData.isActive,
                  onColor: effectiveColor,
                  isHighlighted: isHighlighted,
                ),
              ],
            ),
            const Spacer(),
            // Stat value
            Text(
              locked ? '--' : cardData.value,
              style: TextStyle(
                fontSize: cardData.isEmoji ? 26 : 22,
                fontWeight: FontWeight.w800,
                color:
                    isHighlighted
                        ? Colors.white
                        : locked
                        ? AppColors.textMuted
                        : null,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 5),
            // Title
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color:
                    isHighlighted ? Colors.white.withValues(alpha: 0.9) : null,
              ),
            ),
            const SizedBox(height: 2),
            // Sub label
            Text(
              locked ? 'Sign in to unlock' : cardData.sub,
              style: TextStyle(
                fontSize: 11,
                color:
                    isHighlighted
                        ? Colors.white.withValues(alpha: 0.55)
                        : context.appColors.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            // Mini progress bar
            if (!locked && cardData.progress > 0) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: cardData.progress,
                  minHeight: 3,
                  backgroundColor:
                      isHighlighted
                          ? Colors.white.withValues(alpha: 0.18)
                          : effectiveColor.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isHighlighted ? Colors.white : effectiveColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Status toggle (visual indicator, Smart Home style) ────

class _StatusToggle extends StatelessWidget {
  final bool isOn;
  final Color onColor;
  final bool isHighlighted;

  const _StatusToggle({
    required this.isOn,
    required this.onColor,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    final trackOn =
        isHighlighted
            ? Colors.white.withValues(alpha: 0.28)
            : onColor.withValues(alpha: 0.28);
    final borderOn =
        isHighlighted
            ? Colors.white.withValues(alpha: 0.4)
            : onColor.withValues(alpha: 0.4);
    final thumbOn = isHighlighted ? Colors.white : onColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 36,
      height: 19,
      decoration: BoxDecoration(
        color: isOn ? trackOn : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isOn ? borderOn : Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 220),
        alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 13,
          height: 13,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isOn ? thumbOn : AppColors.textMuted,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// ── All Features section ──────────────────────────────────

class _FeaturesSection extends StatelessWidget {
  final UserTier tier;
  final int monthTxCount;
  final int accountCount;

  const _FeaturesSection({
    required this.tier,
    required this.monthTxCount,
    required this.accountCount,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_FeatureItem>[];

    if (tier != UserTier.guest) {
      items.add(
        _FeatureItem(
          icon: Icons.account_balance_wallet_rounded,
          color: const Color(0xFF0984E3),
          title: 'Expenses',
          subtitle:
              monthTxCount == 0
                  ? 'No transactions this month'
                  : '$monthTxCount transaction${monthTxCount == 1 ? '' : 's'} this month',
          badge:
              accountCount > 0
                  ? '$accountCount acct${accountCount == 1 ? '' : 's'}'
                  : null,
          onTap: (ctx) => ctx.go(AppRoutes.expenses),
        ),
      );
    } else {
      items.add(
        _FeatureItem(
          icon: Icons.login_rounded,
          color: const Color(0xFFF47820),
          title: 'Sign in to unlock more',
          subtitle: 'Expenses, Mood & unlimited habits',
          onTap: (ctx) => ctx.go(AppRoutes.welcome),
        ),
      );
    }

    items.add(
      _FeatureItem(
        icon: Icons.settings_rounded,
        color: AppColors.textSecondary,
        title: 'Settings',
        subtitle: 'Theme, notifications & account',
        onTap: (ctx) => ctx.push(AppRoutes.settings),
        isLast: true,
      ),
    );

    return Container(
      decoration: context.cardDecoration,
      child: Column(
        children:
            items
                .map(
                  (item) => _FeatureRow(
                    icon: item.icon,
                    iconColor: item.color,
                    title: item.title,
                    subtitle: item.subtitle,
                    badge: item.badge,
                    onTap: item.onTap,
                    isLast: item.isLast,
                  ),
                )
                .toList(),
      ),
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? badge;
  final void Function(BuildContext) onTap;
  final bool isLast;

  const _FeatureItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.isLast = false,
  });
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badge;
  final void Function(BuildContext) onTap;
  final bool isLast;

  const _FeatureRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap(context);
          },
          child: Container(
            color: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 21),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.appColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (badge != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: iconColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.appColors.textMuted,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 74,
            endIndent: 16,
            color: Colors.white.withValues(alpha: 0.06),
          ),
      ],
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
        final op = 0.04 + _shimmer.value * 0.08;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _box(h: 52, op: op),
              const SizedBox(height: 24),
              Row(
                children: List.generate(
                  3,
                  (i) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i < 2 ? 10 : 0),
                      child: _box(h: 36, op: op, r: 24),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _box(h: 70, op: op, r: 18),
              const SizedBox(height: 28),
              _box(h: 22, op: op, w: 80),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _box(h: 168, op: op, r: 22),
                        const SizedBox(height: 14),
                        _box(h: 168, op: op, r: 22),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      children: [
                        _box(h: 168, op: op, r: 22),
                        const SizedBox(height: 14),
                        _box(h: 168, op: op, r: 22),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _box({
    required double h,
    required double op,
    double r = 12,
    double? w,
  }) => Container(
    height: h,
    width: w,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: op),
      borderRadius: BorderRadius.circular(r),
    ),
  );
}
