// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Transaction _$TransactionFromJson(Map<String, dynamic> json) => Transaction(
  id: json['id'] as String,
  type: $enumDecode(_$TransactionTypeEnumMap, json['type']),
  amount: (json['amount'] as num).toInt(),
  currency: json['currency'] as String,
  category: json['category'] as String,
  accountId: json['accountId'] as String,
  toAccountId: json['toAccountId'] as String?,
  note: json['note'] as String?,
  recurring: json['recurring'] as bool,
  recurringInterval: $enumDecodeNullable(
    _$RecurringIntervalEnumMap,
    json['recurringInterval'],
  ),
  date: json['date'] as String,
  createdAt: json['createdAt'] as String,
);

Map<String, dynamic> _$TransactionToJson(
  Transaction instance,
) => <String, dynamic>{
  'id': instance.id,
  'type': _$TransactionTypeEnumMap[instance.type]!,
  'amount': instance.amount,
  'currency': instance.currency,
  'category': instance.category,
  'accountId': instance.accountId,
  if (instance.toAccountId case final value?) 'toAccountId': value,
  if (instance.note case final value?) 'note': value,
  'recurring': instance.recurring,
  if (_$RecurringIntervalEnumMap[instance.recurringInterval] case final value?)
    'recurringInterval': value,
  'date': instance.date,
  'createdAt': instance.createdAt,
};

const _$TransactionTypeEnumMap = {
  TransactionType.expense: 'expense',
  TransactionType.income: 'income',
  TransactionType.transfer: 'transfer',
};

const _$RecurringIntervalEnumMap = {
  RecurringInterval.daily: 'daily',
  RecurringInterval.weekly: 'weekly',
  RecurringInterval.monthly: 'monthly',
};
