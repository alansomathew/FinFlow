import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_sizes.dart';
import '../../accounts/data/accounts_repository.dart';
import '../data/transaction_repository.dart';
import '../domain/transaction.dart';
import 'transaction_form_sheet.dart';

class TransactionDetailScreen extends ConsumerWidget {
  final TransactionModel transaction;
  const TransactionDetailScreen({super.key, required this.transaction});

  void _edit(BuildContext context, TransactionModel current) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransactionFormSheet(existing: current),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    TransactionModel current,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        title: const Text(
          'Delete Transaction?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'This will remove "${current.payee.isNotEmpty ? current.payee : current.category}" and reverse its effect on the account balance.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(transactionListProvider.notifier).remove(current.id);
    await ref.read(accountListProvider.notifier).refresh();
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionListProvider);
    // Reflects live edits/deletes made while this screen is open; falls back
    // to the snapshot passed in while the list is loading.
    final current =
        transactionsAsync.valueOrNull
            ?.where((t) => t.id == transaction.id)
            .firstOrNull ??
        transaction;

    final accountsAsync = ref.watch(accountListProvider);
    final accountName =
        accountsAsync.valueOrNull
            ?.where((a) => a.id == current.accountId)
            .firstOrNull
            ?.name ??
        'Closed Account';

    final category = TransactionCategory.getByName(current.category);
    final isDebit = current.bucket != BudgetBucket.income;
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Transaction Details',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppColors.primaryLight),
            onPressed: () => _edit(context, current),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error,
            ),
            onPressed: () => _delete(context, ref, current),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.md),
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: current.bucket.color.withValues(
                      alpha: 0.15,
                    ),
                    child: Text(
                      category.icon,
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                  AppSizes.h12,
                  Text(
                    '${isDebit ? "-" : "+"}${currency.format(current.amount)}',
                    style: TextStyle(
                      color: isDebit
                          ? AppColors.textPrimary
                          : AppColors.success,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  AppSizes.h4,
                  Text(
                    current.payee.isNotEmpty ? current.payee : current.category,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            AppSizes.h24,
            Card(
              color: AppColors.cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: Column(
                children: [
                  _DetailRow(
                    icon: Icons.category_rounded,
                    label: 'Category',
                    value:
                        '${category.icon} ${current.category} (${current.bucket.displayName})',
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  _DetailRow(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Account',
                    value: accountName,
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  _DetailRow(
                    icon: Icons.calendar_month_rounded,
                    label: 'Date',
                    value: DateFormat('dd MMMM yyyy').format(current.date),
                  ),
                  if (current.note.isNotEmpty) ...[
                    const Divider(color: AppColors.border, height: 1),
                    _DetailRow(
                      icon: Icons.sticky_note_2_rounded,
                      label: 'Note',
                      value: current.note,
                    ),
                  ],
                  if (current.refId.isNotEmpty) ...[
                    const Divider(color: AppColors.border, height: 1),
                    _DetailRow(
                      icon: Icons.tag_rounded,
                      label: 'Reference ID',
                      value: current.refId,
                    ),
                  ],
                  if (current.isRecurring) ...[
                    const Divider(color: AppColors.border, height: 1),
                    const _DetailRow(
                      icon: Icons.repeat_rounded,
                      label: 'Recurring',
                      value: 'This transaction repeats',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: 14,
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          AppSizes.w12,
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
