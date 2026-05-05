import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme_extension.dart';
import '../../core/constants/app_limits.dart';
import '../../core/models/mood.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/data_provider.dart';
import '../../shared/widgets/upgrade_prompt_sheet.dart';

// ── Mood level data ───────────────────────────────────────

class _MoodLevel {
  final int level;
  final String emoji;
  final String label;
  final Color color;

  const _MoodLevel(this.level, this.emoji, this.label, this.color);
}

const _kMoodLevels = [
  _MoodLevel(1, '😢', 'Awful', Color(0xFFE17055)),
  _MoodLevel(2, '😔', 'Bad', Color(0xFFFDAA6E)),
  _MoodLevel(3, '😐', 'Meh', Color(0xFF8E8EA0)),
  _MoodLevel(4, '😊', 'Good', Color(0xFF00B894)),
  _MoodLevel(5, '🤩', 'Great', Color(0xFF6C5CE7)),
];

const _kTags = [
  'Work',
  'Family',
  'Exercise',
  'Sleep',
  'Health',
  'Finance',
  'Love',
  'Hobbies',
  'Weather',
  'Learning',
];

// ── Screen ────────────────────────────────────────────────

class MoodScreen extends ConsumerStatefulWidget {
  const MoodScreen({super.key});

  @override
  ConsumerState<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends ConsumerState<MoodScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String _todayStr() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final tier = ref.watch(authNotifierProvider).tier;

    // Guest: locked screen
    if (!AppLimits.canAccessMood(tier)) {
      return _LockedMoodScreen();
    }

