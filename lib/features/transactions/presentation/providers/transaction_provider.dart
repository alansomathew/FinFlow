import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/transaction_model.dart';
import '../../../accounts/presentation/providers/account_provider.dart';
import '../../../dashboard/providers/dashboard_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/local/local_database.dart';

// â”€â”€ Auth helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

CollectionReference<Map<String, dynamic>> get _txCollection =>
    FirebaseFirestore.instance
        .collection(AppConstants.colUsers)
        .doc(_uid)
        .collection(AppConstants.colTransactions);

final _localDb = LocalDatabase.instance;

// â”€â”€ Filter state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class TransactionFilter extends Equatable {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? categoryId;
  final String? accountId;
  final TransactionType? type;
  final double? minAmount;
  final double? maxAmount;
  final String? searchQuery;

  const TransactionFilter({
    this.startDate,
    this.endDate,
    this.categoryId,
    this.accountId,
    this.type,
    this.minAmount,
    this.maxAmount,
    this.searchQuery,
  });

  @override
  List<Object?> get props => [
        startDate,
        endDate,
        categoryId,
        accountId,
        type,
        minAmount,
        maxAmount,
        searchQuery,
      ];

  bool get isEmpty =>
      startDate == null &&
      endDate == null &&
      categoryId == null &&
      accountId == null &&
      type == null &&
      minAmount == null &&
      maxAmount == null &&
      (searchQuery == null || searchQuery!.isEmpty);
}

// â”€â”€ Local stream helper â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
Stream<List<TransactionModel>> _localTransactionsStream(
    TransactionFilter filter) async* {
  // Emit once on start; guest mode has no real-time updates so this is fine
  final rows = await _localDb.getAll('transactions');
  final all = rows.map(TransactionModel.fromLocalMap).where((tx) {
    if (filter.startDate != null &&
        tx.date.isBefore(filter.startDate!)) return false;
    if (filter.endDate != null && tx.date.isAfter(filter.endDate!)) return false;
    if (filter.categoryId != null && tx.categoryId != filter.categoryId) {
      return false;
    }
    if (filter.accountId != null && tx.accountId != filter.accountId) {
      return false;
    }
    if (filter.type != null && tx.type != filter.type) return false;
    if (filter.minAmount != null && tx.amount < filter.minAmount!) return false;
    if (filter.maxAmount != null && tx.amount > filter.maxAmount!) return false;
    if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
      final q = filter.searchQuery!.toLowerCase();
      if (!(tx.payee?.toLowerCase().contains(q) ?? false) &&
          !(tx.note?.toLowerCase().contains(q) ?? false)) return false;
    }
    return true;
  }).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  yield all;
}

// â”€â”€ Transactions Stream â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
final transactionsStreamProvider =
    StreamProvider.family<List<TransactionModel>, TransactionFilter>(
        (ref, filter) {
  final isGuest = ref.watch(guestSessionProvider);
  if (isGuest) return _localTransactionsStream(filter);

  Query<Map<String, dynamic>> query =
      _txCollection.orderBy('date', descending: true);

  if (filter.startDate != null) {
    query = query.where('date',
        isGreaterThanOrEqualTo: Timestamp.fromDate(filter.startDate!));
  }
  if (filter.endDate != null) {
    query = query.where('date',
        isLessThanOrEqualTo: Timestamp.fromDate(filter.endDate!));
  }
  if (filter.categoryId != null) {
    query = query.where('categoryId', isEqualTo: filter.categoryId);
  }
  if (filter.accountId != null) {
    query = query.where('accountId', isEqualTo: filter.accountId);
  }
  if (filter.type != null) {
    query = query.where('type', isEqualTo: filter.type!.name);
  }

  return query.snapshots().map((snap) =>
      snap.docs.map((d) => TransactionModel.fromFirestore(d)).where((tx) {
        if (filter.minAmount != null && tx.amount < filter.minAmount!) {
          return false;
        }
        if (filter.maxAmount != null && tx.amount > filter.maxAmount!) {
          return false;
        }
        if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
          final q = filter.searchQuery!.toLowerCase();
          return (tx.payee?.toLowerCase().contains(q) ?? false) ||
              (tx.note?.toLowerCase().contains(q) ?? false);
        }
        return true;
      }).toList());
});

// â”€â”€ Current month transactions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
final currentMonthTransactionsProvider =
    StreamProvider<List<TransactionModel>>((ref) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  final filter = TransactionFilter(startDate: start, endDate: end);
  return ref.watch(transactionsStreamProvider(filter).stream);
});

// â”€â”€ Recent 5 transactions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
final recentTransactionsProvider =
    StreamProvider<List<TransactionModel>>((ref) async* {
  final isGuest = ref.watch(guestSessionProvider);
  if (isGuest) {
    final rows = await _localDb.getAll('transactions');
    final list = rows
        .map(TransactionModel.fromLocalMap)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    yield list.take(5).toList();
    return;
  }
  yield* _txCollection
      .orderBy('date', descending: true)
      .limit(5)
      .snapshots()
      .map((s) => s.docs.map((d) => TransactionModel.fromFirestore(d)).toList());
});

