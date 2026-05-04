import 'package:json_annotation/json_annotation.dart';

part 'mood.g.dart';

@JsonSerializable(includeIfNull: false)
class Mood {
  final String id;
  final String date; // YYYY-MM-DD
  final int level; // 1 = Awful … 5 = Great
  final String emoji;
  final List<String> tags;
  final String? note; // max 280 chars
  final String loggedAt; // ISO 8601

  const Mood({
    required this.id,
    required this.date,
    required this.level,
    required this.emoji,
    required this.tags,
    this.note,
    required this.loggedAt,
  });

  factory Mood.fromJson(Map<String, dynamic> json) => _$MoodFromJson(json);

  Map<String, dynamic> toJson() => _$MoodToJson(this);

  Mood copyWith({
    String? id,
    String? date,
    int? level,
    String? emoji,
    List<String>? tags,
    String? note,
    String? loggedAt,
  }) => Mood(
    id: id ?? this.id,
    date: date ?? this.date,
    level: level ?? this.level,
    emoji: emoji ?? this.emoji,
    tags: tags ?? this.tags,
    note: note ?? this.note,
    loggedAt: loggedAt ?? this.loggedAt,
  );
}
