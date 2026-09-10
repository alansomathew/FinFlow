import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/db_service.dart';
import '../../auth/data/auth_repository.dart';

class AccountModel {
  final String id;
  final String name;
  final String type; // 'bank', 'credit_card', 'wallet', 'cash'
  final double balance;
  final double creditLimit;
  final String cardDueDate;
  final String colorHex;

  AccountModel({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.creditLimit = 0.0,
    this.cardDueDate = '',
    required this.colorHex,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'balance': balance,
      'credit_limit': creditLimit,
      'card_due_date': cardDueDate,
      'color_hex': colorHex,
    };
  }

  factory AccountModel.fromMap(Map<String, dynamic> map) {
    return AccountModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      type: map['type'] ?? 'bank',
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      creditLimit: (map['credit_limit'] as num?)?.toDouble() ?? 0.0,
      cardDueDate: map['card_due_date'] ?? '',
      colorHex: map['color_hex'] ?? '#1E1E1E',
    );
  }
}

class AccountsRepository {
  final Ref _ref;
  AccountsRepository(this._ref);

  Future<List<AccountModel>> getAccounts() async {
    final user = _ref.read(authProvider);
    if (user == null || user.isGuest) {
      final list = await DbService.instance.queryAllAccounts();
      return list.map((e) => AccountModel.fromMap(e)).toList();
    } else {
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('accounts')
            .get();
        return querySnapshot.docs.map((doc) => AccountModel.fromMap(doc.data())).toList();
      } catch (e) {
        final list = await DbService.instance.queryAllAccounts();
        return list.map((e) => AccountModel.fromMap(e)).toList();
      }
    }
  }

  Future<void> addAccount(AccountModel account) async {
    final user = _ref.read(authProvider);
    if (user == null || user.isGuest) {
      await DbService.instance.insertAccount(account.toMap());
    } else {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('accounts')
            .doc(account.id)
            .set(account.toMap());
        await DbService.instance.insertAccount(account.toMap());
      } catch (e) {
        await DbService.instance.insertAccount(account.toMap());
      }
    }
  }

  Future<void> deleteAccount(String id) async {
    final user = _ref.read(authProvider);
    if (user == null || user.isGuest) {
      await DbService.instance.deleteAccount(id);
    } else {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('accounts')
            .doc(id)
            .delete();
        await DbService.instance.deleteAccount(id);
      } catch (e) {
        await DbService.instance.deleteAccount(id);
      }
    }
  }
}

final accountsRepositoryProvider = Provider<AccountsRepository>((ref) {
  return AccountsRepository(ref);
});

class AccountListNotifier extends StateNotifier<AsyncValue<List<AccountModel>>> {
  final AccountsRepository _repo;
  AccountListNotifier(this._repo) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final list = await _repo.getAccounts();
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> add(AccountModel account) async {
    await _repo.addAccount(account);
    await refresh();
  }

  Future<void> remove(String id) async {
    await _repo.deleteAccount(id);
    await refresh();
  }
}

final accountListProvider = StateNotifierProvider<AccountListNotifier, AsyncValue<List<AccountModel>>>((ref) {
  final repo = ref.watch(accountsRepositoryProvider);
  return AccountListNotifier(repo);
});
