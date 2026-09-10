import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_sizes.dart';
import '../../../database/db_service.dart';
import '../../../utils/sms_parser.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/domain/transaction.dart';

class SmsSandboxSheet extends ConsumerStatefulWidget {
  const SmsSandboxSheet({super.key});

  @override
  ConsumerState<SmsSandboxSheet> createState() => _SmsSandboxSheetState();
}

class _SmsSandboxSheetState extends ConsumerState<SmsSandboxSheet> {
  final _textController = TextEditingController();
  List<Map<String, dynamic>> _smsQueue = [];
  ParsedSms? _parsedResult;
  bool _isDuplicate = false;

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadQueue() async {
    final list = await DbService.instance.queryAllSms();
    setState(() {
      _smsQueue = list.where((m) => m['is_parsed'] == 0 && m['is_skipped'] == 0).toList();
    });
  }

  void _parseCustomSms(String body) {
    if (body.isEmpty) return;
    
    final parsed = SmsParser.parse(body);
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to parse SMS. Verify currency/format.')),
      );
      setState(() {
        _parsedResult = null;
        _isDuplicate = false;
      });
      return;
    }

    _checkDuplicate(parsed);
  }

  Future<void> _checkDuplicate(ParsedSms parsed) async {
    final txs = await DbService.instance.queryAllTransactions();
    // Duplicate detection: Same amount + same day OR same reference ID
    bool dup = false;
    for (var tx in txs) {
      if (parsed.refId.isNotEmpty && tx['ref_id'] == parsed.refId) {
        dup = true;
        break;
      }
      // Check amount and same day
      final txDate = DateTime.parse(tx['date'] as String);
      final isSameDay = txDate.day == DateTime.now().day &&
                        txDate.month == DateTime.now().month &&
                        txDate.year == DateTime.now().year;
      if (tx['amount'] == parsed.amount && isSameDay) {
        dup = true;
        break;
      }
    }

    setState(() {
      _parsedResult = parsed;
      _isDuplicate = dup;
    });
  }

  Future<void> _addParsedToLedger(ParsedSms parsed, String smsId) async {
    final accounts = await ref.read(accountsRepositoryProvider).getAccounts();
    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create an account first')),
      );
      return;
    }

    // Match bank by last 4 digits, fallback to first account
    final matchingAccount = accounts.firstWhere(
      (a) => a.name.contains(parsed.accountLast4) || a.id.contains(parsed.accountLast4),
      orElse: () => accounts.first,
    );

    // Auto-map category
    final category = TransactionCategory.getByName(parsed.payee);

    final tx = TransactionModel(
      id: const Uuid().v4(),
      amount: parsed.amount,
      category: category.name,
      bucket: parsed.type == 'credit' ? BudgetBucket.income : category.bucket,
      accountId: matchingAccount.id,
      date: DateTime.now(),
      payee: parsed.payee,
      note: 'Auto-parsed from SMS alert',
      refId: parsed.refId,
    );

    // Write to ledger
    await ref.read(transactionListProvider.notifier).add(tx);
    await ref.read(accountListProvider.notifier).refresh();

    // Mark SMS as parsed in database
    await DbService.instance.updateSms({
      'id': smsId,
      'is_parsed': 1,
      'is_skipped': 0,
      'message_body': 'parsed', // placeholder update
      'sender': 'system',
      'date': DateTime.now().toIso8601String(),
    });

    _loadQueue();
    
    setState(() {
      _parsedResult = null;
      _textController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${_isDuplicate ? "Duplicate " : ""}Transaction: ₹${parsed.amount} to ${matchingAccount.name}'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _skipSms(String smsId) async {
    await DbService.instance.updateSms({
      'id': smsId,
      'is_parsed': 0,
      'is_skipped': 1,
      'message_body': 'skipped',
      'sender': 'system',
      'date': DateTime.now().toIso8601String(),
    });
    _loadQueue();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusLg)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Pull Bar Indicator
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
                'SMS Parsing Simulator',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              AppSizes.h16,

              // Paste Custom SMS Testing Panel
              Card(
                color: AppColors.cardBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMd)),
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Simulate Custom SMS Message',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      AppSizes.h8,
                      TextField(
                        controller: _textController,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Paste HDFC / SBI / ICICI transaction SMS here...',
                          hintStyle: const TextStyle(color: AppColors.textSecondary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          fillColor: AppColors.background,
                          filled: true,
                        ),
                      ),
                      AppSizes.h12,
                      ElevatedButton(
                        onPressed: () => _parseCustomSms(_textController.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusSm)),
                        ),
                        child: const Text('Parse SMS Text', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Dynamic Parsing Results Panel
              if (_parsedResult != null) ...[
                AppSizes.h12,
                Card(
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    side: BorderSide(color: _isDuplicate ? AppColors.error : AppColors.success, width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('PARSING PREVIEW', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                'Confidence: ${_parsedResult!.confidenceScore}%',
                                style: const TextStyle(color: AppColors.primaryLight, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        AppSizes.h12,
                        Text(
                          '₹${_parsedResult!.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: _parsedResult!.type == 'credit' ? AppColors.success : Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        AppSizes.h8,
                        Text('Merchant: ${_parsedResult!.payee}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                        Text('Account (last 4): ${_parsedResult!.accountLast4}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        if (_parsedResult!.refId.isNotEmpty)
                          Text('Ref ID: ${_parsedResult!.refId}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        
                        if (_isDuplicate) ...[
                          AppSizes.h8,
                          const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 16),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Duplicate Alert: A transaction with this amount has already been logged today.',
                                  style: TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ],
                        AppSizes.h16,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => setState(() => _parsedResult = null),
                              child: const Text('Discard', style: TextStyle(color: AppColors.textSecondary)),
                            ),
                            AppSizes.w12,
                            ElevatedButton(
                              onPressed: () => _addParsedToLedger(_parsedResult!, const Uuid().v4()),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isDuplicate ? AppColors.error : AppColors.success,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusSm)),
                              ),
                              child: Text(_isDuplicate ? 'Add Anyway' : 'Add to Ledger', style: const TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              
              AppSizes.h16,
              const Text(
                'Simulated Pending Inbox Reviews',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              AppSizes.h8,
              
              // Scrollable simulated queue
              Expanded(
                child: _smsQueue.isEmpty
                    ? const Center(
                        child: Text(
                          'No pending inbox items.\nType an SMS above to test parsing.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _smsQueue.length,
                        itemBuilder: (context, index) {
                          final sms = _smsQueue[index];
                          final body = sms['message_body'] as String;
                          final date = DateTime.parse(sms['date'] as String);

                          return Card(
                            color: AppColors.cardBg,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSizes.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        sms['sender'] as String,
                                        style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      Text(
                                        DateFormat('dd MMM hh:mm a').format(date),
                                        style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                  AppSizes.h8,
                                  Text(
                                    body,
                                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, height: 1.3),
                                  ),
                                  AppSizes.h12,
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton(
                                        onPressed: () => _skipSms(sms['id'] as String),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: AppColors.border),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusSm)),
                                        ),
                                        child: const Text('Skip', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                                      ),
                                      AppSizes.w8,
                                      ElevatedButton(
                                        onPressed: () {
                                          final parsed = SmsParser.parse(body);
                                          if (parsed != null) {
                                            _addParsedToLedger(parsed, sms['id'] as String);
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusSm)),
                                        ),
                                        child: const Text('Parse & Add', style: TextStyle(color: Colors.white, fontSize: 11)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
