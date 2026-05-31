import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

enum GoalCategory {
  emergency,
  vacation,
  gadget,
  education,
  wedding,
  downPayment,
  custom,
}

enum ContributionMode { manual, autoMonthly, roundUp }

class SavingsGoalModel {
  final String id;
  final String userId;
  final String name;
  final GoalCategory category;
  final double targetAmount;
  final double currentAmount;
  final DateTime targetDate;
  final String? linkedAccountId;
  final Color color;
  final String emoji;
  final ContributionMode contributionMode;
  final double? monthlyContribution;
  final bool isPaused;
  final bool isCompleted;
  final DateTime createdAt;

  const SavingsGoalModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.targetAmount,
    this.currentAmount = 0,
    required this.targetDate,
    this.linkedAccountId,
    required this.color,
    required this.emoji,
    this.contributionMode = ContributionMode.manual,
    this.monthlyContribution,
    this.isPaused = false,
    this.isCompleted = false,
    required this.createdAt,
  });

  double get progressPercent =>
      targetAmount > 0 ? (currentAmount / targetAmount * 100).clamp(0, 100) : 0;

  double get remaining => targetAmount - currentAmount;

  int get daysRemaining {
    final now = DateTime.now();
    return targetDate.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  double get requiredMonthlyContribution {
    if (daysRemaining <= 0) return remaining;
    final months = (daysRemaining / 30).ceil();
    return months > 0 ? remaining / months : remaining;
  }

  bool get isMilestone25 => progressPercent >= 25 && progressPercent < 50;
  bool get isMilestone50 => progressPercent >= 50 && progressPercent < 75;
  bool get isMilestone75 => progressPercent >= 75 && progressPercent < 100;
  bool get isMilestone100 => progressPercent >= 100;

  String get categoryLabel {
    switch (category) {
      case GoalCategory.emergency:
        return 'Emergency Fund';
      case GoalCategory.vacation:
        return 'Vacation';
      case GoalCategory.gadget:
        return 'Gadget';
      case GoalCategory.education:
        return 'Education';
      case GoalCategory.wedding:
        return 'Wedding';
      case GoalCategory.downPayment:
        return 'Down Payment';
      case GoalCategory.custom:
        return 'Custom Goal';
    }
  }

  factory SavingsGoalModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SavingsGoalModel(
      id: doc.id,
      userId: d['userId'] ?? '',
      name: d['name'] ?? '',
      category: GoalCategory.values.firstWhere(
        (g) => g.name == d['category'],
        orElse: () => GoalCategory.custom,
      ),
      targetAmount: (d['targetAmount'] as num).toDouble(),
      currentAmount: (d['currentAmount'] as num?)?.toDouble() ?? 0,
      targetDate: (d['targetDate'] as Timestamp).toDate(),
      linkedAccountId: d['linkedAccountId'],
      color: Color(d['colorValue'] ?? AppColors.accent.value),
      emoji: d['emoji'] ?? '🎯',
      contributionMode: ContributionMode.values.firstWhere(
        (m) => m.name == d['contributionMode'],
        orElse: () => ContributionMode.manual,
      ),
      monthlyContribution: (d['monthlyContribution'] as num?)?.toDouble(),
      isPaused: d['isPaused'] ?? false,
      isCompleted: d['isCompleted'] ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'name': name,
        'category': category.name,
        'targetAmount': targetAmount,
        'currentAmount': currentAmount,
        'targetDate': Timestamp.fromDate(targetDate),
        'linkedAccountId': linkedAccountId,
        'colorValue': color.value,
        'emoji': emoji,
        'contributionMode': contributionMode.name,
        'monthlyContribution': monthlyContribution,
        'isPaused': isPaused,
        'isCompleted': isCompleted,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  Map<String, dynamic> toLocalMap() => {
        'id': id,
        'userId': userId,
        'name': name,
        'category': category.name,
        'targetAmount': targetAmount,
        'currentAmount': currentAmount,
        'targetDate': targetDate.toIso8601String(),
        'linkedAccountId': linkedAccountId,
        'colorValue': color.value,
        'emoji': emoji,
        'contributionMode': contributionMode.name,
        'monthlyContribution': monthlyContribution,
        'isPaused': isPaused ? 1 : 0,
        'isCompleted': isCompleted ? 1 : 0,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SavingsGoalModel.fromLocalMap(Map<String, dynamic> d) =>
      SavingsGoalModel(
        id: d['id'] as String,
        userId: d['userId'] as String? ?? '',
        name: d['name'] as String,
        category: GoalCategory.values.firstWhere(
          (g) => g.name == d['category'],
          orElse: () => GoalCategory.custom,
        ),
        targetAmount: (d['targetAmount'] as num).toDouble(),
        currentAmount: (d['currentAmount'] as num?)?.toDouble() ?? 0,
        targetDate: DateTime.parse(d['targetDate'] as String),
        linkedAccountId: d['linkedAccountId'] as String?,
        color: Color(d['colorValue'] as int? ?? AppColors.accent.value),
        emoji: d['emoji'] as String? ?? '🎯',
        contributionMode: ContributionMode.values.firstWhere(
          (m) => m.name == d['contributionMode'],
          orElse: () => ContributionMode.manual,
        ),
        monthlyContribution: (d['monthlyContribution'] as num?)?.toDouble(),
        isPaused: (d['isPaused'] == 1 || d['isPaused'] == true),
        isCompleted: (d['isCompleted'] == 1 || d['isCompleted'] == true),
        createdAt: DateTime.parse(d['createdAt'] as String),
      );

  SavingsGoalModel copyWith({
    double? currentAmount,
    bool? isPaused,
    bool? isCompleted,
  }) =>
      SavingsGoalModel(
        id: id,
        userId: userId,
        name: name,
        category: category,
        targetAmount: targetAmount,
        currentAmount: currentAmount ?? this.currentAmount,
        targetDate: targetDate,
        linkedAccountId: linkedAccountId,
        color: color,
        emoji: emoji,
        contributionMode: contributionMode,
        monthlyContribution: monthlyContribution,
        isPaused: isPaused ?? this.isPaused,
        isCompleted: isCompleted ?? this.isCompleted,
        createdAt: createdAt,
      );
}
