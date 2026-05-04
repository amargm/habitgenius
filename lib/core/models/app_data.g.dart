// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppData _$AppDataFromJson(Map<String, dynamic> json) => AppData(
  meta: AppMeta.fromJson(json['meta'] as Map<String, dynamic>),
  settings: AppSettings.fromJson(json['settings'] as Map<String, dynamic>),
  habits:
      (json['habits'] as List<dynamic>)
          .map((e) => Habit.fromJson(e as Map<String, dynamic>))
          .toList(),
  habitLogs:
      (json['habitLogs'] as List<dynamic>)
          .map((e) => HabitLog.fromJson(e as Map<String, dynamic>))
          .toList(),
  moods:
      (json['moods'] as List<dynamic>)
          .map((e) => Mood.fromJson(e as Map<String, dynamic>))
          .toList(),
  focusSessions:
      (json['focusSessions'] as List<dynamic>)
          .map((e) => FocusSession.fromJson(e as Map<String, dynamic>))
          .toList(),
  journal:
      (json['journal'] as List<dynamic>)
          .map((e) => JournalEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
  accounts:
      (json['accounts'] as List<dynamic>)
          .map((e) => Account.fromJson(e as Map<String, dynamic>))
          .toList(),
  transactions:
      (json['transactions'] as List<dynamic>)
          .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
          .toList(),
);

Map<String, dynamic> _$AppDataToJson(AppData instance) => <String, dynamic>{
  'meta': instance.meta,
  'settings': instance.settings,
  'habits': instance.habits,
  'habitLogs': instance.habitLogs,
  'moods': instance.moods,
  'focusSessions': instance.focusSessions,
  'journal': instance.journal,
  'accounts': instance.accounts,
  'transactions': instance.transactions,
};
