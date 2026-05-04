import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_limits.dart';
import '../../core/models/focus_session.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/data_provider.dart';
import '../../core/services/focus_session_service.dart';
import '../../shared/widgets/upgrade_prompt_sheet.dart';

// ── Focus session service provider ────────────────────────

final _focusSvcProvider = ChangeNotifierProvider<FocusSessionService>(
  (ref) => FocusSessionService(),
);

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
  Widget build(BuildContext context) {
    final tier = ref.watch(authNotifierProvider).tier;
    final svc = ref.watch(_focusSvcProvider);
    final sessions = ref.watch(appDataProvider).focusSessions;
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
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            // Category chips
            if (!svc.isRunning && !svc.isPaused) ...[
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

              // Mode toggle
              _SectionLabel(label: 'Mode'),
              const SizedBox(height: 8),
              _ModeToggle(
                selected: _selectedMode,
                onSelected:
                    (m) => setState(() {
                      _selectedMode = m;
                      svc.configure(mode: m);
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
            Center(
              child: _TimerRing(
                progress: svc.progress,
                timeLabel: svc.timeLabel,
                state: svc.state,
                mode: svc.mode,
                cycles: svc.completedCycles,
                primary: primary,
                isStopwatch: svc.mode == FocusMode.stopwatch,
              ),
            ),
            const SizedBox(height: 32),

            // Controls
            _Controls(
              state: svc.state,
              mode: svc.mode,
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
                _onReset(svc);
              },
              onSkip: () {
                HapticFeedback.mediumImpact();
                svc.skipCycle();
              },
              onSave: () => _onSaveSession(svc),
            ),
            const SizedBox(height: 32),

            // Recent sessions
            if (sessions.isNotEmpty) ...[
              _SectionLabel(label: 'Recent sessions'),
              const SizedBox(height: 12),
              ...sessions.reversed
                  .take(10)
                  .map((s) => _SessionTile(session: s)),
            ],
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────

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

  void _onReset(FocusSessionService svc) {
    setState(() {
      _selectedPreset = FocusSessionService.preset25;
    });
    svc.reset();
    svc.configure(
      plannedDuration: _selectedPreset,
      category: _selectedCategory,
    );
  }

  Future<void> _onSaveSession(FocusSessionService svc) async {
    final id = const Uuid().v4();
    final session = svc.buildSession(id);
    if (session == null) {
      // Nothing to save (timer never ran or 0 seconds elapsed).
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Start the timer before saving.')),
        );
      }
      return;
    }
    try {
      await ref.read(dataNotifierProvider.notifier).addFocusSession(session);
      svc.reset();
      svc.configure(
        plannedDuration: _selectedPreset,
        category: _selectedCategory,
      );
      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Session saved ✓')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save session. Please try again.'),
          ),
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
          (_) => AlertDialog(
            title: const Text('Custom duration'),
            content: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minutes',
                suffixText: 'min',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final v = int.tryParse(ctrl.text);
                  if (v != null && v > 0 && v <= 180) {
                    Navigator.pop(context, v * 60);
                  }
                },
                child: const Text('Set'),
              ),
            ],
          ),
    );
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

  const _TimerRing({
    required this.progress,
    required this.timeLabel,
    required this.state,
    required this.mode,
    required this.cycles,
    required this.primary,
    required this.isStopwatch,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(220, 220),
            painter: _RingPainter(
              progress: isStopwatch ? 0 : progress,
              color: primary,
              inactive: AppColors.border,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                timeLabel,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w200,
                  letterSpacing: 2,
                  color: state == TimerState.finished ? primary : null,
                ),
              ),
              if (state == TimerState.finished)
                Text(
                  'Done! 🎉',
                  style: TextStyle(color: primary, fontSize: 14),
                ),
              if (mode == FocusMode.pomodoro && cycles > 0)
                Text(
                  '$cycles 🍅',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
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
  final Color color;
  final Color inactive;

  const _RingPainter({
    required this.progress,
    required this.color,
    required this.inactive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;

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
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ── Controls ──────────────────────────────────────────────

class _Controls extends StatelessWidget {
  final TimerState state;
  final FocusMode mode;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onReset;
  final VoidCallback onSkip;
  final VoidCallback onSave;

  const _Controls({
    required this.state,
    required this.mode,
    required this.onPlay,
    required this.onPause,
    required this.onReset,
    required this.onSkip,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    if (state == TimerState.finished) {
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
            icon: Icons.save_alt_rounded,
            onTap: onSave,
            label: 'Save',
            color: primary,
            large: true,
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
              color: large ? c.withValues(alpha: 0.15) : AppColors.bgCard,
              shape: BoxShape.circle,
              border: Border.all(
                color: large ? c : AppColors.border,
                width: large ? 2 : 1,
              ),
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

// ── Mode toggle ───────────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  final FocusMode selected;
  final ValueChanged<FocusMode> onSelected;

  const _ModeToggle({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    const modes = [
      (FocusMode.pomodoro, '🍅', 'Pomodoro'),
      (FocusMode.countdown, '⏱', 'Countdown'),
      (FocusMode.stopwatch, '⏲', 'Stopwatch'),
    ];
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children:
          modes.map((m) {
            final sel = selected == m.$1;
            return Expanded(
              child: GestureDetector(
                onTap: () => onSelected(m.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color:
                        sel
                            ? primary.withValues(alpha: 0.15)
                            : AppColors.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: sel ? primary : AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Text(m.$2, style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 4),
                      Text(
                        m.$3,
                        style: TextStyle(
                          fontSize: 11,
                          color: sel ? primary : AppColors.textSecondary,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
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
                      sel ? primary.withValues(alpha: 0.15) : AppColors.bgCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? primary : AppColors.border),
                ),
                child: Text(
                  c,
                  style: TextStyle(
                    fontSize: 13,
                    color: sel ? primary : AppColors.textSecondary,
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
                      sel ? primary.withValues(alpha: 0.15) : AppColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: sel ? primary : AppColors.border),
                ),
                child: Center(
                  child: Text(
                    p.$2,
                    style: TextStyle(
                      fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                      color: sel ? primary : AppColors.textSecondary,
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
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!AppLimits.canUseCustomFocusDuration(tier))
                      const Icon(
                        Icons.lock_rounded,
                        size: 12,
                        color: AppColors.textMuted,
                      ),
                    if (!AppLimits.canUseCustomFocusDuration(tier))
                      const SizedBox(width: 4),
                    const Text(
                      'Custom',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
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
      FocusMode.pomodoro => '🍅',
      FocusMode.countdown => '⏱',
      FocusMode.stopwatch => '⏲',
    };
    final when = _relativeTime(session.startedAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(modeIcon, style: const TextStyle(fontSize: 24)),
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
                  style: const TextStyle(
                    color: AppColors.textMuted,
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
                  '${session.completedCycles} 🍅',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
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
