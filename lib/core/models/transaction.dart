import 'package:json_annotation/json_annotation.dart';

part 'transaction.g.dart';

@JsonEnum(fieldRename: FieldRename.snake)
enum TransactionType { expense, income, transfer }

@JsonEnum(fieldRename: FieldRename.snake)
enum RecurringInterval { daily, weekly, monthly }

@JsonSerializable(includeIfNull: false)
class Transaction {
  final String id;
  final TransactionType type;
  final double amount;
  final String currency;
  final String category;
  final String accountId;
  final String? toAccountId;
  final String? note;
  final bool recurring;
  final RecurringInterval? recurringInterval;
  final String date; // YYYY-MM-DD
  final String createdAt; // ISO 8601

  const Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.currency,
    required this.category,
    required this.accountId,
    this.toAccountId,
    this.note,
    required this.recurring,
    this.recurringInterval,
    required this.date,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);

  Map<String, dynamic> toJson() => _$TransactionToJson(this);

  Transaction copyWith({
    String? id,
    TransactionType? type,
    double? amount,
    String? currency,
    String? category,
    String? accountId,
    String? toAccountId,
    String? note,
    bool? recurring,
    RecurringInterval? recurringInterval,
    String? date,
    String? createdAt,
  }) => Transaction(
    id: id ?? this.id,
    type: type ?? this.type,
    amount: amount ?? this.amount,
    currency: currency ?? this.currency,
    category: category ?? this.category,
    accountId: accountId ?? this.accountId,
    toAccountId: toAccountId ?? this.toAccountId,
    note: note ?? this.note,
    recurring: recurring ?? this.recurring,
    recurringInterval: recurringInterval ?? this.recurringInterval,
    date: date ?? this.date,
    createdAt: createdAt ?? this.createdAt,
  );
}
