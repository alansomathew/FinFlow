import 'package:drift/drift.dart';
import 'accounts_table.dart';

class Transactions extends Table {
  TextColumn get id => text()();
  RealColumn get amount => real()();
  TextColumn get category => text()();
  TextColumn get bucket => text()();
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.restrict)();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();
  TextColumn get payee => text()();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  TextColumn get refId => text().nullable()();
  TextColumn get currency => text().withDefault(const Constant('INR'))();

  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
