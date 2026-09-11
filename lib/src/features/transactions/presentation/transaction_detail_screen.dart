import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_sizes.dart';
import '../../../constants/app_theme.dart';
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
    final colors = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        title: Text(
          'Delete Transaction?',
          style: TextStyle(color: colors.textPrimary),
        ),
        content: Text(
          'This will remove "${current.payee.isNotEmpty ? current.payee : current.category}" and reverse its effect on the account balance.',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: colors.error)),
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
    final colors = context.colors;
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
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Text(
          'Transaction Details',
          style: TextStyle(color: colors.textPrimary),
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_rounded, color: colors.primaryLight),
            onPressed: () => _edit(context, current),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: colors.error),
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
                      color: isDebit ? colors.textPrimary : colors.success,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  AppSizes.h4,
                  Text(
                    current.payee.isNotEmpty ? current.payee : current.category,
                    style: TextStyle(color: colors.textSecondary, fontSize: 15),
                  ),
                ],
              ),
            ),
            AppSizes.h24,
            Card(
              color: colors.cardBg,
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
                  Divider(color: colors.border, height: 1),
                  _DetailRow(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Account',
                    value: accountName,
                  ),
                  Divider(color: colors.border, height: 1),
                  _DetailRow(
                    icon: Icons.calendar_month_rounded,
                    label: 'Date',
                    value: DateFormat('dd MMMM yyyy').format(current.date),
                  ),
                  if (current.note.isNotEmpty) ...[
                    Divider(color: colors.border, height: 1),
                    _DetailRow(
                      icon: Icons.sticky_note_2_rounded,
                      label: 'Note',
                      value: current.note,
                    ),
                  ],
                  if (current.refId.isNotEmpty) ...[
                    Divider(color: colors.border, height: 1),
                    _DetailRow(
                      icon: Icons.tag_rounded,
                      label: 'Reference ID',
                      value: current.refId,
                    ),
                  ],
                  if (current.isRecurring) ...[
                    Divider(color: colors.border, height: 1),
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
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: 14,
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.textSecondary, size: 20),
          AppSizes.w12,
          Text(
            label,
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: colors.textPrimary,
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
