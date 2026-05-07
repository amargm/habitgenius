import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/data_provider.dart';
import '../services/drive_service.dart';
import 'settings_provider.dart';

// ── Shared-pref keys ──────────────────────────────────────

const _kSyncEnabled = 'cloud_sync_enabled';
const _kLastSynced = 'cloud_sync_last_synced_ms';

// ── Status enum ───────────────────────────────────────────

enum SyncStatus { idle, syncing, synced, error, disabled }

// ── State ─────────────────────────────────────────────────

class CloudSyncState {
  final SyncStatus status;
  final DateTime? lastSynced;
  final String? errorMessage;

  /// True when the error was caused by the Drive OAuth scope being revoked.
  /// The UI uses this to show a "Reconnect" button instead of "Retry".
  final bool isAuthRevoked;

  const CloudSyncState({
    required this.status,
    this.lastSynced,
    this.errorMessage,
    this.isAuthRevoked = false,
  });

  bool get isEnabled => status != SyncStatus.disabled;

  CloudSyncState copyWith({
    SyncStatus? status,
    DateTime? lastSynced,
    String? errorMessage,
    bool? isAuthRevoked,
  }) => CloudSyncState(
    status: status ?? this.status,
    lastSynced: lastSynced ?? this.lastSynced,
    errorMessage: errorMessage, // intentionally resets to null if omitted
    isAuthRevoked: isAuthRevoked ?? false, // resets to false if omitted
  );
}

// ── Notifier ──────────────────────────────────────────────

/// Manages Google Drive two-way sync for the app's local JSON data file.
///
/// Conflict resolution: last-write-wins using [AppMeta.lastModified].
/// Remote file is stored in the Drive App Data folder (hidden, sandboxed).
///
/// Sync is Pro-only — the caller must gate `enableSync` behind a tier check.
class CloudSyncNotifier extends StateNotifier<CloudSyncState> {
  final SharedPreferences _prefs;

  Timer? _debounceTimer;

  CloudSyncNotifier(this._prefs)
    : super(
        CloudSyncState(
          status:
              (_prefs.getBool(_kSyncEnabled) ?? false)
                  ? SyncStatus.idle
                  : SyncStatus.disabled,
          lastSynced: _readLastSynced(_prefs),
        ),
      );

