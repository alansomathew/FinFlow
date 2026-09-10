import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import '../../../database/app_database.dart';

enum BudgetBucket {
  needs,
  wants,
  savings,
  income;

  String get displayName {
    switch (this) {
      case BudgetBucket.needs:
        return 'Needs';
      case BudgetBucket.wants:
        return 'Wants';
      case BudgetBucket.savings:
        return 'Savings';
      case BudgetBucket.income:
        return 'Income';
    }
  }

  Color get color {
    switch (this) {
      case BudgetBucket.needs:
        return const Color(0xFF1A56DB); // Blue
      case BudgetBucket.wants:
        return const Color(0xFFD97706); // Amber
      case BudgetBucket.savings:
        return const Color(0xFF059669); // Green
      case BudgetBucket.income:
        return const Color(0xFF9333EA); // Purple for Income
    }
  }
}

class TransactionCategory {
  final String name;
  final String icon;
  final BudgetBucket bucket;

  const TransactionCategory({
    required this.name,
    required this.icon,
    required this.bucket,
  });

  static const List<TransactionCategory> presets = [
    // Needs
    TransactionCategory(name: 'Rent', icon: '🏠', bucket: BudgetBucket.needs),
    TransactionCategory(
      name: 'Groceries',
      icon: '🛒',
      bucket: BudgetBucket.needs,
    ),
    TransactionCategory(
      name: 'Utilities',
      icon: '⚡',
      bucket: BudgetBucket.needs,
    ),
    TransactionCategory(name: 'EMI', icon: '💳', bucket: BudgetBucket.needs),
    TransactionCategory(
      name: 'Insurance',
      icon: '🛡️',
      bucket: BudgetBucket.needs,
    ),
    TransactionCategory(
      name: 'Transport',
      icon: '🚗',
      bucket: BudgetBucket.needs,
    ),
    TransactionCategory(
      name: 'Education',
      icon: '🎓',
      bucket: BudgetBucket.needs,
    ),
    TransactionCategory(
      name: 'Healthcare',
      icon: '🏥',
      bucket: BudgetBucket.needs,
    ),

    // Wants
    TransactionCategory(
      name: 'Dining Out',
      icon: '🍔',
      bucket: BudgetBucket.wants,
    ),
    TransactionCategory(
      name: 'Shopping',
      icon: '🛍️',
      bucket: BudgetBucket.wants,
    ),
    TransactionCategory(
      name: 'Entertainment',
      icon: '🎬',
      bucket: BudgetBucket.wants,
    ),
    TransactionCategory(
      name: 'Subscriptions',
      icon: '📺',
      bucket: BudgetBucket.wants,
    ),
    TransactionCategory(name: 'Travel', icon: '✈️', bucket: BudgetBucket.wants),
    TransactionCategory(
      name: 'Personal Care',
      icon: '🧴',
      bucket: BudgetBucket.wants,
    ),
    TransactionCategory(
      name: 'Hobbies',
      icon: '🎨',
      bucket: BudgetBucket.wants,
    ),

    // Savings
    TransactionCategory(name: 'SIP', icon: '📈', bucket: BudgetBucket.savings),
    TransactionCategory(
      name: 'Stocks',
      icon: '📊',
      bucket: BudgetBucket.savings,
    ),
    TransactionCategory(
      name: 'Savings Goals',
      icon: '🎯',
      bucket: BudgetBucket.savings,
    ),
    TransactionCategory(name: 'Gold', icon: '🪙', bucket: BudgetBucket.savings),
    TransactionCategory(
      name: 'Emergency Fund',
      icon: '🚨',
      bucket: BudgetBucket.savings,
    ),
    TransactionCategory(
      name: 'FD / RD',
      icon: '🔒',
      bucket: BudgetBucket.savings,
    ),

    // Income
    TransactionCategory(
      name: 'Salary',
      icon: '💰',
      bucket: BudgetBucket.income,
    ),
    TransactionCategory(
      name: 'Freelance',
      icon: '💻',
      bucket: BudgetBucket.income,
    ),
    TransactionCategory(
      name: 'Investments Return',
      icon: '💵',
      bucket: BudgetBucket.income,
    ),
    TransactionCategory(
      name: 'Other Income',
      icon: '🏷️',
      bucket: BudgetBucket.income,
    ),
  ];

  static TransactionCategory getByName(String name) {
    return presets.firstWhere(
      (cat) => cat.name.toLowerCase() == name.toLowerCase(),
      orElse: () => TransactionCategory(
        name: name,
        icon: '📝',
        bucket: BudgetBucket.wants,
      ),
    );
  }
}

class TransactionModel {
  final String id;
  final double amount;
  final String category;
  final BudgetBucket bucket;
  final String accountId;
  final DateTime date;
  final String note;
  final String payee;
  final bool isRecurring;
  final String refId;

  TransactionModel({
    required this.id,
    required this.amount,
    required this.category,
    required this.bucket,
    required this.accountId,
    required this.date,
    this.note = '',
    required this.payee,
    this.isRecurring = false,
    this.refId = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'category': category,
      'bucket': bucket.name,
      'account_id': accountId,
      'date': date.toIso8601String(),
      'note': note,
      'payee': payee,
      'is_recurring': isRecurring ? 1 : 0,
      'ref_id': refId,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] ?? 'Other',
      bucket: BudgetBucket.values.firstWhere(
        (b) => b.name == map['bucket'],
        orElse: () => BudgetBucket.wants,
      ),
      accountId: map['account_id'] ?? '',
      date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
      note: map['note'] ?? '',
      payee: map['payee'] ?? '',
      isRecurring: map['is_recurring'] == 1,
      refId: map['ref_id'] ?? '',
    );
  }

  factory TransactionModel.fromRow(Transaction row) {
    return TransactionModel(
      id: row.id,
      amount: row.amount,
      category: row.category,
      bucket: BudgetBucket.values.firstWhere(
        (b) => b.name == row.bucket,
        orElse: () => BudgetBucket.wants,
      ),
      accountId: row.accountId,
      date: row.date,
      note: row.note ?? '',
      payee: row.payee,
      isRecurring: row.isRecurring,
      refId: row.refId ?? '',
    );
  }

  TransactionsCompanion toCompanion() {
    return TransactionsCompanion(
      id: Value(id),
      amount: Value(amount),
      category: Value(category),
      bucket: Value(bucket.name),
      accountId: Value(accountId),
      date: Value(date),
      note: Value(note.isEmpty ? null : note),
      payee: Value(payee),
      isRecurring: Value(isRecurring),
      refId: Value(refId.isEmpty ? null : refId),
      updatedAt: Value(DateTime.now()),
    );
  }
}
