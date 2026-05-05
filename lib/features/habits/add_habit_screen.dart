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

// ── Screen ────────────────────────────────────────────────

class AddHabitScreen extends ConsumerStatefulWidget {
  final Habit? initialHabit;
  const AddHabitScreen({super.key, this.initialHabit});

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
  List<int> _scheduleDays = [1, 2, 3, 4, 5]; // Mon–Fri default
  String _emoji = '💪';
  String _colorHex = '#6C5CE7';
  TimeOfDay? _reminderTime;
  bool _saving = false;

  bool get _isEditing => widget.initialHabit != null;

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
    if (_schedule == HabitSchedule.specific && _scheduleDays.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select at least one day.')));
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
        );
      }

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save habit. Please try again.'),
          ),
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
        title: Text(_isEditing ? 'Edit Habit' : 'New Habit'),
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
            _SectionLabel('Progress type'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children:
                  HabitProgressType.values.map((pt) {
                    final selected = _progressType == pt;
                    return ChoiceChip(
                      label: Text(_progressLabel(pt)),
                      selected: selected,
                      onSelected: (_) => setState(() => _progressType = pt),
                    );
                  }).toList(),
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
              children:
                  [HabitSchedule.daily, HabitSchedule.specific].map((s) {
                    final selected = _schedule == s;
                    return ChoiceChip(
                      label: Text(_scheduleLabel(s)),
                      selected: selected,
                      onSelected:
                          (_) => setState(() {
                            _schedule = s;
                            if (s == HabitSchedule.daily) _scheduleDays = [];
                          }),
                    );
                  }).toList(),
            ),
            if (_schedule == HabitSchedule.specific) ...[
              const SizedBox(height: 12),
              _DayPicker(
                selected: _scheduleDays,
                onChanged: (days) => setState(() => _scheduleDays = days),
              ),
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

  static String _scheduleLabel(HabitSchedule s) {
    switch (s) {
      case HabitSchedule.daily:
        return 'Daily';
      case HabitSchedule.weekly:
        return 'Weekly';
      case HabitSchedule.specific:
        return 'Specific days';
      default:
        return s.name;
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
