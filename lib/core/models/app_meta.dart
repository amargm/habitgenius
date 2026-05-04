import 'package:json_annotation/json_annotation.dart';

part 'app_meta.g.dart';

@JsonSerializable()
class AppMeta {
  final int version;
  final String appVersion;
  final String createdAt;
  final String lastModified;
  final String deviceId;

  const AppMeta({
    required this.version,
    required this.appVersion,
    required this.createdAt,
    required this.lastModified,
    required this.deviceId,
  });

  factory AppMeta.fromJson(Map<String, dynamic> json) =>
      _$AppMetaFromJson(json);

  Map<String, dynamic> toJson() => _$AppMetaToJson(this);

  AppMeta copyWith({
    int? version,
    String? appVersion,
    String? createdAt,
    String? lastModified,
    String? deviceId,
  }) => AppMeta(
    version: version ?? this.version,
    appVersion: appVersion ?? this.appVersion,
    createdAt: createdAt ?? this.createdAt,
    lastModified: lastModified ?? this.lastModified,
    deviceId: deviceId ?? this.deviceId,
  );
}
