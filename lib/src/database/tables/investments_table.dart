import 'package:drift/drift.dart';

class Investments extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()(); // 'SIP', 'Mutual Fund', 'Stock'
  TextColumn get name => text()();
  RealColumn get unitsQuantity => real()();
  RealColumn get purchasePrice => real()();
  RealColumn get currentPrice => real()();
  TextColumn get datePurchased => text()();
  TextColumn get currency => text().withDefault(const Constant('INR'))();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
