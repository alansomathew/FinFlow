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

  /// Best-effort match of a parsed SMS's account-last-4 digits to a
  /// concrete account -- an exact match against the account's own stored
  /// [AccountModel.cardLast4] first (set explicitly by the user when
  /// creating the account, so this is the only genuinely reliable check),
  /// falling back to a fuzzy "digits appear in the account name" heuristic
  /// for accounts that haven't set it. Returns null rather than guessing
  /// [accounts.first] when nothing matches -- a wrong guess silently
  /// misattributes real spending to the wrong account (most visibly, a
  /// credit card's spend landing on an unrelated bank account), so callers
  /// must ask the user to pick instead of trusting a blind default.
  static AccountModel? resolveAccount(
    List<AccountModel> accounts,
    String last4,
  ) {
    if (accounts.isEmpty || last4.isEmpty) return null;
    for (final a in accounts) {
      if (a.cardLast4.isNotEmpty && a.cardLast4 == last4) return a;
    }
    for (final a in accounts) {
      if (a.name.contains(last4) || a.id.contains(last4)) return a;
    }
    return null;
  }
}
