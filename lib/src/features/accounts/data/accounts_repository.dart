import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/app_database.dart';
import '../../../services/pro_tier_service.dart';
import '../../auth/data/auth_repository.dart';

const int kFreeAccountLimit = 3;

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

  factory AccountModel.fromRow(Account row) {
    return AccountModel(
      id: row.id,
      name: row.name,
      type: row.type,
      balance: row.balance,
      creditLimit: row.creditLimit,
      cardDueDate: row.cardDueDate ?? '',
      colorHex: row.colorHex,
    );
  }

  AccountsCompanion toCompanion() {
    return AccountsCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      balance: Value(balance),
      creditLimit: Value(creditLimit),
      cardDueDate: Value(cardDueDate.isEmpty ? null : cardDueDate),
      colorHex: Value(colorHex),
      updatedAt: Value(DateTime.now()),
    );
  }
}

class AccountsRepository {
  final Ref _ref;
  AccountsRepository(this._ref);

  AppDatabase get _db => AppDatabase.instance;

  Future<List<AccountModel>> getAccounts() async {
    final user = _ref.read(authProvider);
    if (user == null || user.isGuest) {
      return _getLocalAccounts();
    } else {
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('accounts')
            .get();
        return querySnapshot.docs
            .where((doc) => doc.data()['closed'] != true)
            .map((doc) => AccountModel.fromMap(doc.data()))
            .toList();
      } catch (e) {
        return _getLocalAccounts();
      }
    }
  }

  Future<List<AccountModel>> _getLocalAccounts() async {
    final rows = await (_db.select(
      _db.accounts,
    )..where((t) => t.deletedAt.isNull())).get();
    return rows.map(AccountModel.fromRow).toList();
  }

  Future<int> countAccounts() async => (await getAccounts()).length;

  /// Free tier is capped at [kFreeAccountLimit] accounts; Pro is unlimited.
  Future<bool> canAddAccount() async {
    final isPro = _ref.read(isProProvider).valueOrNull ?? false;
    if (isPro) return true;
    return (await countAccounts()) < kFreeAccountLimit;
  }

  Future<void> addAccount(AccountModel account) async {
    final user = _ref.read(authProvider);
    if (user == null || user.isGuest) {
      await _upsertLocal(account);
    } else {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('accounts')
            .doc(account.id)
            .set(account.toMap());
        await _upsertLocal(account);
      } catch (e) {
        await _upsertLocal(account);
      }
    }
  }

  Future<void> _upsertLocal(AccountModel account) async {
    await _db.into(_db.accounts).insertOnConflictUpdate(account.toCompanion());
  }

  /// Soft-deletes ("closes") an account rather than physically removing the
  /// row -- the FK from transactions/loans to accounts is ON DELETE RESTRICT,
  /// so a hard delete would be rejected the moment any history references
  /// this account (which it almost always does). Closing instead just hides
  /// the account from active lists/pickers while its historical
  /// transactions keep resolving normally.
  Future<void> closeAccount(String id) async {
    final user = _ref.read(authProvider);
    if (user == null || user.isGuest) {
      await _closeLocal(id);
    } else {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('accounts')
            .doc(id)
            .set({'closed': true}, SetOptions(merge: true));
        await _closeLocal(id);
      } catch (e) {
        await _closeLocal(id);
      }
    }
  }

  Future<void> _closeLocal(String id) async {
    await (_db.update(_db.accounts)..where((t) => t.id.equals(id))).write(
      AccountsCompanion(deletedAt: Value(DateTime.now())),
    );
  }
}

final accountsRepositoryProvider = Provider<AccountsRepository>((ref) {
  return AccountsRepository(ref);
});

class AccountListNotifier
    extends StateNotifier<AsyncValue<List<AccountModel>>> {
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

  Future<void> close(String id) async {
    await _repo.closeAccount(id);
    await refresh();
  }
}

final accountListProvider =
    StateNotifierProvider<AccountListNotifier, AsyncValue<List<AccountModel>>>((
      ref,
    ) {
      final repo = ref.watch(accountsRepositoryProvider);
      return AccountListNotifier(repo);
    });
