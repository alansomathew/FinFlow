import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../savings/presentation/providers/savings_provider.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../savings/domain/models/savings_goal_model.dart';

class SavingsGoalsWidget extends ConsumerWidget {
  const SavingsGoalsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(savingsGoalsStreamProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Savings Goals',
            onSeeAll: () => context.push('/savings'),
          ),
          const SizedBox(height: 8),
          goalsAsync.when(
            data: (goals) {
              if (goals.isEmpty) {
                return const EmptyStateWidget(
                    message: 'No savings goals yet. Start one!');
              }
              final topGoals = goals.take(2).toList();
              return Column(
                children: topGoals
                    .map((g) => _GoalTile(goal: g))
                    .toList(),
              );
            },
            loading: () => const ShimmerCard(height: 100),
            error: (_, __) =>
                const EmptyStateWidget(message: 'Error loading goals'),
          ),
        ],
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  final SavingsGoalModel goal;

  const _GoalTile({required this.goal});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(goal.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(goal.name, style: AppTextStyles.bodyMedium),
              ),
              Text(
                '${goal.progressPercent.toStringAsFixed(0)}%',
                style: AppTextStyles.labelMedium
                    .copyWith(color: goal.color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: goal.progressPercent / 100,
              backgroundColor: AppColors.surfaceElevated,
              valueColor: AlwaysStoppedAnimation<Color>(goal.color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                CurrencyFormatter.formatCompact(goal.currentAmount),
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
              Text(
                CurrencyFormatter.formatCompact(goal.targetAmount),
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
