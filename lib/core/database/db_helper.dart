import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../constants/db_constants.dart';
import 'db_migrations.dart';
import 'tables/customer_table.dart';
import 'tables/inventory_table.dart';
import 'tables/transaction_table.dart';
import 'tables/sync_queue_table.dart';

class DbHelper {
  static final DbHelper _instance = DbHelper._internal();
  static Database? _database;

  // Table instances
  late final CustomerTable customers;
  late final InventoryTable inventory;
  late final TransactionTable transactions;
  late final SyncQueueTable syncQueue;

  factory DbHelper() => _instance;

  DbHelper._internal() {
    // Initialize table instances
    customers = CustomerTable(this);
    inventory = InventoryTable(this);
    transactions = TransactionTable(this);
    syncQueue = SyncQueueTable(this);
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, DbConstants.databaseName);

    return await openDatabase(
      path,
      version: DbConstants.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    // Enable foreign keys
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await DbMigrations.createAllTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await DbMigrations.migrate(db, oldVersion, newVersion);
  }

  Future<void> _onOpen(Database db) async {
    // Any post-open operations
  }

  // ==================== GENERIC CRUD OPERATIONS ====================

  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(
      table,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    return await db.update(
      table,
      data,
      where: where,
      whereArgs: whereArgs,
    );
  }

  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    return await db.delete(
      table,
      where: where,
      whereArgs: whereArgs,
    );
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<dynamic>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return await db.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? arguments,
  ]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments);
  }

  Future<int> rawInsert(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawInsert(sql, arguments);
  }

  Future<int> rawUpdate(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawUpdate(sql, arguments);
  }

  Future<int> rawDelete(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawDelete(sql, arguments);
  }

  // ==================== TRANSACTION SUPPORT ====================

  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction(action);
  }

  // ==================== BATCH SUPPORT ====================

  Future<List<dynamic>> batch(void Function(Batch batch) actions) async {
    final db = await database;
    final batch = db.batch();
    actions(batch);
    return await batch.commit();
  }

  // ==================== UTILITY METHODS ====================

  Future<Map<String, dynamic>?> getById(String table, dynamic id) async {
    final results = await query(
      table,
      where: '${DbConstants.colLocalId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> count(String table, {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $table ${where != null ? 'WHERE $where' : ''}',
      whereArgs,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<bool> exists(String table, {String? where, List<dynamic>? whereArgs}) async {
    final c = await count(table, where: where, whereArgs: whereArgs);
    return c > 0;
  }

  Future<void> clearTable(String table) async {
    final db = await database;
    await db.delete(table);
  }

  Future<void> clearAllTables() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(DbConstants.transactionItemsTable);
      await txn.delete(DbConstants.transactionsTable);
      await txn.delete(DbConstants.inventoryTable);
      await txn.delete(DbConstants.customersTable);
      await txn.delete(DbConstants.syncQueueTable);
    });
  }

  // ==================== DATABASE MANAGEMENT ====================

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  Future<void> deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, DbConstants.databaseName);
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }

  Future<void> resetDatabase() async {
    final db = await database;
    await DbMigrations.resetDatabase(db);
  }

  /// Get database file size
  Future<int> getDatabaseSize() async {
    final dbPath = await getDatabasesPath();
    final dbFilePath = join(dbPath, DbConstants.databaseName);
    try {
      final f = File(dbFilePath);
      if (await f.exists()) return await f.length();
    } catch (_) {
      // ignore and return 0 on failure
    }
    return 0;
  }

  /// Vacuum database (optimize)
  Future<void> vacuum() async {
    final db = await database;
    await db.execute('VACUUM');
  }

  /// Check database integrity
  Future<bool> checkIntegrity() async {
    final db = await database;
    final result = await db.rawQuery('PRAGMA integrity_check');
    return result.isNotEmpty && result.first['integrity_check'] == 'ok';
  }
}