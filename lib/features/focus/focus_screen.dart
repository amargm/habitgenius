import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_toast.dart';
import '../../core/theme/app_theme_extension.dart';
import '../../core/constants/app_limits.dart';
import '../../core/models/focus_session.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/data_provider.dart';
import '../../core/services/focus_session_service.dart';
import '../../shared/widgets/upgrade_prompt_sheet.dart';

// ── Focus session service provider (keepAlive so timer runs app-wide) ──────

final focusSvcProvider = ChangeNotifierProvider<FocusSessionService>((ref) {
  ref.keepAlive(); // Timer must survive screen navigation — never auto-dispose
  return FocusSessionService();
});

// ── Category constants ────────────────────────────────────

const _kCategories = [
  'Deep Work',
  'Study',
  'Exercise',
  'Creative',
  'Planning',
  'Other',
];

// ── Focus screen ──────────────────────────────────────────

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen>
    with SingleTickerProviderStateMixin {
  int _selectedPreset = FocusSessionService.preset25;
  String _selectedCategory = _kCategories.first;
  FocusMode _selectedMode = FocusMode.pomodoro;

  @override
  void initState() {
    super.initState();
    // Sync the UI mode chip with whatever mode the running service is in.
    // This matters when the user navigates away and comes back.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final svc = ref.read(focusSvcProvider);
      if (_selectedMode != svc.mode) {
        setState(() => _selectedMode = svc.mode);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tier = ref.watch(authNotifierProvider).tier;
    final svc = ref.watch(focusSvcProvider);
    final sessions = ref.watch(appDataProvider).focusSessions;
    final settings = ref.watch(appDataProvider).settings;
    final goalMinutes = settings.dailyFocusGoalMinutes;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            // Header
            Text(
              'Focus',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              _todayStats(sessions),
              style: TextStyle(
                color: context.appColors.textSecondary,
                fontSize: 14,
              ),
            ),
            if (sessions.isNotEmpty) ...[
              const SizedBox(height: 14),
              _FocusStatsRow(sessions: sessions),
              const SizedBox(height: 10),
              _FocusCategoryRow(sessions: sessions),
            ],

            // Daily goal progress
            if (goalMinutes > 0) ...[
              const SizedBox(height: 14),
              Builder(
                builder: (context) {
                  final now = DateTime.now();
                  final todayStart = DateTime(now.year, now.month, now.day);
                  final todayEnd = todayStart.add(const Duration(days: 1));
                  final todayMinutes = sessions
                      .where((s) {
                        try {
                          final start = DateTime.parse(s.startedAt);
                          return start.isAfter(todayStart) &&
                              start.isBefore(todayEnd);
                        } catch (_) {
                          return false;
                        }
                      })
                      .fold(0, (sum, s) => sum + (s.actualDuration ~/ 60));
                  final progress = (todayMinutes / goalMinutes).clamp(0.0, 1.0);
                  final done = todayMinutes >= goalMinutes;
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.appColors.bgCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.appColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'DAILY GOAL',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: context.appColors.textMuted,
                              ),
                            ),
                            const Spacer(),
                            if (done)
                              Text(
                                '🎯 Goal reached!',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: primary,
                                ),
                              )
                            else
                              Text(
                                '$todayMinutes / $goalMinutes min',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: context.appColors.textPrimary,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: primary.withValues(alpha: 0.12),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              done ? Colors.green : primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 24),

            // Break banner (shown while Pomodoro break is running)
            if (svc.isOnBreak)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🎉', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(
                      svc.completedCycles % 4 == 0
                          ? 'Long break! You earned it.'
                          : 'Break time! Great work.',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

            // Mode selector + category/duration (only when not running)
            if (!svc.isRunning && !svc.isPaused) ...[
              _SectionLabel(label: 'Mode'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children:
                    FocusMode.values.map((m) {
                      return ChoiceChip(
                        label: Text(_modeLabel(m)),
                        selected: _selectedMode == m,
                        onSelected: (_) {
                          setState(() {
                            _selectedMode = m;
                            svc.configure(mode: m);
                          });
                        },
                      );
                    }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                _modeDescription(_selectedMode),
                style: TextStyle(
                  fontSize: 12,
                  color: context.appColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),

              // Divider between Mode and Category
              const Divider(height: 1, thickness: 1),
              const SizedBox(height: 16),

              // Category chips
              _SectionLabel(label: 'Category'),
              const SizedBox(height: 8),
              _CategoryChips(
                selected: _selectedCategory,
                onSelected:
                    (c) => setState(() {
                      _selectedCategory = c;
                      svc.configure(category: c);
                    }),
              ),
              const SizedBox(height: 20),

              // Duration presets
              if (_selectedMode != FocusMode.stopwatch) ...[
                _SectionLabel(label: 'Duration'),
                const SizedBox(height: 8),
                _PresetRow(
                  selected: _selectedPreset,
                  tier: tier,
                  onSelected: (sec) {
                    setState(() => _selectedPreset = sec);
                    svc.configure(plannedDuration: sec);
                  },
                  onCustom: () => _pickCustomDuration(context, tier, svc),
                ),
                const SizedBox(height: 20),
              ],
            ],

            // Timer ring
            LayoutBuilder(
              builder: (context, constraints) {
                final ringSize = (constraints.maxWidth * 0.75).clamp(
                  220.0,
                  320.0,
                );
                final ringColor =
                    svc.isOnBreak ? Colors.green.shade400 : primary;
                return Center(
                  child: _TimerRing(
                    size: ringSize,
                    progress: svc.isOnBreak ? svc.breakProgress : svc.progress,
                    timeLabel:
                        svc.isOnBreak ? svc.breakTimeLabel : svc.timeLabel,
                    state: svc.state,
                    mode: svc.mode,
                    cycles: svc.completedCycles,
                    primary: ringColor,
                    isStopwatch: svc.mode == FocusMode.stopwatch,
                    remaining:
                        svc.isOnBreak ? svc.breakRemaining : svc.remaining,
                    plannedDuration:
                        svc.isOnBreak
                            ? svc.currentBreakDuration
                            : svc.plannedDuration,
                    isOnBreak: svc.isOnBreak,
                  ),
                );
              },
            ),
            const SizedBox(height: 32),

            // Controls
            _Controls(
              state: svc.state,
              mode: svc.mode,
              isOnBreak: svc.isOnBreak,
              onPlay: () {
                HapticFeedback.mediumImpact();
                svc.start();
              },
              onPause: () {
                HapticFeedback.lightImpact();
                svc.pause();
              },
              onReset: () {
                HapticFeedback.lightImpact();
                _onReset(svc); // async; fire-and-forget is intentional
              },
              onSkip: () {
                HapticFeedback.mediumImpact();
                svc.skipCycle();
              },
              onSave: () => _onSaveSession(svc),
            ),
            const SizedBox(height: 32),

            // Recent sessions — grouped by date
            if (sessions.isNotEmpty) ...[
              _SectionLabel(label: 'Recent sessions'),
              const SizedBox(height: 12),
              ..._buildGroupedSessions(sessions),
            ],
          ],
        ),
      ),
    );
  }

  /// Builds session tiles grouped by local calendar day, newest first.
  /// Shows at most 20 sessions across all groups.
  List<Widget> _buildGroupedSessions(List<FocusSession> sessions) {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    // Take 20 most recent, newest first.
    final recent = sessions.reversed.take(20).toList();

    // Group by local date string 'yyyy-MM-dd'.
    final Map<String, List<FocusSession>> byDay = {};
    for (final s in recent) {
      final d = DateTime.tryParse(s.startedAt)?.toLocal();
      if (d == null) continue;
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      byDay.putIfAbsent(key, () => []).add(s);
    }

    String dayLabel(String key) {
      final parts = key.split('-');
      final d = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      if (d.year == today.year &&
          d.month == today.month &&
          d.day == today.day) {
        return 'Today';
      }
      if (d.year == yesterday.year &&
          d.month == yesterday.month &&
          d.day == yesterday.day) {
        return 'Yesterday';
      }
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
      return '${months[d.month - 1]} ${d.day}';
    }

    final widgets = <Widget>[];
    for (final key in byDay.keys) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Text(
            dayLabel(key),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.appColors.textMuted,
              letterSpacing: 0.4,
            ),
          ),
        ),
      );
      for (final s in byDay[key]!) {
        widgets.add(_SessionTile(session: s));
      }
    }
    return widgets;
  }

  // ── Helpers ───────────────────────────────────────────────

  static String _modeLabel(FocusMode m) {
    switch (m) {
      case FocusMode.pomodoro:
        return 'Pomodoro';
      case FocusMode.countdown:
        return 'Timer';
      case FocusMode.stopwatch:
        return 'Stopwatch';
    }
  }

  static String _modeDescription(FocusMode m) {
    switch (m) {
      case FocusMode.pomodoro:
        return '25-min work blocks with 5-min breaks';
      case FocusMode.countdown:
        return 'Count down from a custom duration';
      case FocusMode.stopwatch:
        return 'Count up freely, save when done';
    }
  }

  String _todayStats(List<FocusSession> sessions) {
    final today = DateTime.now();
    // FocusSession.startedAt is stored as UTC; convert to local so sessions
    // are attributed to the correct local calendar day.
    final todaySess =
        sessions.where((s) {
          final d = DateTime.tryParse(s.startedAt)?.toLocal();
          return d != null &&
              d.year == today.year &&
              d.month == today.month &&
              d.day == today.day;
        }).toList();

    if (todaySess.isEmpty) return 'No focus sessions today';
    final totalMin =
        todaySess.map((s) => s.actualDuration).reduce((a, b) => a + b) ~/ 60;
    return '${todaySess.length} session${todaySess.length > 1 ? 's' : ''} · ${totalMin}m focused today';
  }

  Future<void> _onReset(FocusSessionService svc) async {
    // Ask for confirmation if a meaningful session is in progress.
    if ((svc.isRunning || svc.isPaused) && svc.elapsed > 60) {
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Discard session?'),
              content: const Text(
                'Your progress on this session will be lost.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Keep going'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Discard'),
                ),
              ],
            ),
      );
      if (confirmed != true) return;
    }
    // Do NOT reset _selectedPreset — preserve the user's chosen duration.
    svc.reset();
    svc.configure(
      mode: _selectedMode,
      plannedDuration: _selectedPreset,
      category: _selectedCategory,
    );
  }

  Future<void> _onSaveSession(FocusSessionService svc) async {
    final id = const Uuid().v4();
    final session = svc.buildSession(id);
    if (session == null) {
      if (mounted) AppToast.show(context, 'Start the timer before saving.');
      return;
    }
    try {
      await ref.read(dataNotifierProvider.notifier).addFocusSession(session);
      svc.reset();
      svc.configure(
        mode: _selectedMode,
        plannedDuration: _selectedPreset,
        category: _selectedCategory,
      );
      if (mounted) {
        HapticFeedback.mediumImpact();
        AppToast.show(context, 'Session saved ✓', type: ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          'Could not save session. Please try again.',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _pickCustomDuration(
    BuildContext context,
    UserTier tier,
    FocusSessionService svc,
  ) async {
    if (!AppLimits.canUseCustomFocusDuration(tier)) {
      UpgradePromptSheet.show(context, feature: 'Custom duration');
      return;
    }
    final ctrl = TextEditingController(text: '30');
    final result = await showDialog<int>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Custom duration'),
            content: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Minutes',
                suffixText: 'min',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final v = int.tryParse(ctrl.text);
                  if (v != null && v > 0 && v <= 180) {
                    Navigator.pop(ctx, v * 60);
                  }
                },
                child: const Text('Set'),
              ),
            ],
          ),
    );
    ctrl.dispose();
    if (result != null) {
      setState(() => _selectedPreset = result);
      svc.configure(plannedDuration: result);
    }
  }
}

