import 'package:drift/drift.dart';

/// A category's budget *limit* for one calendar month. Deliberately has no
/// stored "spent" column -- how much has been spent is always derived live
/// from the transactions table (see BudgetRepository), never cached here,
/// so it can never drift out of sync with the ledger the way a manually
/// maintained running total could.
///
/// Primary key is (category, monthYear) rather than just category, so each
/// month gets its own row: this is what makes "previous months archived,
/// never deleted" (SRS §6) possible at all -- the old schema had category
/// alone as the key, so every month's save overwrote the last one and no
/// history could ever exist.
class Budgets extends Table {
  TextColumn get category => text()();
  TextColumn get monthYear => text()(); // 'YYYY-MM'
  RealColumn get limitAmount => real()();
  TextColumn get currency => text().withDefault(const Constant('INR'))();

  /// Pro-tier: unspent budget from this category carries over into next
  /// month's limit instead of resetting.
  BoolColumn get rolloverEnabled => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {category, monthYear};
}
