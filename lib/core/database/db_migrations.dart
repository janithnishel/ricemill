import 'package:sqflite/sqflite.dart';

import '../constants/db_constants.dart';
import 'tables/customer_table.dart';
import 'tables/inventory_table.dart';
import 'tables/transaction_table.dart';
import 'tables/sync_queue_table.dart';

class DbMigrations {
  DbMigrations._();

  /// Create all tables and indexes
  static Future<void> createAllTables(Database db) async {
    // Create tables
    await db.execute(CustomerTable.createTableSQL);
    await db.execute(InventoryTable.createTableSQL);
    await db.execute(TransactionTable.createTableSQL);
    await db.execute(TransactionTable.createItemsTableSQL);
    await db.execute(SyncQueueTable.createTableSQL);
    await _createSettingsTable(db);

    // Create indexes
    await _createAllIndexes(db);
  }

  /// Create settings table
  static Future<void> _createSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE ${DbConstants.settingsTable} (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        ${DbConstants.colUpdatedAt} TEXT NOT NULL
      )
    ''');
  }

  /// Create all indexes
  static Future<void> _createAllIndexes(Database db) async {
    // Customer indexes
    for (final sql in CustomerTable.createIndexesSQL) {
      try {
        await db.execute(sql);
      } catch (e) {
        // Index might already exist
        print('Index creation warning: $e');
      }
    }

    // Inventory indexes
    for (final sql in InventoryTable.createIndexesSQL) {
      try {
        await db.execute(sql);
      } catch (e) {
        print('Index creation warning: $e');
      }
    }

    // Transaction indexes
    for (final sql in TransactionTable.createIndexesSQL) {
      try {
        await db.execute(sql);
      } catch (e) {
        print('Index creation warning: $e');
      }
    }

    // Sync queue indexes
    for (final sql in SyncQueueTable.createIndexesSQL) {
      try {
        await db.execute(sql);
      } catch (e) {
        print('Index creation warning: $e');
      }
    }
  }

  /// Handle database migrations
  static Future<void> migrate(Database db, int oldVersion, int newVersion) async {
    // Migration logic for future versions
    
    if (oldVersion < 2) {
      await _migrateToV2(db);
    }
    
    if (oldVersion < 3) {
      await _migrateToV3(db);
    }
    
    // Add more migrations as needed
  }

  // ==================== MIGRATIONS ====================

  /// Migration to version 2 (example)
  static Future<void> _migrateToV2(Database db) async {
    // Example: Add new column to customers table
    // await db.execute('ALTER TABLE ${DbConstants.customersTable} ADD COLUMN email TEXT');
  }

  /// Migration to version 3 (example)
  static Future<void> _migrateToV3(Database db) async {
    // Example: Add new table or column
  }

  // ==================== UTILITIES ====================

  /// Drop all tables (for reset)
  static Future<void> dropAllTables(Database db) async {
    await db.execute('DROP TABLE IF EXISTS ${DbConstants.transactionItemsTable}');
    await db.execute('DROP TABLE IF EXISTS ${DbConstants.transactionsTable}');
    await db.execute('DROP TABLE IF EXISTS ${DbConstants.inventoryTable}');
    await db.execute('DROP TABLE IF EXISTS ${DbConstants.customersTable}');
    await db.execute('DROP TABLE IF EXISTS ${DbConstants.syncQueueTable}');
    await db.execute('DROP TABLE IF EXISTS ${DbConstants.settingsTable}');
  }

  /// Reset database (drop and recreate)
  static Future<void> resetDatabase(Database db) async {
    await dropAllTables(db);
    await createAllTables(db);
  }

  /// Check if table exists
  static Future<bool> tableExists(Database db, String tableName) async {
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );
    return result.isNotEmpty;
  }

  /// Get table info
  static Future<List<Map<String, dynamic>>> getTableInfo(
    Database db,
    String tableName,
  ) async {
    return await db.rawQuery('PRAGMA table_info($tableName)');
  }

  /// Check if column exists
  static Future<bool> columnExists(
    Database db,
    String tableName,
    String columnName,
  ) async {
    final tableInfo = await getTableInfo(db, tableName);
    return tableInfo.any((col) => col['name'] == columnName);
  }

  /// Add column if not exists
  static Future<void> addColumnIfNotExists(
    Database db,
    String tableName,
    String columnName,
    String columnDef,
  ) async {
    if (!await columnExists(db, tableName, columnName)) {
      await db.execute('ALTER TABLE $tableName ADD COLUMN $columnName $columnDef');
    }
  }
}