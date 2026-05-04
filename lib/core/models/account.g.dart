// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Account _$AccountFromJson(Map<String, dynamic> json) => Account(
  id: json['id'] as String,
  name: json['name'] as String,
  type: $enumDecode(_$AccountTypeEnumMap, json['type']),
  startingBalance: (json['startingBalance'] as num).toDouble(),
  currency: json['currency'] as String,
  createdAt: json['createdAt'] as String,
);

Map<String, dynamic> _$AccountToJson(Account instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'type': _$AccountTypeEnumMap[instance.type]!,
  'startingBalance': instance.startingBalance,
  'currency': instance.currency,
  'createdAt': instance.createdAt,
};

const _$AccountTypeEnumMap = {
  AccountType.checking: 'checking',
  AccountType.savings: 'savings',
  AccountType.credit: 'credit',
  AccountType.cash: 'cash',
};
