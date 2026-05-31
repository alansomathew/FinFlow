import '../../features/transactions/domain/models/transaction_model.dart';

class SmsParsedTransaction {
  final String smsId;
  final String body;
  final double amount;
  final TransactionType type;
  final String? maskedNumber; // e.g. "1234"
  final String? payee;
  final DateTime date;
  final String? referenceId;

  SmsParsedTransaction({
    required this.smsId,
    required this.body,
    required this.amount,
    required this.type,
    this.maskedNumber,
    this.payee,
    required this.date,
    this.referenceId,
  });

  Map<String, dynamic> toMap() {
    return {
      'smsId': smsId,
      'body': body,
      'amount': amount,
      'type': type.name,
      'maskedNumber': maskedNumber,
      'payee': payee,
      'date': date.toIso8601String(),
      'referenceId': referenceId,
    };
  }

  factory SmsParsedTransaction.fromMap(Map<String, dynamic> map) {
    return SmsParsedTransaction(
      smsId: map['smsId'] as String,
      body: map['body'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: TransactionType.values.byName(map['type'] as String),
      maskedNumber: map['maskedNumber'] as String?,
      payee: map['payee'] as String?,
      date: DateTime.parse(map['date'] as String),
      referenceId: map['referenceId'] as String?,
    );
  }
}

class SmsParser {
  static SmsParsedTransaction? parse(String id, String body, DateTime date) {
    final lowerBody = body.toLowerCase();
    
    // Check if it is a transaction message
    final isDebit = lowerBody.contains('debited') || 
                    lowerBody.contains('spent') || 
                    lowerBody.contains('paid') || 
                    lowerBody.contains('withdrawn') || 
                    lowerBody.contains('sent to') ||
                    lowerBody.contains('charged');
                    
    final isCredit = lowerBody.contains('credited') || 
                     lowerBody.contains('received') || 
                     lowerBody.contains('deposited') ||
                     lowerBody.contains('refunded');
                     
    if (!isDebit && !isCredit) return null;

    // Parse amount
    // Matches "Rs. 1,000.00", "Rs 500", "INR 300", "Rs.500", etc.
    final amountRegex = RegExp(r'(?:Rs\.?|INR)\s*([0-9,]+\.?[0-9]*)', caseSensitive: false);
    final amountMatch = amountRegex.firstMatch(body);
    if (amountMatch == null) return null;
    
    final cleanAmountStr = amountMatch.group(1)!.replaceAll(',', '');
    final amount = double.tryParse(cleanAmountStr);
    if (amount == null || amount <= 0) return null;

    // Parse masked account/card number
    final accountRegex = RegExp(
      r'(?:a/c|acct|account|card|ending)\s*(?:no\.?)?\s*(?:\.|\b|\s)*([xX\*]*\d{4})',
      caseSensitive: false,
    );
    final accountMatch = accountRegex.firstMatch(body) ?? RegExp(r'(?:\.\.\.)(\d{4})').firstMatch(body);
    String? maskedNumber;
    if (accountMatch != null) {
      final matchStr = accountMatch.group(1) ?? accountMatch.group(0);
      if (matchStr != null) {
        final digits = RegExp(r'\d{4}$').firstMatch(matchStr);
        if (digits != null) {
          maskedNumber = digits.group(0);
        }
      }
    }

    // Parse reference ID
    final refRegex = RegExp(r'(?:ref(?:\s*no\.?)?|txn(?:\s*no\.?)?|reference)\s*:?\s*([a-zA-Z0-9]+)', caseSensitive: false);
    final refMatch = refRegex.firstMatch(body);
    final referenceId = refMatch?.group(1);

    // Try to extract payee
    String? payee;
    final payeeAtRegex = RegExp(r'(?:at|to|info)\s+([a-zA-Z0-9\s&]{3,20})(?:\.|\s|$)', caseSensitive: false);
    final payeeMatch = payeeAtRegex.firstMatch(body);
    if (payeeMatch != null) {
      payee = payeeMatch.group(1)?.trim();
    }
    
    // Default payee based on type
    if (payee == null || payee.toLowerCase() == 'a/c' || payee.isEmpty) {
      payee = isDebit ? 'Merchant' : 'Sender';
    }

    return SmsParsedTransaction(
      smsId: id,
      body: body,
      amount: amount,
      type: isDebit ? TransactionType.debit : TransactionType.credit,
      maskedNumber: maskedNumber,
      payee: payee,
      date: date,
      referenceId: referenceId,
    );
  }
}
