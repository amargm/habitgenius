import 'package:json_annotation/json_annotation.dart';

part 'account.g.dart';

@JsonEnum(fieldRename: FieldRename.snake)
enum AccountType { checking, savings, credit, cash }

@JsonSerializable()
class Account {
  final String id;
  final String name;
  final AccountType type;
  final double startingBalance;
  final String currency;
  final String createdAt; // ISO 8601

  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.startingBalance,
    required this.currency,
    required this.createdAt,
  });

  factory Account.fromJson(Map<String, dynamic> json) =>
      _$AccountFromJson(json);

  Map<String, dynamic> toJson() => _$AccountToJson(this);

  Account copyWith({
    String? id,
    String? name,
    AccountType? type,
    double? startingBalance,
    String? currency,
    String? createdAt,
  }) => Account(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    startingBalance: startingBalance ?? this.startingBalance,
    currency: currency ?? this.currency,
    createdAt: createdAt ?? this.createdAt,
  );
}
