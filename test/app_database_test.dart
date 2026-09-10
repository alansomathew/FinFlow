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
    await db.into(db.accounts).insert(AccountsCompanion.insert(
          id: 'acc1',
          name: 'Test Account',
          type: 'bank',
          balance: 100.0,
          colorHex: '#000000',
        ));

    final accounts = await db.select(db.accounts).get();
    expect(accounts, hasLength(1));
    expect(accounts.single.balance, 100.0);
    // SQL-level DEFAULT applies even though the companion never set it.
    expect(accounts.single.currency, 'INR');
  });

  test('foreign key from transactions to accounts is enforced', () async {
    await db.into(db.accounts).insert(AccountsCompanion.insert(
          id: 'acc1',
          name: 'Test Account',
          type: 'bank',
          balance: 100.0,
          colorHex: '#000000',
        ));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: 'tx1',
          amount: 50.0,
          category: 'Groceries',
          bucket: 'needs',
          accountId: 'acc1',
          date: DateTime(2026, 1, 1),
          payee: 'Store',
        ));

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

  test('clearAllData wipes every table without violating foreign keys', () async {
    await db.into(db.accounts).insert(AccountsCompanion.insert(
          id: 'acc1',
          name: 'Test Account',
          type: 'bank',
          balance: 100.0,
          colorHex: '#000000',
        ));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: 'tx1',
          amount: 50.0,
          category: 'Groceries',
          bucket: 'needs',
          accountId: 'acc1',
          date: DateTime(2026, 1, 1),
          payee: 'Store',
        ));

    await db.clearAllData();

    expect(await db.select(db.accounts).get(), isEmpty);
    expect(await db.select(db.transactions).get(), isEmpty);
  });
}
