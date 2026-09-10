import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_sizes.dart';
import '../../accounts/data/accounts_repository.dart';
import '../data/transaction_repository.dart';
import '../domain/transaction.dart';

class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({super.key});

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _payeeController = TextEditingController();
  final _noteController = TextEditingController();

  TransactionCategory _selectedCategory = TransactionCategory.presets.first;
  AccountModel? _selectedAccount;
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _payeeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate() || _selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields and select an account'),
        ),
      );
      return;
    }

    final amount = double.parse(_amountController.text);
    final tx = TransactionModel(
      id: const Uuid().v4(),
      amount: amount,
      category: _selectedCategory.name,
      bucket: _selectedCategory.bucket,
      accountId: _selectedAccount!.id,
      date: _selectedDate,
      payee: _payeeController.text.trim(),
      note: _noteController.text.trim(),
      isRecurring: false,
    );

    // Add transaction to provider
    ref.read(transactionListProvider.notifier).add(tx);
    // Refresh account balances
    ref.read(accountListProvider.notifier).refresh();

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountListProvider);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusLg),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle Indicator
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  AppSizes.h12,
                  const Text(
                    'Add Transaction',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  AppSizes.h16,

                  // Amount Field
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '₹ 0.00',
                      hintStyle: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 24,
                      ),
                      fillColor: AppColors.cardBg,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(
                        Icons.currency_rupee_rounded,
                        color: AppColors.primaryLight,
                        size: 24,
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Enter amount';
                      if (double.tryParse(val) == null)
                        return 'Enter a valid number';
                      if (double.parse(val) <= 0)
                        return 'Amount must be greater than zero';
                      return null;
                    },
                  ),
                  AppSizes.h16,

                  // Payee Field
                  TextFormField(
                    controller: _payeeController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Payee / Merchant',
                      labelStyle: const TextStyle(
                        color: AppColors.textSecondary,
                      ),
                      fillColor: AppColors.cardBg,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(
                        Icons.storefront_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Enter payee' : null,
                  ),
                  AppSizes.h12,

                  // Account Dropdown selection
                  accountsAsync.when(
                    data: (accounts) {
                      if (accounts.isEmpty) {
                        return const Text(
                          'Create an account first in settings.',
                          style: TextStyle(color: AppColors.error),
                        );
                      }

                      // Auto-select first account
                      _selectedAccount ??= accounts.first;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusMd,
                          ),
                        ),
                        child: DropdownButtonFormField<AccountModel>(
                          value: _selectedAccount,
                          dropdownColor: AppColors.surface,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            labelText: 'Debit/Credit Account',
                            labelStyle: TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                          items: accounts.map((acc) {
                            return DropdownMenuItem<AccountModel>(
                              value: acc,
                              child: Text(
                                '${acc.name} (Bal: ₹${acc.balance.toStringAsFixed(0)})',
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedAccount = val;
                            });
                          },
                        ),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error loading accounts: $e'),
                  ),
                  AppSizes.h12,

                  // Category Selector Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                    child: DropdownButtonFormField<TransactionCategory>(
                      value: _selectedCategory,
                      dropdownColor: AppColors.surface,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        labelText: 'Category & Bucket',
                        labelStyle: TextStyle(color: AppColors.textSecondary),
                      ),
                      style: const TextStyle(color: Colors.white),
                      items: TransactionCategory.presets.map((cat) {
                        return DropdownMenuItem<TransactionCategory>(
                          value: cat,
                          child: Text(
                            '${cat.icon} ${cat.name} (${cat.bucket.displayName})',
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedCategory = val;
                          });
                        }
                      },
                    ),
                  ),
                  AppSizes.h12,

                  // Date Picker & Note Field Row
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.cardBg,
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusMd,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_month_rounded,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                                AppSizes.w8,
                                Text(
                                  DateFormat(
                                    'dd MMM yyyy',
                                  ).format(_selectedDate),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  AppSizes.h12,

                  // Description/Note Input
                  TextFormField(
                    controller: _noteController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Add optional note...',
                      labelStyle: const TextStyle(
                        color: AppColors.textSecondary,
                      ),
                      fillColor: AppColors.cardBg,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(
                        Icons.sticky_note_2_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  AppSizes.h24,

                  // Submit Button
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      ),
                    ),
                    child: const Text(
                      'Save Transaction',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
