import 'package:json_annotation/json_annotation.dart';

part 'focus_session.g.dart';

@JsonEnum(fieldRename: FieldRename.snake)
enum FocusMode { pomodoro, countdown, stopwatch }

@JsonSerializable()
class FocusSession {
  final String id;
  final String category;
  final FocusMode mode;
  final int plannedDuration; // seconds
  final int actualDuration; // seconds
  final int completedCycles;
  final String startedAt; // ISO 8601
  final String endedAt; // ISO 8601

  const FocusSession({
    required this.id,
    required this.category,
    required this.mode,
    required this.plannedDuration,
    required this.actualDuration,
    required this.completedCycles,
    required this.startedAt,
    required this.endedAt,
  });

  factory FocusSession.fromJson(Map<String, dynamic> json) =>
      _$FocusSessionFromJson(json);

  Map<String, dynamic> toJson() => _$FocusSessionToJson(this);

  FocusSession copyWith({
    String? id,
    String? category,
    FocusMode? mode,
    int? plannedDuration,
    int? actualDuration,
    int? completedCycles,
    String? startedAt,
    String? endedAt,
  }) => FocusSession(
    id: id ?? this.id,
    category: category ?? this.category,
    mode: mode ?? this.mode,
    plannedDuration: plannedDuration ?? this.plannedDuration,
    actualDuration: actualDuration ?? this.actualDuration,
    completedCycles: completedCycles ?? this.completedCycles,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt ?? this.endedAt,
  );
}
