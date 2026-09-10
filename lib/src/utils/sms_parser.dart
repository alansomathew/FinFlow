import 'package:flutter/foundation.dart';

class ParsedSms {
  final double amount;
  final String accountLast4;
  final String payee;
  final String type; // 'debit' or 'credit'
  final String refId;
  final int confidenceScore;

  ParsedSms({
    required this.amount,
    required this.accountLast4,
    required this.payee,
    required this.type,
    required this.refId,
    required this.confidenceScore,
  });

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'accountLast4': accountLast4,
      'payee': payee,
      'type': type,
      'refId': refId,
      'confidenceScore': confidenceScore,
    };
  }
}

class SmsParser {
  // Regex pattern matcher for Indian Bank SMS notifications
  static ParsedSms? parse(String messageBody) {
    try {
      final text = messageBody.toUpperCase();
      double? amount;
      String accountLast4 = '0000';
      String payee = 'Unknown Merchant';
      String type = 'debit';
      String refId = '';
      int confidence = 0;

      // 1. Determine transaction type (debit / credit)
      if (text.contains('CREDITED') ||
          text.contains('RECEIVED') ||
          text.contains('DEPOSITED')) {
        type = 'credit';
      } else if (text.contains('DEBITED') ||
          text.contains('SPENT') ||
          text.contains('CHARGED') ||
          text.contains('PAID TO')) {
        type = 'debit';
      }

      // 2. Parse Amount
      final amountRegex = RegExp(
        r'(?:RS\.?|INR)\s*([\d,]+\.?\d*)',
        caseSensitive: false,
      );
      final amountMatch = amountRegex.firstMatch(text);
      if (amountMatch != null) {
        final rawAmount = amountMatch.group(1)?.replaceAll(',', '') ?? '0';
        amount = double.tryParse(rawAmount);
        confidence += 30;
      }

      // 3. Parse Account Last 4
      final accountRegex = RegExp(
        r'(?:A/C|CARD|ACC|ACCOUNT)\s*(?:XX|X)*(\d{4})',
        caseSensitive: false,
      );
      final accountMatch = accountRegex.firstMatch(text);
      if (accountMatch != null) {
        accountLast4 = accountMatch.group(1) ?? '0000';
        confidence += 25;
      }

      // 4. Parse Ref / UPI ID
      final refRegex = RegExp(
        r'(?:REF|REF\s*NO|UPI|TXN|TXN\s*ID)[:\s]*([\w\d]{6,16})',
        caseSensitive: false,
      );
      final refMatch = refRegex.firstMatch(text);
      if (refMatch != null) {
        refId = refMatch.group(1) ?? '';
        confidence += 25;
      }

      // 5. Parse Payee / Merchant Name
      // Look for "TO MERCHANT" or "AT MERCHANT" or "INFO/MERCHANT"
      final merchantRegex = RegExp(
        r'(?:TO|AT|INFO|INFO\s*FOR|SHOP)\s+([A-Z0-9\s\-]{3,15})(?:\.|\s+ON|\s+REF|\s+BAL)',
        caseSensitive: false,
      );
      final merchantMatch = merchantRegex.firstMatch(text);
      if (merchantMatch != null) {
        payee = merchantMatch.group(1)?.trim() ?? 'Unknown Merchant';
        confidence += 20;
      } else {
        // Fallback: search for prominent Indian merchants
        final merchants = [
          'SWIGGY',
          'ZOMATO',
          'AMAZON',
          'FLIPKART',
          'PAYTM',
          'PHONEPE',
          'UBER',
          'OLA',
          'NETFLIX',
          'SPOTIFY',
          'KITE',
          'ZERODHA',
        ];
        for (var m in merchants) {
          if (text.contains(m)) {
            payee = m;
            confidence += 15;
            break;
          }
        }
      }

      if (amount != null) {
        return ParsedSms(
          amount: amount,
          accountLast4: accountLast4,
          payee: payee,
          type: type,
          refId: refId,
          confidenceScore: confidence,
        );
      }
    } catch (e) {
      debugPrint("SMS Parsing error: $e");
    }
    return null;
  }
}
