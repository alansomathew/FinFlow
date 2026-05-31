import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/investment_provider.dart';
import '../../domain/models/investment_model.dart';
import '../../../accounts/presentation/providers/account_provider.dart';
import '../../../transactions/presentation/providers/category_provider.dart';
import '../../../transactions/domain/models/category_model.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/common_widgets.dart';

const _sipFrequencies = ['monthly', 'weekly', 'quarterly'];
const _exchanges = ['NSE', 'BSE'];

class AddInvestmentScreen extends ConsumerStatefulWidget {
  const AddInvestmentScreen({super.key});

  @override
  ConsumerState<AddInvestmentScreen> createState() =>
      _AddInvestmentScreenState();
}

class _AddInvestmentScreenState
    extends ConsumerState<AddInvestmentScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSip = true;
  bool _isLoading = false;

  // SIP fields
  final _fundNameController = TextEditingController();
  final _amcController = TextEditingController();
  final _sipAmountController = TextEditingController();
  final _stepUpController = TextEditingController();
  String _sipFrequency = 'monthly';
  String? _selectedAccountId;
  String _selectedCategoryId = 'investment';

  // Stock fields
  final _tickerController = TextEditingController();
  final _companyController = TextEditingController();
  final _quantityController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _currentPriceController = TextEditingController();
  final _sectorController = TextEditingController();
  String _exchange = 'NSE';

  @override
  void dispose() {
    _fundNameController.dispose();
    _amcController.dispose();
    _sipAmountController.dispose();
    _stepUpController.dispose();
    _tickerController.dispose();
    _companyController.dispose();
    _quantityController.dispose();
    _purchasePriceController.dispose();
    _currentPriceController.dispose();
    _sectorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final categories =
        ref.watch(categoriesByGroupProvider(CategoryGroup.investment));

    if (categories.isNotEmpty &&
        !categories.any((c) => c.id == _selectedCategoryId)) {
      _selectedCategoryId = categories.first.id;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Add Investment',
            style: AppTextStyles.headlineMedium),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Type toggle
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isSip = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12),
                        decoration: BoxDecoration(
                          color: _isSip
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text('SIP / Mutual Fund',
                              style:
                                  AppTextStyles.labelMedium.copyWith(
                            color: _isSip
                                ? Colors.white
                                : AppColors.textSecondary,
                          )),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isSip = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12),
                        decoration: BoxDecoration(
                          color: !_isSip
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text('Stock',
                              style:
                                  AppTextStyles.labelMedium.copyWith(
                            color: !_isSip
                                ? Colors.white
                                : AppColors.textSecondary,
                          )),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            accountsAsync.when(
              data: (accounts) {
                if (_selectedAccountId == null && accounts.isNotEmpty) {
                  _selectedAccountId = accounts.first.id;
                }
                return DropdownButtonFormField<String>(
                  value: _selectedAccountId,
                  decoration: const InputDecoration(
                    labelText: 'Autopay Account',
                    prefixIcon:
                        Icon(Icons.account_balance_wallet_rounded),
                  ),
                  items: accounts
                      .map((acc) => DropdownMenuItem(
                            value: acc.id,
                            child: Text('${acc.emoji} ${acc.name}'),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedAccountId = v),
                );
              },
              loading: () => const ShimmerCard(height: 56),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Investment Category',
                    ),
                    items: categories
                        .map((cat) => DropdownMenuItem(
                              value: cat.id,
                              child: Text('${cat.emoji} ${cat.name}'),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedCategoryId = v);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _showAddInvestmentCategoryDialog,
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Add Category',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isSip) ..._sipFields() else ..._stockFields(),
            const SizedBox(height: 32),
            GradientButton(
              label: _isLoading ? 'Saving...' : 'Add Investment',
              onTap: _isLoading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _sipFields() {
    return [
      TextFormField(
        controller: _fundNameController,
        decoration: const InputDecoration(
          labelText: 'Fund Name',
          hintText: 'e.g. Mirae Asset Large Cap',
        ),
        validator: Validators.required,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _amcController,
        decoration: const InputDecoration(
          labelText: 'AMC / Fund House',
          hintText: 'e.g. Mirae Asset',
        ),
        validator: Validators.required,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _sipAmountController,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'SIP Amount',
          prefixText: '₹ ',
        ),
        validator: Validators.amount,
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: _sipFrequency,
        decoration: const InputDecoration(labelText: 'Frequency'),
        items: _sipFrequencies
            .map((f) => DropdownMenuItem(
                value: f,
                child: Text(f[0].toUpperCase() + f.substring(1))))
            .toList(),
        onChanged: (v) => setState(() => _sipFrequency = v!),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _stepUpController,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Annual Step-Up % (optional)',
          hintText: 'e.g. 10',
        ),
      ),
    ];
  }

  List<Widget> _stockFields() {
    return [
      TextFormField(
        controller: _tickerController,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          labelText: 'Ticker Symbol',
          hintText: 'e.g. RELIANCE',
        ),
        validator: Validators.required,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _companyController,
        decoration: const InputDecoration(
          labelText: 'Company Name',
        ),
        validator: Validators.required,
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: _exchange,
        decoration: const InputDecoration(labelText: 'Exchange'),
        items: _exchanges
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (v) => setState(() => _exchange = v!),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _quantityController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Quantity',
        ),
        validator: Validators.required,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _purchasePriceController,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Purchase Price per Share',
          prefixText: '₹ ',
        ),
        validator: Validators.amount,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _currentPriceController,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Current Price per Share',
          prefixText: '₹ ',
        ),
        validator: Validators.amount,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _sectorController,
        decoration: const InputDecoration(
          labelText: 'Sector (optional)',
          hintText: 'e.g. Energy',
        ),
      ),
    ];
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an account')),
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      if (_isSip) {
        final sip = SipModel(
          id: '',
          userId: '',
          accountId: _selectedAccountId!,
          categoryId: _selectedCategoryId,
          fundName: _fundNameController.text.trim(),
          amc: _amcController.text.trim(),
          sipAmount: double.parse(_sipAmountController.text),
          frequency: _sipFrequency,
          startDate: DateTime.now(),
          stepUpPercent:
              double.tryParse(_stepUpController.text) ?? 0,
          totalInvested:
              double.parse(_sipAmountController.text),
          currentValue:
              double.parse(_sipAmountController.text),
          isActive: true,
        );
        await ref
            .read(investmentNotifierProvider.notifier)
            .addSip(sip);
      } else {
        final stock = StockModel(
          id: '',
          userId: '',
          accountId: _selectedAccountId!,
          categoryId: _selectedCategoryId,
          tickerSymbol:
              _tickerController.text.trim().toUpperCase(),
          companyName: _companyController.text.trim(),
          exchange: _exchange,
          quantity: int.parse(_quantityController.text),
          purchasePrice: double.parse(
              _purchasePriceController.text),
          currentPrice: double.parse(
              _currentPriceController.text),
          purchaseDate: DateTime.now(),
          sector: _sectorController.text.trim().isEmpty
              ? 'Other'
              : _sectorController.text.trim(),
        );
        await ref
            .read(investmentNotifierProvider.notifier)
            .addStock(stock);
      }
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

  Future<void> _showAddInvestmentCategoryDialog() async {
    final nameController = TextEditingController();
    final emojiController = TextEditingController(text: '📈');

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Investment Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emojiController,
              decoration: const InputDecoration(labelText: 'Emoji'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              await ref.read(categoryNotifierProvider.notifier).addCustomCategory(
                    name: name,
                    emoji: emojiController.text.trim().isEmpty
                        ? '📈'
                        : emojiController.text.trim(),
                    group: CategoryGroup.investment,
                  );
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
