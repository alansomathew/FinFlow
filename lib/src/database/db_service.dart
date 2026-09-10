import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:async';

class DbService {
  static final DbService instance = DbService._init();
  static Database? _database;

  DbService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('finflow.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';
    const doubleType = 'REAL NOT NULL';
    const intType = 'INTEGER NOT NULL';

    // Accounts Table
    await db.execute('''
      CREATE TABLE accounts (
        id $textType PRIMARY KEY,
        name $textType,
        type $textType,
        balance $doubleType,
        credit_limit $doubleType,
        card_due_date $textNullable,
        color_hex $textType
      )
    ''');

    // Transactions Table
    await db.execute('''
      CREATE TABLE transactions (
        id $textType PRIMARY KEY,
        amount $doubleType,
        category $textType,
        bucket $textType,
        account_id $textType,
        date $textType,
        note $textNullable,
        payee $textType,
        is_recurring $intType,
        ref_id $textNullable
      )
    ''');

    // Budgets Table
    await db.execute('''
      CREATE TABLE budgets (
        category $textType PRIMARY KEY,
        limit_amount $doubleType,
        spent_amount $doubleType,
        month_year $textType
      )
    ''');

    // Loans Table
    await db.execute('''
      CREATE TABLE loans (
        id $textType PRIMARY KEY,
        lender_name $textType,
        loan_amount $doubleType,
        interest_rate $doubleType,
        tenure_months $intType,
        start_date $textType,
        emi_amount $doubleType,
        debit_account_id $textType
      )
    ''');

    // Investments Table
    await db.execute('''
      CREATE TABLE investments (
        id $textType PRIMARY KEY,
        type $textType,
        name $textType,
        units_quantity $doubleType,
        purchase_price $doubleType,
        current_price $doubleType,
        date_purchased $textType
      )
    ''');

    // SMS Inbox Table
    await db.execute('''
      CREATE TABLE sms_inbox (
        id $textType PRIMARY KEY,
        message_body $textType,
        sender $textType,
        date $textType,
        is_parsed $intType,
        is_skipped $intType
      )
    ''');
  }

  // --- CRUD Operations for Accounts ---
  Future<int> insertAccount(Map<String, dynamic> account) async {
    final db = await database;
    return await db.insert('accounts', account, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> queryAllAccounts() async {
    final db = await database;
    return await db.query('accounts');
  }

  Future<int> updateAccount(Map<String, dynamic> account) async {
    final db = await database;
    return await db.update(
      'accounts',
      account,
      where: 'id = ?',
      whereArgs: [account['id']],
    );
  }

  Future<int> deleteAccount(String id) async {
    final db = await database;
    return await db.delete(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- CRUD Operations for Transactions ---
  Future<int> insertTransaction(Map<String, dynamic> transaction) async {
    final db = await database;
    final res = await db.insert('transactions', transaction, conflictAlgorithm: ConflictAlgorithm.replace);
    
    // Auto-update account balance
    final accountId = transaction['account_id'];
    final amount = transaction['amount'] as double;
    final isDebit = transaction['bucket'] != 'Income'; // Simple rules: non-income reduces balance
    
    final accounts = await db.query('accounts', where: 'id = ?', whereArgs: [accountId]);
    if (accounts.isNotEmpty) {
      final account = Map<String, dynamic>.from(accounts.first);
      final currentBalance = account['balance'] as double;
      final newBalance = isDebit ? (currentBalance - amount) : (currentBalance + amount);
      account['balance'] = newBalance;
      await db.update('accounts', account, where: 'id = ?', whereArgs: [accountId]);
    }
    
    return res;
  }

  Future<List<Map<String, dynamic>>> queryAllTransactions() async {
    final db = await database;
    return await db.query('transactions', orderBy: 'date DESC');
  }

  Future<int> deleteTransaction(String id) async {
    final db = await database;
    
    // Reverse account balance modification before deleting
    final txs = await db.query('transactions', where: 'id = ?', whereArgs: [id]);
    if (txs.isNotEmpty) {
      final tx = txs.first;
      final accountId = tx['account_id'] as String;
      final amount = tx['amount'] as double;
      final isDebit = tx['bucket'] != 'Income';
      
      final accounts = await db.query('accounts', where: 'id = ?', whereArgs: [accountId]);
      if (accounts.isNotEmpty) {
        final account = Map<String, dynamic>.from(accounts.first);
        final currentBalance = account['balance'] as double;
        final newBalance = isDebit ? (currentBalance + amount) : (currentBalance - amount);
        account['balance'] = newBalance;
        await db.update('accounts', account, where: 'id = ?', whereArgs: [accountId]);
      }
    }
    
    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- CRUD Operations for Budgets ---
  Future<int> insertBudget(Map<String, dynamic> budget) async {
    final db = await database;
    return await db.insert('budgets', budget, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> queryAllBudgets() async {
    final db = await database;
    return await db.query('budgets');
  }

  Future<int> updateBudget(Map<String, dynamic> budget) async {
    final db = await database;
    return await db.update(
      'budgets',
      budget,
      where: 'category = ?',
      whereArgs: [budget['category']],
    );
  }

  // --- CRUD Operations for Loans ---
  Future<int> insertLoan(Map<String, dynamic> loan) async {
    final db = await database;
    return await db.insert('loans', loan, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> queryAllLoans() async {
    final db = await database;
    return await db.query('loans');
  }

  Future<int> deleteLoan(String id) async {
    final db = await database;
    return await db.delete(
      'loans',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- CRUD Operations for Investments ---
  Future<int> insertInvestment(Map<String, dynamic> investment) async {
    final db = await database;
    return await db.insert('investments', investment, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> queryAllInvestments() async {
    final db = await database;
    return await db.query('investments');
  }

  Future<int> deleteInvestment(String id) async {
    final db = await database;
    return await db.delete(
      'investments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- CRUD Operations for SMS Inbox ---
  Future<int> insertSms(Map<String, dynamic> sms) async {
    final db = await database;
    return await db.insert('sms_inbox', sms, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<Map<String, dynamic>>> queryAllSms() async {
    final db = await database;
    return await db.query('sms_inbox', orderBy: 'date DESC');
  }

  Future<int> updateSms(Map<String, dynamic> sms) async {
    final db = await database;
    return await db.update(
      'sms_inbox',
      sms,
      where: 'id = ?',
      whereArgs: [sms['id']],
    );
  }

  // --- Clear Database (For resetting or post-migration) ---
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('accounts');
    await db.delete('transactions');
    await db.delete('budgets');
    await db.delete('loans');
    await db.delete('investments');
    await db.delete('sms_inbox');
  }
}
