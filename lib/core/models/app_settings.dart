import 'package:json_annotation/json_annotation.dart';
import '../constants/app_colors.dart';

part 'app_settings.g.dart';

/// JSON uses 'guest'/'free'/'pro'; Dart uses the [UserTier] enum.
class _UserTierConverter implements JsonConverter<UserTier, String> {
  const _UserTierConverter();

  @override
  UserTier fromJson(String json) {
    switch (json) {
      case 'free':
        return UserTier.registered;
      case 'pro':
        return UserTier.pro;
      default:
        return UserTier.guest;
    }
  }

  @override
  String toJson(UserTier tier) {
    switch (tier) {
      case UserTier.guest:
        return 'guest';
      case UserTier.registered:
        return 'free';
      case UserTier.pro:
        return 'pro';
    }
  }
}

@JsonSerializable(includeIfNull: false)
class AppSettings {
  @_UserTierConverter()
  final UserTier userTier;
  final String? displayName;
  final String? avatarInitials;
  final String primaryColorHex;

  /// 'dark' | 'light' | 'system'
  final String themeMode;
  final String currency;
  final String currencySymbol;
  final String locale;
  final String? dataFilePath;
  final bool notificationsEnabled;
  final bool cloudSyncEnabled;

  const AppSettings({
    required this.userTier,
    this.displayName,
    this.avatarInitials,
    required this.primaryColorHex,
    required this.themeMode,
    required this.currency,
    required this.currencySymbol,
    required this.locale,
    this.dataFilePath,
    required this.notificationsEnabled,
    this.cloudSyncEnabled = false,
  });

  factory AppSettings.defaults() => const AppSettings(
    userTier: UserTier.guest,
    primaryColorHex: '#6C5CE7',
    themeMode: 'dark',
    currency: 'USD',
    currencySymbol: r'$',
    locale: 'en_US',
    notificationsEnabled: true,
    cloudSyncEnabled: false,
  );

  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$AppSettingsToJson(this);

  AppSettings copyWith({
    UserTier? userTier,
    String? displayName,
    String? avatarInitials,
    String? primaryColorHex,
    String? themeMode,
    String? currency,
    String? currencySymbol,
    String? locale,
    String? dataFilePath,
    bool? notificationsEnabled,
    bool? cloudSyncEnabled,
  }) => AppSettings(
    userTier: userTier ?? this.userTier,
    displayName: displayName ?? this.displayName,
    avatarInitials: avatarInitials ?? this.avatarInitials,
    primaryColorHex: primaryColorHex ?? this.primaryColorHex,
    themeMode: themeMode ?? this.themeMode,
    currency: currency ?? this.currency,
    currencySymbol: currencySymbol ?? this.currencySymbol,
    locale: locale ?? this.locale,
    dataFilePath: dataFilePath ?? this.dataFilePath,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    cloudSyncEnabled: cloudSyncEnabled ?? this.cloudSyncEnabled,
  );
}
