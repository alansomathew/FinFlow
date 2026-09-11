import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../constants/app_sizes.dart';
import '../../../constants/app_theme.dart';
import '../data/accounts_repository.dart';

const _accountTypes = [
  ('bank', 'Bank', Icons.account_balance_rounded),
  ('cash', 'Cash', Icons.payments_rounded),
  ('wallet', 'Wallet', Icons.account_balance_wallet_rounded),
  ('credit_card', 'Credit Card', Icons.credit_card_rounded),
];

const _colorPalette = [
  '#1A56DB',
  '#059669',
  '#7C3AED',
  '#D97706',
  '#DC2626',
  '#0891B2',
  '#DB2777',
  '#4B5563',
];

/// Add/edit form for a single account. Pass [existing] to edit it in place;
/// omit it to add a new one. New accounts are subject to the free-tier cap
/// ([kFreeAccountLimit]); editing an existing one never is.
class AccountFormSheet extends ConsumerStatefulWidget {
  final AccountModel? existing;
  const AccountFormSheet({super.key, this.existing});

  @override
  ConsumerState<AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends ConsumerState<AccountFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;
  late final TextEditingController _creditLimitController;

  late String _selectedType;
  late String _selectedColor;
  DateTime? _dueDate;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _balanceController = TextEditingController(
      text: existing != null ? existing.balance.toString() : '',
    );
    _creditLimitController = TextEditingController(
      text: existing != null && existing.creditLimit > 0
          ? existing.creditLimit.toString()
          : '',
    );
    _selectedType = existing?.type ?? 'bank';
    _selectedColor = existing?.colorHex ?? _colorPalette.first;
    if (existing != null && existing.cardDueDate.isNotEmpty) {
      _dueDate = DateTime.tryParse(existing.cardDueDate);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _creditLimitController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final colors = context.colors;
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
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
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final repo = ref.read(accountsRepositoryProvider);
    if (!_isEditing) {
      final allowed = await repo.canAddAccount();
      if (!allowed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Free tier allows up to $kFreeAccountLimit accounts. Upgrade to Pro for unlimited.',
              ),
            ),
          );
        }
        return;
      }
    }

    setState(() => _saving = true);

    final account = AccountModel(
      id: widget.existing?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      type: _selectedType,
      balance: double.parse(_balanceController.text),
      creditLimit: _selectedType == 'credit_card'
          ? (double.tryParse(_creditLimitController.text) ?? 0.0)
          : 0.0,
      cardDueDate: _selectedType == 'credit_card' && _dueDate != null
          ? DateFormat('yyyy-MM-dd').format(_dueDate!)
          : '',
      colorHex: _selectedColor,
    );

    await ref.read(accountListProvider.notifier).add(account);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isCreditCard = _selectedType == 'credit_card';

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
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
                    _isEditing ? 'Edit Account' : 'Add Account',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  AppSizes.h16,

                  // Name Field
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Account Name',
                      labelStyle: TextStyle(color: colors.textSecondary),
                      fillColor: colors.cardBg,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'Enter an account name'
                        : null,
                  ),
                  AppSizes.h16,

                  // Type Selector
                  Text(
                    'Type',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                  AppSizes.h8,
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _accountTypes.map((t) {
                      final (value, label, icon) = t;
                      final selected = _selectedType == value;
                      return ChoiceChip(
                        selected: selected,
                        onSelected: (_) =>
                            setState(() => _selectedType = value),
                        avatar: Icon(
                          icon,
                          size: 16,
                          color: selected ? Colors.white : colors.textSecondary,
                        ),
                        label: Text(label),
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : colors.textSecondary,
                        ),
                        selectedColor: colors.primary,
                        backgroundColor: colors.cardBg,
                      );
                    }).toList(),
                  ),
                  AppSizes.h16,

                  // Balance Field
                  TextFormField(
                    controller: _balanceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: isCreditCard
                          ? 'Outstanding Balance (negative)'
                          : 'Balance',
                      labelStyle: TextStyle(color: colors.textSecondary),
                      fillColor: colors.cardBg,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(
                        Icons.currency_rupee_rounded,
                        color: colors.primaryLight,
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Enter a balance';
                      if (double.tryParse(val) == null) {
                        return 'Enter a valid number';
                      }
                      return null;
                    },
                  ),

                  if (isCreditCard) ...[
                    AppSizes.h16,
                    TextFormField(
                      controller: _creditLimitController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Credit Limit',
                        labelStyle: TextStyle(color: colors.textSecondary),
                        fillColor: colors.cardBg,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusMd,
                          ),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Enter a credit limit';
                        }
                        if (double.tryParse(val) == null) {
                          return 'Enter a valid number';
                        }
                        return null;
                      },
                    ),
                    AppSizes.h16,
                    InkWell(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      onTap: _pickDueDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.md,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: colors.cardBg,
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusMd,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.event_rounded,
                              color: colors.textSecondary,
                              size: 20,
                            ),
                            AppSizes.w12,
                            Text(
                              _dueDate != null
                                  ? 'Due: ${DateFormat('dd MMM yyyy').format(_dueDate!)}'
                                  : 'Set Due Date (optional)',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  AppSizes.h16,

                  // Color Picker
                  Text(
                    'Color',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                  AppSizes.h8,
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _colorPalette.map((hex) {
                      final selected = _selectedColor == hex;
                      final color = Color(
                        int.parse(hex.substring(1), radix: 16) + 0xFF000000,
                      );
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColor = hex),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: selected
                                ? Border.all(color: Colors.white, width: 2)
                                : null,
                          ),
                          child: selected
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 18,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  AppSizes.h24,

                  ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      ),
                    ),
                    child: Text(
                      _isEditing ? 'Save Changes' : 'Add Account',
                      style: const TextStyle(
                        color: Colors.white,
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
