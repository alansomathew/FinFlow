import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_colors.dart';

enum BudgetBucket { needs, wants, savings }
enum CategoryGroup { expense, income, investment }

class CategoryModel {
  final String id;
  final String name;
  final String emoji;
  final Color color;
  final BudgetBucket bucket;
  final CategoryGroup group;
  final bool isCustom;
  final bool isActive;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    required this.bucket,
    this.group = CategoryGroup.expense,
    this.isCustom = false,
    this.isActive = true,
  });

  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CategoryModel(
      id: doc.id,
      name: d['name'] ?? '',
      emoji: d['emoji'] ?? '💰',
      color: Color(d['colorValue'] ?? AppColors.catOther.value),
      bucket: BudgetBucket.values.firstWhere(
        (b) => b.name == d['bucket'],
        orElse: () => BudgetBucket.wants,
      ),
      group: CategoryGroup.values.firstWhere(
        (g) => g.name == d['group'],
        orElse: () => CategoryGroup.expense,
      ),
      isCustom: d['isCustom'] ?? false,
      isActive: d['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'emoji': emoji,
        'colorValue': color.value,
        'bucket': bucket.name,
        'group': group.name,
        'isCustom': isCustom,
        'isActive': isActive,
      };

  String get bucketLabel {
    switch (bucket) {
      case BudgetBucket.needs:
        return 'Needs';
      case BudgetBucket.wants:
        return 'Wants';
      case BudgetBucket.savings:
        return 'Savings';
    }
  }

  Color get bucketColor {
    switch (bucket) {
      case BudgetBucket.needs:
        return AppColors.needs;
      case BudgetBucket.wants:
        return AppColors.wants;
      case BudgetBucket.savings:
        return AppColors.savings;
    }
  }

  // ── Default Categories ─────────────────────────────────────────
  static const List<CategoryModel> defaults = [
    // NEEDS
    CategoryModel(
      id: 'food',
      name: 'Food & Dining',
      emoji: '🍽️',
      color: AppColors.catFood,
      bucket: BudgetBucket.needs,
    ),
    CategoryModel(
      id: 'transport',
      name: 'Transport',
      emoji: '🚗',
      color: AppColors.catTransport,
      bucket: BudgetBucket.needs,
    ),
    CategoryModel(
      id: 'groceries',
      name: 'Groceries',
      emoji: '🛒',
      color: Color(0xFF56C596),
      bucket: BudgetBucket.needs,
    ),
    CategoryModel(
      id: 'health',
      name: 'Health & Medical',
      emoji: '🏥',
      color: AppColors.catHealth,
      bucket: BudgetBucket.needs,
    ),
    CategoryModel(
      id: 'utilities',
      name: 'Utilities & Bills',
      emoji: '⚡',
      color: AppColors.catUtilities,
      bucket: BudgetBucket.needs,
    ),
    CategoryModel(
      id: 'rent',
      name: 'Rent & Housing',
      emoji: '🏠',
      color: Color(0xFF6A8FD8),
      bucket: BudgetBucket.needs,
    ),
    CategoryModel(
      id: 'emi',
      name: 'EMI & Loan',
      emoji: '🏦',
      color: AppColors.catEMI,
      bucket: BudgetBucket.needs,
    ),
    CategoryModel(
      id: 'insurance',
      name: 'Insurance',
      emoji: '🛡️',
      color: Color(0xFF5BA4CF),
      bucket: BudgetBucket.needs,
    ),
    // WANTS
    CategoryModel(
      id: 'shopping',
      name: 'Shopping',
      emoji: '🛍️',
      color: AppColors.catShopping,
      bucket: BudgetBucket.wants,
    ),
    CategoryModel(
      id: 'entertainment',
      name: 'Entertainment',
      emoji: '🎬',
      color: AppColors.catEntertainment,
      bucket: BudgetBucket.wants,
    ),
    CategoryModel(
      id: 'dining',
      name: 'Restaurants',
      emoji: '🍕',
      color: Color(0xFFFF7043),
      bucket: BudgetBucket.wants,
    ),
    CategoryModel(
      id: 'travel',
      name: 'Travel & Vacation',
      emoji: '✈️',
      color: Color(0xFF26A69A),
      bucket: BudgetBucket.wants,
    ),
    CategoryModel(
      id: 'subscriptions',
      name: 'Subscriptions',
      emoji: '📱',
      color: Color(0xFF7E57C2),
      bucket: BudgetBucket.wants,
    ),
    CategoryModel(
      id: 'fitness',
      name: 'Fitness & Sports',
      emoji: '💪',
      color: Color(0xFF29B6F6),
      bucket: BudgetBucket.wants,
    ),
    CategoryModel(
      id: 'beauty',
      name: 'Beauty & Personal Care',
      emoji: '💅',
      color: Color(0xFFEC407A),
      bucket: BudgetBucket.wants,
    ),
    CategoryModel(
      id: 'gifts',
      name: 'Gifts & Donations',
      emoji: '🎁',
      color: Color(0xFFAB47BC),
      bucket: BudgetBucket.wants,
    ),
    CategoryModel(
      id: 'education',
      name: 'Education',
      emoji: '📚',
      color: AppColors.catEducation,
      bucket: BudgetBucket.wants,
    ),
    // SAVINGS
    CategoryModel(
      id: 'investment',
      name: 'Investments',
      emoji: '📈',
      color: AppColors.catInvestment,
      bucket: BudgetBucket.savings,
      group: CategoryGroup.investment,
    ),
    CategoryModel(
      id: 'savings_goal',
      name: 'Savings Goal',
      emoji: '🎯',
      color: AppColors.accent,
      bucket: BudgetBucket.savings,
    ),
    CategoryModel(
      id: 'emergency',
      name: 'Emergency Fund',
      emoji: '🔐',
      color: Color(0xFF66BB6A),
      bucket: BudgetBucket.savings,
    ),
    // INCOME
    CategoryModel(
      id: 'salary',
      name: 'Salary',
      emoji: '💼',
      color: AppColors.income,
      bucket: BudgetBucket.needs,
      group: CategoryGroup.income,
    ),
    CategoryModel(
      id: 'freelance',
      name: 'Freelance / Business',
      emoji: '💻',
      color: Color(0xFF4DB6AC),
      bucket: BudgetBucket.needs,
      group: CategoryGroup.income,
    ),
    CategoryModel(
      id: 'dividend',
      name: 'Dividend / Returns',
      emoji: '💹',
      color: Color(0xFF81C784),
      bucket: BudgetBucket.savings,
      group: CategoryGroup.income,
    ),
    CategoryModel(
      id: 'other',
      name: 'Other',
      emoji: '📋',
      color: AppColors.catOther,
      bucket: BudgetBucket.wants,
    ),
  ];

  static CategoryModel byId(String id) {
    return defaults.firstWhere(
      (c) => c.id == id,
      orElse: () => defaults.last,
    );
  }
}
