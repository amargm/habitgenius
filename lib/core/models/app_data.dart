import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

import 'app_meta.dart';
import 'app_settings.dart';
import 'habit.dart';
import 'habit_log.dart';
import 'mood.dart';
import 'focus_session.dart';
import 'journal_entry.dart';
import 'account.dart';
import 'transaction.dart';

part 'app_data.g.dart';

@JsonSerializable()
class AppData {
  final AppMeta meta;
  final AppSettings settings;
  final List<Habit> habits;
  final List<HabitLog> habitLogs;
  final List<Mood> moods;
  final List<FocusSession> focusSessions;
  final List<JournalEntry> journal;
  final List<Account> accounts;
  final List<Transaction> transactions;

  const AppData({
    required this.meta,
    required this.settings,
    required this.habits,
    required this.habitLogs,
    required this.moods,
    required this.focusSessions,
    required this.journal,
    required this.accounts,
    required this.transactions,
  });

  /// Creates a brand-new data file with default settings and all empty lists.
  factory AppData.empty() {
    final now = DateTime.now().toUtc().toIso8601String();
    return AppData(
      meta: AppMeta(
        version: 1,
        appVersion: '1.0.0',
        createdAt: now,
        lastModified: now,
        deviceId: const Uuid().v4(),
      ),
      settings: AppSettings.defaults(),
      habits: const [],
      habitLogs: const [],
      moods: const [],
      focusSessions: const [],
      journal: const [],
      accounts: const [],
      transactions: const [],
    );
  }

  factory AppData.fromJson(Map<String, dynamic> json) =>
      _$AppDataFromJson(json);

  Map<String, dynamic> toJson() => _$AppDataToJson(this);

  AppData copyWith({
    AppMeta? meta,
    AppSettings? settings,
    List<Habit>? habits,
    List<HabitLog>? habitLogs,
    List<Mood>? moods,
    List<FocusSession>? focusSessions,
    List<JournalEntry>? journal,
    List<Account>? accounts,
    List<Transaction>? transactions,
  }) => AppData(
    meta: meta ?? this.meta,
    settings: settings ?? this.settings,
    habits: habits ?? this.habits,
    habitLogs: habitLogs ?? this.habitLogs,
    moods: moods ?? this.moods,
    focusSessions: focusSessions ?? this.focusSessions,
    journal: journal ?? this.journal,
    accounts: accounts ?? this.accounts,
    transactions: transactions ?? this.transactions,
  );
}
