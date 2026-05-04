import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/app_data.dart';

/// Reads and writes the single-file JSON data store (`habitgenius_data.json`).
class DataService {
  static const _kFileName = 'habitgenius_data.json';

  /// Returns the full path to the data file.
  ///
  /// * **Guest** users → app's internal documents directory (not user-visible).
  /// * **Registered/Pro** users → their chosen [customDirPath] (e.g. a Google
  ///   Drive folder), set during the [FileSetupScreen] flow.
  Future<String> resolveFilePath({
    required bool isGuest,
    required String? customDirPath,
  }) async {
    if (isGuest || customDirPath == null || customDirPath.isEmpty) {
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}/$_kFileName';
    }
    final dir =
        customDirPath.endsWith('/')
            ? customDirPath.substring(0, customDirPath.length - 1)
            : customDirPath;
    return '$dir/$_kFileName';
  }

  /// Loads [AppData] from [filePath].
  ///
  /// Returns a fresh [AppData.empty] if the file does not exist.
  /// Treats corrupted / unparseable JSON as an empty file (Sprint 8 adds
  /// a recovery UI for this case).
  Future<AppData> loadData(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return AppData.empty();
    try {
      final contents = await file.readAsString();
      final map = jsonDecode(contents) as Map<String, dynamic>;
      return AppData.fromJson(map);
    } catch (_) {
      return AppData.empty();
    }
  }

  /// Writes [data] to [filePath], stamping [AppMeta.lastModified] first.
  ///
  /// Creates parent directories if needed (e.g. first save).
  Future<void> saveData(AppData data, String filePath) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    final updated = data.copyWith(
      meta: data.meta.copyWith(
        lastModified: DateTime.now().toUtc().toIso8601String(),
      ),
    );
    final json = const JsonEncoder.withIndent('  ').convert(updated.toJson());
    await file.writeAsString(json, flush: true);
  }

  /// Returns true if the data file exists at [filePath].
  Future<bool> fileExists(String filePath) => File(filePath).exists();
}
