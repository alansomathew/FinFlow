import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../constants/app_sizes.dart';
import '../../../constants/app_theme.dart';
import '../../accounts/data/accounts_repository.dart';
import '../data/debt_repository.dart';
import '../domain/amortization_engine.dart';

/// Add/edit form for a single loan. Pass [existing] to edit it in place;
/// omit it to add a new one. New loans are subject to the free-tier cap
/// ([kFreeLoanLimit]); editing an existing one never is.
class LoanFormSheet extends ConsumerStatefulWidget {
  final LoanModel? existing;
  const LoanFormSheet({super.key, this.existing});

  @override
  ConsumerState<LoanFormSheet> createState() => _LoanFormSheetState();
}

class _LoanFormSheetState extends ConsumerState<LoanFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _lenderController;
  late final TextEditingController _principalController;
  late final TextEditingController _rateController;
  late final TextEditingController _tenureController;
  late final TextEditingController _emiController;

  AccountModel? _selectedAccount;
  late DateTime _startDate;
  bool _emiManuallyEdited = false;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _lenderController = TextEditingController(text: existing?.lenderName ?? '');
    _principalController = TextEditingController(
      text: existing != null ? existing.loanAmount.toString() : '',
    );
    _rateController = TextEditingController(
      text: existing != null ? existing.interestRate.toString() : '',
    );
    _tenureController = TextEditingController(
      text: existing != null ? existing.tenureMonths.toString() : '',
    );
    _emiController = TextEditingController(
      text: existing != null ? existing.emiAmount.toString() : '',
    );
    _emiManuallyEdited = existing != null;
    _startDate = existing != null
        ? (DateTime.tryParse(existing.startDate) ?? DateTime.now())
        : DateTime.now();

    for (final c in [
      _principalController,
      _rateController,
      _tenureController,
    ]) {
      c.addListener(_recalculateEmi);
    }
  }

  @override
  void dispose() {
    _lenderController.dispose();
    _principalController.dispose();
    _rateController.dispose();
    _tenureController.dispose();
    _emiController.dispose();
    super.dispose();
  }

  void _recalculateEmi() {
    if (_emiManuallyEdited) return;
    final principal = double.tryParse(_principalController.text);
    final rate = double.tryParse(_rateController.text);
    final tenure = int.tryParse(_tenureController.text);
    if (principal == null || rate == null || tenure == null || tenure <= 0) {
      return;
    }
    final emi = AmortizationEngine.calculateEmi(
      principal: principal,
      annualRate: rate,
      tenureMonths: tenure,
    );
    _emiController.text = emi.toStringAsFixed(2);
  }

  Future<void> _pickStartDate() async {
    final colors = context.colors;
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
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
      setState(() => _startDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields and select a debit account'),
        ),
      );
      return;
    }

    final repo = ref.read(debtRepositoryProvider);
    if (!_isEditing) {
      final allowed = await repo.canAddLoan();
      if (!allowed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Free tier allows up to $kFreeLoanLimit loans. Upgrade to Pro for unlimited.',
              ),
            ),
          );
        }
        return;
      }
    }

    setState(() => _saving = true);

    final loan = LoanModel(
      id: widget.existing?.id ?? const Uuid().v4(),
      lenderName: _lenderController.text.trim(),
      loanAmount: double.parse(_principalController.text),
      interestRate: double.parse(_rateController.text),
      tenureMonths: int.parse(_tenureController.text),
      startDate: DateFormat('yyyy-MM-dd').format(_startDate),
      emiAmount: double.parse(_emiController.text),
      debitAccountId: _selectedAccount!.id,
    );

    await ref.read(loanListProvider.notifier).add(loan);
    if (mounted) Navigator.pop(context);
  }

  InputDecoration _decoration(String label) {
    final colors = context.colors;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: colors.textSecondary),
      fillColor: colors.cardBg,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        borderSide: BorderSide.none,
      ),
    );
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
                    _isEditing ? 'Edit Loan' : 'Add Loan',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  AppSizes.h16,

                  TextFormField(
                    controller: _lenderController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _decoration('Lender Name'),
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'Enter a lender name'
                        : null,
                  ),
                  AppSizes.h16,

                  TextFormField(
                    controller: _principalController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(color: Colors.white),
                    decoration: _decoration('Loan Amount (Principal)'),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Enter an amount';
                      if (double.tryParse(val) == null) {
                        return 'Enter a valid number';
                      }
                      return null;
                    },
                  ),
                  AppSizes.h16,

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _rateController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: const TextStyle(color: Colors.white),
                          decoration: _decoration('Interest Rate (% p.a.)'),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Enter a rate';
                            }
                            if (double.tryParse(val) == null) {
                              return 'Invalid';
                            }
                            return null;
                          },
                        ),
                      ),
                      AppSizes.w12,
                      Expanded(
                        child: TextFormField(
                          controller: _tenureController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: _decoration('Tenure (months)'),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Enter tenure';
                            }
                            if (int.tryParse(val) == null) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  AppSizes.h16,

                  TextFormField(
                    controller: _emiController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(color: Colors.white),
                    decoration: _decoration('Monthly EMI').copyWith(
                      helperText:
                          'Auto-calculated from amount/rate/tenure; edit to override',
                      helperStyle: TextStyle(
                        color: colors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    onChanged: (_) => _emiManuallyEdited = true,
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Enter an EMI';
                      if (double.tryParse(val) == null) {
                        return 'Enter a valid number';
                      }
                      return null;
                    },
                  ),
                  AppSizes.h16,

                  InkWell(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    onTap: _pickStartDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.md,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: colors.cardBg,
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
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
                            'Start Date: ${DateFormat('dd MMM yyyy').format(_startDate)}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AppSizes.h16,

                  accountsAsync.when(
                    data: (accounts) {
                      if (accounts.isEmpty) {
                        return Text(
                          'Add an account first to link this loan.',
                          style: TextStyle(color: colors.error),
                        );
                      }
                      _selectedAccount ??= _isEditing
                          ? accounts.firstWhere(
                              (a) => a.id == widget.existing!.debitAccountId,
                              orElse: () => accounts.first,
                            )
                          : accounts.first;

                      return DropdownButtonFormField<AccountModel>(
                        initialValue: _selectedAccount,
                        dropdownColor: colors.surface,
                        style: const TextStyle(color: Colors.white),
                        decoration: _decoration('Debit Account'),
                        items: accounts.map((acc) {
                          return DropdownMenuItem<AccountModel>(
                            value: acc,
                            child: Text(acc.name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedAccount = val);
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
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
                      _isEditing ? 'Save Changes' : 'Add Loan',
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
