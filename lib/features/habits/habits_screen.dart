import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_limits.dart';
import '../../core/models/habit.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/data_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/habit_helpers.dart';
import '../../shared/widgets/habit_check_widget.dart';
import '../../shared/widgets/upgrade_prompt_sheet.dart';

// ── View enum ─────────────────────────────────────────────

enum _HabitView { today, week, all }

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
    final logs = appData.habitLogs;
    final today = DateTime.now();
    final todayStr = HabitHelpers.todayStr();

    final todayHabits = HabitHelpers.habitsForDate(habits, today);
    final doneToday = todayHabits
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
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (todayHabits.isNotEmpty)
                          Text(
                            '$doneToday / ${todayHabits.length} done today',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
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
                children: _HabitView.values.map((v) {
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
                          color: sel
                              ? Theme.of(context).colorScheme.primary
                              : AppColors.bgCard,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel
                                ? Theme.of(context).colorScheme.primary
                                : AppColors.border,
                          ),
                        ),
                        child: Text(
                          _viewLabel(v),
                          style: TextStyle(
                            color: sel ? Colors.white : AppColors.textSecondary,
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
              child: habits.isEmpty
                  ? _EmptyState(tier: tier)
                  : _buildView(
                      habits: habits,
                      logs: logs,
                      today: today,
                      todayStr: todayStr,
                      primary: Theme.of(context).colorScheme.primary,
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
    required List logs,
    required DateTime today,
    required String todayStr,
    required Color primary,
  }) {
    switch (_view) {
      case _HabitView.today:
        final forToday = HabitHelpers.habitsForDate(habits, today);
        return forToday.isEmpty
            ? const _NoTodayHabits()
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                itemCount: forToday.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _HabitTile(
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
          itemBuilder: (_, i) => _WeeklyHabitCard(
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
          itemBuilder: (_, i) => _HabitTile(
            habit: habits[i],
            logs: logs,
            dateStr: todayStr,
            primary: primary,
          ),
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
    }
  }
}

// ── Habit tile ────────────────────────────────────────────

class _HabitTile extends StatelessWidget {
  final Habit habit;
  final List logs;
  final String dateStr;
  final Color primary;

  const _HabitTile({
    required this.habit,
    required this.logs,
    required this.dateStr,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    Color habitColor;
    try {
      habitColor = Color(
          int.parse('FF${habit.colorHex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      habitColor = primary;
    }
    final streak = HabitHelpers.currentStreak(habit, logs, DateTime.now());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
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
                child: Text(habit.icon, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(habit.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                if (streak > 0)
                  Row(
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text('$streak day streak',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
              ],
            ),
          ),
          HabitCheckWidget(habit: habit, dateStr: dateStr),
        ],
      ),
    );
  }
}

// ── Weekly card ───────────────────────────────────────────

class _WeeklyHabitCard extends StatelessWidget {
  final Habit habit;
  final List logs;
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
          int.parse('FF${habit.colorHex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      habitColor = primary;
    }

    final week = HabitHelpers.weeklyCompletion(habit, logs, today);
    const dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

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
          Row(
            children: [
              Text(habit.icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Text(habit.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15)),
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
                      color: done
                          ? habitColor
                          : habitColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: done
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 14)
                        : null,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dayLabels[i],
                    style: TextStyle(
                      fontSize: 11,
                      color: i == today.weekday % 7
                          ? habitColor
                          : AppColors.textMuted,
                      fontWeight: i == today.weekday % 7
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

  const _MiniRing(
      {required this.done, required this.total, required this.color});

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
            backgroundColor: AppColors.bgElevated,
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

// ── Empty states ──────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final dynamic tier;
  const _EmptyState({required this.tier});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💪', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              const Text('No habits yet',
                  style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text(
                'Tap + to add your first habit.',
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

class _NoTodayHabits extends StatelessWidget {
  const _NoTodayHabits();

  @override
  Widget build(BuildContext context) => const Center(
        child: Text(
          'No habits scheduled for today',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
}

