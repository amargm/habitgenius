import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/focus_session.dart';

// ── Enums ──────────────────────────────────────────────────

enum TimerState { idle, running, paused, finished }

// ── Focus timer service ────────────────────────────────────

/// Controls a single focus timer session.
/// Holds its own [Timer] and exposes a [ValueNotifier] for reactive UI.
class FocusSessionService extends ChangeNotifier {
  // Presets in seconds
  static const int preset25 = 25 * 60;
  static const int preset45 = 45 * 60;
  static const int preset60 = 60 * 60;

  // Break durations
  static const int shortBreak = 5 * 60;
  static const int longBreak = 15 * 60;

  // Current session configuration
  FocusMode _mode = FocusMode.pomodoro;
  String _category = 'Deep Work';
  int _plannedDuration = preset25; // seconds

  // Runtime state
  TimerState _state = TimerState.idle;
  int _remaining = preset25; // seconds remaining
  int _elapsed = 0; // seconds elapsed (for stopwatch)
  int _completedCycles = 0;
  DateTime? _startedAt;

  // Break state
  bool _isOnBreak = false;
  int _breakRemaining = 0;
  int _currentBreakDuration = shortBreak;

  Timer? _timer;

  // ── Getters ───────────────────────────────────────────────

  FocusMode get mode => _mode;
  String get category => _category;
  int get plannedDuration => _plannedDuration;
  TimerState get state => _state;
  int get remaining => _remaining;
  int get elapsed => _elapsed;
  int get completedCycles => _completedCycles;

  bool get isRunning => _state == TimerState.running;
  bool get isPaused => _state == TimerState.paused;
  bool get isFinished => _state == TimerState.finished;
  bool get isIdle => _state == TimerState.idle;

  bool get isOnBreak => _isOnBreak;
  int get breakRemaining => _breakRemaining;
  int get currentBreakDuration => _currentBreakDuration;

  double get breakProgress =>
      _currentBreakDuration > 0
          ? 1.0 - (_breakRemaining / _currentBreakDuration).clamp(0.0, 1.0)
          : 0.0;

  String get breakTimeLabel {
    final m = _breakRemaining ~/ 60;
    final s = _breakRemaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Progress 0.0 → 1.0  (for countdown/pomodoro)
  double get progress {
    if (_mode == FocusMode.stopwatch || _plannedDuration == 0) return 0;
    return 1.0 - (_remaining / _plannedDuration).clamp(0.0, 1.0);
  }

  /// Formatted time string MM:SS
  String get timeLabel {
    final secs = _mode == FocusMode.stopwatch ? _elapsed : _remaining;
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Configuration (only when idle/finished) ──────────────

  void configure({FocusMode? mode, String? category, int? plannedDuration}) {
    if (_state == TimerState.running || _state == TimerState.paused) return;
    _mode = mode ?? _mode;
    _category = category ?? _category;
    if (plannedDuration != null) {
      _plannedDuration = plannedDuration;
    }
    _reset();
  }

  // ── Controls ──────────────────────────────────────────────

  void start() {
    if (_state == TimerState.running) return;
    _startedAt ??= DateTime.now().toUtc();
    _state = TimerState.running;
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
    notifyListeners();
  }

  void pause() {
    if (_state != TimerState.running) return;
    _timer?.cancel();
    _state = TimerState.paused;
    notifyListeners();
  }

  void resume() => start();

  void reset() {
    _timer?.cancel();
    _startedAt = null;
    _completedCycles = 0;
    _isOnBreak = false;
    _breakRemaining = 0;
    _reset();
  }

  /// Skip remaining time for Pomodoro → skip work cycle or active break
  void skipCycle() {
    if (_mode != FocusMode.pomodoro) return;
    if (_isOnBreak) {
      // Skip the break → return to idle for next work cycle
      _isOnBreak = false;
      _timer?.cancel();
      _state = TimerState.idle;
      _remaining = _plannedDuration;
      notifyListeners();
      return;
    }
    _completedCycles++;
    // Credit the time elapsed so far for this cycle so buildSession()
    // doesn't return null (which happens when _elapsed == 0).
    _elapsed += _plannedDuration - _remaining;
    _remaining = _plannedDuration;
    _state = TimerState.finished;
    _timer?.cancel();
    notifyListeners();
  }

  // ── Finalise → build FocusSession model ──────────────────

  FocusSession? buildSession(String id) {
    final started = _startedAt;
    if (started == null) return null;
    // Don't persist a session where nothing was actually timed.
    if (_elapsed == 0) return null;
    return FocusSession(
      id: id,
      category: _category,
      mode: _mode,
      plannedDuration: _plannedDuration,
      actualDuration: _elapsed,
      completedCycles: _completedCycles,
      startedAt: started.toIso8601String(),
      endedAt: DateTime.now().toUtc().toIso8601String(),
    );
  }

  // ── Private ───────────────────────────────────────────────

  void _reset() {
    _remaining = _plannedDuration;
    _elapsed = 0;
    _state = TimerState.idle;
    notifyListeners();
  }

  void _tick(Timer t) {
    // ── Break countdown ───────────────────────────────────
    if (_isOnBreak) {
      if (_breakRemaining > 0) {
        _breakRemaining--;
        notifyListeners();
      } else {
        // Break finished → return to idle for next work cycle
        _isOnBreak = false;
        t.cancel();
        _state = TimerState.idle;
        _remaining = _plannedDuration;
        notifyListeners();
      }
      return;
    }

    if (_mode == FocusMode.stopwatch) {
      _elapsed++;
      notifyListeners();
    } else {
      if (_remaining > 0) {
        _remaining--;
        _elapsed++;
        notifyListeners();
      } else {
        // Countdown or Pomodoro reached zero
        _completedCycles++;
        if (_mode == FocusMode.pomodoro) {
          // Auto-start a break: long break every 4 cycles, else short break
          final isLongBreak = _completedCycles % 4 == 0;
          _currentBreakDuration = isLongBreak ? longBreak : shortBreak;
          _breakRemaining = _currentBreakDuration;
          _isOnBreak = true;
          _remaining = _plannedDuration;
          _state = TimerState.running; // break timer auto-runs
          notifyListeners();
        } else {
          t.cancel();
          _state = TimerState.finished;
          notifyListeners();
        }
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
