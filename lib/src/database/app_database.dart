import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'tables/accounts_table.dart';
import 'tables/budgets_table.dart';
import 'tables/investments_table.dart';
import 'tables/loans_table.dart';
import 'tables/sms_inbox_table.dart';
import 'tables/transactions_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Accounts, Transactions, Budgets, Loans, Investments, SmsInbox])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Test-only constructor for pointing at an in-memory/custom executor.
  AppDatabase.forTesting(super.executor);

  static AppDatabase? _instance;
  static AppDatabase get instance => _instance ??= AppDatabase();

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // Indexes for the query patterns the app actually runs: filtering
          // a single account's history and date-range/category reporting.
          await customStatement(
            'CREATE INDEX idx_transactions_account_date ON transactions (account_id, date);',
          );
          await customStatement(
            'CREATE INDEX idx_transactions_category ON transactions (category);',
          );
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON;');
        },
      );

  /// Wipes every table, e.g. after a verified guest->cloud migration or a
  /// guest "start fresh" choice. Deletes children before parents so the
  /// accounts foreign key (ON DELETE RESTRICT) doesn't reject the parent
  /// deletes.
  Future<void> clearAllData() async {
    await transaction(() async {
      await delete(transactions).go();
      await delete(loans).go();
      await delete(investments).go();
      await delete(budgets).go();
      await delete(smsInbox).go();
      await delete(accounts).go();
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'finflow.db'));

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    return NativeDatabase.createInBackground(file);
  });
}
