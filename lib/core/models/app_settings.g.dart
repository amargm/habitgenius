// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppSettings _$AppSettingsFromJson(Map<String, dynamic> json) => AppSettings(
  userTier: const _UserTierConverter().fromJson(json['userTier'] as String),
  displayName: json['displayName'] as String?,
  avatarInitials: json['avatarInitials'] as String?,
  primaryColorHex: json['primaryColorHex'] as String,
  themeMode: json['themeMode'] as String,
  currency: json['currency'] as String,
  currencySymbol: json['currencySymbol'] as String,
  locale: json['locale'] as String,
  dataFilePath: json['dataFilePath'] as String?,
  notificationsEnabled: json['notificationsEnabled'] as bool,
  cloudSyncEnabled: json['cloudSyncEnabled'] as bool? ?? false,
  dailyFocusGoalMinutes: json['dailyFocusGoalMinutes'] as int? ?? 0,
  categoryBudgets:
      (json['categoryBudgets'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toDouble()),
      ) ??
      const {},
  baseCurrency: json['baseCurrency'] as String? ?? 'USD',
  exchangeRates:
      (json['exchangeRates'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toDouble()),
      ) ??
      const {},
);

Map<String, dynamic> _$AppSettingsToJson(
  AppSettings instance,
) => <String, dynamic>{
  'userTier': const _UserTierConverter().toJson(instance.userTier),
  if (instance.displayName case final value?) 'displayName': value,
  if (instance.avatarInitials case final value?) 'avatarInitials': value,
  'primaryColorHex': instance.primaryColorHex,
  'themeMode': instance.themeMode,
  'currency': instance.currency,
  'currencySymbol': instance.currencySymbol,
  'locale': instance.locale,
  if (instance.dataFilePath case final value?) 'dataFilePath': value,
  'notificationsEnabled': instance.notificationsEnabled,
  if (instance.cloudSyncEnabled) 'cloudSyncEnabled': instance.cloudSyncEnabled,
  if (instance.dailyFocusGoalMinutes != 0)
    'dailyFocusGoalMinutes': instance.dailyFocusGoalMinutes,
  if (instance.categoryBudgets.isNotEmpty)
    'categoryBudgets': instance.categoryBudgets,
  if (instance.baseCurrency != 'USD') 'baseCurrency': instance.baseCurrency,
  if (instance.exchangeRates.isNotEmpty)
    'exchangeRates': instance.exchangeRates,
};
