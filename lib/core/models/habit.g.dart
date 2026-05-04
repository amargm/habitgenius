// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Habit _$HabitFromJson(Map<String, dynamic> json) => Habit(
  id: json['id'] as String,
  name: json['name'] as String,
  icon: json['icon'] as String,
  colorHex: json['colorHex'] as String,
  progressType: $enumDecode(_$HabitProgressTypeEnumMap, json['progressType']),
  targetValue: (json['targetValue'] as num).toInt(),
  unit: json['unit'] as String?,
  schedule: $enumDecode(_$HabitScheduleEnumMap, json['schedule']),
  scheduleDays:
      (json['scheduleDays'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
  reminderTime: json['reminderTime'] as String?,
  createdAt: json['createdAt'] as String,
  archivedAt: json['archivedAt'] as String?,
  checklistItems:
      (json['checklistItems'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
);

Map<String, dynamic> _$HabitToJson(Habit instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'icon': instance.icon,
  'colorHex': instance.colorHex,
  'progressType': _$HabitProgressTypeEnumMap[instance.progressType]!,
  'targetValue': instance.targetValue,
  if (instance.unit case final value?) 'unit': value,
  'schedule': _$HabitScheduleEnumMap[instance.schedule]!,
  'scheduleDays': instance.scheduleDays,
  if (instance.reminderTime case final value?) 'reminderTime': value,
  'createdAt': instance.createdAt,
  if (instance.archivedAt case final value?) 'archivedAt': value,
  'checklistItems': instance.checklistItems,
};

const _$HabitProgressTypeEnumMap = {
  HabitProgressType.checkbox: 'checkbox',
  HabitProgressType.counter: 'counter',
  HabitProgressType.timer: 'timer',
  HabitProgressType.stopwatch: 'stopwatch',
  HabitProgressType.checklist: 'checklist',
};

const _$HabitScheduleEnumMap = {
  HabitSchedule.daily: 'daily',
  HabitSchedule.weekly: 'weekly',
  HabitSchedule.monthly: 'monthly',
  HabitSchedule.specific: 'specific',
  HabitSchedule.custom: 'custom',
};