  static DateTime? _readLastSynced(SharedPreferences prefs) {
    final ms = prefs.getInt(_kLastSynced);
    return ms != null
        ? DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true)
        : null;
  }

  // ── Public API ────────────────────────────────────────────

  /// Enables sync and performs an immediate first sync.
  ///
  /// Caller must have already called [AuthService.requestDriveScope] and
  /// received `true` before calling this.
  Future<void> enableSync({
    required DataNotifier dataNotifier,
    required GoogleSignIn googleSignIn,
  }) async {
    await _prefs.setBool(_kSyncEnabled, true);
    state = state.copyWith(status: SyncStatus.idle);
    await _doSync(dataNotifier: dataNotifier, googleSignIn: googleSignIn);
  }

  /// Disables sync and cancels any pending debounce upload.
  Future<void> disableSync() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    await _prefs.setBool(_kSyncEnabled, false);
    state = CloudSyncState(
      status: SyncStatus.disabled,
      lastSynced: state.lastSynced,
    );
  }

  /// Schedules an upload 5 seconds after the last save.
  ///
  /// Each call resets the timer, so rapid successive saves collapse into one
  /// upload request. No-op if sync is disabled.
  void scheduleUpload({
    required DataNotifier dataNotifier,
    required GoogleSignIn? googleSignIn,
  }) {
    if (!state.isEnabled) return;
    if (googleSignIn == null) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 5), () {
      _doSync(
        dataNotifier: dataNotifier,
        googleSignIn: googleSignIn,
        uploadOnly: true,
      ).ignore();
    });
  }

  /// Checks for remote changes on app resume. Download-first: if the remote
  /// file is newer the local data is refreshed in-place.
  Future<void> checkOnResume({
    required DataNotifier dataNotifier,
    required GoogleSignIn? googleSignIn,
  }) async {
    if (!state.isEnabled) return;
    if (googleSignIn == null) return;
    if (state.status == SyncStatus.syncing) return;
    await _doSync(dataNotifier: dataNotifier, googleSignIn: googleSignIn);
  }

  /// Full two-way sync triggered at launch (after local data is loaded).
  Future<void> syncOnLaunch({
    required DataNotifier dataNotifier,
    required GoogleSignIn? googleSignIn,
  }) => checkOnResume(dataNotifier: dataNotifier, googleSignIn: googleSignIn);

  /// Manually triggered full sync (e.g. "Sync Now" button).
  Future<void> syncNow({
    required DataNotifier dataNotifier,
    required GoogleSignIn googleSignIn,
  }) => _doSync(dataNotifier: dataNotifier, googleSignIn: googleSignIn);

  // ── Core sync logic ───────────────────────────────────────

  Future<void> _doSync({
    required DataNotifier dataNotifier,
    required GoogleSignIn googleSignIn,
    bool uploadOnly = false,
  }) async {
    if (state.status == SyncStatus.syncing) return;
    final filePath = dataNotifier.filePath;
    if (filePath == null) return;

    // Clear any previous error/revoke flags before starting.
    state = state.copyWith(
      status: SyncStatus.syncing,
      errorMessage: null,
      isAuthRevoked: false,
    );

    try {
      // Enforce a 30-second wall-clock timeout so the "Syncing…" UI never
      // hangs indefinitely on a slow or unresponsive network.
      await _runSync(
        dataNotifier: dataNotifier,
        googleSignIn: googleSignIn,
        filePath: filePath,
        uploadOnly: uploadOnly,
      ).timeout(const Duration(seconds: 30));

      final now = DateTime.now().toUtc();
      await _prefs.setInt(_kLastSynced, now.millisecondsSinceEpoch);
      state = state.copyWith(status: SyncStatus.synced, lastSynced: now);
    } catch (e) {
      debugPrint('[CloudSync] Sync error: $e');
      // Detect Drive OAuth scope revocation so the UI can show "Reconnect".
      final isAuth =
          e is DriveServiceException &&
          (e.message.contains('authenticated') ||
              e.message.contains('Not auth'));
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: _friendlyError(e),
        isAuthRevoked: isAuth,
      );
    }
  }

  /// The actual Drive operations — extracted so `.timeout()` can be applied
  /// cleanly to the whole network interaction.
  Future<void> _runSync({
    required DataNotifier dataNotifier,
    required GoogleSignIn googleSignIn,
    required String filePath,
    bool uploadOnly = false,
  }) async {
    await DriveService.instance.init(googleSignIn);

    final remoteMeta = await DriveService.instance.getRemoteMetadata();

    if (!uploadOnly && remoteMeta != null) {
      // Compare timestamps to decide direction.
      final localData = dataNotifier.state.valueOrNull;
      final localModifiedStr = localData?.meta.lastModified;
      final localModified =
          localModifiedStr != null
              ? DateTime.tryParse(localModifiedStr)?.toUtc()
              : null;

      final remoteModified = remoteMeta.modifiedTime;

      if (localModified == null || remoteModified.isAfter(localModified)) {
        // Remote is newer (or local timestamp unknown) → download and reload.
        debugPrint('[CloudSync] Remote newer — downloading');
        final json = await DriveService.instance.downloadFile(
          remoteMeta.fileId,
        );
        await File(filePath).writeAsString(json, flush: true);
        await dataNotifier.reload();
        // Re-upload to stamp Drive's modifiedTime with the file we just wrote
        // (avoids a redundant re-download on the next resume from another device).
        await DriveService.instance.uploadFile(
          filePath,
          existingFileId: remoteMeta.fileId,
        );
      } else {
        // Local is newer (or equal) → upload.
        debugPrint('[CloudSync] Local newer — uploading');
        await DriveService.instance.uploadFile(
          filePath,
          existingFileId: remoteMeta.fileId,
        );
      }
    } else {
      // Upload only (post-save debounce) or no remote file yet.
      debugPrint(
        '[CloudSync] Uploading (${uploadOnly ? "debounced" : "first upload"})',
      );
      await DriveService.instance.uploadFile(
        filePath,
        existingFileId: remoteMeta?.fileId,
      );
    }
  }

  String _friendlyError(Object e) {
    if (e is TimeoutException) {
      return 'Sync timed out — will retry next time';
    }
    if (e is DriveServiceException) {
      if (e.message.contains('authenticated') ||
          e.message.contains('Not auth')) {
        return 'Drive access revoked — tap Reconnect to restore';
      }
      return e.message;
    }
    if (e is SocketException) return 'No internet connection';
    return 'Sync failed — please try again';
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────

final cloudSyncProvider =
    StateNotifierProvider<CloudSyncNotifier, CloudSyncState>((ref) {
      return CloudSyncNotifier(ref.watch(sharedPreferencesProvider));
    });
