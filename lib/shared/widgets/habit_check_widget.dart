import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme_extension.dart';
import '../../core/models/habit.dart';
import '../../core/providers/data_provider.dart';
import '../../core/utils/habit_helpers.dart';

/// Renders the interactive progress control for a single habit tile.
/// Adapts its appearance and tap behaviour to [habit.progressType].
class HabitCheckWidget extends ConsumerWidget {
  final Habit habit;
  final String dateStr; // YYYY-MM-DD

  const HabitCheckWidget({
    super.key,
    required this.habit,
    required this.dateStr,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(appDataProvider).habitLogs;
    final log = HabitHelpers.logForDate(logs, habit.id, dateStr);
    final isCompleted = HabitHelpers.isCompletedOn(habit, logs, dateStr);
    final primary = Theme.of(context).colorScheme.primary;
    final color = _habitColor(habit.colorHex, primary);

    switch (habit.progressType) {
      case HabitProgressType.checkbox:
      case HabitProgressType.checklist:
      case HabitProgressType.stopwatch:
        return _CheckboxControl(
          isCompleted: isCompleted,
          color: color,
          onTap: () => _toggle(ref),
        );

      case HabitProgressType.counter:
        return _CounterControl(
          current: log?.value ?? 0,
          target: habit.targetValue,
          unit: habit.unit ?? '',
          color: color,
          isCompleted: isCompleted,
          onIncrement: () => _increment(ref, 1),
          onDecrement: () => _increment(ref, -1),
        );

      case HabitProgressType.timer:
        return _TimerControl(
          current: log?.value ?? 0,
          target: habit.targetValue,
          unit: habit.unit ?? 'min',
          color: color,
          isCompleted: isCompleted,
          onTap: () => _toggle(ref),
        );
    }
  }

  Future<void> _toggle(WidgetRef ref) async {
    HapticFeedback.lightImpact();
    await ref
        .read(dataNotifierProvider.notifier)
        .toggleHabit(habitId: habit.id, dateStr: dateStr);
  }

  Future<void> _increment(WidgetRef ref, int delta) async {
    HapticFeedback.selectionClick();
    await ref
        .read(dataNotifierProvider.notifier)
        .toggleHabit(habitId: habit.id, dateStr: dateStr, delta: delta);
  }

  static Color _habitColor(String hex, Color fallback) {
    try {
      final v = hex.replaceFirst('#', '');
      return Color(int.parse('FF$v', radix: 16));
    } catch (_) {
      return fallback;
    }
  }
}

// ── Checkbox ──────────────────────────────────────────────

class _CheckboxControl extends StatelessWidget {
  final bool isCompleted;
  final Color color;
  final VoidCallback onTap;

  const _CheckboxControl({
    required this.isCompleted,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isCompleted ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCompleted ? color : context.appColors.textMuted,
            width: 2,
          ),
        ),
        child:
            isCompleted
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                : null,
      ),
    );
  }
}

// ── Counter ───────────────────────────────────────────────

class _CounterControl extends StatelessWidget {
  final int current;
  final int target;
  final String unit;
  final Color color;
  final bool isCompleted;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _CounterControl({
    required this.current,
    required this.target,
    required this.unit,
    required this.color,
    required this.isCompleted,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: current > 0 ? onDecrement : null,
          child: Icon(
            Icons.remove_circle_outline_rounded,
            color:
                current > 0
                    ? context.appColors.textSecondary
                    : context.appColors.textMuted,
            size: 22,
          ),
        ),
        const SizedBox(width: 8),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            color: isCompleted ? color : context.appColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          child: Text('$current/$target ${unit.isEmpty ? '' : unit}'),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onIncrement,
          child: Icon(
            Icons.add_circle_rounded,
            color: isCompleted ? color : context.appColors.textSecondary,
            size: 22,
          ),
        ),
      ],
    );
  }
}

// ── Timer ─────────────────────────────────────────────────

class _TimerControl extends StatelessWidget {
  final int current;
  final int target;
  final String unit;
  final Color color;
  final bool isCompleted;
  final VoidCallback onTap;

  const _TimerControl({
    required this.current,
    required this.target,
    required this.unit,
    required this.color,
    required this.isCompleted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pct = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              value: pct,
              strokeWidth: 3,
              backgroundColor: context.appColors.bgElevated,
              color: isCompleted ? color : context.appColors.textSecondary,
            ),
          ),
          Icon(
            isCompleted ? Icons.check_rounded : Icons.play_arrow_rounded,
            size: 16,
            color: isCompleted ? color : context.appColors.textMuted,
          ),
        ],
      ),
    );
  }
}
