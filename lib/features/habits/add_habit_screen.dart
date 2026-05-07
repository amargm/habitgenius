import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme_extension.dart';
import '../../core/models/habit.dart';
import '../../core/providers/data_provider.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/permission_service.dart';
import '../../core/utils/app_toast.dart';

// ── Emoji picker data ──────────────────────────────────────

const _kEmojis = [
  '💪',
  '🏃',
  '🧘',
  '💤',
  '💧',
  '🥗',
  '📚',
  '✍️',
  '🎨',
  '🎸',
  '🧹',
  '🛁',
  '💊',
  '☀️',
  '🌙',
  '🧠',
  '❤️',
  '🌿',
  '🔥',
  '⭐',
  '🎯',
  '📖',
  '🏋️',
  '🚴',
  '🧗',
  '🏊',
  '🤸',
  '🎵',
  '🎮',
  '🌍',
];

const _kColors = [
  '#6C5CE7',
  '#0984E3',
  '#00B894',
  '#E17055',
  '#FDCB6E',
  '#A29BFE',
  '#00CEC9',
  '#FD79A8',
  '#636E72',
  '#2D3436',
];

// ── Habit template ─────────────────────────────────────────

class HabitTemplate {
  final String name;
  final String emoji;
  final String colorHex;
  final HabitSchedule schedule;
  final String description;

  const HabitTemplate({
    required this.name,
    required this.emoji,
    required this.colorHex,
    required this.description,
    this.schedule = HabitSchedule.daily,
  });
}

const kHabitTemplates = [
  HabitTemplate(
    name: 'Morning Run',
    emoji: '🏃',
    colorHex: '#0984E3',
    description: 'Get moving every morning',
  ),
  HabitTemplate(
    name: 'Drink Water',
    emoji: '💧',
    colorHex: '#00CEC9',
    description: 'Stay hydrated throughout the day',
  ),
  HabitTemplate(
    name: 'Read',
    emoji: '📚',
    colorHex: '#6C5CE7',
    description: 'Read every day for personal growth',
  ),
  HabitTemplate(
    name: 'Meditation',
    emoji: '🧘',
    colorHex: '#A29BFE',
    description: 'Calm your mind daily',
  ),
  HabitTemplate(
    name: 'Sleep Early',
    emoji: '💤',
    colorHex: '#636E72',
    description: 'Get to bed at a consistent time',
  ),
  HabitTemplate(
    name: 'Workout',
    emoji: '🏋️',
    colorHex: '#E17055',
    description: 'Strength training or cardio',
  ),
  HabitTemplate(
    name: 'Journaling',
    emoji: '✍️',
    colorHex: '#FDCB6E',
    description: 'Reflect on your day in writing',
  ),
  HabitTemplate(
    name: 'Healthy Eating',
    emoji: '🥗',
    colorHex: '#00B894',
    description: 'Eat nutritious meals every day',
  ),
  HabitTemplate(
    name: 'Learn Something',
    emoji: '🧠',
    colorHex: '#6C5CE7',
    description: 'Dedicate time to learning daily',
  ),
  HabitTemplate(
    name: 'Vitamins & Meds',
    emoji: '💊',
    colorHex: '#E17055',
    description: 'Take your daily supplements',
  ),
  HabitTemplate(
    name: 'Walk Outside',
    emoji: '☀️',
    colorHex: '#FDCB6E',
    description: 'Get fresh air and sunlight',
  ),
  HabitTemplate(
    name: 'Digital Detox',
    emoji: '📵',
    colorHex: '#2D3436',
    description: 'Disconnect from screens for a while',
  ),
  HabitTemplate(
    name: 'Stretch',
    emoji: '🤸',
    colorHex: '#00CEC9',
    description: 'Keep your body flexible',
  ),
  HabitTemplate(
    name: 'Practice Music',
    emoji: '🎸',
    colorHex: '#FDCB6E',
    description: 'Practice your instrument daily',
  ),
  HabitTemplate(
    name: 'Gratitude',
    emoji: '❤️',
    colorHex: '#FD79A8',
    description: 'Note three things you\'re thankful for',
  ),
  HabitTemplate(
    name: 'No Social Media',
    emoji: '🌿',
    colorHex: '#00B894',
    description: 'Take a break from social media',
  ),
];

// ── Screen ────────────────────────────────────────────────

class AddHabitScreen extends ConsumerStatefulWidget {
  final Habit? initialHabit;
  final HabitTemplate? template;
  const AddHabitScreen({super.key, this.initialHabit, this.template});

  @override
  ConsumerState<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends ConsumerState<AddHabitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _targetCtrl = TextEditingController(text: '1');
  final _unitCtrl = TextEditingController();

