import 'package:json_annotation/json_annotation.dart';

part 'habit_log.g.dart';

@JsonSerializable(includeIfNull: false)
class HabitLog {
  final String id;
  final String habitId;
  final String date; // YYYY-MM-DD
  final bool completed;
  final int value;
  final String? completedAt; // ISO 8601

  const HabitLog({
    required this.id,
    required this.habitId,
    required this.date,
    required this.completed,
    required this.value,
    this.completedAt,
  });

  factory HabitLog.fromJson(Map<String, dynamic> json) =>
      _$HabitLogFromJson(json);

  Map<String, dynamic> toJson() => _$HabitLogToJson(this);

  HabitLog copyWith({
    String? id,
    String? habitId,
    String? date,
    bool? completed,
    int? value,
    String? completedAt,
  }) => HabitLog(
    id: id ?? this.id,
    habitId: habitId ?? this.habitId,
    date: date ?? this.date,
    completed: completed ?? this.completed,
    value: value ?? this.value,
    completedAt: completedAt ?? this.completedAt,
  );
}
