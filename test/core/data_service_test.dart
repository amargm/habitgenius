import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:habitgenius/core/models/app_data.dart';
import 'package:habitgenius/core/models/app_settings.dart';
import 'package:habitgenius/core/services/data_service.dart';

void main() {
  late DataService service;
  late String tempPath;

  setUp(() {
    service = DataService();
    tempPath =
        '${Directory.systemTemp.path}/habitgenius_test_${DateTime.now().millisecondsSinceEpoch}.json';
  });

  tearDown(() async {
    final f = File(tempPath);
    if (await f.exists()) await f.delete();
  });

  group('DataService', () {
    test('loadData returns AppData.empty when file does not exist', () async {
      final data = await service.loadData(tempPath);

      expect(data.habits, isEmpty);
      expect(data.habitLogs, isEmpty);
      expect(data.moods, isEmpty);
      expect(data.focusSessions, isEmpty);
      expect(data.journal, isEmpty);
      expect(data.accounts, isEmpty);
      expect(data.transactions, isEmpty);
    });

    test('saveData creates the file', () async {
      final original = AppData.empty();
      await service.saveData(original, tempPath);

      expect(await service.fileExists(tempPath), isTrue);
    });

    test('saveData + loadData round-trip preserves settings', () async {
      final original = AppData.empty().copyWith(
        settings: AppSettings.defaults().copyWith(currency: 'EUR'),
      );
      await service.saveData(original, tempPath);
      final loaded = await service.loadData(tempPath);

      expect(loaded.settings.currency, 'EUR');
      expect(loaded.meta.version, original.meta.version);
      expect(loaded.meta.deviceId, original.meta.deviceId);
    });

    test('saveData updates lastModified on each save', () async {
      final original = AppData.empty();
      await service.saveData(original, tempPath);
      final first = await service.loadData(tempPath);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      await service.saveData(first, tempPath);
      final second = await service.loadData(tempPath);

      expect(
        DateTime.parse(
          second.meta.lastModified,
        ).isAfter(DateTime.parse(first.meta.lastModified)),
        isTrue,
      );
    });

    test('loadData throws DataCorruptedException on corrupted JSON', () async {
      await File(tempPath).writeAsString('{ invalid json %%% }');

      expect(
        () => service.loadData(tempPath),
        throwsA(isA<DataCorruptedException>()),
      );
    });

    test('fileExists returns false for non-existent path', () async {
      expect(await service.fileExists(tempPath), isFalse);
    });

    test('resolveFilePath uses internal dir for guest', () async {
      final path = await service.resolveFilePath(
        isGuest: true,
        customDirPath: '/some/custom/path',
      );
      expect(path, isNot(contains('/some/custom/path')));
      expect(path, endsWith('habitgenius_data.json'));
    });

    test('resolveFilePath uses customDirPath for registered user', () async {
      const custom = '/storage/emulated/0/HabitGenius';
      final path = await service.resolveFilePath(
        isGuest: false,
        customDirPath: custom,
      );
      expect(path, equals('$custom/habitgenius_data.json'));
    });

    test(
      'resolveFilePath falls back to internal dir when customDirPath is null',
      () async {
        final path = await service.resolveFilePath(
          isGuest: false,
          customDirPath: null,
        );
        expect(path, endsWith('habitgenius_data.json'));
      },
    );
  });
}
