// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_meta.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppMeta _$AppMetaFromJson(Map<String, dynamic> json) => AppMeta(
  version: (json['version'] as num).toInt(),
  appVersion: json['appVersion'] as String,
  createdAt: json['createdAt'] as String,
  lastModified: json['lastModified'] as String,
  deviceId: json['deviceId'] as String,
);

Map<String, dynamic> _$AppMetaToJson(AppMeta instance) => <String, dynamic>{
  'version': instance.version,
  'appVersion': instance.appVersion,
  'createdAt': instance.createdAt,
  'lastModified': instance.lastModified,
  'deviceId': instance.deviceId,
};
