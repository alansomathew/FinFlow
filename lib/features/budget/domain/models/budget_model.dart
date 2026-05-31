import 'package:cloud_firestore/cloud_firestore.dart';

class BudgetCategory {
  final String categoryId;
  final double allocated;
  final double spent;

  const BudgetCategory({
    required this.categoryId,
    required this.allocated,
    this.spent = 0,
  });

  double get remaining => allocated - spent;
  double get usagePercent => allocated > 0 ? (spent / allocated) * 100 : 0;
  bool get isOverBudget => spent > allocated;
  bool get isAtWarning => usagePercent >= 80 && !isOverBudget;

  factory BudgetCategory.fromMap(Map<String, dynamic> m) => BudgetCategory(
        categoryId: m['categoryId'] ?? '',
        allocated: (m['allocated'] as num?)?.toDouble() ?? 0,
        spent: (m['spent'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'categoryId': categoryId,
        'allocated': allocated,
        'spent': spent,
      };

  BudgetCategory copyWith({double? allocated, double? spent}) => BudgetCategory(
        categoryId: categoryId,
        allocated: allocated ?? this.allocated,
        spent: spent ?? this.spent,
      );
}

class BudgetModel {
  final String id;
  final String userId;
  final String monthKey; // e.g., "2025-01"
  final double monthlyIncome;
  final double needsAllocated;
  final double wantsAllocated;
  final double savingsAllocated;
  final List<BudgetCategory> categories;
  final bool rolloverEnabled;
  final DateTime resetDate;
  final DateTime createdAt;

  const BudgetModel({
    required this.id,
    required this.userId,
    required this.monthKey,
    required this.monthlyIncome,
    required this.needsAllocated,
    required this.wantsAllocated,
    required this.savingsAllocated,
    required this.categories,
    this.rolloverEnabled = false,
    required this.resetDate,
    required this.createdAt,
  });

  double get totalAllocated =>
      needsAllocated + wantsAllocated + savingsAllocated;

  double get totalSpent =>
      categories.fold(0, (sum, c) => sum + c.spent);

  double get totalRemaining => totalAllocated - totalSpent;

  /// Auto-calculate 50/30/20 budget from income
  factory BudgetModel.from5030_20({
    required String userId,
    required String monthKey,
    required double income,
    required DateTime resetDate,
  }) {
    return BudgetModel(
      id: monthKey,
      userId: userId,
      monthKey: monthKey,
      monthlyIncome: income,
      needsAllocated: income * 0.5,
      wantsAllocated: income * 0.3,
      savingsAllocated: income * 0.2,
      categories: const [],
      resetDate: resetDate,
      createdAt: DateTime.now(),
    );
  }

  factory BudgetModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return BudgetModel(
      id: doc.id,
      userId: d['userId'] ?? '',
      monthKey: d['monthKey'] ?? '',
      monthlyIncome: (d['monthlyIncome'] as num?)?.toDouble() ?? 0,
      needsAllocated: (d['needsAllocated'] as num?)?.toDouble() ?? 0,
      wantsAllocated: (d['wantsAllocated'] as num?)?.toDouble() ?? 0,
      savingsAllocated: (d['savingsAllocated'] as num?)?.toDouble() ?? 0,
      categories: (d['categories'] as List? ?? [])
          .map((e) => BudgetCategory.fromMap(e as Map<String, dynamic>))
          .toList(),
      rolloverEnabled: d['rolloverEnabled'] ?? false,
      resetDate: (d['resetDate'] as Timestamp).toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'monthKey': monthKey,
        'monthlyIncome': monthlyIncome,
        'needsAllocated': needsAllocated,
        'wantsAllocated': wantsAllocated,
        'savingsAllocated': savingsAllocated,
        'categories': categories.map((c) => c.toMap()).toList(),
        'rolloverEnabled': rolloverEnabled,
        'resetDate': Timestamp.fromDate(resetDate),
        'createdAt': Timestamp.fromDate(createdAt),
      };

  Map<String, dynamic> toLocalMap() => {
        'id': id,
        'userId': userId,
        'monthKey': monthKey,
        'monthlyIncome': monthlyIncome,
        'needsAllocated': needsAllocated,
        'wantsAllocated': wantsAllocated,
        'savingsAllocated': savingsAllocated,
        'categories': categories.map((c) => c.toMap()).toList(),
        'rolloverEnabled': rolloverEnabled ? 1 : 0,
        'resetDate': resetDate.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory BudgetModel.fromLocalMap(Map<String, dynamic> d) => BudgetModel(
        id: d['id'] as String,
        userId: d['userId'] as String? ?? '',
        monthKey: d['monthKey'] as String,
        monthlyIncome: (d['monthlyIncome'] as num?)?.toDouble() ?? 0,
        needsAllocated: (d['needsAllocated'] as num?)?.toDouble() ?? 0,
        wantsAllocated: (d['wantsAllocated'] as num?)?.toDouble() ?? 0,
        savingsAllocated: (d['savingsAllocated'] as num?)?.toDouble() ?? 0,
        categories: (d['categories'] as List? ?? [])
            .map((e) => BudgetCategory.fromMap(e as Map<String, dynamic>))
            .toList(),
        rolloverEnabled: (d['rolloverEnabled'] == 1 || d['rolloverEnabled'] == true),
        resetDate: DateTime.parse(d['resetDate'] as String),
        createdAt: DateTime.parse(d['createdAt'] as String),
      );

  BudgetModel copyWith({
    double? needsAllocated,
    double? wantsAllocated,
    double? savingsAllocated,
    List<BudgetCategory>? categories,
    bool? rolloverEnabled,
  }) =>
      BudgetModel(
        id: id,
        userId: userId,
        monthKey: monthKey,
        monthlyIncome: monthlyIncome,
        needsAllocated: needsAllocated ?? this.needsAllocated,
        wantsAllocated: wantsAllocated ?? this.wantsAllocated,
        savingsAllocated: savingsAllocated ?? this.savingsAllocated,
        categories: categories ?? this.categories,
        rolloverEnabled: rolloverEnabled ?? this.rolloverEnabled,
        resetDate: resetDate,
        createdAt: createdAt,
      );
}
