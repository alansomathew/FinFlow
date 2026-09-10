import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/db_service.dart';
import '../../auth/data/auth_repository.dart';

class BudgetModel {
  final String category;
  final double limitAmount;
  final double spentAmount;
  final String monthYear; // 'YYYY-MM'

  BudgetModel({
    required this.category,
    required this.limitAmount,
    required this.spentAmount,
    required this.monthYear,
  });

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'limit_amount': limitAmount,
      'spent_amount': spentAmount,
      'month_year': monthYear,
    };
  }

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      category: map['category'] ?? '',
      limitAmount: (map['limit_amount'] as num?)?.toDouble() ?? 0.0,
      spentAmount: (map['spent_amount'] as num?)?.toDouble() ?? 0.0,
      monthYear: map['month_year'] ?? '',
    );
  }
}

class BudgetRepository {
  final Ref _ref;
  BudgetRepository(this._ref);

  Future<List<BudgetModel>> getBudgets() async {
    final user = _ref.read(authProvider);
    if (user == null || user.isGuest) {
      final list = await DbService.instance.queryAllBudgets();
      return list.map((e) => BudgetModel.fromMap(e)).toList();
    } else {
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('budgets')
            .get();
        return querySnapshot.docs.map((doc) => BudgetModel.fromMap(doc.data())).toList();
      } catch (e) {
        final list = await DbService.instance.queryAllBudgets();
        return list.map((e) => BudgetModel.fromMap(e)).toList();
      }
    }
  }

  Future<void> saveBudget(BudgetModel budget) async {
    final user = _ref.read(authProvider);
    if (user == null || user.isGuest) {
      await DbService.instance.insertBudget(budget.toMap());
    } else {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('budgets')
            .doc(budget.category)
            .set(budget.toMap());
        await DbService.instance.insertBudget(budget.toMap());
      } catch (e) {
        await DbService.instance.insertBudget(budget.toMap());
      }
    }
  }
}

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref);
});

class BudgetListNotifier extends StateNotifier<AsyncValue<List<BudgetModel>>> {
  final BudgetRepository _repo;
  BudgetListNotifier(this._repo) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final list = await _repo.getBudgets();
      state = AsyncValue.data(list);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> setLimit(String category, double limit, double spent, String monthYear) async {
    final budget = BudgetModel(category: category, limitAmount: limit, spentAmount: spent, monthYear: monthYear);
    await _repo.saveBudget(budget);
    await refresh();
  }
}

final budgetListProvider = StateNotifierProvider<BudgetListNotifier, AsyncValue<List<BudgetModel>>>((ref) {
  final repo = ref.watch(budgetRepositoryProvider);
  return BudgetListNotifier(repo);
});