// â”€â”€ Transaction Notifier â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class TransactionNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  TransactionNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<TransactionModel?> _getTransactionById(String id) async {
    final isGuest = _ref.read(guestSessionProvider);
    if (isGuest) {
      final row = await _localDb.getById('transactions', id);
      return row != null ? TransactionModel.fromLocalMap(row) : null;
    } else {
      final doc = await _txCollection.doc(id).get();
      return doc.exists ? TransactionModel.fromFirestore(doc) : null;
    }
  }

  Future<TransactionModel?> addTransaction(
      Map<String, dynamic> fields) async {
    state = const AsyncValue.loading();
    try {
      final id = const Uuid().v4();
      final isGuest = _ref.read(guestSessionProvider);
      final tx = TransactionModel(
        id: id,
        userId: isGuest ? 'guest' : _uid,
        amount: (fields['amount'] as num).toDouble(),
        type: fields['type'] as TransactionType,
        categoryId: fields['categoryId'] as String,
        accountId: fields['accountId'] as String,
        payee: fields['payee'] as String?,
        note: fields['note'] as String?,
        date: fields['date'] as DateTime,
        source: fields['source'] as TransactionSource? ?? TransactionSource.manual,
        isRecurring: fields['isRecurring'] as bool? ?? false,
        splits: fields['splits'] as List<SplitEntry>?,
        loanId: fields['loanId'] as String?,
        goalId: fields['goalId'] as String?,
      );

      if (isGuest) {
        await _localDb.upsert('transactions', id, tx.toLocalMap());
        await _updateAccountBalance(tx.accountId, tx.amount, tx.type);
      } else {
        await _txCollection.doc(id).set(tx.toFirestore());
        await _updateAccountBalance(tx.accountId, tx.amount, tx.type);
      }

      // Invalidate transaction streams so UI updates immediately
      _invalidateAll();

      state = const AsyncValue.data(null);
      return tx;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> updateTransaction(
      String id, Map<String, dynamic> fields) async {
    state = const AsyncValue.loading();
    try {
      // Revert old balance
      final oldTx = await _getTransactionById(id);
      if (oldTx != null) {
        final reverseType = oldTx.type == TransactionType.debit ? TransactionType.credit : TransactionType.debit;
        await _updateAccountBalance(oldTx.accountId, oldTx.amount, reverseType);
      }

      final isGuest = _ref.read(guestSessionProvider);
      if (isGuest) {
        await _localDb.update('transactions', id, fields);
      } else {
        await _txCollection.doc(id).update(fields);
      }

      // Apply new balance
      final newTx = await _getTransactionById(id);
      if (newTx != null) {
        await _updateAccountBalance(newTx.accountId, newTx.amount, newTx.type);
      }

      _invalidateAll();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteTransaction(String id) async {
    state = const AsyncValue.loading();
    try {
      final tx = await _getTransactionById(id);
      if (tx != null) {
        final reverseType = tx.type == TransactionType.debit ? TransactionType.credit : TransactionType.debit;
        await _updateAccountBalance(tx.accountId, tx.amount, reverseType);
      }

      final isGuest = _ref.read(guestSessionProvider);
      if (isGuest) {
        await _localDb.delete('transactions', id);
      } else {
        await _txCollection.doc(id).delete();
      }

      _invalidateAll();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> _updateAccountBalance(
      String accountId, double amount, TransactionType type) async {
    if (accountId.isEmpty) return;
    final delta = type == TransactionType.debit ? -amount : amount;
    final isGuest = _ref.read(guestSessionProvider);
    if (isGuest) {
      final row = await _localDb.getById('accounts', accountId);
      if (row != null) {
        final currentBalance = (row['balance'] as num?)?.toDouble() ?? 0.0;
        row['balance'] = currentBalance + delta;
        await _localDb.upsert('accounts', accountId, row);
      }
    } else {
      await FirebaseFirestore.instance
          .collection(AppConstants.colUsers)
          .doc(_uid)
          .collection(AppConstants.colAccounts)
          .doc(accountId)
          .update({'balance': FieldValue.increment(delta)});
    }
  }

  void _invalidateAll() {
    _ref.invalidate(transactionsStreamProvider);
    _ref.invalidate(recentTransactionsProvider);
    _ref.invalidate(currentMonthTransactionsProvider);
    _ref.invalidate(accountsStreamProvider);
    _ref.invalidate(netWorthProvider);
    _ref.invalidate(monthlySummaryProvider);
    _ref.invalidate(dailyBudgetRemainingProvider);
  }
}

final transactionNotifierProvider =
    StateNotifierProvider<TransactionNotifier, AsyncValue<void>>(
  (ref) => TransactionNotifier(ref),
);

// â”€â”€ Monthly Summary â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class MonthlySummary {
  final double totalIncome;
  final double totalExpense;
  final Map<String, double> byCategory;

  const MonthlySummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.byCategory,
  });

  double get netSavings => totalIncome - totalExpense;
  double get savingsRate =>
      totalIncome > 0 ? (netSavings / totalIncome) * 100 : 0;
}

final monthlySummaryProvider =
    Provider<AsyncValue<MonthlySummary>>((ref) {
  return ref.watch(currentMonthTransactionsProvider).when(
        data: (txns) {
          double income = 0, expense = 0;
          final byCategory = <String, double>{};
          for (final tx in txns) {
            if (tx.isCredit) {
              income += tx.amount;
            } else {
              expense += tx.amount;
              byCategory[tx.categoryId] =
                  (byCategory[tx.categoryId] ?? 0) + tx.amount;
            }
          }
          return AsyncValue.data(MonthlySummary(
            totalIncome: income,
            totalExpense: expense,
            byCategory: byCategory,
          ));
        },
        loading: () => const AsyncValue.loading(),
        error: (e, s) => AsyncValue.error(e, s),
      );
});
