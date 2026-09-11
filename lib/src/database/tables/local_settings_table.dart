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

  /// Free-tier SMS-parse counter: how many parses have happened in
  /// [smsParseMonth] ('YYYY-MM'). Reset client-side whenever the current
  /// month no longer matches; consolidates into a proper scheduled reset
  /// once Phase 4 stands up Cloud Functions infra.
  IntColumn get smsParseCount => integer().withDefault(const Constant(0))();
  TextColumn get smsParseMonth => text().nullable()();

  /// 'light', 'dark', or 'system'. Defaults to 'dark' to preserve the
  /// app's original dark-first look for existing installs -- this wasn't a
  /// user choice before this column existed, so it shouldn't silently
  /// change on upgrade.
  TextColumn get themeMode => text().withDefault(const Constant('dark'))();

  /// ISO language code ('hi', 'ta', 'kn', 'mr', 'ml', ...), or null to
  /// follow the device's system locale.
  TextColumn get languageCode => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
