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

  /// Daily focus goal in minutes.  0 = no goal.
  final int dailyFocusGoalMinutes;

  /// Monthly spending budget cap per category (category name → amount).
  final Map<String, double> categoryBudgets;

  /// Base currency code used for net-worth conversion (e.g. 'USD').
  final String baseCurrency;

  /// Exchange rates relative to [baseCurrency]:
  ///   key = currency code, value = how many units of key equal 1 unit of base.
  ///   e.g. if base='USD' and USD/EUR rate is 0.92: {'EUR': 0.92}
  ///   Currencies not listed are treated as 1:1 with base.
  final Map<String, double> exchangeRates;

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
    this.dailyFocusGoalMinutes = 0,
    this.categoryBudgets = const {},
    this.baseCurrency = 'USD',
    this.exchangeRates = const {},
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
    dailyFocusGoalMinutes: 0,
    categoryBudgets: {},
    baseCurrency: 'USD',
    exchangeRates: {},
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
    int? dailyFocusGoalMinutes,
    Map<String, double>? categoryBudgets,
    String? baseCurrency,
    Map<String, double>? exchangeRates,
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
    dailyFocusGoalMinutes: dailyFocusGoalMinutes ?? this.dailyFocusGoalMinutes,
    categoryBudgets: categoryBudgets ?? this.categoryBudgets,
    baseCurrency: baseCurrency ?? this.baseCurrency,
    exchangeRates: exchangeRates ?? this.exchangeRates,
  );
}
