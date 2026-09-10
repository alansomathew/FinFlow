import 'package:flutter_test/flutter_test.dart';
import 'package:finflow/src/utils/sms_parser.dart';

void main() {
  group('SMS Parser Engine Tests', () {
    test('HDFC Debit SMS Parsing', () {
      const sms = 'Alert: Rs 1,850.00 debited from HDFC A/c xx8712 to SWIGGY. Ref 61502939.';
      final parsed = SmsParser.parse(sms);
      
      expect(parsed, isNotNull);
      expect(parsed!.amount, 1850.0);
      expect(parsed.accountLast4, '8712');
      expect(parsed.payee, 'SWIGGY');
      expect(parsed.type, 'debit');
      expect(parsed.refId, '61502939');
      expect(parsed.confidenceScore, greaterThanOrEqualTo(80));
    });

    test('SBI Debit SMS Parsing', () {
      const sms = 'Dear Customer, SBI A/c xx5678 debited by Rs 500.00 via UPI to RAJESH STORES. Ref 61503120.';
      final parsed = SmsParser.parse(sms);
      
      expect(parsed, isNotNull);
      expect(parsed!.amount, 500.0);
      expect(parsed.accountLast4, '5678');
      expect(parsed.payee, 'RAJESH STORES');
      expect(parsed.type, 'debit');
      expect(parsed.refId, '61503120');
    });

    test('ICICI Debit SMS Parsing', () {
      const sms = 'ICICI Bank Card xx2001 debited by Rs 2,450.00 at AMAZON INDIA on 29-May-2026.';
      final parsed = SmsParser.parse(sms);
      
      expect(parsed, isNotNull);
      expect(parsed!.amount, 2450.0);
      expect(parsed.accountLast4, '2001');
      expect(parsed.payee, 'AMAZON INDIA');
      expect(parsed.type, 'debit');
    });

    test('Non-financial SMS Parsing Fallback', () {
      const sms = 'Meeting scheduled at 4 PM tomorrow. Please join.';
      final parsed = SmsParser.parse(sms);
      expect(parsed, isNull);
    });
  });
}
