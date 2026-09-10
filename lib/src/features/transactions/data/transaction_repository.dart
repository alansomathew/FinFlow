import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/app_database.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/transaction.dart';

class TransactionRepository {
  final Ref _ref;
  TransactionRepository(this._ref);

  AppDatabase get _db => AppDatabase.instance;

  Future<List<TransactionModel>> getTransactions() async {
    final user = _ref.read(authProvider);
    if (user == null || user.isGuest) {
      return _getLocalTransactions();
    } else {
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('transactions')
            .orderBy('date', descending: true)
            .get();
        return querySnapshot.docs
            .map((doc) => TransactionModel.fromMap(doc.data()))
            .toList();
      } catch (e) {
        // Fallback to local SQLite if Firebase is unconfigured or offline
        return _getLocalTransactions();
      }
    }
  }

  Future<List<TransactionModel>> _getLocalTransactions() async {
    final query = _db.select(_db.transactions)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.date)]);
    final rows = await query.get();
    return rows.map(TransactionModel.fromRow).toList();
  }

  Future<void> addTransaction(TransactionModel tx) async {
    final user = _ref.read(authProvider);
    if (user == null || user.isGuest) {
      await _upsertLocal(tx);
    } else {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('transactions')
            .doc(tx.id)
            .set(tx.toMap());
        await _upsertLocal(tx);
      } catch (e) {
        await _upsertLocal(tx);
      }
    }
  }

  /// Inserts the transaction and adjusts the linked account's balance in a
  /// single Drift transaction so the two writes can't drift out of sync if
  /// one half fails.
  Future<void> _upsertLocal(TransactionModel tx) async {
    await _db.transaction(() async {
      await _db.into(_db.transactions).insertOnConflictUpdate(tx.toCompanion());
      await _applyBalanceDelta(tx.accountId, tx.bucket, tx.amount);
    });
  }

  Future<void> updateTransaction(
    TransactionModel oldTx,
    TransactionModel newTx,
  ) async {
    final user = _ref.read(authProvider);
    if (user == null || user.isGuest) {
      await _updateLocal(oldTx, newTx);
    } else {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('transactions')
            .doc(newTx.id)
            .set(newTx.toMap());
        await _updateLocal(oldTx, newTx);
      } catch (e) {
        await _updateLocal(oldTx, newTx);
      }
    }
  }

  /// Reverses [oldTx]'s balance impact, applies [newTx]'s, then writes the
  /// new row -- all inside one Drift transaction. The two adjustment calls
  /// are sequential selects-then-writes against the same connection, so they
  /// compound correctly even when the account didn't change (the second call
  /// reads the balance the first one just wrote).
  Future<void> _updateLocal(
    TransactionModel oldTx,
    TransactionModel newTx,
  ) async {
    await _db.transaction(() async {
      await _reverseBalanceDelta(oldTx.accountId, oldTx.bucket, oldTx.amount);
      await _applyBalanceDelta(newTx.accountId, newTx.bucket, newTx.amount);
      await (_db.update(
        _db.transactions,
      )..where((t) => t.id.equals(newTx.id))).write(newTx.toCompanion());
    });
  }

  Future<void> deleteTransaction(String id) async {
    final user = _ref.read(authProvider);
    if (user == null || user.isGuest) {
      await _deleteLocal(id);
    } else {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('transactions')
            .doc(id)
            .delete();
        await _deleteLocal(id);
      } catch (e) {
        await _deleteLocal(id);
      }
    }
  }

  Future<void> _deleteLocal(String id) async {
    await _db.transaction(() async {
      final tx = await (_db.select(
        _db.transactions,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (tx == null) return;

      await _reverseBalanceDelta(
        tx.accountId,
        BudgetBucket.values.firstWhere((b) => b.name == tx.bucket),
        tx.amount,
      );
      await (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
    });
  }

  /// Income adds to the account balance; every other bucket subtracts.
  Future<void> _applyBalanceDelta(
    String accountId,
    BudgetBucket bucket,
    double amount,
  ) {
    final isCredit = bucket == BudgetBucket.income;
    return _adjustBalance(accountId, isCredit ? amount : -amount);
  }

  /// Undoes a previously-applied delta for the same bucket/amount.
  Future<void> _reverseBalanceDelta(
    String accountId,
    BudgetBucket bucket,
    double amount,
  ) {
    final isCredit = bucket == BudgetBucket.income;
    return _adjustBalance(accountId, isCredit ? -amount : amount);
  }

  Future<void> _adjustBalance(String accountId, double delta) async {
    final account = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (account == null) return;
    await (_db.update(
      _db.accounts,
    )..where((a) => a.id.equals(accountId))).write(
      AccountsCompanion(
        balance: Value(account.balance + delta),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref);
});

class TransactionListNotifier
    extends StateNotifier<AsyncValue<List<TransactionModel>>> {
  final TransactionRepository _repo;
  TransactionListNotifier(this._repo) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final list = await _repo.getTransactions();
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> add(TransactionModel tx) async {
    await _repo.addTransaction(tx);
    await refresh();
  }

  Future<void> update(TransactionModel oldTx, TransactionModel newTx) async {
    await _repo.updateTransaction(oldTx, newTx);
    await refresh();
  }

  Future<void> remove(String id) async {
    await _repo.deleteTransaction(id);
    await refresh();
  }
}

final transactionListProvider =
    StateNotifierProvider<
      TransactionListNotifier,
      AsyncValue<List<TransactionModel>>
    >((ref) {
      final repo = ref.watch(transactionRepositoryProvider);
      return TransactionListNotifier(repo);
    });
