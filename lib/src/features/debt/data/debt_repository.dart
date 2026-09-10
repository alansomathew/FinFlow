import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/db_service.dart';
import '../../auth/data/auth_repository.dart';

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
}

class DebtRepository {
  final Ref _ref;
  DebtRepository(this._ref);

  Future<List<LoanModel>> getLoans() async {
    final user = _ref.read(authProvider);
    if (user == null || user.isGuest) {
      final list = await DbService.instance.queryAllLoans();
      return list.map((e) => LoanModel.fromMap(e)).toList();
    } else {
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('loans')
            .get();
        return querySnapshot.docs.map((doc) => LoanModel.fromMap(doc.data())).toList();
      } catch (e) {
        final list = await DbService.instance.queryAllLoans();
        return list.map((e) => LoanModel.fromMap(e)).toList();
      }
    }
  }

  Future<void> addLoan(LoanModel loan) async {
    final user = _ref.read(authProvider);
    if (user == null || user.isGuest) {
      await DbService.instance.insertLoan(loan.toMap());
    } else {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('loans')
            .doc(loan.id)
            .set(loan.toMap());
        await DbService.instance.insertLoan(loan.toMap());
      } catch (e) {
        await DbService.instance.insertLoan(loan.toMap());
      }
    }
  }

  Future<void> deleteLoan(String id) async {
    final user = _ref.read(authProvider);
    if (user == null || user.isGuest) {
      await DbService.instance.deleteLoan(id);
    } else {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('loans')
            .doc(id)
            .delete();
        await DbService.instance.deleteLoan(id);
      } catch (e) {
        await DbService.instance.deleteLoan(id);
      }
    }
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

final loanListProvider = StateNotifierProvider<LoanListNotifier, AsyncValue<List<LoanModel>>>((ref) {
  final repo = ref.watch(debtRepositoryProvider);
  return LoanListNotifier(repo);
});
