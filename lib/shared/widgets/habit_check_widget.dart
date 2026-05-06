import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme_extension.dart';
import '../../core/models/habit.dart';
import '../../core/providers/data_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/utils/habit_helpers.dart';
import 'celebration_overlay.dart';

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
          onTap: () => _toggle(context, ref),
        );

      case HabitProgressType.counter:
        return _CounterControl(
          current: log?.value ?? 0,
          target: habit.targetValue,
          unit: habit.unit ?? '',
          color: color,
          isCompleted: isCompleted,
          onIncrement: () => _increment(context, ref, 1),
          onDecrement: () => _increment(context, ref, -1),
        );

      case HabitProgressType.timer:
        return _TimerControl(
          current: log?.value ?? 0,
          target: habit.targetValue,
          unit: habit.unit ?? 'min',
          color: color,
          isCompleted: isCompleted,
          onTap:
              () =>
                  isCompleted
                      ? _confirmUndoTimer(context, ref)
                      : _pickTimer(context, ref),
        );
    }
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();
    final wasDone = HabitHelpers.isCompletedOn(
      habit,
      ref.read(appDataProvider).habitLogs,
      dateStr,
    );
    await ref
        .read(dataNotifierProvider.notifier)
        .toggleHabit(habitId: habit.id, dateStr: dateStr);
    // Celebration on transition to completed
    if (!wasDone && context.mounted) {
      final prefs = ref.read(sharedPreferencesProvider);
      final master = prefs.getBool(PrefKeys.celebrationHaptic) ?? true;
      if (master) _celebrate(context, prefs);
    }
  }

  /// Shows a minute-picker sheet so the user can log time for a timer habit.
  Future<void> _pickTimer(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();
    final logs = ref.read(appDataProvider).habitLogs;
    final current =
        HabitHelpers.logForDate(logs, habit.id, dateStr)?.value ?? 0;
    final result = await _showMinutePicker(context, current, habit.targetValue);
    if (result == null || !context.mounted) return;
    // Store as delta from current value; skip if nothing changed.
    final delta = result - current;
    if (delta == 0) return;
    await ref
        .read(dataNotifierProvider.notifier)
        .toggleHabit(habitId: habit.id, dateStr: dateStr, delta: delta);
    final nowDone = HabitHelpers.isCompletedOn(
      habit,
      ref.read(appDataProvider).habitLogs,
      dateStr,
    );
    if (nowDone && context.mounted) {
      final prefs = ref.read(sharedPreferencesProvider);
      final master = prefs.getBool(PrefKeys.celebrationHaptic) ?? true;
      if (master) _celebrate(context, prefs);
    }
  }

  /// Confirms with the user before clearing a timer habit log.
  Future<void> _confirmUndoTimer(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Undo progress?'),
            content: const Text(
              'This will clear the time logged for today. Are you sure?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Clear'),
              ),
            ],
          ),
    );
    if (confirm == true && context.mounted) {
      // Pass a large negative delta so the timer value clamps to 0 (cleared).
      final logs = ref.read(appDataProvider).habitLogs;
      final currentVal =
          HabitHelpers.logForDate(logs, habit.id, dateStr)?.value ?? 0;
      await ref
          .read(dataNotifierProvider.notifier)
          .toggleHabit(habitId: habit.id, dateStr: dateStr, delta: -currentVal);
    }
  }

  /// Shows a bottom sheet to pick minutes (0–180) for timer habits.
  Future<int?> _showMinutePicker(
    BuildContext context,
    int current,
    int target,
  ) {
    final maxMins = (target * 1.5).clamp(30, 240).toInt();
    // Clamp the initial value so it never exceeds the slider max.
    int val = current.clamp(0, maxMins);
    return showModalBottomSheet<int>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setState) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Log time for ${habit.name}',
                          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed:
                                  val > 0 ? () => setState(() => val--) : null,
                              icon: const Icon(Icons.remove_rounded),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 72,
                              child: Text(
                                '$val min',
                                textAlign: TextAlign.center,
                                style: Theme.of(ctx).textTheme.headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed:
                                  () => setState(
                                    () => val = (val + 1).clamp(0, maxMins),
                                  ),
                              icon: const Icon(Icons.add_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Slider(
                          min: 0,
                          max: maxMins.toDouble(),
                          divisions: maxMins,
                          value: val.toDouble(),
                          onChanged: (v) => setState(() => val = v.round()),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => Navigator.pop(ctx, val),
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  Future<void> _increment(
    BuildContext context,
    WidgetRef ref,
    int delta,
  ) async {
    HapticFeedback.selectionClick();
    final wasDone = HabitHelpers.isCompletedOn(
      habit,
      ref.read(appDataProvider).habitLogs,
      dateStr,
    );
    await ref
        .read(dataNotifierProvider.notifier)
        .toggleHabit(habitId: habit.id, dateStr: dateStr, delta: delta);
    if (!wasDone && delta > 0) {
      final nowDone = HabitHelpers.isCompletedOn(
        habit,
        ref.read(appDataProvider).habitLogs,
        dateStr,
      );
      if (nowDone && context.mounted) {
        final prefs = ref.read(sharedPreferencesProvider);
        final master = prefs.getBool(PrefKeys.celebrationHaptic) ?? true;
        if (master) _celebrate(context, prefs);
      }
    }
  }

  void _celebrate(BuildContext context, SharedPreferences prefs) {
    final vibration = prefs.getBool(PrefKeys.celebrationVibration) ?? true;
    final sound = prefs.getBool(PrefKeys.celebrationSound) ?? true;
    final visual = prefs.getBool(PrefKeys.celebrationVisual) ?? true;

    if (vibration) {
      HapticFeedback.heavyImpact();
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        HapticFeedback.mediumImpact();
      });
      Future<void>.delayed(const Duration(milliseconds: 240), () {
        HapticFeedback.lightImpact();
      });
    }

    if (sound) {
      SystemSound.play(SystemSoundType.click);
    }

    if (visual && context.mounted) {
      CelebrationOverlay.show(context);
    }
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
