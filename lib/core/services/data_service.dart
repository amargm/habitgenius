import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/app_data.dart';

/// Thrown when the data file exists but cannot be parsed.
/// Distinct from a missing file (first-launch) and from a [FileSystemException]
/// (storage access error) so the UI can show a meaningful recovery message.
class DataCorruptedException implements Exception {
  const DataCorruptedException();
  @override
  String toString() =>
      'Your data file is corrupted and could not be read. '
      'Your most recent changes may not have been saved.';
}

/// Reads and writes the single-file JSON data store (`habitgenius_data.json`).
class DataService {
  static const _kFileName = 'habitgenius_data.json';

  /// Current schema version produced by this build.
  static const int _kCurrentVersion = 2;

  /// App version string set by [setAppVersion] at startup.
  /// Stamped into [AppMeta.appVersion] on every save.
  static String _appVersion = '1.0.0';

  /// Called from `main.dart` after [PackageInfo] is resolved.
  static void setAppVersion(String version) => _appVersion = version;

  /// Returns the full path to the data file inside the app's internal
  /// documents directory. All users (guest, registered, pro) share the same
  /// storage location — data never leaves the device.
  Future<String> resolveFilePath({
    // These parameters are kept for API compatibility but are no longer used.
    bool isGuest = true,
    String? customDirPath,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_kFileName';
  }

  /// Loads [AppData] from [filePath].
  ///
  /// Returns [AppData.empty] when the file does not exist (first launch).
  /// Throws [DataCorruptedException] when the file exists but cannot be parsed
  /// so the UI can show a specific recovery prompt instead of silently losing
  /// all user data.
  /// Any [FileSystemException] (permissions, I/O error) propagates as-is.
  Future<AppData> loadData(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return AppData.empty();
    final String contents;
    try {
      contents = await file.readAsString();
    } on FileSystemException {
      rethrow; // storage permission / I-O error — let DataNotifier set error state
    }
    try {
      var map = jsonDecode(contents) as Map<String, dynamic>;
      map = _runMigrations(map);
      return AppData.fromJson(map);
    } on FormatException {
      throw const DataCorruptedException();
    } on TypeError {
      throw const DataCorruptedException();
    } catch (_) {
      throw const DataCorruptedException();
    }
  }

  // ── Schema migrations ─────────────────────────────────────

  /// Runs all pending migrations on [data] (raw JSON map) and returns the
  /// migrated map.  Migrations are applied sequentially from the stored
  /// version up to [_kCurrentVersion].
  Map<String, dynamic> _runMigrations(Map<String, dynamic> data) {
    final meta = data['meta'] as Map<String, dynamic>? ?? {};
    var version = (meta['version'] as int?) ?? 1;
    var current = data;

    if (version < 2) {
      current = _migrateV1ToV2(current);
      version = 2;
    }

    return current;
  }

  /// v1 → v2: convert [Transaction.amount] from fractional dollars (double)
  /// to integer cents so all arithmetic is exact.
  Map<String, dynamic> _migrateV1ToV2(Map<String, dynamic> data) {
    final txList = (data['transactions'] as List<dynamic>?) ?? const [];
    final migratedTxs = txList.map((raw) {
      final tx = Map<String, dynamic>.from(raw as Map<String, dynamic>);
      final amount = tx['amount'];
      if (amount is double) {
        // Convert dollar-fraction to cents, rounding to avoid IEEE 754 drift.
        tx['amount'] = (amount * 100).round();
      } else if (amount is int && amount > 0 && amount < 10000000) {
        // Heuristic: amounts stored as small ints are likely already in dollars
        // (e.g. someone stored 50 meaning $50.00). Convert to cents.
        // Amounts already in cents (>= 10,000,000 = $100,000) are left as-is.
        tx['amount'] = amount * 100;
      }
      return tx;
    }).toList();

    final meta = Map<String, dynamic>.from(
      data['meta'] as Map<String, dynamic>? ?? {},
    );
    meta['version'] = 2;

    return {
      ...data,
      'meta': meta,
      'transactions': migratedTxs,
    };
  }

  /// Writes [data] to [filePath], stamping [AppMeta.lastModified] first.
  ///
  /// Uses an atomic write: data is written to a sibling `.tmp` file first,
  /// then renamed over the real file.  This prevents a partially-written
  /// (and therefore corrupt) file if the app is killed mid-write.
  Future<void> saveData(AppData data, String filePath) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    final updated = data.copyWith(
      meta: data.meta.copyWith(
        lastModified: DateTime.now().toUtc().toIso8601String(),
        appVersion: _appVersion,
        version: _kCurrentVersion,
      ),
    );
    final json = const JsonEncoder.withIndent('  ').convert(updated.toJson());
    // Write to a temp file first, then atomically rename.
    final tmp = File('$filePath.tmp');
    await tmp.writeAsString(json, flush: true);
    try {
      await tmp.rename(filePath);
    } on FileSystemException {
      // rename() fails across filesystem boundaries (e.g. internal → SD card
      // on some OEM devices). Fall back to copy + delete which always works.
      await tmp.copy(filePath);
      await tmp.delete();
    }
  }

  /// Returns true if the data file exists at [filePath].
  Future<bool> fileExists(String filePath) => File(filePath).exists();

  /// Verifies that the app can actually write to [dirPath].
  ///
  /// Creates a hidden test file, writes a byte, then deletes it.
  /// Returns true if all three succeed; false otherwise.
  ///
  /// Use this in the folder-setup flow BEFORE persisting the chosen path
  /// to SharedPreferences — on Android 11+ scoped storage, user-picked
  /// external directories cannot be accessed with dart:io even if
  /// file_picker returned a real filesystem path.
  Future<bool> testWriteAccess(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final probe = File('$dirPath/.hg_write_probe');
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }
}
