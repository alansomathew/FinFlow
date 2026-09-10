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

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
