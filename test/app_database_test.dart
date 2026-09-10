import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:drift/native.dart';
import 'package:finflow/src/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('creates schema and round-trips an account', () async {
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'acc1',
            name: 'Test Account',
            type: 'bank',
            balance: 100.0,
            colorHex: '#000000',
          ),
        );

    final accounts = await db.select(db.accounts).get();
    expect(accounts, hasLength(1));
    expect(accounts.single.balance, 100.0);
    // SQL-level DEFAULT applies even though the companion never set it.
    expect(accounts.single.currency, 'INR');
  });

  test('foreign key from transactions to accounts is enforced', () async {
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'acc1',
            name: 'Test Account',
            type: 'bank',
            balance: 100.0,
            colorHex: '#000000',
          ),
        );
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            id: 'tx1',
            amount: 50.0,
            category: 'Groceries',
            bucket: 'needs',
            accountId: 'acc1',
            date: DateTime(2026, 1, 1),
            payee: 'Store',
          ),
        );

    // Deleting an account that still has a transaction referencing it must
    // be rejected by the ON DELETE RESTRICT foreign key, not silently orphan
    // the transaction the way the old unconstrained sqflite schema did.
    await expectLater(
      (db.delete(db.accounts)..where((a) => a.id.equals('acc1'))).go(),
      throwsA(anything),
    );

    final transactions = await db.select(db.transactions).get();
    expect(transactions, hasLength(1));
  });

  test(
    'clearAllData wipes every table without violating foreign keys',
    () async {
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'acc1',
              name: 'Test Account',
              type: 'bank',
              balance: 100.0,
              colorHex: '#000000',
            ),
          );
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              id: 'tx1',
              amount: 50.0,
              category: 'Groceries',
              bucket: 'needs',
              accountId: 'acc1',
              date: DateTime(2026, 1, 1),
              payee: 'Store',
            ),
          );

      await db.clearAllData();

      expect(await db.select(db.accounts).get(), isEmpty);
      expect(await db.select(db.transactions).get(), isEmpty);
    },
  );

  test(
    'local settings row is seeded on create and isPro is toggleable',
    () async {
      final initial = await db.watchLocalSettings().first;
      expect(initial.isPro, isFalse);

      await db.setPro(true);
      final updated = await db.watchLocalSettings().first;
      expect(updated.isPro, isTrue);
    },
  );

  test(
    'sms parse counter accumulates within a month and reads as zero for a stale month',
    () async {
      expect(await db.smsParsesThisMonth(), 0);

      await db.recordSmsParsed();
      await db.recordSmsParsed();
      expect(await db.smsParsesThisMonth(), 2);

      // Simulate a stale stored month (e.g. the app wasn't opened last month)
      // by writing one directly -- the counter should read as reset without
      // needing an explicit reset write.
      await (db.update(db.localSettings)..where((t) => t.id.equals(0))).write(
        const LocalSettingsCompanion(smsParseMonth: Value('2000-01')),
      );
      expect(await db.smsParsesThisMonth(), 0);

      // The next recordSmsParsed() call re-establishes the current month at 1,
      // not 3 -- confirming it doesn't just increment the stale count.
      await db.recordSmsParsed();
      expect(await db.smsParsesThisMonth(), 1);
    },
  );

  test(
    'insertOrIgnore does not reset SQLite last_insert_rowid on conflict '
    '(documents why insertSms checks existence explicitly instead)',
    () async {
      final firstInsert = await db
          .into(db.smsInbox)
          .insert(
            SmsInboxCompanion.insert(
              id: 'sms1',
              messageBody: 'first',
              sender: 'AD-HDFCBK',
              date: DateTime(2026, 1, 1),
            ),
            mode: InsertMode.insertOrIgnore,
          );

      final secondInsert = await db
          .into(db.smsInbox)
          .insert(
            SmsInboxCompanion.insert(
              id: 'sms1',
              messageBody: 'duplicate scan of the same message',
              sender: 'AD-HDFCBK',
              date: DateTime(2026, 1, 1),
            ),
            mode: InsertMode.insertOrIgnore,
          );

      // Both calls report the same rowid -- the ignored insert does NOT
      // return 0, it returns the previous successful insert's rowid. A
      // caller relying on "return value != 0" to detect a new row would be
      // wrong every time.
      expect(secondInsert, firstInsert);

      final rows = await db.select(db.smsInbox).get();
      expect(rows, hasLength(1));
      expect(
        rows.single.messageBody,
        'first',
      ); // untouched by the ignored insert
    },
  );
}
