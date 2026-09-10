import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/app_database.dart';
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

  factory BudgetModel.fromRow(Budget row) {
    return BudgetModel(
      category: row.category,
      limitAmount: row.limitAmount,
      spentAmount: row.spentAmount,
      monthYear: row.monthYear,
    );
  }

  BudgetsCompanion toCompanion() {
    return BudgetsCompanion(
      category: Value(category),
      limitAmount: Value(limitAmount),
      spentAmount: Value(spentAmount),
      monthYear: Value(monthYear),
      updatedAt: Value(DateTime.now()),
    );
  }
}

class BudgetRepository {
  final Ref _ref;
  BudgetRepository(this._ref);

  AppDatabase get _db => AppDatabase.instance;

  Future<List<BudgetModel>> getBudgets() async {
    final user = _ref.read(authProvider);
    if (user == null || user.isGuest) {
      return _getLocalBudgets();
    } else {
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('budgets')
            .get();
        return querySnapshot.docs.map((doc) => BudgetModel.fromMap(doc.data())).toList();
      } catch (e) {
        return _getLocalBudgets();
      }
    }
  }

  Future<List<BudgetModel>> _getLocalBudgets() async {
    final rows = await (_db.select(_db.budgets)..where((t) => t.deletedAt.isNull())).get();
    return rows.map(BudgetModel.fromRow).toList();
  }

  Future<void> saveBudget(BudgetModel budget) async {
    final user = _ref.read(authProvider);
    if (user == null || user.isGuest) {
      await _upsertLocal(budget);
    } else {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('budgets')
            .doc(budget.category)
            .set(budget.toMap());
        await _upsertLocal(budget);
      } catch (e) {
        await _upsertLocal(budget);
      }
    }
  }

  Future<void> _upsertLocal(BudgetModel budget) async {
    await _db.into(_db.budgets).insertOnConflictUpdate(budget.toCompanion());
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
