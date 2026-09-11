import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../constants/app_sizes.dart';
import '../../../constants/app_theme.dart';
import '../../../database/app_database.dart';
import '../../../utils/sms_parser.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/domain/transaction.dart';
import '../data/sms_repository.dart';
import '../domain/sms_duplicate_detector.dart';

class SmsSandboxSheet extends ConsumerStatefulWidget {
  const SmsSandboxSheet({super.key});

  @override
  ConsumerState<SmsSandboxSheet> createState() => _SmsSandboxSheetState();
}

class _SmsSandboxSheetState extends ConsumerState<SmsSandboxSheet> {
  final _textController = TextEditingController();
  List<SmsInboxData> _smsQueue = [];
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
    final list = await ref.read(smsRepositoryProvider).getPendingInbox();
    setState(() {
      _smsQueue = list;
    });
  }

  void _parseCustomSms(String body) {
    if (body.isEmpty) return;

    final parsed = SmsParser.parse(body);
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to parse SMS. Verify currency/format.'),
        ),
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
    final txs = await ref.read(transactionRepositoryProvider).getTransactions();
    final accounts = await ref.read(accountsRepositoryProvider).getAccounts();
    final resolvedAccount = SmsDuplicateDetector.resolveAccount(
      accounts,
      parsed.accountLast4,
    );

    final dup = resolvedAccount != null
        ? SmsDuplicateDetector.isDuplicate(
            parsed: parsed,
            smsDate: DateTime.now(),
            resolvedAccountId: resolvedAccount.id,
            existingTransactions: txs,
          )
        : false;

    setState(() {
      _parsedResult = parsed;
      _isDuplicate = dup;
    });
  }

  Future<void> _addParsedToLedger(ParsedSms parsed, String smsId) async {
    final smsRepo = ref.read(smsRepositoryProvider);
    if (!await smsRepo.canParseMoreThisMonth()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Free tier allows up to $kFreeSmsParseLimit SMS parses per month. Upgrade to Pro for unlimited.',
          ),
          backgroundColor: context.colors.warning,
        ),
      );
      return;
    }

    final accounts = await ref.read(accountsRepositoryProvider).getAccounts();
    if (accounts.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create an account first')),
      );
      return;
    }

    final matchingAccount = SmsDuplicateDetector.resolveAccount(
      accounts,
      parsed.accountLast4,
    )!;

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

    // Mark SMS as parsed without touching its original message content;
    // also counts toward the free-tier monthly cap.
    await smsRepo.markParsed(smsId);

    _loadQueue();

    if (!mounted) return;
    setState(() {
      _parsedResult = null;
      _textController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added ${_isDuplicate ? "Duplicate " : ""}Transaction: ₹${parsed.amount} to ${matchingAccount.name}',
        ),
        backgroundColor: context.colors.success,
      ),
    );
  }

  Future<void> _skipSms(String smsId) async {
    await ref.read(smsRepositoryProvider).markSkipped(smsId);
    _loadQueue();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusLg),
        ),
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
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              AppSizes.h12,
              Text(
                'SMS Parsing Simulator',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppSizes.h16,

              // Paste Custom SMS Testing Panel
              Card(
                color: colors.cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Simulate Custom SMS Message',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      AppSizes.h8,
                      TextField(
                        controller: _textController,
                        maxLines: 2,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Paste HDFC / SBI / ICICI transaction SMS here...',
                          hintStyle: TextStyle(color: colors.textSecondary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusSm,
                            ),
                            borderSide: BorderSide(color: colors.border),
                          ),
                          fillColor: colors.background,
                          filled: true,
                        ),
                      ),
                      AppSizes.h12,
                      ElevatedButton(
                        onPressed: () => _parseCustomSms(_textController.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusSm,
                            ),
                          ),
                        ),
                        child: const Text(
                          'Parse SMS Text',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Dynamic Parsing Results Panel
              if (_parsedResult != null) ...[
                AppSizes.h12,
                Card(
                  color: colors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    side: BorderSide(
                      color: _isDuplicate ? colors.error : colors.success,
                      width: 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'PARSING PREVIEW',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                'Confidence: ${_parsedResult!.confidenceScore}%',
                                style: TextStyle(
                                  color: colors.primaryLight,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        AppSizes.h12,
                        Text(
                          '₹${_parsedResult!.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: _parsedResult!.type == 'credit'
                                ? colors.success
                                : Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        AppSizes.h8,
                        Text(
                          'Merchant: ${_parsedResult!.payee}',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Account (last 4): ${_parsedResult!.accountLast4}',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        if (_parsedResult!.refId.isNotEmpty)
                          Text(
                            'Ref ID: ${_parsedResult!.refId}',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),

                        if (_isDuplicate) ...[
                          AppSizes.h8,
                          Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: colors.error,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Duplicate Alert: A transaction with this amount has already been logged today.',
                                  style: TextStyle(
                                    color: colors.error,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
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
                              onPressed: () =>
                                  setState(() => _parsedResult = null),
                              child: Text(
                                'Discard',
                                style: TextStyle(color: colors.textSecondary),
                              ),
                            ),
                            AppSizes.w12,
                            ElevatedButton(
                              onPressed: () => _addParsedToLedger(
                                _parsedResult!,
                                const Uuid().v4(),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isDuplicate
                                    ? colors.error
                                    : colors.success,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.radiusSm,
                                  ),
                                ),
                              ),
                              child: Text(
                                _isDuplicate ? 'Add Anyway' : 'Add to Ledger',
                                style: const TextStyle(color: Colors.white),
                              ),
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
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppSizes.h8,

              // Scrollable simulated queue
              Expanded(
                child: _smsQueue.isEmpty
                    ? Center(
                        child: Text(
                          'No pending inbox items.\nType an SMS above to test parsing.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _smsQueue.length,
                        itemBuilder: (context, index) {
                          final sms = _smsQueue[index];
                          final body = sms.messageBody;
                          final date = sms.date;

                          return Card(
                            color: colors.cardBg,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSizes.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        sms.sender,
                                        style: TextStyle(
                                          color: colors.primaryLight,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        DateFormat(
                                          'dd MMM hh:mm a',
                                        ).format(date),
                                        style: TextStyle(
                                          color: colors.textMuted,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                  AppSizes.h8,
                                  Text(
                                    body,
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 12,
                                      height: 1.3,
                                    ),
                                  ),
                                  AppSizes.h12,
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton(
                                        onPressed: () => _skipSms(sms.id),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                            color: colors.border,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              AppSizes.radiusSm,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'Skip',
                                          style: TextStyle(
                                            color: colors.textSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      AppSizes.w8,
                                      ElevatedButton(
                                        onPressed: () {
                                          final parsed = SmsParser.parse(body);
                                          if (parsed != null) {
                                            _addParsedToLedger(parsed, sms.id);
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: colors.primary,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              AppSizes.radiusSm,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          'Parse & Add',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                          ),
                                        ),
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
