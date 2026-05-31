import 'package:cloud_firestore/cloud_firestore.dart';

enum LoanType {
  homeLoan,
  carLoan,
  personalLoan,
  educationLoan,
  goldLoan,
  creditCardEmi,
  bnpl,
  custom,
}

class EmiEntry {
  final DateTime dueDate;
  final double amount;
  final bool isPaid;
  final String? transactionId;

  const EmiEntry({
    required this.dueDate,
    required this.amount,
    this.isPaid = false,
    this.transactionId,
  });

  factory EmiEntry.fromMap(Map<String, dynamic> m) => EmiEntry(
        dueDate: (m['dueDate'] as Timestamp).toDate(),
        amount: (m['amount'] as num).toDouble(),
        isPaid: m['isPaid'] ?? false,
        transactionId: m['transactionId'],
      );

  Map<String, dynamic> toMap() => {
        'dueDate': Timestamp.fromDate(dueDate),
        'amount': amount,
        'isPaid': isPaid,
        'transactionId': transactionId,
      };
}

class LoanModel {
  final String id;
  final String userId;
  final LoanType type;
  final String lenderName;
  final double principalAmount;
  final double interestRate;
  final int tenureMonths;
  final DateTime startDate;
  final double emiAmount;
  final String accountId;
  final double outstandingPrincipal;
  final bool isActive;
  final String? notes;

  const LoanModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.lenderName,
    required this.principalAmount,
    required this.interestRate,
    required this.tenureMonths,
    required this.startDate,
    required this.emiAmount,
    required this.accountId,
    required this.outstandingPrincipal,
    this.isActive = true,
    this.notes,
  });

  int get monthsRemaining {
    final now = DateTime.now();
    final end = DateTime(
        startDate.year, startDate.month + tenureMonths, startDate.day);
    final diff =
        end.difference(DateTime(now.year, now.month, now.day)).inDays;
    return (diff / 30).ceil().clamp(0, tenureMonths);
  }

  double get totalInterest => (emiAmount * tenureMonths) - principalAmount;

  DateTime get nextEmiDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, startDate.day);
  }

  String get typeLabel {
    switch (type) {
      case LoanType.homeLoan:
        return 'Home Loan';
      case LoanType.carLoan:
        return 'Car Loan';
      case LoanType.personalLoan:
        return 'Personal Loan';
      case LoanType.educationLoan:
        return 'Education Loan';
      case LoanType.goldLoan:
        return 'Gold Loan';
      case LoanType.creditCardEmi:
        return 'Credit Card EMI';
      case LoanType.bnpl:
        return 'Buy Now Pay Later';
      case LoanType.custom:
        return 'Custom Loan';
    }
  }

  /// EMI calculation: reducing balance formula
  static double calculateEmi(
      double principal, double annualRate, int months) {
    if (annualRate == 0) return principal / months;
    final r = annualRate / 12 / 100;
    return principal * r * (1 + r).floor() / ((1 + r).floor() - 1);
  }

  factory LoanModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return LoanModel(
      id: doc.id,
      userId: d['userId'] ?? '',
      type: LoanType.values.firstWhere(
        (t) => t.name == d['type'],
        orElse: () => LoanType.custom,
      ),
      lenderName: d['lenderName'] ?? '',
      principalAmount: (d['principalAmount'] as num).toDouble(),
      interestRate: (d['interestRate'] as num).toDouble(),
      tenureMonths: d['tenureMonths'] as int,
      startDate: (d['startDate'] as Timestamp).toDate(),
      emiAmount: (d['emiAmount'] as num).toDouble(),
      accountId: d['accountId'] ?? '',
      outstandingPrincipal: (d['outstandingPrincipal'] as num).toDouble(),
      isActive: d['isActive'] ?? true,
      notes: d['notes'],
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'type': type.name,
        'lenderName': lenderName,
        'principalAmount': principalAmount,
        'interestRate': interestRate,
        'tenureMonths': tenureMonths,
        'startDate': Timestamp.fromDate(startDate),
        'emiAmount': emiAmount,
        'accountId': accountId,
        'outstandingPrincipal': outstandingPrincipal,
        'isActive': isActive,
        'notes': notes,
      };

  Map<String, dynamic> toLocalMap() => {
        'id': id,
        'userId': userId,
        'type': type.name,
        'lenderName': lenderName,
        'principalAmount': principalAmount,
        'interestRate': interestRate,
        'tenureMonths': tenureMonths,
        'startDate': startDate.toIso8601String(),
        'emiAmount': emiAmount,
        'accountId': accountId,
        'outstandingPrincipal': outstandingPrincipal,
        'isActive': isActive ? 1 : 0,
        'notes': notes,
      };

  factory LoanModel.fromLocalMap(Map<String, dynamic> d) => LoanModel(
        id: d['id'] as String,
        userId: d['userId'] as String? ?? '',
        type: LoanType.values.firstWhere(
          (t) => t.name == d['type'],
          orElse: () => LoanType.custom,
        ),
        lenderName: d['lenderName'] as String? ?? '',
        principalAmount: (d['principalAmount'] as num).toDouble(),
        interestRate: (d['interestRate'] as num).toDouble(),
        tenureMonths: d['tenureMonths'] as int,
        startDate: DateTime.parse(d['startDate'] as String),
        emiAmount: (d['emiAmount'] as num).toDouble(),
        accountId: d['accountId'] as String? ?? '',
        outstandingPrincipal: (d['outstandingPrincipal'] as num).toDouble(),
        isActive: (d['isActive'] == 1 || d['isActive'] == true),
        notes: d['notes'] as String?,
      );
}
