import 'package:json_annotation/json_annotation.dart';

part 'journal_entry.g.dart';

@JsonSerializable(includeIfNull: false)
class JournalEntry {
  final String id;
  final String? title;
  final String body;
  final List<String> tags;
  final String? linkedMoodId;
  final String createdAt; // ISO 8601
  final String updatedAt; // ISO 8601

  const JournalEntry({
    required this.id,
    this.title,
    required this.body,
    required this.tags,
    this.linkedMoodId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory JournalEntry.fromJson(Map<String, dynamic> json) =>
      _$JournalEntryFromJson(json);

  Map<String, dynamic> toJson() => _$JournalEntryToJson(this);

  JournalEntry copyWith({
    String? id,
    String? title,
    String? body,
    List<String>? tags,
    String? linkedMoodId,
    String? createdAt,
    String? updatedAt,
  }) => JournalEntry(
    id: id ?? this.id,
    title: title ?? this.title,
    body: body ?? this.body,
    tags: tags ?? this.tags,
    linkedMoodId: linkedMoodId ?? this.linkedMoodId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