// ── Timer ring ────────────────────────────────────────────

class _TimerRing extends StatelessWidget {
  final double progress;
  final String timeLabel;
  final TimerState state;
  final FocusMode mode;
  final int cycles;
  final Color primary;
  final bool isStopwatch;
  final int remaining;
  final int plannedDuration;
  final bool isOnBreak;
  final double size;

  const _TimerRing({
    required this.progress,
    required this.timeLabel,
    required this.state,
    required this.mode,
    required this.cycles,
    required this.primary,
    required this.isStopwatch,
    this.remaining = 0,
    this.plannedDuration = 0,
    this.isOnBreak = false,
    this.size = 220,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: isStopwatch ? 0 : progress,
              remaining: remaining,
              plannedDuration: plannedDuration,
              primary: primary,
              inactive: primary.withValues(alpha: 0.12),
              isRunning: state == TimerState.running,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                timeLabel,
                style: TextStyle(
                  fontSize: size * 0.218,
                  fontWeight: FontWeight.w200,
                  letterSpacing: 2,
                  color:
                      (state == TimerState.finished || isOnBreak)
                          ? primary
                          : null,
                ),
              ),
              if (isOnBreak)
                Text(
                  'Break',
                  style: TextStyle(
                    color: primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else if (state == TimerState.finished)
                Text(
                  'Session Complete',
                  style: TextStyle(
                    color: primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (mode == FocusMode.pomodoro && !isOnBreak)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(4, (i) {
                      final done =
                          i < (cycles % 4 == 0 && cycles > 0 ? 4 : cycles % 4);
                      return Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        decoration: BoxDecoration(
                          color:
                              done ? primary : primary.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: primary.withValues(alpha: done ? 0.0 : 0.5),
                            width: done ? 0 : 1,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final int remaining;
  final int plannedDuration;
  final Color primary;
  final Color inactive;
  final bool isRunning;

  const _RingPainter({
    required this.progress,
    required this.remaining,
    required this.plannedDuration,
    required this.primary,
    required this.inactive,
    required this.isRunning,
  });

  /// Derives the arc colour based on urgency:
  /// Normal → Amber (last 5 min) → Red (last 1 min).
  Color get _arcColor {
    if (!isRunning || plannedDuration == 0) return primary;
    const amber = Color(0xFFFAA61A);
    const red = Color(0xFFE53935);
    if (remaining <= 60) {
      // Last minute: interpolate amber → red
      final t = 1.0 - (remaining / 60).clamp(0.0, 1.0);
      return Color.lerp(amber, red, t)!;
    }
    if (remaining <= 300) {
      // Last 5 minutes: interpolate primary → amber
      final t = 1.0 - ((remaining - 60) / 240).clamp(0.0, 1.0);
      return Color.lerp(primary, amber, t)!;
    }
    return primary;
  }

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;
    final arcColor = _arcColor;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = inactive
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    // Arc
    if (progress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final sweep = 2 * math.pi * progress;

      // Glow pass (only when running)
      if (isRunning) {
        canvas.drawArc(
          rect,
          -math.pi / 2,
          sweep,
          false,
          Paint()
            ..color = arcColor.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke + 6
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }

      // Main arc
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..color = arcColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.remaining != remaining ||
      old.isRunning != isRunning ||
      old.primary != primary;
}

// ── Controls ──────────────────────────────────────────────

class _Controls extends StatelessWidget {
  final TimerState state;
  final FocusMode mode;
  final bool isOnBreak;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onReset;
  final VoidCallback onSkip;
  final VoidCallback onSave;

  const _Controls({
    required this.state,
    required this.mode,
    required this.isOnBreak,
    required this.onPlay,
    required this.onPause,
    required this.onReset,
    required this.onSkip,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    // Break controls: save work + skip break
    if (isOnBreak) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ControlBtn(
            icon: Icons.save_alt_rounded,
            onTap: onSave,
            label: 'Save',
          ),
          const SizedBox(width: 24),
          _ControlBtn(
            icon: Icons.skip_next_rounded,
            onTap: onSkip,
            label: 'Skip Break',
            color: Colors.green.shade400,
            large: true,
          ),
        ],
      );
    }

    if (state == TimerState.finished) {
      return Center(
        child: _ControlBtn(
          icon: Icons.refresh_rounded,
          onTap: onReset,
          label: 'New Session',
          large: true,
        ),
      );
    }

    // Stopwatch: show Save button alongside Reset/Pause when running or paused
    if (mode == FocusMode.stopwatch &&
        (state == TimerState.running || state == TimerState.paused)) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ControlBtn(
            icon: Icons.refresh_rounded,
            onTap: onReset,
            label: 'Reset',
          ),
          const SizedBox(width: 24),
          _ControlBtn(
            icon:
                state == TimerState.running
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
            onTap: state == TimerState.running ? onPause : onPlay,
            label: state == TimerState.running ? 'Pause' : 'Resume',
            color: primary,
            large: true,
          ),
          const SizedBox(width: 24),
          _ControlBtn(
            icon: Icons.save_alt_rounded,
            onTap: onSave,
            label: 'Save',
            color: primary,
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ControlBtn(
          icon: Icons.refresh_rounded,
          onTap: onReset,
          label: 'Reset',
        ),
        const SizedBox(width: 24),
        _ControlBtn(
          icon:
              state == TimerState.running
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
          onTap: state == TimerState.running ? onPause : onPlay,
          label: state == TimerState.running ? 'Pause' : 'Start',
          color: primary,
          large: true,
        ),
        if (mode == FocusMode.pomodoro) ...[
          const SizedBox(width: 24),
          _ControlBtn(
            icon: Icons.skip_next_rounded,
            onTap: onSkip,
            label: 'Skip',
          ),
        ],
      ],
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String label;
  final Color? color;
  final bool large;

  const _ControlBtn({
    required this.icon,
    required this.onTap,
    required this.label,
    this.color,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    final size = large ? 64.0 : 48.0;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color:
                  large ? c.withValues(alpha: 0.15) : context.appColors.bgCard,
              shape: BoxShape.circle,
              border: large ? Border.all(color: c, width: 2) : null,
              boxShadow: large ? null : context.appColors.cardShadow,
            ),
            child: Icon(icon, color: c, size: large ? 32 : 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: c, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Category chips ────────────────────────────────────────

class _CategoryChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _CategoryChips({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          _kCategories.map((c) {
            final sel = selected == c;
            return GestureDetector(
              onTap: () => onSelected(c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color:
                      sel
                          ? primary.withValues(alpha: 0.15)
                          : context.appColors.bgCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: sel ? primary : context.appColors.border,
                  ),
                ),
                child: Text(
                  c,
                  style: TextStyle(
                    fontSize: 13,
                    color: sel ? primary : context.appColors.textSecondary,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }
}

// ── Preset row ────────────────────────────────────────────

class _PresetRow extends StatelessWidget {
  final int selected;
  final UserTier tier;
  final ValueChanged<int> onSelected;
  final VoidCallback onCustom;

  const _PresetRow({
    required this.selected,
    required this.tier,
    required this.onSelected,
    required this.onCustom,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    const presets = [
      (FocusSessionService.preset25, '25m'),
      (FocusSessionService.preset45, '45m'),
      (FocusSessionService.preset60, '60m'),
    ];

    return Row(
      children: [
        ...presets.map((p) {
          final sel = selected == p.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(p.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color:
                      sel
                          ? primary.withValues(alpha: 0.15)
                          : context.appColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: sel ? primary : context.appColors.border,
                  ),
                ),
                child: Center(
                  child: Text(
                    p.$2,
                    style: TextStyle(
                      fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                      color: sel ? primary : context.appColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
        Expanded(
          child: GestureDetector(
            onTap: onCustom,
            child: Container(
              margin: const EdgeInsets.only(right: 0),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: context.cardDecorationR(12),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!AppLimits.canUseCustomFocusDuration(tier))
                      Icon(
                        Icons.lock_rounded,
                        size: 12,
                        color: context.appColors.textMuted,
                      ),
                    if (!AppLimits.canUseCustomFocusDuration(tier))
                      const SizedBox(width: 4),
                    Text(
                      'Custom',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.appColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Session tile ──────────────────────────────────────────

class _SessionTile extends StatelessWidget {
  final FocusSession session;
  const _SessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final dur = _fmtDuration(session.actualDuration);
    final modeIcon = switch (session.mode) {
      FocusMode.pomodoro => Icons.timer_rounded,
      FocusMode.countdown => Icons.hourglass_bottom_rounded,
      FocusMode.stopwatch => Icons.watch_rounded,
    };
    final when = _relativeTime(session.startedAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: context.cardDecorationR(14),
      child: Row(
        children: [
          Icon(modeIcon, size: 24, color: context.appColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.category,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  when,
                  style: TextStyle(
                    color: context.appColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                dur,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              if (session.completedCycles > 0)
                Text(
                  '${session.completedCycles} cycles',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.appColors.textMuted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmtDuration(int secs) {
    if (secs < 60) return '${secs}s';
    final m = secs ~/ 60;
    final s = secs % 60;
    return s == 0 ? '${m}m' : '${m}m ${s}s';
  }

  static String _relativeTime(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    final diff = DateTime.now().toUtc().difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ── Focus stats row ───────────────────────────────────────

class _FocusStatsRow extends StatelessWidget {
  final List<FocusSession> sessions;
  const _FocusStatsRow({required this.sessions});

  /// Consecutive days (ending today) that each had at least one session.
  static int _streak(List<FocusSession> sessions) {
    if (sessions.isEmpty) return 0;
    final days = <String>{};
    for (final s in sessions) {
      final d = DateTime.tryParse(s.startedAt)?.toLocal();
      if (d == null) continue;
      days.add(
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
      );
    }
    int streak = 0;
    var day = DateTime.now();
    while (true) {
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      if (!days.contains(key)) break;
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todaySec = sessions
        .where((s) {
          final d = DateTime.tryParse(s.startedAt)?.toLocal();
          return d != null &&
              d.year == now.year &&
              d.month == now.month &&
              d.day == now.day;
        })
        .fold<int>(0, (sum, s) => sum + s.actualDuration);

    final startOfWeek = now.subtract(Duration(days: now.weekday % 7));
    final weekSec = sessions
        .where((s) {
          final d = DateTime.tryParse(s.startedAt)?.toLocal();
          return d != null && !d.isBefore(startOfWeek);
        })
        .fold<int>(0, (sum, s) => sum + s.actualDuration);

    final streak = _streak(sessions);

    String fmt(int sec) {
      final min = sec ~/ 60;
      return min >= 60 ? '${(min / 60).toStringAsFixed(1)}h' : '${min}m';
    }

    return Row(
      children: [
        Expanded(child: _FocusStatCard(label: 'Today', value: fmt(todaySec))),
        const SizedBox(width: 10),
        Expanded(
          child: _FocusStatCard(label: 'This week', value: fmt(weekSec)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _FocusStatCard(
            label: 'Day streak',
            value: streak > 0 ? '🔥 $streak' : '—',
          ),
        ),
      ],
    );
  }
}

// ── Category breakdown row ────────────────────────────────

class _FocusCategoryRow extends StatelessWidget {
  final List<FocusSession> sessions;
  const _FocusCategoryRow({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    // Aggregate seconds per category
    final Map<String, int> byCat = {};
    for (final s in sessions) {
      final cat = s.category.isNotEmpty ? s.category : 'Other';
      byCat[cat] = (byCat[cat] ?? 0) + s.actualDuration;
    }
    if (byCat.isEmpty) return const SizedBox.shrink();

    final total = byCat.values.fold<int>(0, (a, b) => a + b);
    final sorted =
        byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    // Show top 4 categories
    final top = sorted.take(4).toList();

    String fmt(int sec) {
      final min = sec ~/ 60;
      return min >= 60 ? '${(min / 60).toStringAsFixed(1)}h' : '${min}m';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: context.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BY CATEGORY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: context.appColors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          ...top.map((e) {
            final fraction = total > 0 ? e.value / total : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.key,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text(
                        '${fmt(e.value)} (${(fraction * 100).round()}%)',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.appColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 6,
                      backgroundColor: primary.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(primary),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _FocusStatCard extends StatelessWidget {
  final String label;
  final String value;
  const _FocusStatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: context.cardDecorationR(12),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: context.appColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      color: AppColors.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
    ),
  );
}
