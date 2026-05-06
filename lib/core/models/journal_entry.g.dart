// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'journal_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

JournalEntry _$JournalEntryFromJson(Map<String, dynamic> json) => JournalEntry(
  id: json['id'] as String,
  title: json['title'] as String?,
  body: json['body'] as String,
  tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
  linkedMoodId: json['linkedMoodId'] as String?,
  pinned: json['pinned'] as bool? ?? false,
  createdAt: json['createdAt'] as String,
  updatedAt: json['updatedAt'] as String,
);

Map<String, dynamic> _$JournalEntryToJson(JournalEntry instance) =>
    <String, dynamic>{
      'id': instance.id,
      if (instance.title case final value?) 'title': value,
      'body': instance.body,
      'tags': instance.tags,
      if (instance.linkedMoodId case final value?) 'linkedMoodId': value,
      if (instance.pinned) 'pinned': instance.pinned,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
    };
