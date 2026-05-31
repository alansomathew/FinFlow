import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// SQLite database for storing guest-mode data locally.
/// All rows store raw JSON in a `data` column keyed by `id`.
class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  static Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'finflow_guest.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, _) async {
        for (final table in _tables) {
          await db.execute(
            'CREATE TABLE IF NOT EXISTS $table '
            '(id TEXT PRIMARY KEY, data TEXT NOT NULL)',
          );
        }
      },
      onUpgrade: (db, _, __) async {
        for (final table in _tables) {
          await db.execute(
            'CREATE TABLE IF NOT EXISTS $table '
            '(id TEXT PRIMARY KEY, data TEXT NOT NULL)',
          );
        }
      },
    );
  }

  static const List<String> _tables = [
    'transactions',
    'accounts',
    'budgets',
    'savings_goals',
    'investments',
    'loans',
    'categories',
  ];

  // ── Generic CRUD ────────────────────────────────────────────────────────────

  Future<void> upsert(String table, String id, Map<String, dynamic> data) async {
    final d = await db;
    await d.insert(
      table,
      {'id': id, 'data': jsonEncode(data)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String table, String id) async {
    final d = await db;
    await d.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> getById(String table, String id) async {
    final d = await db;
    final rows = await d.query(table, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['data'] as String) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getAll(String table) async {
    final d = await db;
    final rows = await d.query(table);
    return rows
        .map((r) => jsonDecode(r['data'] as String) as Map<String, dynamic>)
        .toList();
  }

  Future<void> update(
      String table, String id, Map<String, dynamic> fields) async {
    final existing = await getById(table, id);
    if (existing == null) return;
    existing.addAll(fields);
    await upsert(table, id, existing);
  }

  /// Delete every row in every table — called after a successful cloud sync.
  Future<void> clearAll() async {
    final d = await db;
    for (final table in _tables) {
      await d.delete(table);
    }
  }
}
