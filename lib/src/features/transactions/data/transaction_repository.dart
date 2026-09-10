import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/db_service.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/transaction.dart';

class TransactionRepository {
  final Ref _ref;
  TransactionRepository(this._ref);

  Future<List<TransactionModel>> getTransactions() async {
    final user = _ref.read(authProvider);
    if (user == null || user.isGuest) {
      final list = await DbService.instance.queryAllTransactions();
      return list.map((e) => TransactionModel.fromMap(e)).toList();
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
        final list = await DbService.instance.queryAllTransactions();
        return list.map((e) => TransactionModel.fromMap(e)).toList();
      }
    }
  }

  Future<void> addTransaction(TransactionModel tx) async {
    final user = _ref.read(authProvider);
    if (user == null || user.isGuest) {
      await DbService.instance.insertTransaction(tx.toMap());
    } else {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('transactions')
            .doc(tx.id)
            .set(tx.toMap());
        await DbService.instance.insertTransaction(tx.toMap());
      } catch (e) {
        await DbService.instance.insertTransaction(tx.toMap());
      }
    }
  }

  Future<void> deleteTransaction(String id) async {
    final user = _ref.read(authProvider);
    if (user == null || user.isGuest) {
      await DbService.instance.deleteTransaction(id);
    } else {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('transactions')
            .doc(id)
            .delete();
        await DbService.instance.deleteTransaction(id);
      } catch (e) {
        await DbService.instance.deleteTransaction(id);
      }
    }
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
