import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme_extension.dart';
import '../../core/constants/app_limits.dart';
import '../../core/models/habit.dart';
import '../../core/models/habit_log.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/data_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/habit_helpers.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/habit_check_widget.dart';
import '../../shared/widgets/upgrade_prompt_sheet.dart';

// ── View enum ─────────────────────────────────────────────

enum _HabitView { today, week, all, year, archived }

// ── Screen ────────────────────────────────────────────────

class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  _HabitView _view = _HabitView.today;

  @override
  Widget build(BuildContext context) {
    final appData = ref.watch(appDataProvider);
    final tier = ref.watch(authNotifierProvider).tier;
    final habits = appData.habits.where((h) => h.archivedAt == null).toList();
    final archivedHabits =
        appData.habits.where((h) => h.archivedAt != null).toList();
    final logs = appData.habitLogs;
    final today = DateTime.now();
    final todayStr = HabitHelpers.todayStr();

    final todayHabits = HabitHelpers.habitsForDate(habits, today);
    final doneToday =
        todayHabits
            .where((h) => HabitHelpers.isCompletedOn(h, logs, todayStr))
            .length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Habits',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (todayHabits.isNotEmpty)
                          Text(
                            '$doneToday / ${todayHabits.length} done today',
                            style: TextStyle(
                              color: context.appColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (todayHabits.isNotEmpty)
                    _MiniRing(
                      done: doneToday,
                      total: todayHabits.length,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── View filter chips ─────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children:
                    _HabitView.values.map((v) {
                      final sel = _view == v;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _view = v),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  sel
                                      ? Theme.of(context).colorScheme.primary
                                      : context.appColors.bgCard,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color:
                                    sel
                                        ? Theme.of(context).colorScheme.primary
                                        : context.appColors.border,
                              ),
                            ),
                            child: Text(
                              _viewLabel(v),
                              style: TextStyle(
                                color:
                                    sel
                                        ? Colors.white
                                        : context.appColors.textSecondary,
                                fontWeight:
                                    sel ? FontWeight.w600 : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // ── Body ──────────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                onRefresh:
                    () => ref.read(dataNotifierProvider.notifier).reload(),
                child:
                    habits.isEmpty
                        ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: EmptyStateWidget(
                            icon: Icons.check_circle_outline_rounded,
                            title: 'No habits yet',
                            subtitle:
                                'Tap + to add your first habit and start building great routines.',
                            actionLabel: 'Add habit',
                            onAction: () => _onAddHabit(tier, 0),
                          ),
                        )
                        : _buildView(
                          habits: habits,
                          archivedHabits: archivedHabits,
                          logs: logs,
                          today: today,
                          todayStr: todayStr,
                          primary: Theme.of(context).colorScheme.primary,
                        ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onAddHabit(tier, habits.length),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildView({
    required List<Habit> habits,
    required List<Habit> archivedHabits,
    required List<HabitLog> logs,
    required DateTime today,
    required String todayStr,
    required Color primary,
  }) {
    switch (_view) {
      case _HabitView.today:
        final forToday = HabitHelpers.habitsForDate(habits, today);
        return forToday.isEmpty
            ? SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: EmptyStateWidget(
                icon: Icons.today_rounded,
                title: 'Rest day',
                subtitle:
                    'No habits scheduled for today.\nSwitch to All to see all habits.',
              ),
            )
            : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
              itemCount: forToday.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder:
                  (_, i) => _HabitTile(
                    habit: forToday[i],
                    logs: logs,
                    dateStr: todayStr,
                    primary: primary,
                  ),
            );

      case _HabitView.week:
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
          itemCount: habits.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder:
              (_, i) => _WeeklyHabitCard(
                habit: habits[i],
                logs: logs,
                today: today,
                primary: primary,
              ),
        );

      case _HabitView.all:
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
          itemCount: habits.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder:
              (_, i) => _HabitTile(
                habit: habits[i],
                logs: logs,
                dateStr: todayStr,
                primary: primary,
              ),
        );

      case _HabitView.year:
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
          itemCount: habits.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder:
              (_, i) => _YearHeatmapCard(
                habit: habits[i],
                logs: logs,
                today: today,
                primary: primary,
              ),
        );

      case _HabitView.archived:
        return archivedHabits.isEmpty
            ? SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: EmptyStateWidget(
                icon: Icons.archive_outlined,
                title: 'No archived habits',
                subtitle: 'Habits you archive will appear here.',
              ),
            )
            : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
              itemCount: archivedHabits.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder:
                  (_, i) => _ArchivedHabitTile(habit: archivedHabits[i]),
            );
    }
  }

  void _onAddHabit(tier, int currentCount) {
    final limit = AppLimits.maxHabits(tier);
    if (currentCount >= limit) {
      UpgradePromptSheet.show(context, feature: 'More Habits');
    } else {
      context.push(AppRoutes.addHabit);
    }
  }

  static String _viewLabel(_HabitView v) {
    switch (v) {
      case _HabitView.today:
        return 'Today';
      case _HabitView.week:
        return 'This Week';
      case _HabitView.all:
        return 'All';
      case _HabitView.year:
        return 'Year';
      case _HabitView.archived:
        return 'Archived';
    }
  }
}

