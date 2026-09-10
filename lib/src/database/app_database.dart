import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import '../utils/month_key.dart';
import 'tables/accounts_table.dart';
import 'tables/budgets_table.dart';
import 'tables/goals_table.dart';
import 'tables/investments_table.dart';
import 'tables/loans_table.dart';
import 'tables/local_settings_table.dart';
import 'tables/net_worth_snapshots_table.dart';
import 'tables/recurring_rules_table.dart';
import 'tables/sms_inbox_table.dart';
import 'tables/transactions_table.dart';

part 'app_database.g.dart';

const _singletonSettingsId = 0;

@DriftDatabase(
  tables: [
    Accounts,
    Transactions,
    Budgets,
    Loans,
    Investments,
    SmsInbox,
    LocalSettings,
    RecurringRules,
    Goals,
    NetWorthSnapshots,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Test-only constructor for pointing at an in-memory/custom executor.
  AppDatabase.forTesting(super.executor);

  static AppDatabase? _instance;
  static AppDatabase get instance => _instance ??= AppDatabase();

  @override
  int get schemaVersion => 8;

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
      await _seedLocalSettings();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(localSettings);
        await _seedLocalSettings();
      }
      if (from < 3) {
        await m.createTable(recurringRules);
      }
      if (from < 4) {
        await m.addColumn(localSettings, localSettings.smsParseCount);
        await m.addColumn(localSettings, localSettings.smsParseMonth);
      }
      if (from < 5) {
        // Budgets moves from category-only primary key (one row per
        // category, ever -- every month's save overwrote the last, so no
        // history could exist) to (category, monthYear), and drops the
        // stored spentAmount column entirely in favor of always deriving it
        // live from transactions. Pre-launch, no installed base to migrate
        // data for, so this is a clean drop-and-recreate rather than a
        // column-preserving migration.
        await m.deleteTable('budgets');
        await m.createTable(budgets);
      }
      if (from < 6) {
        await m.addColumn(accounts, accounts.ownerUids);
      }
      if (from < 7) {
        await m.createTable(goals);
      }
      if (from < 8) {
        await m.createTable(netWorthSnapshots);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
    },
  );

  Future<void> _seedLocalSettings() async {
    await into(
      localSettings,
    ).insert(const LocalSettingsCompanion(id: Value(_singletonSettingsId)));
  }

  /// The one-row local settings record, created on first launch by
  /// [migration]'s onCreate/onUpgrade.
  Stream<LocalSettingsRow> watchLocalSettings() {
    return (select(
      localSettings,
    )..where((t) => t.id.equals(_singletonSettingsId))).watchSingle();
  }

  Future<LocalSettingsRow> _getSettings() {
    return (select(
      localSettings,
    )..where((t) => t.id.equals(_singletonSettingsId))).getSingle();
  }

  Future<void> setPro(bool isPro) async {
    await (update(localSettings)
          ..where((t) => t.id.equals(_singletonSettingsId)))
        .write(LocalSettingsCompanion(isPro: Value(isPro)));
  }

  /// How many SMS have been parsed-to-ledger this calendar month. Resets
  /// implicitly: a stored month that doesn't match the current one reads as
  /// zero without needing an explicit reset write.
  Future<int> smsParsesThisMonth() async {
    final settings = await _getSettings();
    if (settings.smsParseMonth != monthKeyOf(DateTime.now())) return 0;
    return settings.smsParseCount;
  }

  Future<void> recordSmsParsed() async {
    final settings = await _getSettings();
    final currentMonth = monthKeyOf(DateTime.now());
    final newCount = settings.smsParseMonth == currentMonth
        ? settings.smsParseCount + 1
        : 1;
    await (update(
      localSettings,
    )..where((t) => t.id.equals(_singletonSettingsId))).write(
      LocalSettingsCompanion(
        smsParseCount: Value(newCount),
        smsParseMonth: Value(currentMonth),
      ),
    );
  }

  /// Wipes every table, e.g. after a verified guest->cloud migration or a
  /// guest "start fresh" choice. Deletes children before parents so the
  /// accounts foreign key (ON DELETE RESTRICT) doesn't reject the parent
  /// deletes.
  Future<void> clearAllData() async {
    await transaction(() async {
      await delete(recurringRules).go();
      await delete(transactions).go();
      await delete(loans).go();
      await delete(investments).go();
      await delete(budgets).go();
      await delete(goals).go();
      await delete(netWorthSnapshots).go();
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
