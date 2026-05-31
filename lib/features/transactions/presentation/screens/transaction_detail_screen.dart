import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../../domain/models/transaction_model.dart';
import '../../../../features/accounts/presentation/providers/account_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/common_widgets.dart';

class TransactionDetailScreen extends ConsumerWidget {
  final String transactionId;

  const TransactionDetailScreen(
      {super.key, required this.transactionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = TransactionFilter();
    final txAsync = ref.watch(transactionsStreamProvider(filter));

    return txAsync.when(
      data: (transactions) {
        final tx = transactions
            .cast<TransactionModel?>()
            .firstWhere((t) => t?.id == transactionId,
                orElse: () => null);
        if (tx == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Not Found')),
            body: const Center(child: Text('Transaction not found')),
          );
        }
        return _TransactionDetailView(tx: tx);
      },
      loading: () => Scaffold(
        appBar: AppBar(
            backgroundColor: AppColors.background, elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('$e')),
      ),
    );
  }
}

class _TransactionDetailView extends ConsumerWidget {
  final TransactionModel tx;

  const _TransactionDetailView({required this.tx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cat = ref.watch(categoryByIdProvider(tx.categoryId));
    final accountAsync = ref.watch(accountByIdProvider(tx.accountId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Transaction', style: AppTextStyles.headlineMedium),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () {
              context.push('/add-transaction',
                  extra: {'transactionId': tx.id});
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.expenseRed),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Amount + Category header
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: cat.color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(cat.emoji,
                        style: const TextStyle(fontSize: 34)),
                  ),
                ),
                const SizedBox(height: 12),
                AmountText(
                  amount: tx.amount,
                  isExpense: tx.type == TransactionType.debit,
                  style: AppTextStyles.amountLarge,
                ),
                const SizedBox(height: 4),
                Text(tx.payee ?? '—', style: AppTextStyles.headlineMedium),
                const SizedBox(height: 4),
                CategoryChip(label: cat.name, emoji: cat.emoji, color: cat.color),
              ],
            ),
          ),
          const SizedBox(height: 28),
          AppCard(
            child: Column(
              children: [
                InfoRow(
                  label: 'Date',
                  value: DateFormatter.displayDateTime(tx.date),
                ),
                const Divider(color: AppColors.border, height: 1),
                accountAsync.when(
                  data: (acc) => InfoRow(
                    label: 'Account',
                    value: acc != null
                        ? '${acc.emoji} ${acc.name}'
                        : '—',
                  ),
                  loading: () => const InfoRow(
                      label: 'Account', value: '...'),
                  error: (_, __) =>
                      const InfoRow(label: 'Account', value: '—'),
                ),
                if (tx.note != null &&
                    tx.note!.trim().isNotEmpty) ...[
                  const Divider(color: AppColors.border, height: 1),
                  InfoRow(label: 'Notes', value: tx.note!),
                ],
                if (tx.source == TransactionSource.sms) ...[
                  const Divider(color: AppColors.border, height: 1),
                  const InfoRow(
                    label: 'Source',
                    value: '📱 Auto-imported via SMS',
                  ),
                ],
                if (tx.source == TransactionSource.recurring) ...[
                  const Divider(color: AppColors.border, height: 1),
                  const InfoRow(label: 'Source', value: '🔁 Recurring'),
                ],
              ],
            ),
          ),
          if (tx.splits != null && tx.splits!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Split Details', style: AppTextStyles.labelLarge),
            const SizedBox(height: 8),
            AppCard(
              child: Column(
                children: tx.splits!
                    .map((s) => Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(s.categoryId,
                                  style: AppTextStyles.bodySmall),
                              Text(
                                CurrencyFormatter.format(s.amount),
                                style: AppTextStyles.labelSmall,
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Transaction'),
        content:
            const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.expenseRed)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(transactionNotifierProvider.notifier)
          .deleteTransaction(tx.id);
      if (context.mounted) context.pop();
    }
  }
}
