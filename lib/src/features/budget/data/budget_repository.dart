import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/app_database.dart';
import '../../../utils/month_key.dart';
import '../../auth/data/auth_repository.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/domain/transaction.dart';

class BudgetModel {
  final String category;
  final String monthYear; // 'YYYY-MM'
  final double limitAmount;

  /// Always derived live from real transactions by [BudgetRepository] --
  /// never stored. A budget row only ever holds a *limit*; how much of it
  /// has been spent is computed fresh every read, so it can never drift out
  /// of sync with the ledger the way a manually maintained running total did
  /// before (nothing updated it when a real transaction was added/edited).
  final double spentAmount;

  /// Pro-tier: unspent budget carries into next month's limit instead of
  /// resetting. Not enforced yet (real billing lands in Phase 11); the flag
  /// is plumbed through now so it's not another schema change later.
  final bool rolloverEnabled;

  BudgetModel({
    required this.category,
    required this.monthYear,
    required this.limitAmount,
    required this.spentAmount,
    this.rolloverEnabled = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'month_year': monthYear,
      'limit_amount': limitAmount,
      'rollover_enabled': rolloverEnabled,
    };
  }

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      category: map['category'] ?? '',
      monthYear: map['month_year'] ?? '',
      limitAmount: (map['limit_amount'] as num?)?.toDouble() ?? 0.0,
      spentAmount: 0.0,
      rolloverEnabled: map['rollover_enabled'] ?? false,
    );
  }

  factory BudgetModel.fromRow(Budget row) {
    return BudgetModel(
      category: row.category,
      monthYear: row.monthYear,
      limitAmount: row.limitAmount,
      spentAmount: 0.0,
      rolloverEnabled: row.rolloverEnabled,
    );
  }

  BudgetsCompanion toCompanion() {
    return BudgetsCompanion(
      category: Value(category),
      monthYear: Value(monthYear),
      limitAmount: Value(limitAmount),
      rolloverEnabled: Value(rolloverEnabled),
      updatedAt: Value(DateTime.now()),
    );
  }

  BudgetModel copyWith({
    double? limitAmount,
    double? spentAmount,
    bool? rolloverEnabled,
  }) {
    return BudgetModel(
      category: category,
      monthYear: monthYear,
      limitAmount: limitAmount ?? this.limitAmount,
      spentAmount: spentAmount ?? this.spentAmount,
      rolloverEnabled: rolloverEnabled ?? this.rolloverEnabled,
    );
  }

  // Value equality by (category, monthYear) -- its composite primary key --
  // not the default identity equality. getBudgets() builds brand-new
  // BudgetModel instances on every call (spentAmount is always recomputed),
  // and the envelope-transfer dropdown holds a selected BudgetModel that
  // must stay "==" to something in a possibly-rebuilt items list, or
  // Flutter throws "There should be exactly one item with [DropdownButton]'s
  // value".
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BudgetModel &&
          other.category == category &&
          other.monthYear == monthYear);

  @override
  int get hashCode => Object.hash(category, monthYear);
}

class BudgetRepository {
  final Ref _ref;
  BudgetRepository(this._ref);

  AppDatabase get _db => AppDatabase.instance;

  /// Returns [monthYear]'s budgets (defaults to the current month) with
  /// spentAmount derived live from real transactions. If no rows exist yet
  /// for the *current* month but the previous month has some, lazily
  /// carries the limits forward -- the client-side half of "budgets reset
  /// on the 1st": the limit persists across months, and spent naturally
  /// starts at zero because a new month has no transactions yet, with no
  /// explicit reset write needed for that part at all. Carry-forward is
  /// only attempted for the current month (not arbitrary past months
  /// requested for history) so viewing history never mutates data.
  Future<List<BudgetModel>> getBudgets({String? monthYear}) async {
    final isCurrentMonth = monthYear == null;
    final targetMonth = monthYear ?? monthKeyOf(DateTime.now());

    var limits = await _getLimits(targetMonth);
    if (limits.isEmpty && isCurrentMonth) {
      limits = await _carryForwardFromPreviousMonth(targetMonth);
    }
    if (limits.isEmpty) return [];

    final transactions = await _ref
        .read(transactionRepositoryProvider)
        .getTransactions();
    final spentByCategory = <String, double>{};
    for (final tx in transactions) {
      if (tx.bucket == BudgetBucket.income)
        continue; // budgets track spending, not income
      if (monthKeyOf(tx.date) != targetMonth) continue;
      spentByCategory[tx.category] =
          (spentByCategory[tx.category] ?? 0) + tx.amount;
    }

    return limits
        .map((b) => b.copyWith(spentAmount: spentByCategory[b.category] ?? 0.0))
        .toList();
  }

