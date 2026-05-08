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
// Persisted across process restarts so "sync failed" survives app kill/reopen.
const _kLastSyncStatus = 'cloud_sync_last_status'; // 'idle'|'synced'|'error'
const _kLastSyncError = 'cloud_sync_last_error';
// Accurate conflict resolution: cache Drive's modifiedTime (ms UTC) and
// the local data.meta.lastModified string after every successful sync.
// Comparing Drive timestamps to each other avoids the bug where
// Drive's upload time is always later than the mutation time it carries.
const _kLastKnownDriveMs = 'cloud_sync_last_known_drive_ms';
const _kLastSyncedLocalModified = 'cloud_sync_last_synced_local_modified';

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
  bool _syncCancelled = false;
  // Tracks when the current sync started so we can detect hangs.
  DateTime? _syncStartedAt;
  // Stored args for flush-on-background immediate upload.
  DataNotifier? _pendingDataNotifier;
  GoogleSignIn? _pendingGoogleSignIn;

  CloudSyncNotifier(this._prefs)
    : super(
        CloudSyncState(
          // Restore persisted error so the user sees "sync failed" after reopening.
          status: _readInitialStatus(_prefs),
          lastSynced: _readLastSynced(_prefs),
          errorMessage: _prefs.getString(_kLastSyncError),
        ),
      );

  static SyncStatus _readInitialStatus(SharedPreferences prefs) {
    if (!(prefs.getBool(_kSyncEnabled) ?? false)) return SyncStatus.disabled;
    final s = prefs.getString(_kLastSyncStatus);
    if (s == 'error') return SyncStatus.error;
    if (s == 'synced') return SyncStatus.synced;
    return SyncStatus.idle;
  }

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
    _syncCancelled = true;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _pendingDataNotifier = null;
    _pendingGoogleSignIn = null;
    await _prefs.setBool(_kSyncEnabled, false);
    await _prefs.remove(_kLastSyncStatus);
    await _prefs.remove(_kLastSyncError);
    // Clear cached Drive timestamps so the next user/re-enable starts fresh.
    await _prefs.remove(_kLastKnownDriveMs);
    await _prefs.remove(_kLastSyncedLocalModified);
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
    // Cache args so flushPendingUpload() can use them.
    _pendingDataNotifier = dataNotifier;
    _pendingGoogleSignIn = googleSignIn;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 5), () {
      _pendingDataNotifier = null;
      _pendingGoogleSignIn = null;
      _doSync(
        dataNotifier: dataNotifier,
        googleSignIn: googleSignIn,
        uploadOnly: true,
      ).ignore();
    });
  }

  /// Cancels the debounce timer and immediately triggers an upload.
  /// Call this when the app goes to background so data is synced before
  /// the process might be killed.
  Future<void> flushPendingUpload() async {
    final dn = _pendingDataNotifier;
    final gs = _pendingGoogleSignIn;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _pendingDataNotifier = null;
    _pendingGoogleSignIn = null;
    if (!state.isEnabled || dn == null || gs == null) return;
    await _doSync(dataNotifier: dn, googleSignIn: gs, uploadOnly: true);
  }

  /// If a sync has been running for more than 20 seconds,
  /// resets the state to error so the UI doesn't show "Syncing…" forever.
  /// Returns true if the hang was detected and state was reset.
  bool abortIfHanging() {
    if (state.status != SyncStatus.syncing) return false;
    const hangThresholdSeconds = 20;
    final started = _syncStartedAt;
    if (started != null &&
        DateTime.now().difference(started).inSeconds > hangThresholdSeconds) {
      _syncCancelled =
          true; // stop any in-flight _doSync from overwriting state
      const msg = 'Sync timed out — will retry next time';
      state = state.copyWith(status: SyncStatus.error, errorMessage: msg);
      _prefs.setString(_kLastSyncStatus, 'error').ignore();
      _prefs.setString(_kLastSyncError, msg).ignore();
      // Reset flag after a tick so a fresh _doSync can be started.
      Future.microtask(() => _syncCancelled = false);
      return true;
    }
    return false;
  }

  /// Checks for remote changes on app resume. Download-first: if the remote
  /// file is newer the local data is refreshed in-place.
  Future<void> checkOnResume({
    required DataNotifier dataNotifier,
    required GoogleSignIn? googleSignIn,
  }) async {
    if (!state.isEnabled) return;
    if (googleSignIn == null) return;
    // If a previous sync is stuck (hung in background), abort it first.
    abortIfHanging();
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

    _syncCancelled = false;
    _syncStartedAt = DateTime.now();
    state = state.copyWith(
      status: SyncStatus.syncing,
      errorMessage: null,
      isAuthRevoked: false,
    );

    try {
      // 15-second timeout so the UI never hangs indefinitely.
      await _runSync(
        dataNotifier: dataNotifier,
        googleSignIn: googleSignIn,
        filePath: filePath,
        uploadOnly: uploadOnly,
      ).timeout(const Duration(seconds: 15));

      if (_syncCancelled) {
        _syncCancelled = false;
        return;
      }
      _syncStartedAt = null;
      final now = DateTime.now().toUtc();
      await _prefs.setInt(_kLastSynced, now.millisecondsSinceEpoch);
      await _prefs.setString(_kLastSyncStatus, 'synced');
      await _prefs.remove(_kLastSyncError);
      state = state.copyWith(status: SyncStatus.synced, lastSynced: now);
    } catch (e) {
      debugPrint('[CloudSync] Sync error: $e');
      final isAuth = _isAuthError(e);
      if (_syncCancelled) {
        _syncCancelled = false;
        return;
      }
      _syncStartedAt = null;
      final msg = _friendlyError(e);
      // Persist error so the user sees it after reopening the app.
      await _prefs.setString(_kLastSyncStatus, 'error');
      await _prefs.setString(_kLastSyncError, msg);
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: msg,
        isAuthRevoked: isAuth,
      );
    }
  }

  /// The actual Drive operations — extracted so `.timeout()` can be applied
  /// cleanly to the whole network interaction.
  ///
  /// Conflict resolution strategy:
  ///   Full sync: compare Drive modifiedTime AGAINST our cached last-known
  ///   Drive timestamp (not against the local mutation time, which is always
  ///   earlier than the upload time that carries it — that was the bug).
  ///   - Remote changed since last sync  → DOWNLOAD
  ///   - Local changed since last sync   → UPLOAD
  ///   - Both unchanged                  → NO-OP (nothing to do)
  ///
  ///   Upload-only (debounce/flush): blind upload; this device just saved, it wins.
  ///
  ///   Bootstrap (no cached Drive ts, e.g. fresh install or upgrade from old
  ///   build that never wrote this key): fall back to comparing Drive's
  ///   modifiedTime against data.meta.lastModified as a one-time heuristic.
  Future<void> _runSync({
    required DataNotifier dataNotifier,
    required GoogleSignIn googleSignIn,
    required String filePath,
    bool uploadOnly = false,
  }) async {
    await DriveService.instance.init(googleSignIn);

    final remoteMeta = await DriveService.instance.getRemoteMetadata();

    if (uploadOnly) {
      // This device just saved — unconditionally upload.
      debugPrint('[CloudSync] Uploading (debounced / flush)');
      final result = await DriveService.instance.uploadFile(
        filePath,
        existingFileId: remoteMeta?.fileId,
      );
      _cacheSyncResult(
        driveModifiedTime: result.modifiedTime,
        localModified: dataNotifier.state.valueOrNull?.meta.lastModified,
      );
      return;
    }

    if (remoteMeta == null) {
      // No remote file yet (first-ever sync for this account).
      debugPrint('[CloudSync] No remote file — uploading baseline');
      final result = await DriveService.instance.uploadFile(filePath);
      _cacheSyncResult(
        driveModifiedTime: result.modifiedTime,
        localModified: dataNotifier.state.valueOrNull?.meta.lastModified,
      );
      return;
    }

    // ── Full sync with remote file present ────────────────────────────
    final cachedDriveMs = _prefs.getInt(_kLastKnownDriveMs);
    final cachedLocalModified = _prefs.getString(_kLastSyncedLocalModified);
    final remoteModifiedMs = remoteMeta.modifiedTime.millisecondsSinceEpoch;

    if (cachedDriveMs == null) {
      // Bootstrap: no cache yet (fresh install or upgrade from old version).
      // Use the old heuristic as a one-time fallback.
      final localData = dataNotifier.state.valueOrNull;
      final localModified =
          localData?.meta.lastModified != null
              ? DateTime.tryParse(localData!.meta.lastModified)?.toUtc()
              : null;
      if (localModified == null ||
          remoteMeta.modifiedTime.isAfter(localModified)) {
        debugPrint('[CloudSync] Bootstrap — remote newer, downloading');
        await _downloadAndReload(dataNotifier, filePath, remoteMeta);
      } else {
        debugPrint('[CloudSync] Bootstrap — local newer, uploading');
        final result = await DriveService.instance.uploadFile(
          filePath,
          existingFileId: remoteMeta.fileId,
        );
        _cacheSyncResult(
          driveModifiedTime: result.modifiedTime,
          localModified: localData?.meta.lastModified,
        );
      }
      return;
    }

    // Normal path: compare Drive timestamps to each other.
    final remoteChangedSinceLastSync = remoteModifiedMs > cachedDriveMs;
    final localData = dataNotifier.state.valueOrNull;
    final currentLocalModified = localData?.meta.lastModified;
    final localChangedSinceLastSync =
        currentLocalModified != null &&
        currentLocalModified != cachedLocalModified;

    if (remoteChangedSinceLastSync) {
      // Remote changed on another device since our last sync → download.
      debugPrint('[CloudSync] Remote changed — downloading');
      await _downloadAndReload(dataNotifier, filePath, remoteMeta);
    } else if (localChangedSinceLastSync) {
      // Local changed on this device since last sync → upload.
      debugPrint('[CloudSync] Local changed — uploading');
      final result = await DriveService.instance.uploadFile(
        filePath,
        existingFileId: remoteMeta.fileId,
      );
      _cacheSyncResult(
        driveModifiedTime: result.modifiedTime,
        localModified: currentLocalModified,
      );
    } else {
      // Both remote and local unchanged since last sync — nothing to do.
      debugPrint('[CloudSync] Already in sync — no-op');
      // Still update the "last synced" UI timestamp so the user sees a
      // reassuring timestamp without triggering any Drive requests.
    }
  }

  /// Downloads the remote file, writes it to disk, and reloads in-memory data.
  /// Does NOT re-upload after downloading — that was the bug (it stamped a
  /// new Drive modifiedTime that confused the other device's next sync).
  Future<void> _downloadAndReload(
    DataNotifier dataNotifier,
    String filePath,
    DriveFileMeta remoteMeta,
  ) async {
    final json = await DriveService.instance.downloadFile(remoteMeta.fileId);
    await File(filePath).writeAsString(json, flush: true);
    await dataNotifier.reload();
    // Cache the Drive timestamp we just downloaded so the next full sync
    // won't re-download the same data.
    _cacheSyncResult(
      driveModifiedTime: remoteMeta.modifiedTime,
      localModified: dataNotifier.state.valueOrNull?.meta.lastModified,
    );
  }

  /// Persists the Drive modifiedTime and local lastModified after a successful
  /// sync direction so the next sync can compare correctly.
  void _cacheSyncResult({
    required DateTime? driveModifiedTime,
    required String? localModified,
  }) {
    if (driveModifiedTime != null) {
      _prefs
          .setInt(_kLastKnownDriveMs, driveModifiedTime.millisecondsSinceEpoch)
          .ignore();
    }
    if (localModified != null) {
      _prefs.setString(_kLastSyncedLocalModified, localModified).ignore();
    }
  }

  String _friendlyError(Object e) {
    if (e is TimeoutException) {
      return 'Sync timed out — will retry next time';
    }
    if (_isAuthError(e)) {
      return 'Drive access revoked — tap Reconnect to restore';
    }
    if (e is DriveServiceException) return e.message;
    if (e is SocketException) return 'No internet connection';
    return 'Sync failed — please try again';
  }

  /// Returns true when [e] indicates the Drive OAuth token has been revoked
  /// or is otherwise invalid. Covers both DriveServiceException messages and
  /// raw HTTP 401 / insufficient_scope / invalid_grant errors from googleapis.
  bool _isAuthError(Object e) {
    final s = e.toString().toLowerCase();
    if (e is DriveServiceException) {
      return s.contains('authenticated') ||
          s.contains('not auth') ||
          s.contains('401') ||
          s.contains('scope') ||
          s.contains('invalid_grant') ||
          s.contains('token');
    }
    return s.contains('401') ||
        s.contains('invalid_grant') ||
        s.contains('insufficient_scope');
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