    final moods = ref.watch(appDataProvider).moods;
    final todayMood = moods.where((m) => m.date == _todayStr()).firstOrNull;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Text(
                'Mood',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _todayLabel(),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tab bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: context.appColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabs,
                  indicator: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: const [Tab(text: 'Today'), Tab(text: 'Calendar')],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _TodayTab(
                    todayMood: todayMood,
                    todayStr: _todayStr(),
                    allMoods: moods,
                  ),
                  _CalendarTab(moods: moods),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _todayLabel() {
    final now = DateTime.now();
    const months = [
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
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }
}

// ── Today tab ─────────────────────────────────────────────

class _TodayTab extends ConsumerStatefulWidget {
  final Mood? todayMood;
  final String todayStr;
  final List<Mood> allMoods;

  const _TodayTab({
    required this.todayMood,
    required this.todayStr,
    required this.allMoods,
  });

  @override
  ConsumerState<_TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends ConsumerState<_TodayTab> {
  int? _selectedLevel;
  final Set<String> _selectedTags = {};
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.todayMood;
    if (m != null) {
      _selectedLevel = m.level;
      _selectedTags.addAll(m.tags);
      _noteCtrl.text = m.note ?? '';
    }
  }

  @override
  void didUpdateWidget(_TodayTab old) {
    super.didUpdateWidget(old);
    if (old.todayMood == null && widget.todayMood != null) {
      final m = widget.todayMood!;
      setState(() {
        _selectedLevel = m.level;
        _selectedTags
          ..clear()
          ..addAll(m.tags);
      });
      _noteCtrl.text = m.note ?? '';
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedLevel == null) return;
    setState(() => _saving = true);
    final ml = _kMoodLevels[_selectedLevel! - 1];
    final existing = widget.todayMood;
    final mood = Mood(
      id: existing?.id ?? const Uuid().v4(),
      date: widget.todayStr,
      level: _selectedLevel!,
      emoji: ml.emoji,
      tags: _selectedTags.toList(),
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      loggedAt: DateTime.now().toUtc().toIso8601String(),
    );
    await ref.read(dataNotifierProvider.notifier).upsertMood(mood);
    if (mounted) {
      HapticFeedback.mediumImpact();
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Mood saved ✓')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      children: [
        // ── Mood selector ─────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: context.cardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'How are you feeling?',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children:
                    _kMoodLevels.map((ml) {
                      final sel = _selectedLevel == ml.level;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedLevel = ml.level);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:
                                sel
                                    ? ml.color.withValues(alpha: 0.2)
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: sel ? ml.color : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                ml.emoji,
                                style: TextStyle(fontSize: sel ? 36 : 28),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                ml.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: sel ? ml.color : AppColors.textMuted,
                                  fontWeight:
                                      sel ? FontWeight.w700 : FontWeight.normal,
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
        ),
        const SizedBox(height: 16),

        // ── Tags ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: context.cardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'What\'s influencing this?',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    _kTags.map((tag) {
                      final sel = _selectedTags.contains(tag);
                      return GestureDetector(
                        onTap:
                            () => setState(
                              () =>
                                  sel
                                      ? _selectedTags.remove(tag)
                                      : _selectedTags.add(tag),
                            ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                sel
                                    ? primary.withValues(alpha: 0.15)
                                    : AppColors.bgElevated,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel ? primary : AppColors.border,
                            ),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 13,
                              color: sel ? primary : AppColors.textSecondary,
                              fontWeight:
                                  sel ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Note ──────────────────────────────────────────
        TextField(
          controller: _noteCtrl,
          maxLength: 280,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Add a note (optional)',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 20),

        // ── Save button ───────────────────────────────────
        ElevatedButton(
          onPressed: _selectedLevel == null || _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child:
              _saving
                  ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : Text(
                    widget.todayMood == null ? 'Log Mood' : 'Update Mood',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
        ),
        const SizedBox(height: 28),

        // ── 30-day stats ──────────────────────────────────
        _MoodStats(moods: widget.allMoods),
      ],
    );
  }
}

// ── Mood stats ────────────────────────────────────────────

class _MoodStats extends StatelessWidget {
  final List<Mood> moods;
  const _MoodStats({required this.moods});

  @override
  Widget build(BuildContext context) {
    if (moods.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    // Use local-midnight cutoff so entries on the boundary day are not
    // accidentally excluded due to UTC-offset when parsing YYYY-MM-DD.
    final cutoff = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 30));
    final recent =
        moods.where((m) {
          final d = DateTime.tryParse(m.date); // parses as local midnight
          return d != null && !d.isBefore(cutoff);
        }).toList();

    if (recent.isEmpty) return const SizedBox.shrink();

    final positive = recent.where((m) => m.level >= 4).length;
    final pct = (positive / recent.length * 100).round();
    final avg =
        recent.map((m) => m.level).reduce((a, b) => a + b) / recent.length;
    final avgMl = _kMoodLevels[avg.round().clamp(1, 5) - 1];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: context.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Last 30 days',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatChip(
                label: 'Positive days',
                value: '$pct%',
                color: AppColors.success,
              ),
              const SizedBox(width: 12),
              _StatChip(
                label: 'Avg mood',
                value: '${avgMl.emoji} ${avgMl.label}',
                color: avgMl.color,
              ),
              const SizedBox(width: 12),
              _StatChip(
                label: 'Logged',
                value: '${recent.length}',
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

// ── Calendar tab ──────────────────────────────────────────

class _CalendarTab extends StatefulWidget {
  final List<Mood> moods;
  const _CalendarTab({required this.moods});

  @override
  State<_CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<_CalendarTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  Map<String, Mood> get _moodByDate => {
    for (final m in widget.moods) m.date: m,
  };

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    final firstWeekday =
        DateTime(_month.year, _month.month, 1).weekday % 7; // 0=Sun

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      children: [
        // Month nav
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed:
                  () => setState(
                    () => _month = DateTime(_month.year, _month.month - 1),
                  ),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Text(
              _monthLabel(_month),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            IconButton(
              onPressed:
                  _month.year == DateTime.now().year &&
                          _month.month == DateTime.now().month
                      ? null
                      : () => setState(
                        () => _month = DateTime(_month.year, _month.month + 1),
                      ),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Day-of-week headers
        Row(
          children:
              ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                  .map(
                    (d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 8),

        // Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1,
          ),
          itemCount: firstWeekday + daysInMonth,
          itemBuilder: (_, i) {
            if (i < firstWeekday) return const SizedBox.shrink();
            final day = i - firstWeekday + 1;
            final dateStr =
                '${_month.year}-${_month.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
            final mood = _moodByDate[dateStr];
            final isToday =
                DateTime.now().day == day &&
                DateTime.now().month == _month.month &&
                DateTime.now().year == _month.year;

            return GestureDetector(
              onTap: mood == null ? null : () => _showDetail(mood),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color:
                      mood != null
                          ? _kMoodLevels[mood.level.clamp(1, 5) - 1].color
                              .withValues(alpha: 0.25)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isToday ? Border.all(color: primary, width: 2) : null,
                ),
                child: Center(
                  child:
                      mood != null
                          ? Text(
                            mood.emoji,
                            style: const TextStyle(fontSize: 16),
                          )
                          : Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 12,
                              color: isToday ? primary : AppColors.textMuted,
                              fontWeight:
                                  isToday ? FontWeight.w700 : FontWeight.normal,
                            ),
                          ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showDetail(Mood mood) {
    final level = mood.level.clamp(1, 5);
    final ml = _kMoodLevels[level - 1];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (_) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: const Border(top: BorderSide(color: AppColors.border)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(ml.emoji, style: const TextStyle(fontSize: 36)),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ml.label,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: ml.color,
                          ),
                        ),
                        Text(
                          mood.date,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (mood.tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children:
                        mood.tags
                            .map(
                              (t) => Chip(
                                label: Text(t),
                                backgroundColor: AppColors.bgElevated,
                                labelStyle: const TextStyle(fontSize: 12),
                              ),
                            )
                            .toList(),
                  ),
                ],
                if (mood.note != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    mood.note!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
    );
  }

  static String _monthLabel(DateTime d) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }
}

// ── Guest locked screen ───────────────────────────────────

class _LockedMoodScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('😊', style: TextStyle(fontSize: 40)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Mood Tracking',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Track your daily mood, spot patterns, and understand what affects how you feel.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed:
                      () => UpgradePromptSheet.show(
                        context,
                        feature: 'Mood Tracking',
                      ),
                  child: const Text('Sign in to unlock'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Extension helper removed ─────────────────────────────
