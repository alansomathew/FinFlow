import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/account_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/local/local_database.dart';

String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

CollectionReference<Map<String, dynamic>> get _col =>
    FirebaseFirestore.instance
        .collection(AppConstants.colUsers)
        .doc(_uid)
        .collection(AppConstants.colAccounts);

final _localDb = LocalDatabase.instance;

final accountsStreamProvider = StreamProvider<List<AccountModel>>((ref) async* {
  final isGuest = ref.watch(guestSessionProvider);
  if (isGuest) {
    final rows = await _localDb.getAll('accounts');
    yield rows
        .map(AccountModel.fromLocalMap)
        .where((a) => a.isActive)
        .toList();
    return;
  }
  yield* _col
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs.map((d) => AccountModel.fromFirestore(d)).toList());
});

final accountByIdProvider =
    StreamProvider.family<AccountModel?, String>((ref, id) async* {
  final isGuest = ref.watch(guestSessionProvider);
  if (isGuest) {
    final row = await _localDb.getById('accounts', id);
    yield row != null ? AccountModel.fromLocalMap(row) : null;
    return;
  }
  yield* _col
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? AccountModel.fromFirestore(d) : null);
});

// Net worth = sum of all non-credit-card balances - credit card outstanding
final netWorthProvider = Provider<AsyncValue<double>>((ref) {
  return ref.watch(accountsStreamProvider).when(
        data: (accounts) {
          double netWorth = 0;
          for (final acc in accounts) {
            if (acc.isCreditCard) {
              netWorth -= acc.balance.abs();
            } else {
              netWorth += acc.balance;
            }
          }
          return AsyncValue.data(netWorth);
        },
        loading: () => const AsyncValue.loading(),
        error: (e, s) => AsyncValue.error(e, s),
      );
});

class AccountNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  AccountNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> addAccount(AccountModel account) async {
    state = const AsyncValue.loading();
    try {
      final id = const Uuid().v4();
      final isGuest = _ref.read(guestSessionProvider);
      final acc = AccountModel(
        id: id,
        userId: isGuest ? 'guest' : _uid,
        name: account.name,
        bankName: account.bankName,
        type: account.type,
        balance: account.balance,
        maskedNumber: account.maskedNumber,
        creditLimit: account.creditLimit,
        statementDay: account.statementDay,
        dueDay: account.dueDay,
        interestRate: account.interestRate,
        color: account.color,
        emoji: account.emoji,
      );
      if (isGuest) {
        await _localDb.upsert('accounts', id, acc.toLocalMap());
      } else {
        await _col.doc(id).set(acc.toFirestore());
      }
      // Invalidate accountsStreamProvider and netWorthProvider so UI updates immediately
      _ref.invalidate(accountsStreamProvider);
      _ref.invalidate(netWorthProvider);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> updateAccount(String id, Map<String, dynamic> fields) async {
    state = const AsyncValue.loading();
    try {
      final isGuest = _ref.read(guestSessionProvider);
      if (isGuest) {
        await _localDb.update('accounts', id, fields);
      } else {
        await _col.doc(id).update(fields);
      }
      _ref.invalidate(accountsStreamProvider);
      _ref.invalidate(netWorthProvider);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> deleteAccount(String id) async {
    state = const AsyncValue.loading();
    try {
      final isGuest = _ref.read(guestSessionProvider);
      if (isGuest) {
        await _localDb.update('accounts', id, {'isActive': 0});
      } else {
        await _col.doc(id).update({'isActive': false});
      }
      _ref.invalidate(accountsStreamProvider);
      _ref.invalidate(netWorthProvider);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }
}

final accountNotifierProvider =
    StateNotifierProvider<AccountNotifier, AsyncValue<void>>(
  (ref) => AccountNotifier(ref),
);

