import 'package:drift/drift.dart';
import 'accounts_table.dart';

/// A savings goal, e.g. "Emergency Fund" or "Europe Trip". Unlike budgets,
/// currentAmount is genuinely stored rather than derived -- a contribution
/// is a deliberate manual action (there's no natural transaction category
/// that maps 1:1 to a specific goal the way spending maps to a budget
/// category), so it's mutated directly by GoalsRepository.contribute().
class Goals extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get targetAmount => real()();
  RealColumn get currentAmount => real().withDefault(const Constant(0.0))();
  DateTimeColumn get targetDate => dateTime().nullable()();
  TextColumn get icon => text().withDefault(const Constant('🎯'))();
  TextColumn get colorHex => text().withDefault(const Constant('#6366F1'))();

  /// Optional -- purely informational (e.g. "this goal's money lives in
  /// HDFC Savings"); contributions are always manual, never auto-tracked
  /// from this account's transactions.
  TextColumn get linkedAccountId =>
      text().nullable().references(Accounts, #id, onDelete: KeyAction.setNull)();

  TextColumn get currency => text().withDefault(const Constant('INR'))();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
