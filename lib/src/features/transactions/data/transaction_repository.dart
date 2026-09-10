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
        return querySnapshot.docs.map((doc) => TransactionModel.fromMap(doc.data())).toList();
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

      final account =
          await (_db.select(_db.accounts)..where((a) => a.id.equals(tx.accountId))).getSingleOrNull();
      if (account != null) {
        // Income increases the balance; every other bucket is a spend.
        final isCredit = tx.bucket == BudgetBucket.income;
        final newBalance = isCredit ? account.balance + tx.amount : account.balance - tx.amount;
        await (_db.update(_db.accounts)..where((a) => a.id.equals(tx.accountId))).write(
          AccountsCompanion(balance: Value(newBalance), updatedAt: Value(DateTime.now())),
        );
      }
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
      final tx = await (_db.select(_db.transactions)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (tx == null) return;

      // Reverse the balance adjustment applied when this transaction was added.
      final account =
          await (_db.select(_db.accounts)..where((a) => a.id.equals(tx.accountId))).getSingleOrNull();
      if (account != null) {
        final wasCredit = tx.bucket == BudgetBucket.income.name;
        final newBalance = wasCredit ? account.balance - tx.amount : account.balance + tx.amount;
        await (_db.update(_db.accounts)..where((a) => a.id.equals(tx.accountId))).write(
          AccountsCompanion(balance: Value(newBalance), updatedAt: Value(DateTime.now())),
        );
      }

      await (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
    });
  }
}

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref);
});

class TransactionListNotifier extends StateNotifier<AsyncValue<List<TransactionModel>>> {
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

  Future<void> remove(String id) async {
    await _repo.deleteTransaction(id);
    await refresh();
  }
}

final transactionListProvider = StateNotifierProvider<TransactionListNotifier, AsyncValue<List<TransactionModel>>>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return TransactionListNotifier(repo);
});
