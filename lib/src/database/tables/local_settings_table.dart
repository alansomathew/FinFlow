import 'package:drift/drift.dart';

/// Single-row table of local, device-scoped app settings that aren't part of
/// the user's synced financial data. Currently just the Pro-tier flag,
/// manually toggleable until Phase 11 wires up real billing -- introduced
/// now so every free/Pro gate from here on has a real field to read instead
/// of being invented ad hoc per phase.
@DataClassName('LocalSettingsRow')
class LocalSettings extends Table {
  IntColumn get id => integer()();
  BoolColumn get isPro => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
