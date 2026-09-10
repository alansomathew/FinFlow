import 'package:drift/drift.dart';

class SmsInbox extends Table {
  TextColumn get id => text()();
  TextColumn get messageBody => text()();
  TextColumn get sender => text()();
  DateTimeColumn get date => dateTime()();
  BoolColumn get isParsed => boolean().withDefault(const Constant(false))();
  BoolColumn get isSkipped => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
