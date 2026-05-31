import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/budget_model.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../../../transactions/domain/models/category_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/local/local_database.dart';

String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

DocumentReference<Map<String, dynamic>> _budgetDoc(String monthKey) =>
    FirebaseFirestore.instance
        .collection(AppConstants.colUsers)
        .doc(_uid)
        .collection(AppConstants.colBudgets)
        .doc(monthKey);

final _localDb = LocalDatabase.instance;

final currentMonthBudgetProvider =
    StreamProvider<BudgetModel?>((ref) async* {
  final monthKey = DateFormatter.firestoreMonthKey(DateTime.now());
  final isGuest = ref.watch(guestSessionProvider);
  if (isGuest) {
    final row = await _localDb.getById('budgets', monthKey);
    yield row != null ? BudgetModel.fromLocalMap(row) : null;
    return;
  }
  yield* _budgetDoc(monthKey).snapshots().map(
        (doc) => doc.exists ? BudgetModel.fromFirestore(doc) : null,
      );
});

// Merge budget + actual spending
final budgetWithSpendingProvider =
    Provider<AsyncValue<BudgetModel?>>((ref) {
  final budgetAsync = ref.watch(currentMonthBudgetProvider);
  final summaryAsync = ref.watch(monthlySummaryProvider);

  return budgetAsync.when(
    data: (budget) {
      if (budget == null) return const AsyncValue.data(null);
      return summaryAsync.when(
        data: (summary) {
          final updatedCats = budget.categories.map((cat) {
            final spent = summary.byCategory[cat.categoryId] ?? 0;
            return cat.copyWith(spent: spent);
          }).toList();

          // Add missing categories from spending
          for (final entry in summary.byCategory.entries) {
            final exists = updatedCats.any((c) => c.categoryId == entry.key);
            if (!exists) {
              updatedCats.add(
                BudgetCategory(
                  categoryId: entry.key,
                  allocated: 0,
                  spent: entry.value,
                ),
              );
            }
          }

          return AsyncValue.data(budget.copyWith(categories: updatedCats));
        },
        loading: () => const AsyncValue.loading(),
        error: (e, s) => AsyncValue.error(e, s),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
  );
});

// 50/30/20 Bucket spending
class BucketSummary {
  final double needsSpent;
  final double wantsSpent;
  final double savingsSpent;
  final double needsAllocated;
  final double wantsAllocated;
  final double savingsAllocated;

  const BucketSummary({
    required this.needsSpent,
    required this.wantsSpent,
    required this.savingsSpent,
    required this.needsAllocated,
    required this.wantsAllocated,
    required this.savingsAllocated,
  });
}

final bucketSummaryProvider = Provider<AsyncValue<BucketSummary>>((ref) {
  final budgetAsync = ref.watch(budgetWithSpendingProvider);

  return budgetAsync.when(
    data: (budget) {
      if (budget == null) return const AsyncValue.data(BucketSummary(
        needsSpent: 0, wantsSpent: 0, savingsSpent: 0,
        needsAllocated: 0, wantsAllocated: 0, savingsAllocated: 0,
      ));

      double needsSpent = 0, wantsSpent = 0, savingsSpent = 0;
      for (final cat in budget.categories) {
        final catModel = CategoryModel.byId(cat.categoryId);
        switch (catModel.bucket) {
          case BudgetBucket.needs:
            needsSpent += cat.spent;
            break;
          case BudgetBucket.wants:
            wantsSpent += cat.spent;
            break;
          case BudgetBucket.savings:
            savingsSpent += cat.spent;
            break;
        }
      }

      return AsyncValue.data(BucketSummary(
        needsSpent: needsSpent,
        wantsSpent: wantsSpent,
        savingsSpent: savingsSpent,
        needsAllocated: budget.needsAllocated,
        wantsAllocated: budget.wantsAllocated,
        savingsAllocated: budget.savingsAllocated,
      ));
    },
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
  );
});

class BudgetNotifier extends StateNotifier<AsyncValue<void>> {
  BudgetNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<void> createOrUpdateBudget(BudgetModel budget) async {
    state = const AsyncValue.loading();
    try {
      final isGuest = _ref.read(guestSessionProvider);
      if (isGuest) {
        await _localDb.upsert('budgets', budget.id, budget.toLocalMap());
      } else {
        await _budgetDoc(budget.monthKey).set(budget.toFirestore());
      }
      _ref.invalidate(currentMonthBudgetProvider);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> updateCategoryAllocation(
      String monthKey, String categoryId, double allocated) async {
    state = const AsyncValue.loading();
    try {
      final isGuest = _ref.read(guestSessionProvider);
      if (isGuest) {
        final row = await _localDb.getById('budgets', monthKey);
        if (row == null) return;
        final budget = BudgetModel.fromLocalMap(row);
        final updatedCats = budget.categories.map((c) {
          if (c.categoryId == categoryId) return c.copyWith(allocated: allocated);
          return c;
        }).toList();
        final updated = budget.copyWith(categories: updatedCats);
        await _localDb.upsert('budgets', monthKey, updated.toLocalMap());
      } else {
        final doc = await _budgetDoc(monthKey).get();
        if (!doc.exists) return;
        final budget = BudgetModel.fromFirestore(doc);
        final updatedCats = budget.categories.map((c) {
          if (c.categoryId == categoryId) return c.copyWith(allocated: allocated);
          return c;
        }).toList();
        await _budgetDoc(monthKey).update({
          'categories': updatedCats.map((c) => c.toMap()).toList(),
        });
      }
      _ref.invalidate(currentMonthBudgetProvider);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }
}

final budgetNotifierProvider =
    StateNotifierProvider<BudgetNotifier, AsyncValue<void>>(
  (ref) => BudgetNotifier(ref),
);
