import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/loan_provider.dart';
import '../../domain/models/loan_model.dart';
import '../../../../features/accounts/presentation/providers/account_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/common_widgets.dart';

class AddLoanScreen extends ConsumerStatefulWidget {
  const AddLoanScreen({super.key});

  @override
  ConsumerState<AddLoanScreen> createState() => _AddLoanScreenState();
}

class _AddLoanScreenState extends ConsumerState<AddLoanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _lenderController = TextEditingController();
  final _principalController = TextEditingController();
  final _rateController = TextEditingController();
  final _tenureController = TextEditingController();

  LoanType _selectedType = LoanType.personalLoan;
  String? _accountId;
  DateTime _startDate = DateTime.now();
  double _calculatedEmi = 0;
  bool _isLoading = false;

  @override
  void dispose() {
    _lenderController.dispose();
    _principalController.dispose();
    _rateController.dispose();
    _tenureController.dispose();
    super.dispose();
  }

  void _recalculateEmi() {
    final p = double.tryParse(
            _principalController.text.replaceAll(',', '')) ??
        0;
    final r = double.tryParse(_rateController.text) ?? 0;
    final t = int.tryParse(_tenureController.text) ?? 0;
    if (p > 0 && t > 0) {
      setState(() {
        _calculatedEmi = LoanModel.calculateEmi(p, r, t);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Add Loan', style: AppTextStyles.headlineMedium),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Loan type
            Text('Loan Type', style: AppTextStyles.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: LoanType.values.map((type) {
                final isSelected = type == _selectedType;
                final l = LoanModel(
                  id: '',
                  userId: '',
                  type: type,
                  lenderName: '',
                  principalAmount: 0,
                  interestRate: 0,
                  tenureMonths: 0,
                  startDate: DateTime.now(),
                  emiAmount: 0,
                  accountId: '',
                  outstandingPrincipal: 0,
                );
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = type),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      l.typeLabel,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lenderController,
              decoration: const InputDecoration(
                labelText: 'Lender / Bank Name',
              ),
              validator: Validators.required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _principalController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Loan Amount',
                prefixText: '₹ ',
              ),
              validator: Validators.amount,
              onChanged: (_) => _recalculateEmi(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _rateController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Interest Rate (% p.a.)',
              ),
              validator: Validators.interestRate,
              onChanged: (_) => _recalculateEmi(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tenureController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Tenure (Months)',
              ),
              validator: Validators.required,
              onChanged: (_) => _recalculateEmi(),
            ),
            // EMI preview
            if (_calculatedEmi > 0)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.accent.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Calculated EMI',
                        style: AppTextStyles.labelMedium),
                    Text(
                      '₹${_calculatedEmi.toStringAsFixed(2)}',
                      style: AppTextStyles.amountSmall
                          .copyWith(color: AppColors.accent),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            accountsAsync.when(
              data: (accounts) => DropdownButtonFormField<String>(
                value: _accountId,
                decoration: const InputDecoration(
                  labelText: 'Linked Account',
                ),
                items: accounts
                    .map((acc) => DropdownMenuItem(
                          value: acc.id,
                          child: Text('${acc.emoji} ${acc.name}'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _accountId = v),
              ),
              loading: () => const ShimmerCard(height: 56),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 32),
            GradientButton(
              label: _isLoading ? 'Saving...' : 'Add Loan',
              onTap: _isLoading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final principal = double.parse(
        _principalController.text.replaceAll(',', ''));
    final rate = double.parse(_rateController.text);
    final tenure = int.parse(_tenureController.text);
    final emi = LoanModel.calculateEmi(principal, rate, tenure);

    final loan = LoanModel(
      id: '',
      userId: '',
      type: _selectedType,
      lenderName: _lenderController.text.trim(),
      principalAmount: principal,
      interestRate: rate,
      tenureMonths: tenure,
      startDate: _startDate,
      emiAmount: emi,
      accountId: _accountId ?? '',
      outstandingPrincipal: principal,
    );

    try {
      await ref
          .read(loanNotifierProvider.notifier)
          .addLoan(loan);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
