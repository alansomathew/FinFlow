import 'package:drift/drift.dart';
import 'accounts_table.dart';

/// A recurring-transaction template: everything needed to materialize a real
/// [Transactions] row on its due date, plus enough state (nextDueDate) to
/// know when that next materialization should happen. Client-side
/// materialization runs on app-open for now; a Cloud Function takes over
/// reliable app-closed execution once Phase 4 stands up that infra.
class RecurringRules extends Table {
  TextColumn get id => text()();
  RealColumn get amount => real()();
  TextColumn get category => text()();
  TextColumn get bucket => text()();
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.restrict)();
  TextColumn get payee => text()();
  TextColumn get note => text().nullable()();

  /// 'daily', 'weekly', or 'monthly'.
  TextColumn get frequency => text()();
  DateTimeColumn get nextDueDate => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}
