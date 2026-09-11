import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_sizes.dart';
import '../../../constants/app_theme.dart';
import '../data/accounts_repository.dart';
import 'account_detail_screen.dart';
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

class AccountsListScreen extends ConsumerWidget {
  const AccountsListScreen({super.key});

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

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AccountFormSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final accountsAsync = ref.watch(accountListProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Text(
          'Accounts & Cards',
          style: TextStyle(color: colors.textPrimary),
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: colors.primary,
        onPressed: () => _showAddSheet(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: accountsAsync.when(
        data: (accounts) {
          if (accounts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: colors.textSecondary,
                    size: 40,
                  ),
                  AppSizes.h12,
                  Text(
                    'No accounts yet.',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                  AppSizes.h12,
                  ElevatedButton.icon(
                    onPressed: () => _showAddSheet(context),
                    icon: const Icon(Icons.add_rounded, color: Colors.white),
                    label: const Text(
                      'Add Account',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSizes.md),
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final a = accounts[index];
              final isCreditCard = a.type == 'credit_card';
              final utilization = isCreditCard && a.creditLimit > 0
                  ? (a.balance.abs() / a.creditLimit).clamp(0.0, 1.0)
                  : 0.0;

              return Card(
                color: colors.cardBg,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AccountDetailScreen(account: a),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: _hexToColor(
                                a.colorHex,
                              ).withValues(alpha: 0.2),
                              child: Icon(
                                _typeIcons[a.type] ??
                                    Icons.account_balance_rounded,
                                color: _hexToColor(a.colorHex),
                                size: 18,
                              ),
                            ),
                            AppSizes.w12,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.name,
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    _typeLabels[a.type] ?? a.type,
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _formatCurrency(a.balance),
                              style: TextStyle(
                                color: a.balance < 0
                                    ? colors.error
                                    : colors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        if (isCreditCard) ...[
                          AppSizes.h12,
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: utilization,
                              backgroundColor: colors.border,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                utilization >= 1.0
                                    ? colors.error
                                    : utilization >= 0.8
                                    ? colors.warning
                                    : colors.success,
                              ),
                              minHeight: 4,
                            ),
                          ),
                          AppSizes.h4,
                          Text(
                            '${(utilization * 100).toStringAsFixed(0)}% utilized',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
