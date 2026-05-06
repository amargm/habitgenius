import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme_extension.dart';
import '../../core/models/app_data.dart';
import '../../core/models/habit.dart';
import '../../core/models/habit_log.dart';
import '../../core/models/mood.dart';
import '../../core/models/transaction.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/data_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/habit_helpers.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/permission_service.dart';
import '../../shared/widgets/empty_state_widget.dart';

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

    final activeHabits =
        data.habits.where((h) => h.archivedAt == null).toList();
    final todayHabits = HabitHelpers.habitsForDate(activeHabits, today);
    final todayMood = data.moods.where((m) => m.date == todayStr).firstOrNull;
    final habitsDoneToday =
        todayHabits
            .where(
              (h) => HabitHelpers.isCompletedOn(h, data.habitLogs, todayStr),
            )
            .length;
    final doneToday = habitsDoneToday + (todayMood != null ? 1 : 0);
    final totalTodayActivities = todayHabits.length + 1; // habits + mood
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final weekStart = todayMidnight.subtract(
      Duration(days: todayMidnight.weekday - 1),
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
                const SizedBox(height: 28),

                // Always show Today section (mood shown even when zero habits)
                ...[
                  _SectionHeader(
                    label: 'Today',
                    trailing: Text(
                      '$doneToday / $totalTodayActivities done',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            doneToday == totalTodayActivities
                                ? primary
                                : context.appColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _TodayHabitsRow(
                    habits: todayHabits,
                    logs: data.habitLogs,
                    todayStr: todayStr,
                    allHabits: activeHabits,
                    allLogs: data.habitLogs,
                    today: today,
                    primary: primary,
                    todayMood: todayMood,
                    allMoods: data.moods,
                  ),
                  const SizedBox(height: 28),
                ],

                _SectionHeader(label: 'This Week', trailing: const SizedBox()),
                const SizedBox(height: 14),
                _WeeklyOverview(
                  data: data,
                  activeHabits: activeHabits,
                  weekStart: weekStart,
                  today: today,
                  primary: primary,
                  tier: auth.tier,
                ),
                if (activeHabits.isEmpty) ...[
                  const SizedBox(height: 32),
                  _FirstHabitCta(primary: primary),
                ],
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── First habit CTA (shown when user has no habits yet) ───

class _FirstHabitCta extends StatelessWidget {
  final Color primary;
  const _FirstHabitCta({required this.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text('🌱', style: const TextStyle(fontSize: 44)),
          const SizedBox(height: 16),
          Text(
            'Start your journey',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first habit and begin building great routines, one day at a time.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: context.appColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => context.push(AppRoutes.addHabit),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add first habit'),
          ),
        ],
      ),
    );
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
                greeting,
                style: TextStyle(
                  color: context.appColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                firstName,
                style: const TextStyle(
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
        // Avatar / settings
        GestureDetector(
          onTap: onSettings,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
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

// ── Section header ────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final Widget? trailing;

  const _SectionHeader({required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        const Spacer(),
        trailing ??
            Icon(
              Icons.more_horiz_rounded,
              color: context.appColors.textMuted,
              size: 22,
            ),
      ],
    );
  }
}

// ── Today's habits horizontal row ────────────────────────

class _TodayHabitsRow extends ConsumerWidget {
  final List<Habit> habits;
  final List<HabitLog> logs;
  final String todayStr;
  final List<Habit> allHabits;
  final List<HabitLog> allLogs;
  final DateTime today;
  final Color primary;
  final Mood? todayMood;
  final List<Mood> allMoods;

  const _TodayHabitsRow({
    required this.habits,
    required this.logs,
    required this.todayStr,
    required this.allHabits,
    required this.allLogs,
    required this.today,
    required this.primary,
    this.todayMood,
    this.allMoods = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 90,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          ...habits.asMap().entries.map((entry) {
            final i = entry.key;
            final habit = habits[i];
            final done = HabitHelpers.isCompletedOn(habit, logs, todayStr);
            Color habitColor;
            try {
              habitColor = Color(
                int.parse(
                  'FF${habit.colorHex.replaceFirst('#', '')}',
                  radix: 16,
                ),
              );
            } catch (_) {
              habitColor = primary;
            }

            final log = HabitHelpers.logForDate(logs, habit.id, todayStr);
            final currentVal = log?.value ?? 0;
            final isCounter = habit.progressType == HabitProgressType.counter;
            final isTimer = habit.progressType == HabitProgressType.timer;
            final timerPct =
                isTimer && habit.targetValue > 0
                    ? (currentVal / habit.targetValue).clamp(0.0, 1.0)
                    : 0.0;

            Widget circleInner;
            if (done) {
              circleInner = const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 26,
              );
            } else if (isCounter) {
              circleInner = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(habit.icon, style: const TextStyle(fontSize: 18)),
                  if (habit.targetValue > 0)
                    Text(
                      '$currentVal/${habit.targetValue}',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: habitColor,
                      ),
                    ),
                ],
              );
            } else {
              circleInner = Text(
                habit.icon,
                style: const TextStyle(fontSize: 24),
              );
            }

            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () async {
                  if (isCounter) {
                    HapticFeedback.selectionClick();
                    final wasDone = done;
                    await ref
                        .read(dataNotifierProvider.notifier)
                        .toggleHabit(
                          habitId: habit.id,
                          dateStr: todayStr,
                          delta: 1,
                        );
                    if (!wasDone) {
                      final nowDone = HabitHelpers.isCompletedOn(
                        habit,
                        ref.read(dataNotifierProvider).value?.habitLogs ?? logs,
                        todayStr,
                      );
                      if (nowDone) {
                        final celebrate =
                            ref
                                .read(sharedPreferencesProvider)
                                .getBool(PrefKeys.celebrationHaptic) ??
                            true;
                        if (celebrate) {
                          HapticFeedback.heavyImpact();
                          await Future<void>.delayed(
                            const Duration(milliseconds: 120),
                          );
                          HapticFeedback.mediumImpact();
                        }
                      }
                    }
                  } else if (isTimer) {
                    _showTimerPicker(context, ref, habit, currentVal, todayStr);
                  } else {
                    HapticFeedback.selectionClick();
                    final wasDone = HabitHelpers.isCompletedOn(
                      habit,
                      ref.read(dataNotifierProvider).value?.habitLogs ?? logs,
                      todayStr,
                    );
                    await ref
                        .read(dataNotifierProvider.notifier)
                        .toggleHabit(habitId: habit.id, dateStr: todayStr);
                    if (!wasDone) {
                      final celebrate =
                          ref
                              .read(sharedPreferencesProvider)
                              .getBool(PrefKeys.celebrationHaptic) ??
                          true;
                      if (celebrate) {
                        HapticFeedback.heavyImpact();
                        await Future<void>.delayed(
                          const Duration(milliseconds: 120),
                        );
                        HapticFeedback.mediumImpact();
                      }
                    }
                  }
                },
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  if (isCounter && currentVal > 0) {
                    // Long-press on counter = decrement
                    ref
                        .read(dataNotifierProvider.notifier)
                        .toggleHabit(
                          habitId: habit.id,
                          dateStr: todayStr,
                          delta: -1,
                        );
                  } else {
                    _showYearHeatmap(
                      context,
                      habit,
                      allLogs,
                      today,
                      habitColor,
                    );
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color:
                                done
                                    ? habitColor
                                    : habitColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border:
                                done
                                    ? null
                                    : Border.all(
                                      color: habitColor.withValues(alpha: 0.5),
                                      width: 1.5,
                                    ),
                            boxShadow:
                                done
                                    ? [
                                      BoxShadow(
                                        color: habitColor.withValues(
                                          alpha: 0.4,
                                        ),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                    : null,
                          ),
                          child: Center(child: circleInner),
                        ),
                        if (isTimer && !done)
                          SizedBox(
                            width: 56,
                            height: 56,
                            child: CircularProgressIndicator(
                              value: timerPct,
                              strokeWidth: 3,
                              backgroundColor: habitColor.withValues(
                                alpha: 0.15,
                              ),
                              color: habitColor,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 68,
                      child: Text(
                        habit.name,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color:
                              done
                                  ? habitColor
                                  : context.appColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          // Mood quick-entry button
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              _showMoodPicker(context, ref, todayStr, todayMood);
            },
            onLongPress: () {
              HapticFeedback.mediumImpact();
              _showMoodYearHeatmap(context, allMoods, today);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color:
                        todayMood != null
                            ? AppColors.featureMood.withValues(alpha: 0.25)
                            : context.appColors.bgElevated,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          todayMood != null
                              ? AppColors.featureMood.withValues(alpha: 0.6)
                              : context.appColors.border,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      todayMood?.emoji ?? '😶',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 60,
                  child: Text(
                    'Mood',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color:
                          todayMood != null
                              ? AppColors.featureMood
                              : context.appColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMoodPicker(
    BuildContext context,
    WidgetRef ref,
    String todayStr,
    Mood? existing,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MoodQuickPicker(todayStr: todayStr, existing: existing),
    );
  }

  void _showYearHeatmap(
    BuildContext context,
    Habit habit,
    List<HabitLog> logs,
    DateTime today,
    Color habitColor,
  ) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        barrierDismissible: true,
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (ctx, anim, _) {
          return FadeTransition(
            opacity: anim,
            child: _HabitYearHeatmapPage(
              habit: habit,
              logs: logs,
              today: today,
              habitColor: habitColor,
            ),
          );
        },
      ),
    );
  }

  void _showTimerPicker(
    BuildContext context,
    WidgetRef ref,
    Habit habit,
    int currentVal,
    String dateStr,
  ) {
    final target = habit.targetValue > 0 ? habit.targetValue : 60;
    final remaining = (target - currentVal).clamp(0, target + 60);
    final presets =
        [5, 10, 15, 20, 30, 45, 60].where((m) => m <= remaining + 30).toList();
    if (presets.isEmpty) presets.add(15);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final primary = Theme.of(context).colorScheme.primary;
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          decoration: BoxDecoration(
            color: context.appColors.bgCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Log time · ${habit.name}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$currentVal / $target ${habit.unit ?? 'min'} done',
                style: TextStyle(
                  color: context.appColors.textMuted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children:
                    presets
                        .map(
                          (mins) => ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await ref
                                  .read(dataNotifierProvider.notifier)
                                  .toggleHabit(
                                    habitId: habit.id,
                                    dateStr: dateStr,
                                    delta: mins,
                                  );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary.withValues(alpha: 0.12),
                              foregroundColor: primary,
                              elevation: 0,
                              shadowColor: Colors.transparent,
                            ),
                            child: Text('+$mins min'),
                          ),
                        )
                        .toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMoodYearHeatmap(
    BuildContext context,
    List<Mood> moods,
    DateTime today,
  ) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        barrierDismissible: true,
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (ctx, anim, _) {
          return FadeTransition(
            opacity: anim,
            child: _MoodYearHeatmapPage(moods: moods, today: today),
          );
        },
      ),
    );
  }
}

class _MoodYearHeatmapPage extends StatelessWidget {
  final List<Mood> moods;
  final DateTime today;

  static const _monthNames = [
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
  static const _moodColors = [
    Color(0xFFE17055),
    Color(0xFFFDAA6E),
    Color(0xFF8E8EA0),
    Color(0xFF00B894),
    Color(0xFF6C5CE7),
  ];

  const _MoodYearHeatmapPage({required this.moods, required this.today});

  @override
  Widget build(BuildContext context) {
    final moodMap = {for (final m in moods) m.date: m};
    final logged =
        moods.where((m) {
          final d = DateTime.tryParse(m.date);
          return d != null && d.year == today.year;
        }).toList();
    final avgLevel =
        logged.isEmpty
            ? null
            : (logged.map((m) => m.level).reduce((a, b) => a + b) /
                    logged.length)
                .round()
                .clamp(1, 5);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (_) {},
      onHorizontalDragEnd: (_) {},
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mood',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${logged.length} days logged  •  ${today.year}'
                      '${avgLevel != null ? '  •  avg ${_moodColors[avgLevel - 1] != Colors.transparent ? '' : ''}' : ''}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.9,
                        ),
                    itemCount: 12,
                    itemBuilder:
                        (_, i) => _MoodMiniMonth(
                          month: DateTime(today.year, i + 1, 1),
                          moodByDate: moodMap,
                          today: today,
                          monthName: _monthNames[i],
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoodMiniMonth extends StatelessWidget {
  final DateTime month;
  final Map<String, Mood> moodByDate;
  final DateTime today;
  final String monthName;

  static const _moodColors = [
    Color(0xFFE17055),
    Color(0xFFFDAA6E),
    Color(0xFF8E8EA0),
    Color(0xFF00B894),
    Color(0xFF6C5CE7),
  ];

  const _MoodMiniMonth({
    required this.month,
    required this.moodByDate,
    required this.today,
    required this.monthName,
  });

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final firstWeekday = (DateTime(month.year, month.month, 1).weekday - 1) % 7;
    final todayMid = DateTime(today.year, today.month, today.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          monthName,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white70,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 5),
        Expanded(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              childAspectRatio: 1,
            ),
            itemCount: firstWeekday + daysInMonth,
            itemBuilder: (_, idx) {
              if (idx < firstWeekday) return const SizedBox.shrink();
              final day = idx - firstWeekday + 1;
              final dayDate = DateTime(month.year, month.month, day);
              if (dayDate.isAfter(todayMid)) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }
              final ds =
                  '${month.year}-${month.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
              final mood = moodByDate[ds];
              if (mood != null) {
                return Container(
                  decoration: BoxDecoration(
                    color: _moodColors[mood.level.clamp(1, 5) - 1].withValues(
                      alpha: 0.25,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Center(
                    child: Text(
                      mood.emoji,
                      style: const TextStyle(fontSize: 7, height: 1),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Full-year heatmap page (shown on long press) ─────────

class _HabitYearHeatmapPage extends StatelessWidget {
  final Habit habit;
  final List<HabitLog> logs;
  final DateTime today;
  final Color habitColor;

  const _HabitYearHeatmapPage({
    required this.habit,
    required this.logs,
    required this.today,
    required this.habitColor,
  });

  @override
  Widget build(BuildContext context) {
    final heatmap = HabitHelpers.yearlyHeatmap(habit, logs, today);
    final totalDone = heatmap.values.where((v) => v > 0).length;
    final streak = HabitHelpers.currentStreak(habit, logs, today);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (_) {},
      onHorizontalDragEnd: (_) {},
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                  ],
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalDone of 365 days  •  ${(totalDone / 3.65).toStringAsFixed(0)}%'
                      '  •  $streak day streak',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 12-month grid (Jan–Dec, fits screen without scrolling)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: _YearMonthGrid(
                    today: today,
                    heatmap: heatmap,
                    habitColor: habitColor,
                    createdAt:
                        DateTime.tryParse(habit.createdAt) ??
                        today.subtract(const Duration(days: 365)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Year month grid (12 months, image style) ──────────────

class _YearMonthGrid extends StatelessWidget {
  final DateTime today;
  final Map<String, int> heatmap;
  final Color habitColor;
  final DateTime createdAt;

  static const _monthNames = [
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
  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  const _YearMonthGrid({
    required this.today,
    required this.heatmap,
    required this.habitColor,
    required this.createdAt,
  });

  Color _cell(int? v) {
    if (v == null) return Colors.transparent;
    switch (v) {
      case 0:
        return habitColor.withValues(alpha: 0.12);
      case 1:
        return habitColor.withValues(alpha: 0.30);
      case 2:
        return habitColor.withValues(alpha: 0.55);
      case 3:
        return habitColor.withValues(alpha: 0.75);
      default:
        return habitColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show Jan–Dec of the current year
    final months = List.generate(12, (i) => DateTime(today.year, i + 1, 1));

    return LayoutBuilder(
      builder: (context, constraints) {
        const cols = 3;
        const rows = 4;
        const hGap = 14.0;
        const vGap = 12.0;
        final cellW = (constraints.maxWidth - hGap * (cols - 1)) / cols;
        final cellH =
            constraints.maxHeight.isFinite
                ? (constraints.maxHeight - vGap * (rows - 1)) / rows
                : cellW / 0.75;
        final ratio = (cellW / cellH).clamp(0.4, 1.5);
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: hGap,
            mainAxisSpacing: vGap,
            childAspectRatio: ratio,
          ),
          itemCount: 12,
          itemBuilder: (_, idx) {
            final monthStart = months[idx];
            return _MonthBlock(
              monthStart: monthStart,
              today: today,
              heatmap: heatmap,
              habitColor: habitColor,
              createdAt: createdAt,
              cellColor: _cell,
              dayLabels: _dayLabels,
              monthNames: _monthNames,
            );
          },
        );
      },
    );
  }
}

class _MonthBlock extends StatelessWidget {
  final DateTime monthStart;
  final DateTime today;
  final Map<String, int> heatmap;
  final Color habitColor;
  final DateTime createdAt;
  final Color Function(int?) cellColor;
  final List<String> dayLabels;
  final List<String> monthNames;

  const _MonthBlock({
    required this.monthStart,
    required this.today,
    required this.heatmap,
    required this.habitColor,
    required this.createdAt,
    required this.cellColor,
    required this.dayLabels,
    required this.monthNames,
  });

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    // Weekday of first day (Mon=0)
    final firstWeekday = (monthStart.weekday - 1) % 7;
    final daysInMonth = DateUtils.getDaysInMonth(
      monthStart.year,
      monthStart.month,
    );
    final todayMidnight = DateTime(today.year, today.month, today.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${monthNames[monthStart.month - 1]} ${monthStart.year}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        // Day-of-week headers
        Row(
          children: List.generate(7, (d) {
            return Expanded(
              child: Text(
                dayLabels[d],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 7,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 3),
        // Calendar grid
        Expanded(
          child: LayoutBuilder(
            builder: (ctx, _) {
              return GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                  childAspectRatio: 1,
                ),
                itemCount: 42,
                itemBuilder: (_, cellIdx) {
                  final dayOffset = cellIdx - firstWeekday;
                  // Cells outside current month → invisible spacer
                  if (dayOffset < 0 || dayOffset >= daysInMonth) {
                    return const SizedBox();
                  }
                  final day = DateTime(
                    monthStart.year,
                    monthStart.month,
                    dayOffset + 1,
                  );
                  // Future dates or pre-habit-creation dates → outline only
                  final outlineOnly =
                      day.isAfter(todayMidnight) ||
                      day.isBefore(
                        DateTime(
                          createdAt.year,
                          createdAt.month,
                          createdAt.day,
                        ),
                      );
                  if (outlineOnly) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                          width: 0.5,
                        ),
                      ),
                    );
                  }
                  final key = _fmt(day);
                  final v = heatmap[key];
                  return Container(
                    decoration: BoxDecoration(
                      color:
                          v == null
                              ? Colors.white.withValues(alpha: 0.06)
                              : cellColor(v),
                      borderRadius: BorderRadius.circular(2),
                      border:
                          v == null
                              ? Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                                width: 0.5,
                              )
                              : null,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Mood quick-entry picker ───────────────────────────────

class _MoodQuickPicker extends ConsumerWidget {
  final String todayStr;
  final Mood? existing;

  static const _levels = [
    (1, '😣', 'Awful'),
    (2, '😔', 'Bad'),
    (3, '😐', 'Okay'),
    (4, '😊', 'Good'),
    (5, '🤩', 'Great'),
  ];

  const _MoodQuickPicker({required this.todayStr, required this.existing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      decoration: BoxDecoration(
        color: context.appColors.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.appColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'How are you feeling?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.appColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children:
                _levels.map((lvl) {
                  final isSelected = existing?.level == lvl.$1;
                  return GestureDetector(
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      final mood = Mood(
                        id: existing?.id ?? const Uuid().v4(),
                        date: todayStr,
                        level: lvl.$1,
                        emoji: lvl.$2,
                        tags: existing?.tags ?? [],
                        note: existing?.note,
                        loggedAt: DateTime.now().toUtc().toIso8601String(),
                      );
                      await ref
                          .read(dataNotifierProvider.notifier)
                          .upsertMood(mood);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? AppColors.featureMood.withValues(alpha: 0.18)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            isSelected
                                ? Border.all(
                                  color: AppColors.featureMood.withValues(
                                    alpha: 0.5,
                                  ),
                                )
                                : null,
                      ),
                      child: Column(
                        children: [
                          Text(lvl.$2, style: const TextStyle(fontSize: 32)),
                          const SizedBox(height: 6),
                          Text(
                            lvl.$3,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color:
                                  isSelected
                                      ? AppColors.featureMood
                                      : context.appColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Weekly overview ───────────────────────────────────────

class _WeeklyOverview extends StatefulWidget {
  final AppData data;
  final List<Habit> activeHabits;
  final DateTime weekStart;
  final DateTime today;
  final Color primary;
  final UserTier tier;

  static const _dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _moodEmojis = ['😣', '😔', '😐', '😊', '🤩'];
  static const _moodColors = [
    Color(0xFFE17055),
    Color(0xFFFDAA6E),
    Color(0xFF8E8EA0),
    Color(0xFF00B894),
    Color(0xFF6C5CE7),
  ];

  const _WeeklyOverview({
    required this.data,
    required this.activeHabits,
    required this.weekStart,
    required this.today,
    required this.primary,
    required this.tier,
  });

  @override
  State<_WeeklyOverview> createState() => _WeeklyOverviewState();
}

class _WeeklyOverviewState extends State<_WeeklyOverview> {
  String? _expandedRow;

  void _toggle(String title) =>
      setState(() => _expandedRow = _expandedRow == title ? null : title);

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtMins(int m) =>
      m == 0
          ? '--'
          : m >= 60
          ? '${m ~/ 60}h${m % 60 > 0 ? '${m % 60}m' : ''}'
          : '${m}m';

  String _smartMoney(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final activeHabits = widget.activeHabits;
    final weekStart = widget.weekStart;
    final today = widget.today;
    final primary = widget.primary;
    final tier = widget.tier;
    final todayMid = DateTime(today.year, today.month, today.day);
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));

    // ── Habits ───────────────────────────────────────
    final habitsRatios =
        days.map<double?>((day) {
          if (day.isAfter(todayMid)) return null;
          final sched =
              HabitHelpers.habitsForDate(activeHabits, day).where((h) {
                final created = DateTime.tryParse(h.createdAt)?.toLocal();
                if (created == null) return true;
                return !DateTime(
                  created.year,
                  created.month,
                  created.day,
                ).isAfter(day);
              }).toList();
          if (sched.isEmpty) return -1;
          final ds = _fmt(day);
          final done =
              sched
                  .where(
                    (h) => HabitHelpers.isCompletedOn(h, data.habitLogs, ds),
                  )
                  .length;
          return done / sched.length;
        }).toList();
    final validR = habitsRatios
        .where((r) => r != null && r >= 0)
        .map((r) => r!);
    final weekHabitsAvg =
        validR.isEmpty ? null : validR.reduce((a, b) => a + b) / validR.length;

    // ── Mood ─────────────────────────────────────────
    final moodMap = {for (final m in data.moods) m.date: m};
    final dayMoods =
        days.map((day) {
          if (day.isAfter(todayMid)) return null;
          return moodMap[_fmt(day)];
        }).toList();
    final loggedMoods =
        dayMoods.where((m) => m != null).map((m) => m!).toList();
    final avgMoodLevel =
        loggedMoods.isEmpty
            ? null
            : (loggedMoods.map((m) => m.level).reduce((a, b) => a + b) /
                    loggedMoods.length)
                .round()
                .clamp(1, 5);

    // ── Focus ─────────────────────────────────────────
    final dayFocusMins =
        days.map<int?>((day) {
          if (day.isAfter(todayMid)) return null;
          return data.focusSessions
              .where((s) {
                final d = DateTime.tryParse(s.startedAt)?.toLocal();
                return d != null &&
                    d.year == day.year &&
                    d.month == day.month &&
                    d.day == day.day;
              })
              .fold<int>(0, (sum, s) => sum + (s.actualDuration ~/ 60));
        }).toList();
    final totalFocusMins = dayFocusMins
        .where((m) => m != null)
        .fold<int>(0, (s, m) => s + (m ?? 0));
    final maxFocusMins =
        dayFocusMins.where((m) => m != null && m > 0).isEmpty
            ? 1
            : dayFocusMins
                .where((m) => m != null)
                .map((m) => m as int)
                .reduce((a, b) => a > b ? a : b);

    // ── Journal ───────────────────────────────────────
    final dayJournal =
        days.map<int?>((day) {
          if (day.isAfter(todayMid)) return null;
          final ds = _fmt(day);
          return data.journal.where((e) {
            final d = DateTime.tryParse(e.createdAt)?.toLocal();
            return d != null && _fmt(d) == ds;
          }).length;
        }).toList();
    final totalJournal = dayJournal
        .where((c) => c != null)
        .fold<int>(0, (s, c) => s + c!);

    // ── Expenses ─────────────────────────────────────
    List<double?> daySpend = [];
    double totalSpend = 0;
    if (tier != UserTier.guest) {
      daySpend =
          days.map<double?>((day) {
            if (day.isAfter(todayMid)) return null;
            final ds = _fmt(day);
            return data.transactions
                .where((t) => t.date == ds && t.type == TransactionType.expense)
                .fold<double>(0, (s, t) => s + t.amount);
          }).toList();
      totalSpend = daySpend
          .where((s) => s != null)
          .fold<double>(0, (s, v) => s + v!);
    }

    return Column(
      children: [
        _WeekRowCard(
          icon: Icons.check_circle_outline_rounded,
          title: 'Habits',
          color: primary,
          dayNames: _WeeklyOverview._dayNames,
          dayCells:
              days.asMap().entries.map((e) {
                final r = habitsRatios[e.key];
                if (r == null || r < 0) {
                  return _DayCellBox(
                    fill: 0,
                    color: primary,
                    empty: true,
                  );
                }
                return _DayCellBox(fill: r, color: primary, empty: false);
              }).toList(),
          aggregate:
              weekHabitsAvg == null
                  ? '--'
                  : '${(weekHabitsAvg * 100).round()}%',
          aggregateColor: primary,
          expanded: _expandedRow == 'Habits',
          onTap: () => _toggle('Habits'),
          expansionContent:
              _expandedRow == 'Habits'
                  ? _FourWeekExpansion(
                      title: 'Habits',
                      data: data,
                      activeHabits: activeHabits,
                      today: today,
                      thisWeekStart: weekStart,
                      primary: primary,
                      tier: tier,
                      skipCurrentWeek: true,
                      inlineMode: true,
                    )
                  : null,
        ),
        const SizedBox(height: 10),
        _WeekRowCard(
          icon: Icons.sentiment_satisfied_alt_rounded,
          title: 'Mood',
          color: const Color(0xFF9B59B6),
          dayNames: _WeeklyOverview._dayNames,
          dayCells:
              days.asMap().entries.map((e) {
                final mood = dayMoods[e.key];
                if (mood == null) {
                  return _DayCellBox(
                    fill: 0,
                    color: const Color(0xFF9B59B6),
                    empty: true,
                  );
                }
                return _DayCellText(text: mood.emoji);
              }).toList(),
          aggregate:
              avgMoodLevel == null
                  ? '--'
                  : _WeeklyOverview._moodEmojis[avgMoodLevel - 1],
          aggregateColor:
              avgMoodLevel == null
                  ? AppColors.textMuted
                  : _WeeklyOverview._moodColors[avgMoodLevel - 1],
          expanded: _expandedRow == 'Mood',
          onTap: () => _toggle('Mood'),
          expansionContent:
              _expandedRow == 'Mood'
                  ? _FourWeekExpansion(
                      title: 'Mood',
                      data: data,
                      activeHabits: activeHabits,
                      today: today,
                      thisWeekStart: weekStart,
                      primary: primary,
                      tier: tier,
                      skipCurrentWeek: true,
                      inlineMode: true,
                    )
                  : null,
        ),
        const SizedBox(height: 10),
        _WeekRowCard(
          icon: Icons.timer_rounded,
          title: 'Focus',
          color: const Color(0xFFF39C12),
          dayNames: _WeeklyOverview._dayNames,
          dayCells:
              days.asMap().entries.map((e) {
                final mins = dayFocusMins[e.key];
                if (mins == null || mins == 0) {
                  return _DayCellBox(
                    fill: 0,
                    color: const Color(0xFFF39C12),
                    empty: true,
                  );
                }
                return _DayCellBox(
                  fill: (mins / maxFocusMins).clamp(0.0, 1.0),
                  color: const Color(0xFFF39C12),
                  empty: false,
                );
              }).toList(),
          aggregate: _fmtMins(totalFocusMins),
          aggregateColor: const Color(0xFFF39C12),
          expanded: _expandedRow == 'Focus',
          onTap: () => _toggle('Focus'),
          expansionContent:
              _expandedRow == 'Focus'
                  ? _FourWeekExpansion(
                      title: 'Focus',
                      data: data,
                      activeHabits: activeHabits,
                      today: today,
                      thisWeekStart: weekStart,
                      primary: primary,
                      tier: tier,
                      skipCurrentWeek: true,
                      inlineMode: true,
                    )
                  : null,
        ),
        const SizedBox(height: 10),
        _WeekRowCard(
          icon: Icons.menu_book_rounded,
          title: 'Journal',
          color: const Color(0xFF3498DB),
          dayNames: _WeeklyOverview._dayNames,
          dayCells:
              days.asMap().entries.map((e) {
                final count = dayJournal[e.key];
                if (count == null || count == 0) {
                  return _DayCellBox(
                    fill: 0,
                    color: const Color(0xFF3498DB),
                    empty: true,
                  );
                }
                return _DayCellBox(
                  fill: 1.0,
                  color: const Color(0xFF3498DB),
                  empty: false,
                );
              }).toList(),
          aggregate: totalJournal == 0 ? '--' : '$totalJournal',
          aggregateColor: const Color(0xFF3498DB),
          expanded: _expandedRow == 'Journal',
          onTap: () => _toggle('Journal'),
          expansionContent:
              _expandedRow == 'Journal'
                  ? _FourWeekExpansion(
                      title: 'Journal',
                      data: data,
                      activeHabits: activeHabits,
                      today: today,
                      thisWeekStart: weekStart,
                      primary: primary,
                      tier: tier,
                      skipCurrentWeek: true,
                      inlineMode: true,
                    )
                  : null,
        ),
        if (tier != UserTier.guest) ...[
          const SizedBox(height: 10),
          _WeekRowCard(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Spend',
            color: const Color(0xFF2ECC71),
            dayNames: _WeeklyOverview._dayNames,
            dayCells:
                days.asMap().entries.map((e) {
                  final spend =
                      daySpend.isNotEmpty ? daySpend[e.key] : null;
                  if (spend == null || spend == 0) {
                    return _DayCellBox(
                      fill: 0,
                      color: const Color(0xFF2ECC71),
                      empty: true,
                    );
                  }
                  return _DayCellText(
                    text: _smartMoney(spend),
                    color: const Color(0xFF2ECC71),
                    small: true,
                  );
                }).toList(),
            aggregate: totalSpend == 0 ? '--' : _smartMoney(totalSpend),
            aggregateColor: const Color(0xFF2ECC71),
            expanded: _expandedRow == 'Spend',
            onTap: () => _toggle('Spend'),
            expansionContent:
                _expandedRow == 'Spend'
                    ? _FourWeekExpansion(
                        title: 'Spend',
                        data: data,
                        activeHabits: activeHabits,
                        today: today,
                        thisWeekStart: weekStart,
                        primary: primary,
                        tier: tier,
                        skipCurrentWeek: true,
                        inlineMode: true,
                      )
                    : null,
          ),
        ],
      ],
    );
  }
}

// ── Week row card ─────────────────────────────────────────

class _WeekRowCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final List<String> dayNames;
  final List<Widget> dayCells;
  final String aggregate;
  final Color aggregateColor;
  final VoidCallback? onTap;
  final bool expanded;
  /// Previous 3 weeks rendered inside the card when [expanded] is true.
  /// The card itself expands downward — no separate container is introduced.
  final Widget? expansionContent;

  const _WeekRowCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.dayNames,
    required this.dayCells,
    required this.aggregate,
    required this.aggregateColor,
    this.onTap,
    this.expanded = false,
    this.expansionContent,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: context.cardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────
              Row(
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.appColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 1,
                    height: 14,
                    color: context.appColors.border,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  Text(
                    aggregate,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: aggregateColor,
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: context.appColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // ── Day names header ─────────────────────
              Row(
                children: [
                  if (expanded) const SizedBox(width: 28),
                  ...List.generate(
                    7,
                    (i) => Expanded(
                      child: Text(
                        dayNames[i],
                        style: TextStyle(
                          fontSize: 9,
                          color: context.appColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              // ── Previous 3 weeks (inside same card, above current) ──
              if (expanded && expansionContent != null) ...[
                expansionContent!,
                const SizedBox(height: 4),
              ],
              // ── Current week row ─────────────────────
              Row(
                children: [
                  if (expanded)
                    SizedBox(
                      width: 28,
                      child: Text(
                        'Now',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ...dayCells.map((c) => Expanded(child: Center(child: c))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Four-week expansion ───────────────────────────────────

class _FourWeekExpansion extends StatelessWidget {
  final String title;
  final AppData data;
  final List<Habit> activeHabits;
  final DateTime today;
  final DateTime thisWeekStart;
  final Color primary;
  final UserTier tier;

  /// When true, skips rendering the current ("Now") week row — used when the
  /// current week is already shown by the parent _WeekRowCard.
  final bool skipCurrentWeek;

  /// When true, renders only the week rows with no outer container decoration
  /// or day-name header — used when embedded inside a _WeekRowCard.
  final bool inlineMode;

  static const _dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  const _FourWeekExpansion({
    required this.title,
    required this.data,
    required this.activeHabits,
    required this.today,
    required this.thisWeekStart,
    required this.primary,
    required this.tier,
    this.skipCurrentWeek = false,
    this.inlineMode = false,
  });

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _smartMoney(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }

  Color _metricColor() {
    switch (title) {
      case 'Habits':
        return primary;
      case 'Mood':
        return const Color(0xFF9B59B6);
      case 'Focus':
        return const Color(0xFFF39C12);
      case 'Journal':
        return const Color(0xFF3498DB);
      case 'Spend':
        return const Color(0xFF2ECC71);
      default:
        return primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayMid = DateTime(today.year, today.month, today.day);
    final color = _metricColor();
    // Build 4 weeks ending at thisWeekStart (week 0 = current, week -1, -2, -3)
    final weeks = List.generate(
      4,
      (i) => thisWeekStart.subtract(Duration(days: 7 * (3 - i))),
    );

    final moodMap = {for (final m in data.moods) m.date: m};

    // For Focus bars: compute max across all 4 weeks
    int maxFocusMins = 1;
    if (title == 'Focus') {
      for (final ws in weeks) {
        for (int d = 0; d < 7; d++) {
          final day = ws.add(Duration(days: d));
          if (!day.isAfter(todayMid)) {
            final mins = data.focusSessions
                .where((s) {
                  final sd = DateTime.tryParse(s.startedAt)?.toLocal();
                  return sd != null &&
                      sd.year == day.year &&
                      sd.month == day.month &&
                      sd.day == day.day;
                })
                .fold<int>(0, (sum, s) => sum + (s.actualDuration ~/ 60));
            if (mins > maxFocusMins) maxFocusMins = mins;
          }
        }
      }
    }

    final weekRows = weeks.asMap().entries.map<Widget>((we) {
      final weekIdx = we.key;
      // Skip the current week row (index 3 = "Now") when the parent
      // already renders it as a _WeekRowCard.
      if (skipCurrentWeek && weekIdx == 3) {
        return const SizedBox.shrink();
      }
      final ws = we.value;
      final days = List.generate(7, (d) => ws.add(Duration(days: d)));
      final weekLabel = weekIdx == 3 ? 'Now' : '-${3 - weekIdx}w';

      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                weekLabel,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: context.appColors.textMuted,
                ),
              ),
            ),
            ...days.map((day) {
              Widget cell;
              if (day.isAfter(todayMid)) {
                cell = _DayCellBox(fill: 0, color: color, empty: true);
              } else {
                final ds = _fmt(day);
                switch (title) {
                  case 'Habits':
                    final sched = HabitHelpers.habitsForDate(
                      activeHabits,
                      day,
                    );
                    if (sched.isEmpty) {
                      cell = _DayCellBox(
                        fill: 0,
                        color: color,
                        empty: true,
                      );
                    } else {
                      final done =
                          sched
                              .where(
                                (h) => HabitHelpers.isCompletedOn(
                                  h,
                                  data.habitLogs,
                                  ds,
                                ),
                              )
                              .length;
                      cell = _DayCellBox(
                        fill: done / sched.length,
                        color: color,
                        empty: false,
                      );
                    }
                  case 'Mood':
                    final mood = moodMap[ds];
                    if (mood == null) {
                      cell = _DayCellBox(
                        fill: 0,
                        color: color,
                        empty: true,
                      );
                    } else {
                      cell = _DayCellText(text: mood.emoji);
                    }
                  case 'Focus':
                    final mins = data.focusSessions
                        .where((s) {
                          final sd =
                              DateTime.tryParse(s.startedAt)?.toLocal();
                          return sd != null &&
                              sd.year == day.year &&
                              sd.month == day.month &&
                              sd.day == day.day;
                        })
                        .fold<int>(
                          0,
                          (sum, s) => sum + (s.actualDuration ~/ 60),
                        );
                    cell = _DayCellBox(
                      fill:
                          mins == 0
                              ? 0
                              : (mins / maxFocusMins).clamp(0.0, 1.0),
                      color: color,
                      empty: mins == 0,
                    );
                  case 'Journal':
                    final count =
                        data.journal.where((e) {
                          final d =
                              DateTime.tryParse(e.createdAt)?.toLocal();
                          return d != null && _fmt(d) == ds;
                        }).length;
                    cell = _DayCellBox(
                      fill: count > 0 ? 1.0 : 0,
                      color: color,
                      empty: count == 0,
                    );
                  case 'Spend':
                    final spend = data.transactions
                        .where(
                          (t) =>
                              t.date == ds &&
                              t.type == TransactionType.expense,
                        )
                        .fold<double>(0, (s, t) => s + t.amount);
                    if (spend == 0) {
                      cell = _DayCellBox(
                        fill: 0,
                        color: color,
                        empty: true,
                      );
                    } else {
                      cell = _DayCellText(
                        text: _smartMoney(spend),
                        color: color,
                        small: true,
                      );
                    }
                  default:
                    cell = _DayCellBox(
                      fill: 0,
                      color: color,
                      empty: true,
                    );
                }
              }
              return Expanded(child: Center(child: cell));
            }),
          ],
        ),
      );
    }).toList();

    // Inline mode: rendered inside _WeekRowCard — no decoration, no day header.
    if (inlineMode) {
      return Column(children: weekRows);
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          children: [
            // Day name header
            Row(
              children: [
                const SizedBox(width: 28),
                ...List.generate(
                  7,
                  (i) => Expanded(
                    child: Text(
                      _dayNames[i],
                      style: TextStyle(
                        fontSize: 9,
                        color: context.appColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...weekRows,
          ],
        ),
      ),
    );
  }
}

// ── Day cell: box (habits, journal) ──────────────────────

class _DayCellBox extends StatelessWidget {
  final double fill;
  final Color color;
  final bool empty;

  const _DayCellBox({
    required this.fill,
    required this.color,
    required this.empty,
  });

  @override
  Widget build(BuildContext context) {
    final c =
        empty
            ? context.appColors.bgElevated
            : fill >= 1.0
            ? color
            : fill > 0
            ? color.withValues(alpha: 0.35 + fill * 0.55)
            : context.appColors.bgElevated;
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(4),
        border:
            !empty && fill > 0 && fill < 1.0
                ? Border.all(color: color.withValues(alpha: 0.5), width: 1)
                : null,
      ),
    );
  }
}

// ── Day cell: text (mood emoji, spend) ───────────────────

class _DayCellText extends StatelessWidget {
  final String text;
  final Color? color;
  final bool small;

  const _DayCellText({required this.text, this.color, this.small = false});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: small ? 9 : 14,
      color: color,
      fontWeight: small ? FontWeight.w600 : FontWeight.normal,
    ),
    textAlign: TextAlign.center,
  );
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
