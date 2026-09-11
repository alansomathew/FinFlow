import 'package:drift/drift.dart';

class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // 'bank', 'credit_card', 'wallet', 'cash'
  RealColumn get balance => real()();
  RealColumn get creditLimit => real().withDefault(const Constant(0.0))();
  TextColumn get cardDueDate => text().nullable()();
  TextColumn get colorHex => text()();
  TextColumn get currency => text().withDefault(const Constant('INR'))();

  /// Last 4 digits of the card/account number, as they'd appear in a bank
  /// SMS alert (e.g. "HDFC Bank Card xx1234 debited..."). Nullable and
  /// mainly meaningful for 'bank'/'credit_card' accounts -- lets
  /// SmsDuplicateDetector.resolveAccount match a parsed SMS to the exact
  /// account instead of guessing, which matters most for credit cards
  /// since a user often has several and a wrong guess misattributes real
  /// spending to the wrong card.
  TextColumn get cardLast4 => text().nullable()();

  /// JSON-encoded array of Firebase UIDs with access to this account, beyond
  /// the owner. Nullable and unused until Phase 11's joint wallet feature;
  /// added now so that feature doesn't need its own migration later.
  TextColumn get ownerUids => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
