import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../constants/app_sizes.dart';
import '../../../constants/app_theme.dart';
import '../../accounts/data/accounts_repository.dart';
import '../data/recurring_repository.dart';
import '../data/transaction_repository.dart';
import '../domain/transaction.dart';

/// Add/edit form for a single transaction. Pass [existing] to edit it in
/// place; omit it to add a new one. The recurring toggle is only offered
/// when adding, since retrofitting recurrence onto an already-materialized
/// transaction would need to locate/update its originating rule, which
/// isn't tracked back from the transaction row.
class TransactionFormSheet extends ConsumerStatefulWidget {
  final TransactionModel? existing;
  const TransactionFormSheet({super.key, this.existing});

  @override
  ConsumerState<TransactionFormSheet> createState() =>
      _TransactionFormSheetState();
}

const _frequencies = ['daily', 'weekly', 'monthly'];

class _TransactionFormSheetState extends ConsumerState<TransactionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _payeeController;
  late final TextEditingController _noteController;

  late TransactionCategory _selectedCategory;
  AccountModel? _selectedAccount;
  late DateTime _selectedDate;
  bool _isRecurring = false;
  String _frequency = 'monthly';

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _amountController = TextEditingController(
      text: existing != null ? existing.amount.toString() : '',
    );
    _payeeController = TextEditingController(text: existing?.payee ?? '');
    _noteController = TextEditingController(text: existing?.note ?? '');
    _selectedCategory = existing != null
        ? TransactionCategory.getByName(existing.category)
        : TransactionCategory.presets.first;
    _selectedDate = existing?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _payeeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final colors = context.colors;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: colors.primary,
              onPrimary: Colors.white,
              surface: colors.surface,
              onSurface: colors.textPrimary,
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

  DateTime _firstOccurrenceAfter(DateTime date, String frequency) {
    switch (frequency) {
      case 'daily':
        return date.add(const Duration(days: 1));
      case 'weekly':
        return date.add(const Duration(days: 7));
      case 'monthly':
      default:
        return DateTime(date.year, date.month + 1, date.day);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields and select an account'),
        ),
      );
      return;
    }

    final amount = double.parse(_amountController.text);

    if (_isEditing) {
      final updated = TransactionModel(
        id: widget.existing!.id,
        amount: amount,
        category: _selectedCategory.name,
        bucket: _selectedCategory.bucket,
        accountId: _selectedAccount!.id,
        date: _selectedDate,
        payee: _payeeController.text.trim(),
        note: _noteController.text.trim(),
        isRecurring: widget.existing!.isRecurring,
        refId: widget.existing!.refId,
      );
      await ref
          .read(transactionListProvider.notifier)
          .update(widget.existing!, updated);
      await ref.read(accountListProvider.notifier).refresh();
    } else {
      final tx = TransactionModel(
        id: const Uuid().v4(),
        amount: amount,
        category: _selectedCategory.name,
        bucket: _selectedCategory.bucket,
        accountId: _selectedAccount!.id,
        date: _selectedDate,
        payee: _payeeController.text.trim(),
        note: _noteController.text.trim(),
        isRecurring: _isRecurring,
      );
      await ref.read(transactionListProvider.notifier).add(tx);
      await ref.read(accountListProvider.notifier).refresh();

      if (_isRecurring) {
        final recurringRepo = ref.read(recurringRepositoryProvider);
        if (await recurringRepo.canAddRule()) {
          await recurringRepo.addRule(
            amount: amount,
            category: _selectedCategory.name,
            bucket: _selectedCategory.bucket,
            accountId: _selectedAccount!.id,
            payee: _payeeController.text.trim(),
            note: _noteController.text.trim(),
            frequency: _frequency,
            nextDueDate: _firstOccurrenceAfter(_selectedDate, _frequency),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Free tier allows up to $kFreeRecurringLimit recurring transactions. This one was added once, but not scheduled to repeat.',
              ),
            ),
          );
        }
      }
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountListProvider);
    final colors = context.colors;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
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
                        color: colors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  AppSizes.h12,
                  Text(
                    _isEditing ? 'Edit Transaction' : 'Add Transaction',
                    style: TextStyle(
                      color: colors.textPrimary,
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
                        color: colors.textMuted,
                        fontSize: 24,
                      ),
                      fillColor: colors.cardBg,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(
                        Icons.currency_rupee_rounded,
                        color: colors.primaryLight,
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
                      labelStyle: TextStyle(color: colors.textSecondary),
                      fillColor: colors.cardBg,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(
                        Icons.storefront_rounded,
                        color: colors.textSecondary,
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
                        return Text(
                          'Create an account first in settings.',
                          style: TextStyle(color: colors.error),
                        );
                      }

                      _selectedAccount ??= _isEditing
                          ? accounts.firstWhere(
                              (a) => a.id == widget.existing!.accountId,
                              orElse: () => accounts.first,
                            )
                          : accounts.first;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: colors.cardBg,
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusMd,
                          ),
                        ),
                        child: DropdownButtonFormField<AccountModel>(
                          initialValue: _selectedAccount,
                          dropdownColor: colors.surface,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            labelText: 'Debit/Credit Account',
                            labelStyle: TextStyle(color: colors.textSecondary),
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
                      color: colors.cardBg,
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                    child: DropdownButtonFormField<TransactionCategory>(
                      initialValue: _selectedCategory,
                      dropdownColor: colors.surface,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        labelText: 'Category & Bucket',
                        labelStyle: TextStyle(color: colors.textSecondary),
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

                  // Date Picker
                  InkWell(
                    onTap: () => _selectDate(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colors.cardBg,
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_month_rounded,
                            color: colors.textSecondary,
                            size: 20,
                          ),
                          AppSizes.w8,
                          Text(
                            DateFormat('dd MMM yyyy').format(_selectedDate),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AppSizes.h12,

                  // Description/Note Input
                  TextFormField(
                    controller: _noteController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Add optional note...',
                      labelStyle: TextStyle(color: colors.textSecondary),
                      fillColor: colors.cardBg,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(
                        Icons.sticky_note_2_rounded,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),

                  if (!_isEditing) ...[
                    AppSizes.h12,
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: colors.cardBg,
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      ),
                      child: SwitchListTile(
                        title: const Text(
                          'Repeat this transaction',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          'Free tier: up to $kFreeRecurringLimit active recurring transactions',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        value: _isRecurring,
                        activeThumbColor: colors.primary,
                        onChanged: (val) => setState(() => _isRecurring = val),
                      ),
                    ),
                    if (_isRecurring) ...[
                      AppSizes.h8,
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: colors.cardBg,
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusMd,
                          ),
                        ),
                        child: DropdownButtonFormField<String>(
                          initialValue: _frequency,
                          dropdownColor: colors.surface,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            labelText: 'Frequency',
                            labelStyle: TextStyle(color: colors.textSecondary),
                          ),
                          style: const TextStyle(color: Colors.white),
                          items: _frequencies
                              .map(
                                (f) => DropdownMenuItem(
                                  value: f,
                                  child: Text(
                                    f[0].toUpperCase() + f.substring(1),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _frequency = val);
                          },
                        ),
                      ),
                    ],
                  ],
                  AppSizes.h24,

                  // Submit Button
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      ),
                    ),
                    child: Text(
                      _isEditing ? 'Save Changes' : 'Save Transaction',
                      style: const TextStyle(
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
