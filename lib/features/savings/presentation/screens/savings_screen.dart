import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/savings_provider.dart';
import '../../domain/models/savings_goal_model.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/common_widgets.dart';

class SavingsScreen extends ConsumerWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(savingsGoalsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Savings Goals',
            style: AppTextStyles.headlineMedium),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: goalsAsync.when(
        data: (goals) {
          if (goals.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🎯',
                      style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  Text('No Goals Yet',
                      style: AppTextStyles.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Create a savings goal to track your progress',
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  GradientButton(
                    label: 'Create Goal',
                    onTap: () => context.push('/add-goal'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: goals.length,
            itemBuilder: (_, i) => _GoalCard(goal: goals[i]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child:
                Text('Error: $e', style: AppTextStyles.bodyMedium)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-goal'),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _GoalCard extends ConsumerWidget {
  final SavingsGoalModel goal;

  const _GoalCard({required this.goal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: goal.isMilestone100
            ? Border.all(color: AppColors.savingsColor, width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(goal.emoji,
                  style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.name,
                        style: AppTextStyles.bodyMedium),
                    Text(
                      '${goal.daysRemaining} days remaining',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (goal.isPaused)
                const Icon(Icons.pause_circle_outline,
                    color: AppColors.textSecondary),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'add') {
                    _showContributeSheet(context, ref, goal);
                  } else if (v == 'pause') {
                    await ref
                        .read(savingsNotifierProvider.notifier)
                        .togglePause(goal.id, !goal.isPaused);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'add',
                    child: Row(
                      children: [
                        const Icon(Icons.add_circle_outline,
                            size: 16),
                        const SizedBox(width: 8),
                        const Text('Add Money'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'pause',
                    child: Row(
                      children: [
                        Icon(
                          goal.isPaused
                              ? Icons.play_circle_outline
                              : Icons.pause_circle_outline,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(goal.isPaused ? 'Resume' : 'Pause'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                CurrencyFormatter.format(goal.currentAmount),
                style: AppTextStyles.amountSmall
                    .copyWith(color: goal.color),
              ),
              Text(
                CurrencyFormatter.format(goal.targetAmount),
                style: AppTextStyles.amountSmall.copyWith(
                    color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: goal.progressPercent / 100,
              backgroundColor: AppColors.surfaceElevated,
              valueColor:
                  AlwaysStoppedAnimation<Color>(goal.color),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Need ${CurrencyFormatter.formatCompact(goal.requiredMonthlyContribution)}/month',
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  void _showContributeSheet(
      BuildContext ctx, WidgetRef ref, SavingsGoalModel goal) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add to ${goal.name}',
                style: AppTextStyles.headlineMedium),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 24),
            GradientButton(
              label: 'Add Contribution',
              onTap: () async {
                final amount = double.tryParse(
                    controller.text.replaceAll(',', ''));
                if (amount != null && amount > 0) {
                  await ref
                      .read(savingsNotifierProvider.notifier)
                      .addContribution(goal.id, amount);
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
