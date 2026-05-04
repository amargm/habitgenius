// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'focus_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FocusSession _$FocusSessionFromJson(Map<String, dynamic> json) => FocusSession(
  id: json['id'] as String,
  category: json['category'] as String,
  mode: $enumDecode(_$FocusModeEnumMap, json['mode']),
  plannedDuration: (json['plannedDuration'] as num).toInt(),
  actualDuration: (json['actualDuration'] as num).toInt(),
  completedCycles: (json['completedCycles'] as num).toInt(),
  startedAt: json['startedAt'] as String,
  endedAt: json['endedAt'] as String,
);

Map<String, dynamic> _$FocusSessionToJson(FocusSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'category': instance.category,
      'mode': _$FocusModeEnumMap[instance.mode]!,
      'plannedDuration': instance.plannedDuration,
      'actualDuration': instance.actualDuration,
      'completedCycles': instance.completedCycles,
      'startedAt': instance.startedAt,
      'endedAt': instance.endedAt,
    };

const _$FocusModeEnumMap = {
  FocusMode.pomodoro: 'pomodoro',
  FocusMode.countdown: 'countdown',
  FocusMode.stopwatch: 'stopwatch',
};
