import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../transactions/domain/models/transaction_model.dart';
import '../../../transactions/domain/models/category_model.dart';

class RecentTransactionsWidget extends ConsumerWidget {
  const RecentTransactionsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentTransactionsProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Recent Transactions',
            onSeeAll: () => context.go('/transactions'),
          ),
          const SizedBox(height: 8),
          recentAsync.when(
            data: (transactions) {
              if (transactions.isEmpty) {
                return const EmptyStateWidget(
                  message: 'No transactions yet.\nTap + to add one.',
                );
              }
              return Column(
                children: transactions
                    .map((t) => _TransactionTile(transaction: t))
                    .toList(),
              );
            },
            loading: () => Column(
              children: List.generate(
                  3, (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: ShimmerCard(height: 56),
                  )),
            ),
            error: (_, __) =>
                const EmptyStateWidget(message: 'Error loading transactions'),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final TransactionModel transaction;

  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final category = CategoryModel.byId(transaction.categoryId);
    final isCredit = transaction.type == TransactionType.credit;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: category.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                category.emoji,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.payee ?? '—',
                  style: AppTextStyles.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  DateFormatter.relativeDate(transaction.date),
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          AmountText(
            amount: transaction.amount,
            isIncome: isCredit,
          ),
        ],
      ),
    );
  }
}
