import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../../../transactions/presentation/providers/category_provider.dart';
import '../../../transactions/domain/models/transaction_model.dart';
import '../../../transactions/domain/models/category_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/local/local_database.dart';

String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

// ── Monthly spending trend (last 6 months) ────────────────────────────────
class MonthlyTrend {
  final String monthKey;
  final double income;
  final double expense;
  final double savings;

  const MonthlyTrend({
    required this.monthKey,
    required this.income,
    required this.expense,
    required this.savings,
  });
}

final monthlyTrendProvider =
    FutureProvider<List<MonthlyTrend>>((ref) async {
  final isGuest = ref.watch(guestSessionProvider);
  if (isGuest) {
    final db = LocalDatabase.instance;
    final allRows = await db.getAll('transactions');
    final allTransactions = allRows.map(TransactionModel.fromLocalMap).toList();
    final months = DateFormatter.lastNMonths(6);
    final List<MonthlyTrend> trends = [];
    for (final month in months) {
      final start = DateFormatter.startOfMonth(month);
      final end = DateFormatter.endOfMonth(month);
      double income = 0, expense = 0;
      for (final t in allTransactions) {
        if (!t.date.isBefore(start) && !t.date.isAfter(end)) {
          if (t.type == TransactionType.credit) {
            income += t.amount;
          } else {
            expense += t.amount;
          }
        }
      }
      trends.add(MonthlyTrend(
        monthKey: DateFormatter.firestoreMonthKey(month),
        income: income,
        expense: expense,
        savings: income - expense,
      ));
    }
    return trends;
  }

  if (_uid.isEmpty) return [];

  final months = DateFormatter.lastNMonths(6);
  final List<MonthlyTrend> trends = [];

  for (final month in months) {
    final start = DateFormatter.startOfMonth(month);
    final end = DateFormatter.endOfMonth(month);

    final snap = await FirebaseFirestore.instance
        .collection(AppConstants.colUsers)
        .doc(_uid)
        .collection(AppConstants.colTransactions)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    double income = 0, expense = 0;
    for (final doc in snap.docs) {
      final t = TransactionModel.fromFirestore(doc);
      if (t.type == TransactionType.credit) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }

    trends.add(MonthlyTrend(
      monthKey: DateFormatter.firestoreMonthKey(month),
      income: income,
      expense: expense,
      savings: income - expense,
    ));
  }

  return trends;
});

// ── Category Breakdown (current month) ───────────────────────────────────
class CategoryBreakdown {
  final CategoryModel category;
  final double amount;
  final int count;
  final double percent;

  const CategoryBreakdown({
    required this.category,
    required this.amount,
    required this.count,
    required this.percent,
  });
}

final categoryBreakdownProvider =
    Provider<AsyncValue<List<CategoryBreakdown>>>((ref) {
  final allCategories = ref.watch(allCategoriesProvider);
  return ref.watch(monthlySummaryProvider).when(
        data: (summary) {
          final total = summary.totalExpense;
          final entries = summary.byCategory.entries
              .map((e) => CategoryBreakdown(
                    category: allCategories.firstWhere(
                      (c) => c.id == e.key,
                      orElse: () => CategoryModel.byId(e.key),
                    ),
                    amount: e.value,
                    count: 1,
                    percent: total > 0 ? (e.value / total * 100) : 0,
                    ),
                  )
              .toList()
            ..sort((a, b) => b.amount.compareTo(a.amount));
          return AsyncValue.data(entries);
        },
        loading: () => const AsyncValue.loading(),
        error: (e, s) => AsyncValue.error(e, s),
      );
});

enum AnalyticsTimeframe { lastMonth, last6Months, lastYear }

