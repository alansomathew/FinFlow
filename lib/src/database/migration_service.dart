import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../features/accounts/data/accounts_repository.dart';
import '../features/budget/data/budget_repository.dart';
import '../features/debt/data/debt_repository.dart';
import '../features/investments/data/investments_repository.dart';
import '../features/transactions/domain/transaction.dart';
import 'app_database.dart';

/// Result of a guest-to-cloud migration attempt.
enum MigrationResult { success, failed }

class MigrationService {
  /// Copies all local guest data to Firestore under [uid]. Local data is
  /// left in place either way: on success it becomes the warm offline
  /// cache for the newly-linked account (every repository already
  /// write-throughs to both Firestore and local for real accounts); on
  /// failure ([MigrationResult.failed]) it's simply the only copy that
  /// still exists, since the Firestore write never verifiably committed.
  /// The caller should surface a failure rather than silently proceeding
  /// as if the backup succeeded.
  static Future<MigrationResult> migrateGuestDataToFirebase(String uid) async {
    final db = AppDatabase.instance;

    try {
      // Load all data from the local database
      final accounts = (await db.select(db.accounts).get())
          .map(AccountModel.fromRow)
          .toList();
      final transactions = (await db.select(db.transactions).get())
          .map(TransactionModel.fromRow)
          .toList();
      final budgets = (await db.select(db.budgets).get())
          .map(BudgetModel.fromRow)
          .toList();
      final loans = (await db.select(db.loans).get())
          .map(LoanModel.fromRow)
          .toList();
      final investments = (await db.select(db.investments).get())
          .map(InvestmentModel.fromRow)
          .toList();
      final sms = await db.select(db.smsInbox).get();

      debugPrint(
        "Migration started for user $uid. Migrating ${accounts.length} accounts, ${transactions.length} transactions...",
      );

      final fs = FirebaseFirestore.instance;
      final batch = fs.batch();

      // Migrate Accounts
      for (var account in accounts) {
        final docRef = fs
            .collection('users')
            .doc(uid)
            .collection('accounts')
            .doc(account.id);
        batch.set(docRef, account.toMap());
      }

      // Migrate Transactions
      for (var tx in transactions) {
        final docRef = fs
            .collection('users')
            .doc(uid)
            .collection('transactions')
            .doc(tx.id);
        batch.set(docRef, tx.toMap());
      }

      // Migrate Budgets
      for (var budget in budgets) {
        final docRef = fs
            .collection('users')
            .doc(uid)
            .collection('budgets')
            .doc(budget.category);
        batch.set(docRef, budget.toMap());
      }

      // Migrate Loans
      for (var loan in loans) {
        final docRef = fs
            .collection('users')
            .doc(uid)
            .collection('loans')
            .doc(loan.id);
        batch.set(docRef, loan.toMap());
      }

      // Migrate Investments
      for (var inv in investments) {
        final docRef = fs
            .collection('users')
            .doc(uid)
            .collection('investments')
            .doc(inv.id);
        batch.set(docRef, inv.toMap());
      }

      // Migrate SMS
      for (var msg in sms) {
        final docRef = fs
            .collection('users')
            .doc(uid)
            .collection('sms_inbox')
            .doc(msg.id);
        batch.set(docRef, {
          'id': msg.id,
          'message_body': msg.messageBody,
          'sender': msg.sender,
          'date': msg.date.toIso8601String(),
          'is_parsed': msg.isParsed ? 1 : 0,
          'is_skipped': msg.isSkipped ? 1 : 0,
        });
      }

      // Let this throw on failure — do NOT catch-and-continue. A caught
      // failure here previously fell through to clearAllData() regardless,
      // which deleted the user's only copy of their data. Propagate instead.
      await batch.commit();

      // Deliberately NOT clearing local data here. Every repository already
      // write-throughs to both Firestore and local SQLite for real accounts
      // and falls back to the local copy if a Firestore read fails (offline,
      // transient error, etc.) -- local is the app's offline cache, not
      // guest-only storage. Wiping it immediately after migration would
      // leave that cache empty, so a user who loses connectivity right
      // after joining would see an empty app despite their data being safe
      // in Firestore. Since batch.commit() just verified above, local and
      // Firestore now hold the same data under the same IDs, so keeping
      // local is exactly the warm cache the offline-fallback path expects.
      debugPrint("Migration completed successfully!");
      return MigrationResult.success;
    } catch (e) {
      debugPrint("Migration failed, local data left intact: $e");
      return MigrationResult.failed;
    }
  }
}
