import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

enum AccountType {
  savings,
  current,
  creditCard,
  wallet,
  cash,
  upi,
  fixedDeposit,
}

class AccountModel {
  final String id;
  final String userId;
  final String name;
  final String? bankName;
  final AccountType type;
  final double balance;
  final String? maskedNumber;
  final double? creditLimit;
  final int? statementDay;
  final int? dueDay;
  final double? interestRate;
  final Color color;
  final String emoji;
  final bool isActive;

  const AccountModel({
    required this.id,
    required this.userId,
    required this.name,
    this.bankName,
    required this.type,
    required this.balance,
    this.maskedNumber,
    this.creditLimit,
    this.statementDay,
    this.dueDay,
    this.interestRate,
    required this.color,
    this.emoji = '🏦',
    this.isActive = true,
  });

  bool get isCreditCard => type == AccountType.creditCard;

  double get availableCredit =>
      isCreditCard && creditLimit != null ? creditLimit! - balance.abs() : 0;

  double get utilizationRatio =>
      isCreditCard && creditLimit != null && creditLimit! > 0
          ? balance.abs() / creditLimit!
          : 0;

  String get typeLabel {
    switch (type) {
      case AccountType.savings:
        return 'Savings Account';
      case AccountType.current:
        return 'Current Account';
      case AccountType.creditCard:
        return 'Credit Card';
      case AccountType.wallet:
        return 'Digital Wallet';
      case AccountType.cash:
        return 'Cash';
      case AccountType.upi:
        return 'UPI Account';
      case AccountType.fixedDeposit:
        return 'Fixed Deposit';
    }
  }

  factory AccountModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AccountModel(
      id: doc.id,
      userId: d['userId'] ?? '',
      name: d['name'] ?? '',
      bankName: d['bankName'],
      type: AccountType.values.firstWhere(
        (t) => t.name == d['type'],
        orElse: () => AccountType.savings,
      ),
      balance: (d['balance'] as num?)?.toDouble() ?? 0,
      maskedNumber: d['maskedNumber'],
      creditLimit: (d['creditLimit'] as num?)?.toDouble(),
      statementDay: d['statementDay'] as int?,
      dueDay: d['dueDay'] as int?,
      interestRate: (d['interestRate'] as num?)?.toDouble(),
      color: Color(d['colorValue'] ?? AppColors.primary.value),
      emoji: d['emoji'] ?? '🏦',
      isActive: d['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'name': name,
        'bankName': bankName,
        'type': type.name,
        'balance': balance,
        'maskedNumber': maskedNumber,
        'creditLimit': creditLimit,
        'statementDay': statementDay,
        'dueDay': dueDay,
        'interestRate': interestRate,
        'colorValue': color.value,
        'emoji': emoji,
        'isActive': isActive,
      };

  /// SQLite-compatible map (no Firestore types).
  Map<String, dynamic> toLocalMap() => {
        'id': id,
        'userId': userId,
        'name': name,
        'bankName': bankName,
        'type': type.name,
        'balance': balance,
        'maskedNumber': maskedNumber,
        'creditLimit': creditLimit,
        'statementDay': statementDay,
        'dueDay': dueDay,
        'interestRate': interestRate,
        'colorValue': color.value,
        'emoji': emoji,
        'isActive': isActive ? 1 : 0,
      };

  factory AccountModel.fromLocalMap(Map<String, dynamic> d) => AccountModel(
        id: d['id'] as String,
        userId: d['userId'] as String? ?? '',
        name: d['name'] as String,
        bankName: d['bankName'] as String?,
        type: AccountType.values.firstWhere(
          (t) => t.name == d['type'],
          orElse: () => AccountType.savings,
        ),
        balance: (d['balance'] as num?)?.toDouble() ?? 0,
        maskedNumber: d['maskedNumber'] as String?,
        creditLimit: (d['creditLimit'] as num?)?.toDouble(),
        statementDay: d['statementDay'] as int?,
        dueDay: d['dueDay'] as int?,
        interestRate: (d['interestRate'] as num?)?.toDouble(),
        color: Color(d['colorValue'] as int? ?? AppColors.primary.value),
        emoji: d['emoji'] as String? ?? '🏦',
        isActive: (d['isActive'] == 1 || d['isActive'] == true),
      );

  AccountModel copyWith({
    String? name,
    double? balance,
    double? creditLimit,
    Color? color,
    bool? isActive,
  }) =>
      AccountModel(
        id: id,
        userId: userId,
        name: name ?? this.name,
        bankName: bankName,
        type: type,
        balance: balance ?? this.balance,
        maskedNumber: maskedNumber,
        creditLimit: creditLimit ?? this.creditLimit,
        statementDay: statementDay,
        dueDay: dueDay,
        interestRate: interestRate,
        color: color ?? this.color,
        emoji: emoji,
        isActive: isActive ?? this.isActive,
      );
}
