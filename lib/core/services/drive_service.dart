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
      await googleSignIn.signInSilently();
    }
    final client = await googleSignIn.authenticatedClient();
    if (client == null) {
      throw const DriveServiceException('Not authenticated');
    }
    _api = drive.DriveApi(client);
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
    final result = await _requireApi.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_kDriveFileName'",
      $fields: 'files(id,modifiedTime)',
      pageSize: 1,
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
  /// Returns the Drive file ID of the uploaded file.
  Future<String> uploadFile(String localPath, {String? existingFileId}) async {
    final bytes = await File(localPath).readAsBytes();
    final media = drive.Media(
      Stream.value(bytes),
      bytes.length,
      contentType: 'application/json',
    );

    if (existingFileId != null) {
      final updated = await _requireApi.files.update(
        drive.File(),
        existingFileId,
        uploadMedia: media,
        $fields: 'id',
      );
      return updated.id ?? existingFileId;
    } else {
      final created = await _requireApi.files.create(
        drive.File()
          ..name = _kDriveFileName
          ..parents = ['appDataFolder'],
        uploadMedia: media,
        $fields: 'id',
      );
      final id = created.id;
      if (id == null) {
        throw const DriveServiceException(
          'Upload succeeded but no file ID returned',
        );
      }
      return id;
    }
  }

  /// Downloads the file with [fileId] and returns its contents as a JSON string.
  Future<String> downloadFile(String fileId) async {
    final media =
        await _requireApi.files.get(
              fileId,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;

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
}

class DriveServiceException implements Exception {
  final String message;
  const DriveServiceException(this.message);

  @override
  String toString() => 'DriveServiceException: $message';
}
