import 'package:drift/drift.dart';

class Budgets extends Table {
  TextColumn get category => text()();
  RealColumn get limitAmount => real()();
  RealColumn get spentAmount => real()();
  TextColumn get monthYear => text()(); // 'YYYY-MM'
  TextColumn get currency => text().withDefault(const Constant('INR'))();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {category};
}
