import 'package:json_annotation/json_annotation.dart';

part 'habit.g.dart';

@JsonEnum(fieldRename: FieldRename.snake)
enum HabitProgressType { checkbox, counter, timer, stopwatch, checklist }

@JsonEnum(fieldRename: FieldRename.snake)
enum HabitSchedule { daily, weekly, monthly, specific, custom }

@JsonSerializable(includeIfNull: false)
class Habit {
  final String id;
  final String name;
  final String icon;
  final String colorHex;
  final HabitProgressType progressType;
  final int targetValue;
  final String? unit;
  final HabitSchedule schedule;

  /// Day indices: 0 = Sunday, 1 = Monday … 6 = Saturday.
  final List<int> scheduleDays;
  final String? reminderTime; // HH:mm
  final String createdAt; // ISO 8601
  final String? archivedAt; // ISO 8601
  final List<String> checklistItems;

  const Habit({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorHex,
    required this.progressType,
    required this.targetValue,
    this.unit,
    required this.schedule,
    required this.scheduleDays,
    this.reminderTime,
    required this.createdAt,
    this.archivedAt,
    required this.checklistItems,
  });

  factory Habit.fromJson(Map<String, dynamic> json) => _$HabitFromJson(json);

  Map<String, dynamic> toJson() => _$HabitToJson(this);

  Habit copyWith({
    String? id,
    String? name,
    String? icon,
    String? colorHex,
    HabitProgressType? progressType,
    int? targetValue,
    String? unit,
    HabitSchedule? schedule,
    List<int>? scheduleDays,
    String? reminderTime,
    String? createdAt,
    String? archivedAt,
    List<String>? checklistItems,
  }) => Habit(
    id: id ?? this.id,
    name: name ?? this.name,
    icon: icon ?? this.icon,
    colorHex: colorHex ?? this.colorHex,
    progressType: progressType ?? this.progressType,
    targetValue: targetValue ?? this.targetValue,
    unit: unit ?? this.unit,
    schedule: schedule ?? this.schedule,
    scheduleDays: scheduleDays ?? this.scheduleDays,
    reminderTime: reminderTime ?? this.reminderTime,
    createdAt: createdAt ?? this.createdAt,
    archivedAt: archivedAt ?? this.archivedAt,
    checklistItems: checklistItems ?? this.checklistItems,
  );
}
