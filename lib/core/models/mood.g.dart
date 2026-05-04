// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mood.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Mood _$MoodFromJson(Map<String, dynamic> json) => Mood(
  id: json['id'] as String,
  date: json['date'] as String,
  level: (json['level'] as num).toInt(),
  emoji: json['emoji'] as String,
  tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
  note: json['note'] as String?,
  loggedAt: json['loggedAt'] as String,
);

Map<String, dynamic> _$MoodToJson(Mood instance) => <String, dynamic>{
  'id': instance.id,
  'date': instance.date,
  'level': instance.level,
  'emoji': instance.emoji,
  'tags': instance.tags,
  if (instance.note case final value?) 'note': value,
  'loggedAt': instance.loggedAt,
};
