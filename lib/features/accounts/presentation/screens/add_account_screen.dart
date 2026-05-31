import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/account_provider.dart';
import '../../domain/models/account_model.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/utils/currency_formatter.dart';

class AddAccountScreen extends ConsumerStatefulWidget {
  const AddAccountScreen({super.key});

  @override
  ConsumerState<AddAccountScreen> createState() =>
      _AddAccountScreenState();
}

class _AddAccountScreenState
    extends ConsumerState<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bankController = TextEditingController();
  final _balanceController = TextEditingController();
  final _maskedNumberController = TextEditingController();
  final _creditLimitController = TextEditingController();
  final _interestRateController = TextEditingController();

  AccountType _selectedType = AccountType.savings;
  Color _selectedColor = AppColors.primary;
  String _selectedEmoji = '🏦';
  bool _isLoading = false;

  static const _colorOptions = [
    AppColors.primary,
    AppColors.accent,
    AppColors.needsColor,
    AppColors.wantsColor,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
  ];

  static const _emojiOptions = [
    '🏦', '💳', '👛', '💰', '🏧', '📱', '💎', '🏠'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _bankController.dispose();
    _balanceController.dispose();
    _maskedNumberController.dispose();
    _creditLimitController.dispose();
    _interestRateController.dispose();
    super.dispose();
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title:
            const Text('Add Account', style: AppTextStyles.headlineMedium),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Dynamic Live Card Preview
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 180,
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _selectedColor,
                    _selectedColor.withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _selectedColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _bankController.text.isEmpty
                            ? 'BANK NAME'
                            : _bankController.text.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        _selectedEmoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nameController.text.isEmpty
                            ? 'Account Name'
                            : _nameController.text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _maskedNumberController.text.isEmpty
                            ? '•••• •••• •••• 0000'
                            : '•••• •••• •••• ${_maskedNumberController.text}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'BALANCE',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(
                              double.tryParse(_balanceController.text.replaceAll(',', '')) ?? 0.0,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _typeLabel(_selectedType).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Type selector
            Text('Account Type', style: AppTextStyles.labelMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: AccountType.values.map((type) {
                  final isSelected = type == _selectedType;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedType = type),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _typeLabel(type),
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
            ),
            const SizedBox(height: 16),
            // Card Color Selector
            Text('Card Color', style: AppTextStyles.labelMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _colorOptions.map((color) {
                  final isSelected = color == _selectedColor;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 38,
                      height: 38,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withOpacity(0.5),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            // Emoji Selector
            Text('Icon / Emoji', style: AppTextStyles.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _emojiOptions
                  .map((e) => GestureDetector(
                        onTap: () => setState(() => _selectedEmoji = e),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _selectedEmoji == e
                                ? AppColors.primary.withOpacity(0.2)
                                : AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(8),
                            border: _selectedEmoji == e
                                ? Border.all(color: AppColors.primary)
                                : null,
                          ),
                          child: Text(e, style: const TextStyle(fontSize: 20)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Account Name',
                hintText: 'e.g. HDFC Savings',
              ),
              validator: Validators.required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bankController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Bank / Institution',
                hintText: 'e.g. HDFC Bank',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _balanceController,
              onChanged: (_) => setState(() {}),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Current Balance',
                prefixText: '₹ ',
              ),
              validator: Validators.amount,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _maskedNumberController,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'Last 4 Digits (optional)',
                hintText: 'e.g. 1234',
              ),
            ),
            if (_selectedType == AccountType.creditCard) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _creditLimitController,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Credit Limit',
                  prefixText: '₹ ',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _interestRateController,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Interest Rate % p.a.',
                  hintText: 'e.g. 40',
                ),
                validator: Validators.interestRate,
              ),
            ],
            const SizedBox(height: 32),
            GradientButton(
              label: _isLoading ? 'Saving...' : 'Add Account',
              onTap: _isLoading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(AccountType type) {
    switch (type) {
      case AccountType.savings:
        return 'Savings';
      case AccountType.current:
        return 'Current';
      case AccountType.creditCard:
        return 'Credit Card';
      case AccountType.wallet:
        return 'Wallet';
      case AccountType.cash:
        return 'Cash';
      case AccountType.upi:
        return 'UPI';
      case AccountType.fixedDeposit:
        return 'FD';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final account = AccountModel(
      id: '',
      userId: '',
      name: _nameController.text.trim(),
      bankName: _bankController.text.trim(),
      type: _selectedType,
      balance: double.tryParse(
              _balanceController.text.replaceAll(',', '')) ??
          0,
      maskedNumber: _maskedNumberController.text.trim().isEmpty
          ? null
          : _maskedNumberController.text.trim(),
      creditLimit: _creditLimitController.text.trim().isEmpty
          ? null
          : double.tryParse(
              _creditLimitController.text.replaceAll(',', '')),
      interestRate: _interestRateController.text.trim().isEmpty
          ? null
          : double.tryParse(_interestRateController.text),
      color: _selectedColor,
      emoji: _selectedEmoji,
    );

    try {
      await ref
          .read(accountNotifierProvider.notifier)
          .addAccount(account);
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
