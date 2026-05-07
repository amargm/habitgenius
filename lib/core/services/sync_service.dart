import 'dart:io';
import '../../core/providers/data_provider.dart';

/// Watches the data file's modification timestamp.
/// On app resume ([WidgetsBindingObserver.didChangeAppLifecycleState]),
/// call [checkAndReload] to transparently refresh data if the file changed.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  DateTime? _lastKnownModified;

  /// Resets the stored timestamp.
  /// Call whenever the current user changes (sign-out / sign-in) so the next
  /// [checkAndReload] compares against the new user's file, not the old one's.
  void reset() => _lastKnownModified = null;

  /// Records the current instant as the baseline modification time.
  ///
  /// Call after every successful in-app save so that a subsequent app-resume
  /// does NOT trigger a spurious reload.  The file mtime just changed because
  /// of this app's own write — not because of an external modification.
  void markUpdated() {
    // Truncate to second precision so comparisons with filesystem mtime
    // (which some Android OEM kernels round to the second) don't produce
    // spurious reloads.
    final n = DateTime.now();
    _lastKnownModified = DateTime(
      n.year,
      n.month,
      n.day,
      n.hour,
      n.minute,
      n.second,
    );
  }

  /// Checks whether the backing file was modified since we last read it.
  /// If so, triggers a [DataNotifier.reload]. Safe to call frequently.
  Future<void> checkAndReload(DataNotifier notifier) async {
    final path = notifier.filePath;
    if (path == null) return;
    try {
      final file = File(path);
      if (!await file.exists()) return;
      final modified = (await file.stat()).modified;
      if (_lastKnownModified == null) {
        _lastKnownModified = modified;
        return;
      }
      if (modified.isAfter(_lastKnownModified!)) {
        _lastKnownModified = modified;
        await notifier.reload();
      }
    } catch (_) {
      // File access errors are non-fatal — silently skip.
    }
  }

  /// Call after a successful [DataNotifier.load] to seed the baseline timestamp.
  Future<void> seedTimestamp(String? filePath) async {
    if (filePath == null) return;
    try {
      final file = File(filePath);
      if (await file.exists()) {
        _lastKnownModified = (await file.stat()).modified;
      }
    } catch (_) {}
  }
}
