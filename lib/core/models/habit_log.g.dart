// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit_log.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HabitLog _$HabitLogFromJson(Map<String, dynamic> json) => HabitLog(
  id: json['id'] as String,
  habitId: json['habitId'] as String,
  date: json['date'] as String,
  completed: json['completed'] as bool,
  value: (json['value'] as num).toInt(),
  completedAt: json['completedAt'] as String?,
);

Map<String, dynamic> _$HabitLogToJson(HabitLog instance) => <String, dynamic>{
  'id': instance.id,
  'habitId': instance.habitId,
  'date': instance.date,
  'completed': instance.completed,
  'value': instance.value,
  if (instance.completedAt case final value?) 'completedAt': value,
};
