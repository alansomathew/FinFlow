import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/app_database.dart';
import '../../../services/pro_tier_service.dart';
import '../../auth/data/auth_repository.dart';

const int kFreeLoanLimit = 2;

class LoanModel {
  final String id;
  final String lenderName;
  final double loanAmount;
  final double interestRate; // Annual %
  final int tenureMonths;
  final String startDate;
  final double emiAmount;
  final String debitAccountId;

  LoanModel({
    required this.id,
    required this.lenderName,
    required this.loanAmount,
    required this.interestRate,
    required this.tenureMonths,
    required this.startDate,
    required this.emiAmount,
    required this.debitAccountId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'lender_name': lenderName,
      'loan_amount': loanAmount,
      'interest_rate': interestRate,
      'tenure_months': tenureMonths,
      'start_date': startDate,
      'emi_amount': emiAmount,
      'debit_account_id': debitAccountId,
    };
  }

  factory LoanModel.fromMap(Map<String, dynamic> map) {
    return LoanModel(
      id: map['id'] ?? '',
      lenderName: map['lender_name'] ?? '',
      loanAmount: (map['loan_amount'] as num?)?.toDouble() ?? 0.0,
      interestRate: (map['interest_rate'] as num?)?.toDouble() ?? 0.0,
      tenureMonths: map['tenure_months'] as int? ?? 12,
      startDate: map['start_date'] ?? '',
      emiAmount: (map['emi_amount'] as num?)?.toDouble() ?? 0.0,
      debitAccountId: map['debit_account_id'] ?? '',
    );
  }

  factory LoanModel.fromRow(Loan row) {
    return LoanModel(
      id: row.id,
      lenderName: row.lenderName,
      loanAmount: row.loanAmount,
      interestRate: row.interestRate,
      tenureMonths: row.tenureMonths,
      startDate: row.startDate,
      emiAmount: row.emiAmount,
      debitAccountId: row.debitAccountId,
    );
  }

  LoansCompanion toCompanion() {
    return LoansCompanion(
      id: Value(id),
      lenderName: Value(lenderName),
      loanAmount: Value(loanAmount),
      interestRate: Value(interestRate),
      tenureMonths: Value(tenureMonths),
      startDate: Value(startDate),
      emiAmount: Value(emiAmount),
      debitAccountId: Value(debitAccountId),
      updatedAt: Value(DateTime.now()),
    );
  }
}

class DebtRepository {
  final Ref _ref;
  DebtRepository(this._ref);

  AppDatabase get _db => AppDatabase.instance;

  Future<List<LoanModel>> getLoans() async {
    final user = _ref.read(authProvider);
    if (user == null || user.isGuest) {
      return _getLocalLoans();
    } else {
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('loans')
            .get();
        return querySnapshot.docs
            .map((doc) => LoanModel.fromMap(doc.data()))
            .toList();
      } catch (e) {
        return _getLocalLoans();
      }
    }
  }

  Future<List<LoanModel>> _getLocalLoans() async {
    final rows = await (_db.select(
      _db.loans,
    )..where((t) => t.deletedAt.isNull())).get();
    return rows.map(LoanModel.fromRow).toList();
  }

  Future<int> countLoans() async => (await getLoans()).length;

  /// Free tier is capped at [kFreeLoanLimit] loans; Pro is unlimited.
  Future<bool> canAddLoan() async {
    final isPro = _ref.read(isProProvider).valueOrNull ?? false;
    if (isPro) return true;
    return (await countLoans()) < kFreeLoanLimit;
  }

  Future<void> addLoan(LoanModel loan) async {
    final user = _ref.read(authProvider);
    if (user == null || user.isGuest) {
      await _upsertLocal(loan);
    } else {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('loans')
            .doc(loan.id)
            .set(loan.toMap());
        await _upsertLocal(loan);
      } catch (e) {
        await _upsertLocal(loan);
      }
    }
  }

  Future<void> _upsertLocal(LoanModel loan) async {
    await _db.into(_db.loans).insertOnConflictUpdate(loan.toCompanion());
  }

  Future<void> deleteLoan(String id) async {
    final user = _ref.read(authProvider);
    if (user == null || user.isGuest) {
      await _deleteLocal(id);
    } else {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('loans')
            .doc(id)
            .delete();
        await _deleteLocal(id);
      } catch (e) {
        await _deleteLocal(id);
      }
    }
  }

  Future<void> _deleteLocal(String id) async {
    await (_db.delete(_db.loans)..where((t) => t.id.equals(id))).go();
  }
}

final debtRepositoryProvider = Provider<DebtRepository>((ref) {
  return DebtRepository(ref);
});

class LoanListNotifier extends StateNotifier<AsyncValue<List<LoanModel>>> {
  final DebtRepository _repo;
  LoanListNotifier(this._repo) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final list = await _repo.getLoans();
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> add(LoanModel loan) async {
    await _repo.addLoan(loan);
    await refresh();
  }

  Future<void> remove(String id) async {
    await _repo.deleteLoan(id);
    await refresh();
  }
}

final loanListProvider =
    StateNotifierProvider<LoanListNotifier, AsyncValue<List<LoanModel>>>((ref) {
      final repo = ref.watch(debtRepositoryProvider);
      return LoanListNotifier(repo);
    });