  HabitProgressType _progressType = HabitProgressType.checkbox;
  HabitSchedule _schedule = HabitSchedule.daily;
  List<int> _scheduleDays = [];
  // UI-level schedule preset; maps to HabitSchedule + scheduleDays on save.
  _SchedulePreset _schedulePreset = _SchedulePreset.daily;
  String _emoji = '💪';
  String _colorHex = '#6C5CE7';
  TimeOfDay? _reminderTime;
  bool _saving = false;
  // True when user explicitly taps a progress type chip (required for templates)
  bool _progressTypeChosen = false;

  bool get _isEditing => widget.initialHabit != null;
  bool get _isTemplate => widget.template != null && !_isEditing;

  @override
  void initState() {
    super.initState();
    final h = widget.initialHabit;
    if (h != null) {
      _nameCtrl.text = h.name;
      _targetCtrl.text = h.targetValue.toString();
      _unitCtrl.text = h.unit ?? '';
      _progressType = h.progressType;
      _schedule = h.schedule;
      _scheduleDays = List<int>.from(h.scheduleDays);
      _schedulePreset = _SchedulePreset.fromHabit(h.schedule, h.scheduleDays);
      _emoji = h.icon;
      _colorHex = h.colorHex;
      if (h.reminderTime != null) {
        final parts = h.reminderTime!.split(':');
        if (parts.length == 2) {
          _reminderTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 8,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
    } else if (widget.template != null) {
      // Pre-fill from template; user must still choose progress type.
      final t = widget.template!;
      _nameCtrl.text = t.name;
      _emoji = t.emoji;
      _colorHex = t.colorHex;
      _schedule = t.schedule;
      _scheduleDays = [];
      _schedulePreset = _SchedulePreset.daily;
      // Do NOT pre-select progress type — user must choose.
      _progressTypeChosen = false;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isTemplate && !_progressTypeChosen) {
      AppToast.show(context, 'Please choose how you will track this habit.');
      return;
    }
    if ((_schedule == HabitSchedule.specific ||
            _schedule == HabitSchedule.weekly) &&
        _scheduleDays.isEmpty) {
      AppToast.show(context, 'Select at least one day.');
      return;
    }
    if (_schedule == HabitSchedule.monthly && _scheduleDays.isEmpty) {
      AppToast.show(context, 'Select a day of the month.');
      return;
    }
    setState(() => _saving = true);

    try {
      final reminderStr =
          _reminderTime != null
              ? '${_reminderTime!.hour.toString().padLeft(2, '0')}:${_reminderTime!.minute.toString().padLeft(2, '0')}'
              : null;

      final habit = Habit(
        id: _isEditing ? widget.initialHabit!.id : const Uuid().v4(),
        name: _nameCtrl.text.trim(),
        icon: _emoji,
        colorHex: _colorHex,
        progressType: _progressType,
        targetValue: int.tryParse(_targetCtrl.text) ?? 1,
        unit: _unitCtrl.text.trim().isEmpty ? null : _unitCtrl.text.trim(),
        schedule: _schedule,
        scheduleDays: _scheduleDays,
        reminderTime: reminderStr,
        createdAt:
            _isEditing
                ? widget.initialHabit!.createdAt
                : DateTime.now().toUtc().toIso8601String(),
        archivedAt: _isEditing ? widget.initialHabit!.archivedAt : null,
        checklistItems:
            _isEditing ? widget.initialHabit!.checklistItems : const [],
      );

      if (_isEditing) {
        // If the reminder was removed during editing, cancel the old notification.
        if (widget.initialHabit!.reminderTime != null && reminderStr == null) {
          await NotificationService.cancelHabitReminder(habit.id);
        }
        await ref.read(dataNotifierProvider.notifier).updateHabit(habit);
      } else {
        await ref.read(dataNotifierProvider.notifier).addHabit(habit);
      }

      if (_reminderTime != null) {
        await NotificationService.scheduleHabitReminder(
          habitId: habit.id,
          habitName: habit.name,
          timeOfDay: _reminderTime!,
          scheduleDays: _scheduleDays,
          schedule: _schedule,
        );
      }

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          'Could not save habit. Please try again.',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickReminder() async {
    // Ask for notification permission contextually before showing the time
    // picker — the user is clearly about to set a reminder.
    final granted = await PermissionService.instance.notificationsGranted;
    if (!granted) {
      if (!mounted) return;
      final allow = await PermissionService.instance.requestNotifications(
        context,
      );
      if (!allow) return; // User declined — don't show time picker.
    }
    if (!mounted) return;
    // Ensure exact-alarm permission is granted (required on Android 12).
    await PermissionService.instance.requestExactAlarm(context);
    if (!mounted) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? const TimeOfDay(hour: 8, minute: 0),
      helpText: 'REMINDER TIME',
    );
    if (picked != null) setState(() => _reminderTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? 'Edit Habit'
              : _isTemplate
              ? 'Customise Template'
              : 'New Habit',
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child:
                _saving
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : Text(
                      'Save',
                      style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Emoji + Name ──────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _showEmojiPicker,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: context.cardDecorationR(14),
                    child: Center(
                      child: Text(_emoji, style: const TextStyle(fontSize: 28)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Habit name',
                      hintText: 'e.g. Morning run',
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    validator:
                        (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Enter a habit name'
                                : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Progress type ──────────────────────────────
            // When using a template, show a required-selection banner.
            if (_isTemplate && !_progressTypeChosen)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Choose how you want to track this habit (required)',
                        style: TextStyle(
                          fontSize: 13,
                          color: primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            _SectionLabel('Progress type'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children:
                  HabitProgressType.values
                      .where((pt) => pt != HabitProgressType.stopwatch)
                      .map((pt) {
                        final selected =
                            _progressType == pt &&
                            (_progressTypeChosen || !_isTemplate);
                        return ChoiceChip(
                          label: Text(_progressLabel(pt)),
                          selected: selected,
                          onSelected:
                              (_) => setState(() {
                                _progressType = pt;
                                _progressTypeChosen = true;
                              }),
                        );
                      })
                      .toList(),
            ),
            if (_progressType == HabitProgressType.counter ||
                _progressType == HabitProgressType.timer) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _targetCtrl,
                      decoration: InputDecoration(
                        labelText:
                            _progressType == HabitProgressType.timer
                                ? 'Target (minutes)'
                                : 'Target count',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n < 1) {
                          return 'Enter a positive number';
                        }
                        if (n > 9999) return 'Maximum is 9999';
                        return null;
                      },
                    ),
                  ),
                  if (_progressType == HabitProgressType.counter) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _unitCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Unit (optional)',
                          hintText: 'e.g. glasses',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 24),

            // ── Schedule ──────────────────────────────────
            _SectionLabel('Schedule'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  _SchedulePreset.values.map((p) {
                    final selected = _schedulePreset == p;
                    return ChoiceChip(
                      label: Text(p.label),
                      selected: selected,
                      onSelected: (_) {
                        setState(() {
                          _schedulePreset = p;
                          _schedule = p.habitSchedule;
                          _scheduleDays = p.defaultDays;
                        });
                      },
                    );
                  }).toList(),
            ),
            // Day-of-week picker (weekly & custom)
            if (_schedulePreset == _SchedulePreset.weekly ||
                _schedulePreset == _SchedulePreset.custom) ...[
              const SizedBox(height: 12),
              _DayPicker(
                selected: _scheduleDays,
                onChanged: (days) => setState(() => _scheduleDays = days),
              ),
            ],
            // Day-of-month picker (monthly)
            if (_schedulePreset == _SchedulePreset.monthly) ...[
              const SizedBox(height: 12),
              _MonthDayPicker(
                selected: _scheduleDays.isNotEmpty ? _scheduleDays.first : 1,
                onChanged: (d) => setState(() => _scheduleDays = [d]),
              ),
              if (_scheduleDays.isNotEmpty && _scheduleDays.first >= 29) ...[
                const SizedBox(height: 8),
                Text(
                  'Note: reminder will be skipped in months shorter than '
                  '${_scheduleDays.first} days.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 24),

            // ── Color ─────────────────────────────────────
            _SectionLabel('Colour'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children:
                  _kColors.map((hex) {
                    final color = _parseColor(hex);
                    final selected = _colorHex == hex;
                    return GestureDetector(
                      onTap: () => setState(() => _colorHex = hex),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border:
                              selected
                                  ? Border.all(color: Colors.white, width: 2.5)
                                  : null,
                        ),
                        child:
                            selected
                                ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 16,
                                )
                                : null,
                      ),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 24),

            // ── Reminder ──────────────────────────────────
            _SectionLabel('Reminder (optional)'),
            const SizedBox(height: 10),
            _ReminderTile(
              time: _reminderTime,
              onTap: _pickReminder,
              onClear: () => setState(() => _reminderTime = null),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (_) => Container(
            decoration: BoxDecoration(
              color: context.appColors.bgCard,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children:
                      _kEmojis
                          .map(
                            (e) => GestureDetector(
                              onTap: () {
                                setState(() => _emoji = e);
                                Navigator.pop(context);
                              },
                              child: Text(
                                e,
                                style: const TextStyle(fontSize: 32),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ],
            ),
          ),
    );
  }

  static Color _parseColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF6C5CE7);
    }
  }

  static String _progressLabel(HabitProgressType t) {
    switch (t) {
      case HabitProgressType.checkbox:
        return 'Checkbox';
      case HabitProgressType.counter:
        return 'Counter';
      case HabitProgressType.timer:
        return 'Timer';
      case HabitProgressType.stopwatch:
        return 'Stopwatch';
      case HabitProgressType.checklist:
        return 'Checklist';
    }
  }
}

// ── Schedule preset (UI helper) ───────────────────────────

enum _SchedulePreset {
  daily,
  weekdays,
  weekends,
  weekly,
  monthly,
  custom;

  String get label {
    switch (this) {
      case _SchedulePreset.daily:
        return 'Daily';
      case _SchedulePreset.weekdays:
        return 'Weekdays';
      case _SchedulePreset.weekends:
        return 'Weekends';
      case _SchedulePreset.weekly:
        return 'Weekly';
      case _SchedulePreset.monthly:
        return 'Monthly';
      case _SchedulePreset.custom:
        return 'Custom';
    }
  }

  HabitSchedule get habitSchedule {
    switch (this) {
      case _SchedulePreset.daily:
        return HabitSchedule.daily;
      case _SchedulePreset.weekdays:
      case _SchedulePreset.weekends:
      case _SchedulePreset.custom:
        return HabitSchedule.specific;
      case _SchedulePreset.weekly:
        return HabitSchedule.weekly;
      case _SchedulePreset.monthly:
        return HabitSchedule.monthly;
    }
  }

  List<int> get defaultDays {
    switch (this) {
      case _SchedulePreset.daily:
        return [];
      case _SchedulePreset.weekdays:
        return [1, 2, 3, 4, 5]; // Mon–Fri
      case _SchedulePreset.weekends:
        return [0, 6]; // Sun, Sat
      case _SchedulePreset.weekly:
        return [DateTime.now().weekday % 7]; // today's weekday
      case _SchedulePreset.monthly:
        return [DateTime.now().day]; // today's date
      case _SchedulePreset.custom:
        return [];
    }
  }

  static _SchedulePreset fromHabit(HabitSchedule s, List<int> days) {
    switch (s) {
      case HabitSchedule.daily:
        return _SchedulePreset.daily;
      case HabitSchedule.weekly:
        return _SchedulePreset.weekly;
      case HabitSchedule.monthly:
        return _SchedulePreset.monthly;
      case HabitSchedule.specific:
      case HabitSchedule.custom:
        final sorted = [...days]..sort();
        if (sorted.length == 5 &&
            sorted.every((d) => [1, 2, 3, 4, 5].contains(d))) {
          return _SchedulePreset.weekdays;
        }
        if (sorted.length == 2 && sorted.every((d) => [0, 6].contains(d))) {
          return _SchedulePreset.weekends;
        }
        return _SchedulePreset.custom;
    }
  }
}

// ── Helper widgets ────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.titleSmall?.copyWith(
      color: context.appColors.textSecondary,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
    ),
  );
}

class _DayPicker extends StatelessWidget {
  final List<int> selected;
  final ValueChanged<List<int>> onChanged;

  const _DayPicker({required this.selected, required this.onChanged});

  static const _labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: List.generate(7, (i) {
        final sel = selected.contains(i);
        return GestureDetector(
          onTap: () {
            final updated = [...selected];
            sel ? updated.remove(i) : updated.add(i);
            onChanged(updated);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 8),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: sel ? primary : context.appColors.bgCard,
              shape: BoxShape.circle,
              border: Border.all(
                color: sel ? primary : context.appColors.border,
              ),
            ),
            child: Center(
              child: Text(
                _labels[i],
                style: TextStyle(
                  color: sel ? Colors.white : context.appColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Month-day picker (day 1–31 for monthly habits) ────────

class _MonthDayPicker extends StatelessWidget {
  final int selected; // 1-31
  final ValueChanged<int> onChanged;

  const _MonthDayPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(31, (i) {
        final day = i + 1;
        final sel = selected == day;
        return GestureDetector(
          onTap: () => onChanged(day),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: sel ? primary : context.appColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: sel ? primary : context.appColors.border,
              ),
            ),
            child: Center(
              child: Text(
                '$day',
                style: TextStyle(
                  color: sel ? Colors.white : context.appColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  final TimeOfDay? time;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _ReminderTile({
    required this.time,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.appColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                time != null
                    ? primary.withValues(alpha: 0.4)
                    : Colors.transparent,
          ),
          boxShadow: context.appColors.cardShadow,
        ),
        child: Row(
          children: [
            Icon(
              Icons.notifications_outlined,
              color: time != null ? primary : AppColors.textMuted,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              time != null ? time!.format(context) : 'Set reminder time',
              style: TextStyle(
                color: time != null ? AppColors.text : AppColors.textMuted,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            if (time != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