// ── Habit tile ────────────────────────────────────────────

class _HabitTile extends ConsumerWidget {
  final Habit habit;
  final List<HabitLog> logs;
  final String dateStr;
  final Color primary;

  const _HabitTile({
    required this.habit,
    required this.logs,
    required this.dateStr,
    required this.primary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color habitColor;
    try {
      habitColor = Color(
        int.parse('FF${habit.colorHex.replaceFirst('#', '')}', radix: 16),
      );
    } catch (_) {
      habitColor = primary;
    }
    final streak = HabitHelpers.currentStreak(habit, logs, DateTime.now());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: context.cardDecoration,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: habitColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(habit.icon, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                if (streak > 0)
                  Row(
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        '$streak day streak',
                        style: TextStyle(
                          color: context.appColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          HabitCheckWidget(habit: habit, dateStr: dateStr),
          const SizedBox(width: 4),
          // Long-press menu: archive or delete the habit.
          PopupMenuButton<_HabitAction>(
            icon: Icon(
              Icons.more_vert_rounded,
              size: 18,
              color: context.appColors.textMuted,
            ),
            onSelected: (action) => _onAction(context, ref, action),
            itemBuilder:
                (_) => [
                  const PopupMenuItem(
                    value: _HabitAction.edit,
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: _HabitAction.archive,
                    child: Row(
                      children: [
                        Icon(Icons.archive_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Archive'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: _HabitAction.delete,
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppColors.danger,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Delete',
                          style: TextStyle(color: AppColors.danger),
                        ),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    _HabitAction action,
  ) async {
    if (action == _HabitAction.edit) {
      context.push(AppRoutes.editHabit, extra: habit);
    } else if (action == _HabitAction.archive) {
      final archived = habit.copyWith(
        archivedAt: DateTime.now().toUtc().toIso8601String(),
      );
      await ref.read(dataNotifierProvider.notifier).updateHabit(archived);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Habit archived'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                await ref
                    .read(dataNotifierProvider.notifier)
                    .updateHabit(habit);
              },
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Delete habit?'),
              content: Text(
                'All logs for "${habit.name}" will also be deleted. This cannot be undone.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                  ),
                  child: const Text('Delete'),
                ),
              ],
            ),
      );
      if (confirmed == true) {
        await ref.read(dataNotifierProvider.notifier).deleteHabit(habit.id);
      }
    }
  }
}

enum _HabitAction { edit, archive, delete }

// ── Archived habit tile ───────────────────────────────────

class _ArchivedHabitTile extends ConsumerWidget {
  final Habit habit;
  const _ArchivedHabitTile({required this.habit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color habitColor;
    try {
      habitColor = Color(
        int.parse('FF${habit.colorHex.replaceFirst('#', '')}', radix: 16),
      );
    } catch (_) {
      habitColor = Theme.of(context).colorScheme.primary;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: context.cardDecoration,
      child: Row(
        children: [
          Opacity(
            opacity: 0.5,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: habitColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(habit.icon, style: const TextStyle(fontSize: 22)),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: context.appColors.textSecondary,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: context.appColors.textSecondary,
                  ),
                ),
                Text(
                  'Archived',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.appColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          // Unarchive button
          IconButton(
            icon: Icon(
              Icons.unarchive_outlined,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            tooltip: 'Unarchive',
            onPressed: () async {
              // copyWith can't clear nullable fields to null via ??, so
              // construct a new Habit explicitly with archivedAt: null.
              final unarchived = Habit(
                id: habit.id,
                name: habit.name,
                icon: habit.icon,
                colorHex: habit.colorHex,
                progressType: habit.progressType,
                targetValue: habit.targetValue,
                unit: habit.unit,
                schedule: habit.schedule,
                scheduleDays: habit.scheduleDays,
                reminderTime: habit.reminderTime,
                createdAt: habit.createdAt,
                archivedAt: null,
                checklistItems: habit.checklistItems,
              );
              await ref
                  .read(dataNotifierProvider.notifier)
                  .updateHabit(unarchived);
            },
          ),
          // Delete button
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: AppColors.danger,
            ),
            tooltip: 'Delete permanently',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder:
                    (ctx) => AlertDialog(
                      title: const Text('Delete habit?'),
                      content: Text(
                        'All logs for "${habit.name}" will also be deleted permanently.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.danger,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
              );
              if (confirmed == true && context.mounted) {
                await ref
                    .read(dataNotifierProvider.notifier)
                    .deleteHabit(habit.id);
              }
            },
          ),
        ],
      ),
    );
  }
}

// ── Weekly card ───────────────────────────────────────────

class _WeeklyHabitCard extends StatelessWidget {
  final Habit habit;
  final List<HabitLog> logs;
  final DateTime today;
  final Color primary;

  const _WeeklyHabitCard({
    required this.habit,
    required this.logs,
    required this.today,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    Color habitColor;
    try {
      habitColor = Color(
        int.parse('FF${habit.colorHex.replaceFirst('#', '')}', radix: 16),
      );
    } catch (_) {
      habitColor = primary;
    }

    final week = HabitHelpers.weeklyCompletion(habit, logs, today);
    const dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: context.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(habit.icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Text(
                habit.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final done = week[i];
              return Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color:
                          done
                              ? habitColor
                              : habitColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child:
                        done
                            ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 14,
                            )
                            : null,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dayLabels[i],
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          i == today.weekday % 7
                              ? habitColor
                              : context.appColors.textMuted,
                      fontWeight:
                          i == today.weekday % 7
                              ? FontWeight.w700
                              : FontWeight.normal,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ── Mini ring ─────────────────────────────────────────────

class _MiniRing extends StatelessWidget {
  final int done;
  final int total;
  final Color color;

  const _MiniRing({
    required this.done,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? done / total : 0.0;
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: pct,
            strokeWidth: 4,
            backgroundColor: context.appColors.bgElevated,
            color: pct == 1.0 ? AppColors.success : color,
          ),
          Text(
            '$done',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: pct == 1.0 ? AppColors.success : color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Year heatmap card ─────────────────────────────────────

class _YearHeatmapCard extends StatefulWidget {
  final Habit habit;
  final List<HabitLog> logs;
  final DateTime today;
  final Color primary;

  const _YearHeatmapCard({
    required this.habit,
    required this.logs,
    required this.today,
    required this.primary,
  });

  @override
  State<_YearHeatmapCard> createState() => _YearHeatmapCardState();
}

class _YearHeatmapCardState extends State<_YearHeatmapCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _animCtrl.forward();
    } else {
      _animCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final habit = widget.habit;
    final logs = widget.logs;
    final today = widget.today;
    final primary = widget.primary;

    Color habitColor;
    try {
      habitColor = Color(
        int.parse('FF${habit.colorHex.replaceFirst('#', '')}', radix: 16),
      );
    } catch (_) {
      habitColor = primary;
    }

    // Map of dateStr → intensity (0=missed, 1–4=partial/full completion)
    final heatmap = HabitHelpers.yearlyHeatmap(habit, logs, today);
    final totalDone = heatmap.values.where((v) => v > 0).length;
    final createdAt =
        DateTime.tryParse(habit.createdAt)?.toLocal() ??
        today.subtract(const Duration(days: 365));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(16),
      decoration: context.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(habit.icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  habit.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                '$totalDone days done',
                style: TextStyle(
                  color: context.appColors.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              // Expand / collapse button
              GestureDetector(
                onTap: _toggle,
                child: AnimatedRotation(
                  turns: _expanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: habitColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: habitColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 350),
            firstCurve: Curves.easeInOut,
            secondCurve: Curves.easeInOut,
            crossFadeState:
                _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
            firstChild: _HeatmapGrid(
              today: today,
              heatmap: heatmap,
              habitColor: habitColor,
              startDate: createdAt,
            ),
            secondChild:
                _expanded
                    ? _ExpandedMonthGrid(
                      today: today,
                      heatmap: heatmap,
                      habitColor: habitColor,
                      createdAt: createdAt,
                    )
                    : const SizedBox(),
          ),
        ],
      ),
    );
  }
}

// ── Expanded 12-month grid (habits screen) ─────────────────

class _ExpandedMonthGrid extends StatelessWidget {
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

  const _ExpandedMonthGrid({
    required this.today,
    required this.heatmap,
    required this.habitColor,
    required this.createdAt,
  });

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Color _cellColor(int? v) {
    if (v == null) return habitColor.withValues(alpha: 0.06);
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
    final currentMonth = DateTime(today.year, today.month, 1);
    final months = List.generate(12, (i) {
      return DateTime(currentMonth.year, currentMonth.month - (11 - i), 1);
    });
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final createdMidnight = DateTime(
      createdAt.year,
      createdAt.month,
      createdAt.day,
    );

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 0.82,
      ),
      itemCount: 12,
      itemBuilder: (_, idx) {
        final monthStart = months[idx];
        final firstWeekday = (monthStart.weekday - 1) % 7;
        final daysInMonth = DateUtils.getDaysInMonth(
          monthStart.year,
          monthStart.month,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_monthNames[monthStart.month - 1]} ${monthStart.year}',
              style: TextStyle(
                color: context.appColors.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: List.generate(
                7,
                (d) => Expanded(
                  child: Text(
                    _dayLabels[d],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.appColors.textMuted,
                      fontSize: 6,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                  childAspectRatio: 1,
                ),
                itemCount: 42,
                itemBuilder: (_, cellIdx) {
                  final dayOffset = cellIdx - firstWeekday;
                  if (dayOffset < 0 || dayOffset >= daysInMonth) {
                    return const SizedBox();
                  }
                  final day = DateTime(
                    monthStart.year,
                    monthStart.month,
                    dayOffset + 1,
                  );
                  if (day.isAfter(todayMidnight)) return const SizedBox();
                  if (day.isBefore(createdMidnight)) return const SizedBox();
                  final v = heatmap[_fmt(day)];
                  return Container(
                    decoration: BoxDecoration(
                      color: _cellColor(v),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Heatmap grid ──────────────────────────────────────────

class _HeatmapGrid extends StatelessWidget {
  final DateTime today;
  final Map<String, int> heatmap; // dateStr → 0–4
  final Color habitColor;
  final DateTime? startDate; // if provided, grid starts from here

  static const _cellSize = 13.0;
  static const _cellGap = 3.0;
  static const _dayLabelWidth = 22.0;

  const _HeatmapGrid({
    required this.today,
    required this.heatmap,
    required this.habitColor,
    this.startDate,
  });

  DateTime _weekStart(DateTime date) {
    final diff = (date.weekday - DateTime.monday + 7) % 7;
    return DateTime(date.year, date.month, date.day - diff);
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Color _cellColor(int? intensity) {
    if (intensity == null) return habitColor.withValues(alpha: 0.06);
    switch (intensity) {
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
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final currentWeekStart = _weekStart(todayMidnight);

    // Start from habit creation date if provided, else fall back to 53 weeks
    final effectiveStart =
        startDate != null
            ? DateTime(startDate!.year, startDate!.month, startDate!.day)
            : todayMidnight.subtract(const Duration(days: 52 * 7));
    final firstWeekStart = _weekStart(effectiveStart);

    final numWeeks =
        (currentWeekStart.difference(firstWeekStart).inDays ~/ 7) + 1;

    final weeks = List.generate(
      numWeeks,
      (w) => firstWeekStart.add(Duration(days: w * 7)),
    );

    const monthNames = [
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
    final monthLabels = <int, String>{};
    int? lastMonth;
    for (int w = 0; w < weeks.length; w++) {
      final m = weeks[w].month;
      if (m != lastMonth) {
        monthLabels[w] = monthNames[m - 1];
        lastMonth = m;
      }
    }

    final colWidth = _cellSize + _cellGap;
    final gridWidth = _dayLabelWidth + numWeeks * colWidth;
    final gridHeight = 20.0 + 7 * (_cellSize + _cellGap);
    final todayKey = _dateKey(todayMidnight);

    // Build all positioned widgets in a flat list to avoid Builder-in-Stack.
    final stackChildren = <Widget>[];

    // Day labels (Mon / Wed / Fri on rows 0, 2, 4)
    for (int row = 0; row < 7; row++) {
      if (row != 0 && row != 2 && row != 4) continue;
      stackChildren.add(
        Positioned(
          left: 0,
          top: 20 + row * (_cellSize + _cellGap) + (_cellSize - 10) / 2,
          child: SizedBox(
            width: _dayLabelWidth - 4,
            child: Text(
              ['M', 'T', 'W', 'T', 'F', 'S', 'S'][row],
              style: TextStyle(fontSize: 9, color: context.appColors.textMuted),
            ),
          ),
        ),
      );
    }

    // Month labels
    for (final entry in monthLabels.entries) {
      stackChildren.add(
        Positioned(
          left: _dayLabelWidth + entry.key * colWidth,
          top: 0,
          child: Text(
            entry.value,
            style: TextStyle(fontSize: 9, color: context.appColors.textMuted),
          ),
        ),
      );
    }

    // Cells
    for (int w = 0; w < numWeeks; w++) {
      for (int row = 0; row < 7; row++) {
        final cellDate = weeks[w].add(Duration(days: row));
        if (cellDate.isAfter(todayMidnight)) continue;
        final key = _dateKey(cellDate);
        final intensity = heatmap[key]; // null = not scheduled
        final isToday = key == todayKey;

        stackChildren.add(
          Positioned(
            left: _dayLabelWidth + w * colWidth,
            top: 20 + row * (_cellSize + _cellGap),
            child: Container(
              width: _cellSize,
              height: _cellSize,
              decoration: BoxDecoration(
                color: _cellColor(intensity),
                borderRadius: BorderRadius.circular(3),
                border:
                    isToday ? Border.all(color: habitColor, width: 1.5) : null,
              ),
            ),
          ),
        );
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: gridWidth,
        height: gridHeight,
        child: Stack(children: stackChildren),
      ),
    );
  }
}
