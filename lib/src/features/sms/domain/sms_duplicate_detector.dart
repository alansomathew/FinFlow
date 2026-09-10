import '../../accounts/data/accounts_repository.dart';
import '../../transactions/domain/transaction.dart';
import '../../../utils/sms_parser.dart';

/// Duplicate detection per the SRS composite key:
/// - Secondary check: an exact reference/UPI ID match is an immediate duplicate.
/// - Primary check: same amount + same resolved account + same transaction
///   type (credit/debit) on the same calendar day.
/// - Time window: same amount within +/-5 minutes is also a duplicate --
///   this is what collapses the common "bank SMS + UPI app SMS for the same
///   transaction" case (they usually land a few seconds apart) into one
///   prompt instead of two.
class SmsDuplicateDetector {
  static bool isDuplicate({
    required ParsedSms parsed,
    required DateTime smsDate,
    required String resolvedAccountId,
    required List<TransactionModel> existingTransactions,
  }) {
    for (final tx in existingTransactions) {
      if (parsed.refId.isNotEmpty && tx.refId == parsed.refId) {
        return true;
      }

      if (tx.amount != parsed.amount) continue;

      final sameDay =
          tx.date.year == smsDate.year &&
          tx.date.month == smsDate.month &&
          tx.date.day == smsDate.day;
      final withinFiveMinutes =
          tx.date.difference(smsDate).abs() <= const Duration(minutes: 5);
      final sameAccount = tx.accountId == resolvedAccountId;
      final sameType =
          (parsed.type == 'credit') == (tx.bucket == BudgetBucket.income);

      if ((sameDay && sameAccount && sameType) || withinFiveMinutes) {
        return true;
      }
    }
    return false;
  }

  /// Resolves a parsed SMS's account-last-4 digits to a concrete account,
  /// using the same heuristic transaction creation itself uses (match by
  /// name/id containing the digits, falling back to the first account) so
  /// duplicate checks are consistent with what actually gets created.
  static AccountModel? resolveAccount(
    List<AccountModel> accounts,
    String last4,
  ) {
    if (accounts.isEmpty) return null;
    for (final a in accounts) {
      if (a.name.contains(last4) || a.id.contains(last4)) return a;
    }
    return accounts.first;
  }
}
