import 'dart:io';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/sms_parser.dart';

class SmsService {
  static const _processedKey = 'processed_sms_ids';

  // Fetch pending transactions
  Future<List<SmsParsedTransaction>> fetchPendingTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final processedIds = prefs.getStringList(_processedKey)?.toSet() ?? {};

    List<SmsParsedTransaction> parsed = [];

    // 1. Try to read real SMS if on Android
    if (Platform.isAndroid) {
      try {
        final query = SmsQuery();
        final messages = await query.querySms(
          kinds: [SmsQueryKind.inbox],
        );
        for (final msg in messages) {
          final id = msg.id?.toString() ?? msg.body.hashCode.toString();
          if (processedIds.contains(id)) continue;
          
          final date = msg.date ?? DateTime.now();
          final parsedTx = SmsParser.parse(id, msg.body ?? '', date);
          if (parsedTx != null) {
            parsed.add(parsedTx);
          }
        }
      } catch (e) {
        print('Error reading native SMS: $e');
      }
    }

    // 2. If no real SMS parsed (or on emulator/simulator), load mock data for testing/demo
    if (parsed.isEmpty) {
      final now = DateTime.now();
      final mockSmsData = [
        {
          'id': 'mock_sms_1',
          'body': 'Dear Customer, your A/c ...5678 has been debited by Rs. 1,200.00 on 30-05-2026. Ref: UPI/6392019302 at SWIGGY.',
          'date': now.subtract(const Duration(minutes: 10)),
        },
        {
          'id': 'mock_sms_2',
          'body': 'Alert: Rs. 4,500.00 spent on Card ending 1234 at CROMA. Avl Bal: Rs 43,200.00.',
          'date': now.subtract(const Duration(minutes: 45)),
        },
        {
          'id': 'mock_sms_3',
          'body': 'Your account XXXXXX5678 has been credited with Rs. 50,000.00 on 30-05-2026. Ref: SALARY.',
          'date': now.subtract(const Duration(hours: 2)),
        },
      ];

      for (final mock in mockSmsData) {
        final id = mock['id'] as String;
        if (processedIds.contains(id)) continue;
        final parsedTx = SmsParser.parse(id, mock['body'] as String, mock['date'] as DateTime);
        if (parsedTx != null) {
          parsed.add(parsedTx);
        }
      }
    }

    // 3. Deduplicate
    // Filter duplicates: same amount, type, maskedNumber within 5 minutes or identical referenceId
    final List<SmsParsedTransaction> uniquePending = [];
    for (final tx in parsed) {
      bool isDuplicate = false;
      for (final existing in uniquePending) {
        // If reference IDs match and are not null
        if (tx.referenceId != null && tx.referenceId == existing.referenceId) {
          isDuplicate = true;
          break;
        }
        // If same amount, type, maskedNumber, and within 5 minutes
        if (tx.amount == existing.amount &&
            tx.type == existing.type &&
            tx.maskedNumber == existing.maskedNumber &&
            tx.date.difference(existing.date).abs().inMinutes <= 5) {
          isDuplicate = true;
          break;
        }
      }
      if (!isDuplicate) {
        uniquePending.add(tx);
      }
    }

    return uniquePending;
  }

  // Mark SMS as processed (imported or dismissed)
  Future<void> markAsProcessed(String smsId) async {
    final prefs = await SharedPreferences.getInstance();
    final processedIds = prefs.getStringList(_processedKey) ?? [];
    if (!processedIds.contains(smsId)) {
      processedIds.add(smsId);
      await prefs.setStringList(_processedKey, processedIds);
    }
  }

  // Mark multiple SMS as processed
  Future<void> markMultipleAsProcessed(List<String> smsIds) async {
    final prefs = await SharedPreferences.getInstance();
    final processedIds = prefs.getStringList(_processedKey) ?? [];
    for (final id in smsIds) {
      if (!processedIds.contains(id)) {
        processedIds.add(id);
      }
    }
    await prefs.setStringList(_processedKey, processedIds);
  }
}
