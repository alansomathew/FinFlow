import 'package:drift/drift.dart';
import 'accounts_table.dart';

class Loans extends Table {
  TextColumn get id => text()();
  TextColumn get lenderName => text()();
  RealColumn get loanAmount => real()();
  RealColumn get interestRate => real()(); // Annual %
  IntColumn get tenureMonths => integer()();
  TextColumn get startDate => text()();
  RealColumn get emiAmount => real()();
  TextColumn get debitAccountId =>
      text().references(Accounts, #id, onDelete: KeyAction.restrict)();
  TextColumn get currency => text().withDefault(const Constant('INR'))();

  /// When true, this loan is a credit-card EMI (a purchase converted to
  /// installments) rather than a standalone bank loan -- [debitAccountId]
  /// is then the credit card account whose statement includes this EMI,
  /// not a separate bank account being auto-debited.
  BoolColumn get isCardEmi => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