  /// All distinct months with at least one budget row, most recent first --
  /// backs the Monthly History view.
  Future<List<String>> getAvailableMonths() async {
    final user = _ref.read(authProvider);
    List<String> months;
    if (user == null || user.isGuest) {
      final rows =
          await (_db.selectOnly(_db.budgets)
                ..addColumns([_db.budgets.monthYear])
                ..where(_db.budgets.deletedAt.isNull())
                ..groupBy([_db.budgets.monthYear]))
              .get();
      months = rows.map((r) => r.read(_db.budgets.monthYear)!).toList();
    } else {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('budgets')
            .get();
        months = snapshot.docs
            .map((d) => d.data()['month_year'] as String)
            .toSet()
            .toList();
      } catch (e) {
        final rows =
            await (_db.selectOnly(_db.budgets)
                  ..addColumns([_db.budgets.monthYear])
                  ..where(_db.budgets.deletedAt.isNull())
                  ..groupBy([_db.budgets.monthYear]))
                .get();
        months = rows.map((r) => r.read(_db.budgets.monthYear)!).toList();
      }
    }
    months.sort((a, b) => b.compareTo(a));
    return months;
  }

  /// The salary/income figure entered for [monthYear] via the Salary-Based
  /// 50/30/20 Planner, or null if none has been saved yet. Local-only for
  /// guests, write-through (Firestore + local) for signed-in users, same
  /// pattern as every other per-month value in this repository.
  Future<double?> getMonthlyIncome(String monthYear) async {
    final user = _ref.read(authProvider);
    if (user == null || user.isGuest) {
      return _getLocalMonthlyIncome(monthYear);
    } else {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('monthlyIncome')
            .doc(monthYear)
            .get();
        if (doc.exists) {
          return (doc.data()?['salary_amount'] as num?)?.toDouble();
        }
        return _getLocalMonthlyIncome(monthYear);
      } catch (e) {
        return _getLocalMonthlyIncome(monthYear);
      }
    }
  }

  Future<double?> _getLocalMonthlyIncome(String monthYear) async {
    final row = await (_db.select(
      _db.monthlyIncome,
    )..where((t) => t.monthYear.equals(monthYear))).getSingleOrNull();
    return row?.salaryAmount;
  }

  Future<void> setMonthlyIncome(String monthYear, double amount) async {
    final user = _ref.read(authProvider);
    if (user == null || user.isGuest) {
      await _setLocalMonthlyIncome(monthYear, amount);
    } else {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('monthlyIncome')
            .doc(monthYear)
            .set({'month_year': monthYear, 'salary_amount': amount});
        await _setLocalMonthlyIncome(monthYear, amount);
      } catch (e) {
        await _setLocalMonthlyIncome(monthYear, amount);
      }
    }
  }

  Future<void> _setLocalMonthlyIncome(String monthYear, double amount) async {
    await _db
        .into(_db.monthlyIncome)
        .insertOnConflictUpdate(
          MonthlyIncomeCompanion.insert(
            monthYear: monthYear,
            salaryAmount: amount,
          ),
        );
  }

  Future<List<BudgetModel>> _getLimits(String monthYear) async {
    final user = _ref.read(authProvider);
    if (user == null || user.isGuest) {
      return _getLocalLimits(monthYear);
    } else {
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('budgets')
            .where('month_year', isEqualTo: monthYear)
            .get();
        return querySnapshot.docs
            .map((doc) => BudgetModel.fromMap(doc.data()))
            .toList();
      } catch (e) {
        return _getLocalLimits(monthYear);
      }
    }
  }

  Future<List<BudgetModel>> _getLocalLimits(String monthYear) async {
    final rows =
        await (_db.select(_db.budgets)..where(
              (t) => t.deletedAt.isNull() & t.monthYear.equals(monthYear),
            ))
            .get();
    return rows.map(BudgetModel.fromRow).toList();
  }

  Future<List<BudgetModel>> _carryForwardFromPreviousMonth(
    String targetMonth,
  ) async {
    final prevLimits = await _getLimits(_previousMonthKey(targetMonth));
    if (prevLimits.isEmpty) return [];

    final carried = <BudgetModel>[];
    for (final prev in prevLimits) {
      final budget = BudgetModel(
        category: prev.category,
        monthYear: targetMonth,
        // Rollover math (unspent carries into next month's limit) lands in
        // Phase 11 alongside real billing; for now the limit just repeats.
        limitAmount: prev.limitAmount,
        spentAmount: 0.0,
        rolloverEnabled: prev.rolloverEnabled,
      );
      await saveBudget(budget);
      carried.add(budget);
    }
    return carried;
  }

  String _previousMonthKey(String monthYear) {
    final parts = monthYear.split('-');
    var year = int.parse(parts[0]);
    var month = int.parse(parts[1]) - 1;
    if (month == 0) {
      month = 12;
      year -= 1;
    }
    return '$year-${month.toString().padLeft(2, '0')}';
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
            .doc('${budget.category}_${budget.monthYear}')
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

  Future<void> deleteBudget(String category, String monthYear) async {
    final user = _ref.read(authProvider);
    if (user == null || user.isGuest) {
      await _deleteLocal(category, monthYear);
    } else {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('budgets')
            .doc('${category}_$monthYear')
            .delete();
        await _deleteLocal(category, monthYear);
      } catch (e) {
        await _deleteLocal(category, monthYear);
      }
    }
  }

  Future<void> _deleteLocal(String category, String monthYear) async {
    await (_db.delete(_db.budgets)..where(
          (t) => t.category.equals(category) & t.monthYear.equals(monthYear),
        ))
        .go();
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

  Future<void> setLimit(
    String category,
    double limit,
    String monthYear, {
    bool rolloverEnabled = false,
  }) async {
    final budget = BudgetModel(
      category: category,
      monthYear: monthYear,
      limitAmount: limit,
      spentAmount: 0.0,
      rolloverEnabled: rolloverEnabled,
    );
    await _repo.saveBudget(budget);
    await refresh();
  }

  Future<void> remove(String category, String monthYear) async {
    await _repo.deleteBudget(category, monthYear);
    await refresh();
  }
}

final budgetListProvider =
    StateNotifierProvider<BudgetListNotifier, AsyncValue<List<BudgetModel>>>((
      ref,
    ) {
      final repo = ref.watch(budgetRepositoryProvider);
      return BudgetListNotifier(repo);
    });
