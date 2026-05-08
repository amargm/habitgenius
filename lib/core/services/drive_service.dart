import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

/// The filename stored in the Drive App Data folder.
/// Must match [DataService._kFileName].
const _kDriveFileName = 'habitgenius_data.json';

/// Metadata returned from [DriveService.getRemoteMetadata].
class DriveFileMeta {
  final String fileId;
  final DateTime modifiedTime;

  const DriveFileMeta({required this.fileId, required this.modifiedTime});
}

/// Result of a successful upload operation.
class DriveUploadResult {
  final String fileId;

  /// Drive's server-side modifiedTime for the uploaded file.
  /// Null when the API response omits the field (should not happen in practice).
  final DateTime? modifiedTime;

  const DriveUploadResult({required this.fileId, required this.modifiedTime});
}

/// Thin wrapper around the Google Drive v3 API, scoped to the App Data folder.
///
/// The App Data folder (`appDataFolder`) is:
///   - Hidden from the user — not visible in their Drive UI
///   - Sandboxed per-app — no other app can read it
///   - Quota: 100 MB per app per user
///
/// All methods throw [DriveServiceException] on unrecoverable errors.
/// Network errors and transient failures are allowed to propagate as-is.
class DriveService {
  DriveService._();
  static final DriveService instance = DriveService._();

  drive.DriveApi? _api;

  /// Initialises the Drive API client from the current Google Sign-In session.
  ///
  /// Must be called (and awaited) before any other method.
  /// Safe to call again after a token refresh — it simply rebuilds the client.
  Future<void> init(GoogleSignIn googleSignIn) async {
    // If there is no current user (e.g. app was killed and restarted while
    // sync was enabled, or the token was evicted from cache), attempt a silent
    // sign-in to restore the session before building the HTTP client.
    if (googleSignIn.currentUser == null) {
      try {
        await googleSignIn.signInSilently();
      } catch (_) {
        // A PlatformException here means sign-in failed (e.g. network issue,
        // credentials revoked, or a developer-config error).  Fall through to
        // authenticatedClient() which will return null and produce a clear
        // DriveServiceException that the caller maps to an auth error.
      }
    }
    try {
      final client = await googleSignIn.authenticatedClient();
      if (client == null) {
        throw const DriveServiceException('Not authenticated');
      }
      _api = drive.DriveApi(client);
    } on DriveServiceException {
      rethrow;
    } catch (_) {
      // authenticatedClient() can throw (e.g. PlatformException from
      // GoogleSignInAccount.authHeaders when the token can't be refreshed).
      throw const DriveServiceException('Not authenticated');
    }
  }

  drive.DriveApi get _requireApi {
    final api = _api;
    if (api == null) {
      throw const DriveServiceException('DriveService not initialised');
    }
    return api;
  }

  /// Lists the App Data folder and returns the metadata for [_kDriveFileName],
  /// or null if the file does not exist yet.
  Future<DriveFileMeta?> getRemoteMetadata() async {
    final result = await _withRetry(
      () => _requireApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$_kDriveFileName'",
        $fields: 'files(id,modifiedTime)',
        pageSize: 1,
      ),
    );
    final files = result.files;
    if (files == null || files.isEmpty) return null;
    final f = files.first;
    final id = f.id;
    final modified = f.modifiedTime;
    if (id == null || modified == null) return null;
    return DriveFileMeta(fileId: id, modifiedTime: modified.toUtc());
  }

  /// Uploads [localPath] to the App Data folder.
  ///
  /// If [existingFileId] is provided, the existing file is patched (updated).
  /// Otherwise a new file is created.
  /// Returns a [DriveUploadResult] containing the file ID and Drive's
  /// server-side modifiedTime (used for accurate conflict resolution).
  Future<DriveUploadResult> uploadFile(
    String localPath, {
    String? existingFileId,
  }) async {
    final bytes = await File(localPath).readAsBytes();
    final media = drive.Media(
      Stream.value(bytes),
      bytes.length,
      contentType: 'application/json',
    );

    if (existingFileId != null) {
      final updated = await _withRetry(
        () => _requireApi.files.update(
          drive.File(),
          existingFileId,
          uploadMedia: media,
          $fields: 'id,modifiedTime',
        ),
      );
      return DriveUploadResult(
        fileId: updated.id ?? existingFileId,
        modifiedTime: updated.modifiedTime?.toUtc(),
      );
    } else {
      final created = await _withRetry(
        () => _requireApi.files.create(
          drive.File()
            ..name = _kDriveFileName
            ..parents = ['appDataFolder'],
          uploadMedia: media,
          $fields: 'id,modifiedTime',
        ),
      );
      final id = created.id;
      if (id == null) {
        throw const DriveServiceException(
          'Upload succeeded but no file ID returned',
        );
      }
      return DriveUploadResult(
        fileId: id,
        modifiedTime: created.modifiedTime?.toUtc(),
      );
    }
  }

  /// Downloads the file with [fileId] and returns its contents as a JSON string.
  Future<String> downloadFile(String fileId) async {
    final media = await _withRetry(
          () async =>
              await _requireApi.files.get(
                    fileId,
                    downloadOptions: drive.DownloadOptions.fullMedia,
                  )
                  as drive.Media,
        );

    final bytes = await _collectStream(media.stream);
    return utf8.decode(bytes);
  }

  Future<List<int>> _collectStream(Stream<List<int>> stream) async {
    final buffer = <int>[];
    await for (final chunk in stream) {
      buffer.addAll(chunk);
    }
    return buffer;
  }

  /// Retries [fn] up to [maxAttempts] times using exponential backoff.
  ///
  /// Retries only on transient HTTP errors (429 Too Many Requests, 503 Service
  /// Unavailable) and [SocketException] (network unreachable).  All other
  /// errors are rethrown immediately.
  ///
  /// Delays: 1 s, 2 s, 4 s, … (capped at 30 s).
  static Future<T> _withRetry<T>(
    Future<T> Function() fn, {
    int maxAttempts = 3,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        return await fn();
      } on drive.DetailedApiRequestError catch (e) {
        final retryable = e.status == 429 || e.status == 503;
        attempt++;
        if (!retryable || attempt >= maxAttempts) rethrow;
        final delay = Duration(seconds: (1 << (attempt - 1)).clamp(1, 30));
        await Future<void>.delayed(delay);
      } on SocketException {
        attempt++;
        if (attempt >= maxAttempts) rethrow;
        final delay = Duration(seconds: (1 << (attempt - 1)).clamp(1, 30));
        await Future<void>.delayed(delay);
      }
    }
  }
}

class DriveServiceException implements Exception {
  final String message;
  const DriveServiceException(this.message);

  @override
  String toString() => 'DriveServiceException: $message';
}
