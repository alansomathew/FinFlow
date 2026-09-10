import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_sizes.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/transaction_detail_screen.dart';
import '../data/accounts_repository.dart';
import 'account_form_sheet.dart';

const _typeLabels = {
  'bank': 'Bank Account',
  'cash': 'Cash',
  'wallet': 'Wallet',
  'credit_card': 'Credit Card',
};

const _typeIcons = {
  'bank': Icons.account_balance_rounded,
  'cash': Icons.payments_rounded,
  'wallet': Icons.account_balance_wallet_rounded,
  'credit_card': Icons.credit_card_rounded,
};

class AccountDetailScreen extends ConsumerWidget {
  final AccountModel account;
  const AccountDetailScreen({super.key, required this.account});

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(amount);
  }

  Color _hexToColor(String hex) {
    return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
  }

  void _edit(BuildContext context, AccountModel current) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AccountFormSheet(existing: current),
    );
  }

  Future<void> _close(
    BuildContext context,
    WidgetRef ref,
    AccountModel current,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        title: const Text(
          'Close Account?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          '"${current.name}" will be hidden from your account list, but its '
          'transaction history is kept intact.',
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
              'Close Account',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(accountListProvider.notifier).close(current.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  Widget _buildDueDateBanner(String cardDueDate) {
    final due = DateTime.tryParse(cardDueDate);
    if (due == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysLeft = due.difference(today).inDays;

    late String text;
    late Color color;
    if (daysLeft < 0) {
      text = 'Overdue by ${-daysLeft} day${-daysLeft == 1 ? '' : 's'}';
      color = AppColors.error;
    } else if (daysLeft == 0) {
      text = 'Due today';
      color = AppColors.error;
    } else if (daysLeft <= 7) {
      text = 'Due in $daysLeft day${daysLeft == 1 ? '' : 's'}';
      color = AppColors.warning;
    } else {
      text = 'Due ${DateFormat('dd MMM yyyy').format(due)}';
      color = AppColors.success;
    }

    return Container(
      margin: const EdgeInsets.only(top: AppSizes.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_rounded, color: color, size: 16),
          AppSizes.w8,
          Text(
            text,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountListProvider);
    final current =
        accountsAsync.valueOrNull
            ?.where((a) => a.id == account.id)
            .firstOrNull ??
        account;

    final transactionsAsync = ref.watch(transactionListProvider);
    final linkedTransactions =
        transactionsAsync.valueOrNull
            ?.where((t) => t.accountId == current.id)
            .toList()
          ?..sort((a, b) => b.date.compareTo(a.date));

    final isCreditCard = current.type == 'credit_card';
    final utilization = isCreditCard && current.creditLimit > 0
        ? (current.balance.abs() / current.creditLimit).clamp(0.0, 1.0)
        : 0.0;
    final utilizationColor = utilization >= 1.0
        ? AppColors.error
        : utilization >= 0.8
        ? AppColors.warning
        : AppColors.success;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          current.name,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppColors.primaryLight),
            onPressed: () => _edit(context, current),
          ),
          IconButton(
            icon: const Icon(
              Icons.remove_circle_outline_rounded,
              color: AppColors.error,
            ),
            tooltip: 'Close Account',
            onPressed: () => _close(context, ref, current),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.md),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.lg),
              decoration: BoxDecoration(
                color: _hexToColor(current.colorHex),
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _typeIcons[current.type] ?? Icons.account_balance_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                      AppSizes.w8,
                      Text(
                        _typeLabels[current.type] ?? current.type,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  AppSizes.h8,
                  Text(
                    _formatCurrency(current.balance),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isCreditCard) ...[
                    AppSizes.h16,
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: utilization,
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          utilizationColor,
                        ),
                        minHeight: 6,
                      ),
                    ),
                    AppSizes.h4,
                    Text(
                      '${_formatCurrency(current.balance.abs())} of ${_formatCurrency(current.creditLimit)} used (${(utilization * 100).toStringAsFixed(0)}%)',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    if (current.cardDueDate.isNotEmpty)
                      _buildDueDateBanner(current.cardDueDate),
                  ],
                ],
              ),
            ),
            AppSizes.h24,
            const Text(
              'Recent Transactions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            AppSizes.h8,
            if (linkedTransactions == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSizes.lg),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (linkedTransactions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSizes.lg),
                child: Center(
                  child: Text(
                    'No transactions on this account yet.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              ...linkedTransactions.map((t) {
                final category = TransactionCategory.getByName(t.category);
                final isDebit = t.bucket != BudgetBucket.income;
                return Card(
                  color: AppColors.cardBg,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  child: ListTile(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            TransactionDetailScreen(transaction: t),
                      ),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: t.bucket.color.withValues(alpha: 0.15),
                      child: Text(
                        category.icon,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                    title: Text(
                      t.payee.isNotEmpty ? t.payee : t.category,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      DateFormat('dd MMM yyyy').format(t.date),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Text(
                      '${isDebit ? "-" : "+"}${_formatCurrency(t.amount)}',
                      style: TextStyle(
                        color: isDebit ? AppColors.textPrimary : AppColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