final categoryTimeframeExpensesProvider = FutureProvider.family<List<CategoryBreakdown>, AnalyticsTimeframe>((ref, timeframe) async {
  final isGuest = ref.watch(guestSessionProvider);
  final allCategories = ref.watch(allCategoriesProvider);
  final now = DateTime.now();
  
  DateTime startDate;
  DateTime endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
  
  switch (timeframe) {
    case AnalyticsTimeframe.lastMonth:
      // Start of previous month to end of previous month
      startDate = DateTime(now.year, now.month - 1, 1);
      endDate = DateTime(now.year, now.month, 0, 23, 59, 59);
      break;
    case AnalyticsTimeframe.last6Months:
      // Start of 6 months ago to now
      startDate = DateTime(now.year, now.month - 5, 1);
      break;
    case AnalyticsTimeframe.lastYear:
      // Start of 12 months ago to now
      startDate = DateTime(now.year, now.month - 11, 1);
      break;
  }

  List<TransactionModel> transactions = [];

  if (isGuest) {
    final db = LocalDatabase.instance;
    final allRows = await db.getAll('transactions');
    transactions = allRows
        .map(TransactionModel.fromLocalMap)
        .where((t) => t.type == TransactionType.debit && !t.date.isBefore(startDate) && !t.date.isAfter(endDate))
        .toList();
  } else {
    final snap = await FirebaseFirestore.instance
        .collection(AppConstants.colUsers)
        .doc(_uid)
        .collection(AppConstants.colTransactions)
        .where('type', isEqualTo: TransactionType.debit.name)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();
    transactions = snap.docs.map((doc) => TransactionModel.fromFirestore(doc)).toList();
  }

  // Group by categoryId
  final Map<String, double> byCategory = {};
  final Map<String, int> countByCategory = {};
  double totalExpense = 0;

  for (final t in transactions) {
    byCategory[t.categoryId] = (byCategory[t.categoryId] ?? 0) + t.amount;
    countByCategory[t.categoryId] = (countByCategory[t.categoryId] ?? 0) + 1;
    totalExpense += t.amount;
  }

  final List<CategoryBreakdown> list = [];
  for (final entry in byCategory.entries) {
    final cat = allCategories.firstWhere(
      (c) => c.id == entry.key,
      orElse: () => CategoryModel.byId(entry.key),
    );
    list.add(CategoryBreakdown(
      category: cat,
      amount: entry.value,
      count: countByCategory[entry.key] ?? 1,
      percent: totalExpense > 0 ? (entry.value / totalExpense) * 100 : 0,
    ));
  }

  list.sort((a, b) => b.amount.compareTo(a.amount));
  return list;
});

// ── 50/30/20 Compliance History ───────────────────────────────────────────
class BucketCompliance {
  final String monthKey;
  final double needsPercent;
  final double wantsPercent;
  final double savingsPercent;

  const BucketCompliance({
    required this.monthKey,
    required this.needsPercent,
    required this.wantsPercent,
    required this.savingsPercent,
  });
}

final bucketComplianceHistoryProvider =
    FutureProvider<List<BucketCompliance>>((ref) async {
  // Returns empty — full implementation queries monthly snapshots
  // In production, store monthly summaries in Firestore when month closes
  return const [];
});

// ── Year-to-Date Stats ────────────────────────────────────────────────────
class YtdStats {
  final double totalIncome;
  final double totalExpense;
  final double totalSavings;
  final double avgMonthlyExpense;

  const YtdStats({
    required this.totalIncome,
    required this.totalExpense,
    required this.totalSavings,
    required this.avgMonthlyExpense,
  });
}

final ytdStatsProvider = FutureProvider<YtdStats>((ref) async {
  final now = DateTime.now();
  final isGuest = ref.watch(guestSessionProvider);

  if (isGuest) {
    final db = LocalDatabase.instance;
    final allRows = await db.getAll('transactions');
    final yearStart = DateTime(now.year, 1, 1);
    double income = 0, expense = 0;
    for (final row in allRows) {
      final t = TransactionModel.fromLocalMap(row);
      if (t.date.isBefore(yearStart)) continue;
      if (t.type == TransactionType.credit) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    final months = now.month;
    return YtdStats(
      totalIncome: income,
      totalExpense: expense,
      totalSavings: income - expense,
      avgMonthlyExpense: months > 0 ? expense / months : 0,
    );
  }

  if (_uid.isEmpty) {
    return const YtdStats(
        totalIncome: 0,
        totalExpense: 0,
        totalSavings: 0,
        avgMonthlyExpense: 0);
  }
  final yearStart = DateTime(now.year, 1, 1);

  final snap = await FirebaseFirestore.instance
      .collection(AppConstants.colUsers)
      .doc(_uid)
      .collection(AppConstants.colTransactions)
      .where('date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(yearStart))
      .get();

  double income = 0, expense = 0;
  for (final doc in snap.docs) {
    final t = TransactionModel.fromFirestore(doc);
    if (t.type == TransactionType.credit) {
      income += t.amount;
    } else {
      expense += t.amount;
    }
  }

  final months = now.month;
  return YtdStats(
    totalIncome: income,
    totalExpense: expense,
    totalSavings: income - expense,
    avgMonthlyExpense: months > 0 ? expense / months : 0,
  );
});
