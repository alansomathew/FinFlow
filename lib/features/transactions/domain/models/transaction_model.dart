import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { debit, credit }

enum TransactionSource { manual, sms, recurring, investment }

class SplitEntry {
  final String categoryId;
  final double amount;

  const SplitEntry({required this.categoryId, required this.amount});

  factory SplitEntry.fromMap(Map<String, dynamic> m) =>
      SplitEntry(categoryId: m['categoryId'], amount: (m['amount'] as num).toDouble());

  Map<String, dynamic> toMap() => {'categoryId': categoryId, 'amount': amount};
}

class TransactionModel {
  final String id;
  final String userId;
  final double amount;
  final TransactionType type;
  final String categoryId;
  final String accountId;
  final String? payee;
  final String? note;
  final DateTime date;
  final TransactionSource source;
  final bool isRecurring;
  final String? recurringId;
  final String? receiptUrl;
  final List<SplitEntry>? splits;
  final String? smsRef;
  final String? loanId;
  final String? goalId;

  const TransactionModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.accountId,
    this.payee,
    this.note,
    required this.date,
    this.source = TransactionSource.manual,
    this.isRecurring = false,
    this.recurringId,
    this.receiptUrl,
    this.splits,
    this.smsRef,
    this.loanId,
    this.goalId,
  });

  bool get isDebit => type == TransactionType.debit;
  bool get isCredit => type == TransactionType.credit;

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      userId: d['userId'] ?? '',
      amount: (d['amount'] as num).toDouble(),
      type: d['type'] == 'credit'
          ? TransactionType.credit
          : TransactionType.debit,
      categoryId: d['categoryId'] ?? 'other',
      accountId: d['accountId'] ?? '',
      payee: d['payee'],
      note: d['note'],
      date: (d['date'] as Timestamp).toDate(),
      source: TransactionSource.values.firstWhere(
        (s) => s.name == d['source'],
        orElse: () => TransactionSource.manual,
      ),
      isRecurring: d['isRecurring'] ?? false,
      recurringId: d['recurringId'],
      receiptUrl: d['receiptUrl'],
      splits: (d['splits'] as List?)
          ?.map((e) => SplitEntry.fromMap(e as Map<String, dynamic>))
          .toList(),
      smsRef: d['smsRef'],
      loanId: d['loanId'],
      goalId: d['goalId'],
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'amount': amount,
        'type': type.name,
        'categoryId': categoryId,
        'accountId': accountId,
        'payee': payee,
        'note': note,
        'date': Timestamp.fromDate(date),
        'source': source.name,
        'isRecurring': isRecurring,
        'recurringId': recurringId,
        'receiptUrl': receiptUrl,
        'splits': splits?.map((s) => s.toMap()).toList(),
        'smsRef': smsRef,
        'loanId': loanId,
        'goalId': goalId,
      };

  /// Serialize for SQLite (dates as ISO-8601 strings, no Timestamp).
  Map<String, dynamic> toLocalMap() => {
        'id': id,
        'userId': userId,
        'amount': amount,
        'type': type.name,
        'categoryId': categoryId,
        'accountId': accountId,
        'payee': payee,
        'note': note,
        'date': date.toIso8601String(),
        'source': source.name,
        'isRecurring': isRecurring ? 1 : 0,
        'recurringId': recurringId,
        'receiptUrl': receiptUrl,
        'splits': splits?.map((s) => s.toMap()).toList(),
        'smsRef': smsRef,
        'loanId': loanId,
        'goalId': goalId,
      };

  factory TransactionModel.fromLocalMap(Map<String, dynamic> d) =>
      TransactionModel(
        id: d['id'] as String,
        userId: d['userId'] as String? ?? '',
        amount: (d['amount'] as num).toDouble(),
        type: d['type'] == 'credit'
            ? TransactionType.credit
            : TransactionType.debit,
        categoryId: d['categoryId'] as String? ?? 'other',
        accountId: d['accountId'] as String? ?? '',
        payee: d['payee'] as String?,
        note: d['note'] as String?,
        date: DateTime.parse(d['date'] as String),
        source: TransactionSource.values.firstWhere(
          (s) => s.name == d['source'],
          orElse: () => TransactionSource.manual,
        ),
        isRecurring: (d['isRecurring'] == 1 || d['isRecurring'] == true),
        recurringId: d['recurringId'] as String?,
        receiptUrl: d['receiptUrl'] as String?,
        splits: (d['splits'] as List?)
            ?.map((e) => SplitEntry.fromMap(e as Map<String, dynamic>))
            .toList(),
        smsRef: d['smsRef'] as String?,
        loanId: d['loanId'] as String?,
        goalId: d['goalId'] as String?,
      );

  TransactionModel copyWith({
    double? amount,
    TransactionType? type,
    String? categoryId,
    String? accountId,
    String? payee,
    String? note,
    DateTime? date,
    String? receiptUrl,
  }) =>
      TransactionModel(
        id: id,
        userId: userId,
        amount: amount ?? this.amount,
        type: type ?? this.type,
        categoryId: categoryId ?? this.categoryId,
        accountId: accountId ?? this.accountId,
        payee: payee ?? this.payee,
        note: note ?? this.note,
        date: date ?? this.date,
        source: source,
        isRecurring: isRecurring,
        recurringId: recurringId,
        receiptUrl: receiptUrl ?? this.receiptUrl,
        splits: splits,
        smsRef: smsRef,
        loanId: loanId,
        goalId: goalId,
      );
}
