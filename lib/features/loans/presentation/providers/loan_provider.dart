import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/loan_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/local/local_database.dart';

String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

CollectionReference<Map<String, dynamic>> get _col =>
    FirebaseFirestore.instance
        .collection(AppConstants.colUsers)
        .doc(_uid)
        .collection(AppConstants.colLoans);

final _localDb = LocalDatabase.instance;

final loansStreamProvider = StreamProvider<List<LoanModel>>((ref) async* {
  final isGuest = ref.watch(guestSessionProvider);
  if (isGuest) {
    final rows = await _localDb.getAll('loans');
    yield rows
        .map(LoanModel.fromLocalMap)
        .where((l) => l.isActive)
        .toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    return;
  }
  yield* _col
      .where('isActive', isEqualTo: true)
      .orderBy('startDate', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => LoanModel.fromFirestore(d)).toList());
});

final totalDebtProvider = Provider<AsyncValue<double>>((ref) {
  return ref.watch(loansStreamProvider).when(
        data: (loans) => AsyncValue.data(
          loans.fold(0.0, (sum, l) => sum + l.outstandingPrincipal),
        ),
        loading: () => const AsyncValue.loading(),
        error: (e, s) => AsyncValue.error(e, s),
      );
});

class LoanNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  LoanNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> addLoan(LoanModel loan) async {
    state = const AsyncValue.loading();
    try {
      final id = const Uuid().v4();
      final isGuest = _ref.read(guestSessionProvider);
      final newLoan = LoanModel(
        id: id,
        userId: isGuest ? 'guest' : _uid,
        type: loan.type,
        lenderName: loan.lenderName,
        principalAmount: loan.principalAmount,
        interestRate: loan.interestRate,
        tenureMonths: loan.tenureMonths,
        startDate: loan.startDate,
        emiAmount: loan.emiAmount,
        accountId: loan.accountId,
        outstandingPrincipal: loan.principalAmount,
        notes: loan.notes,
      );
      if (isGuest) {
        await _localDb.upsert('loans', id, newLoan.toLocalMap());
      } else {
        await _col.doc(id).set(newLoan.toFirestore());
      }
      _ref.invalidate(loansStreamProvider);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> recordEmiPayment(String loanId, double emiAmount,
      double principalComponent) async {
    state = const AsyncValue.loading();
    try {
      final isGuest = _ref.read(guestSessionProvider);
      if (isGuest) {
        final row = await _localDb.getById('loans', loanId);
        if (row == null) return;
        final loan = LoanModel.fromLocalMap(row);
        final updated = LoanModel(
          id: loan.id,
          userId: loan.userId,
          type: loan.type,
          lenderName: loan.lenderName,
          principalAmount: loan.principalAmount,
          interestRate: loan.interestRate,
          tenureMonths: loan.tenureMonths,
          startDate: loan.startDate,
          emiAmount: loan.emiAmount,
          accountId: loan.accountId,
          outstandingPrincipal:
              (loan.outstandingPrincipal - principalComponent).clamp(0, double.infinity),
          isActive: loan.isActive,
          notes: loan.notes,
        );
        await _localDb.upsert('loans', loanId, updated.toLocalMap());
      } else {
        await _col.doc(loanId).update({
          'outstandingPrincipal': FieldValue.increment(-principalComponent),
        });
      }
      _ref.invalidate(loansStreamProvider);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> closeLoan(String loanId) async {
    final isGuest = _ref.read(guestSessionProvider);
    if (isGuest) {
      await _localDb.update('loans', loanId, {'isActive': 0});
    } else {
      await _col.doc(loanId).update({'isActive': false});
    }
    _ref.invalidate(loansStreamProvider);
  }
}

final loanNotifierProvider =
    StateNotifierProvider<LoanNotifier, AsyncValue<void>>(
  (ref) => LoanNotifier(ref),
);
