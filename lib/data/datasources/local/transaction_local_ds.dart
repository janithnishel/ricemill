// lib/data/datasources/local/transaction_local_ds.dart

import 'package:sqflite/sqflite.dart';
import '../../../core/database/db_helper.dart';
import '../../../core/database/tables/transaction_table.dart';
import '../../../core/constants/db_constants.dart';
import '../../../core/constants/enums.dart';
import '../../../core/errors/exceptions.dart';
import '../../models/transaction_model.dart';
import '../../models/transaction_item_model.dart';

abstract class TransactionLocalDataSource {
  /// Get all transactions
  Future<List<TransactionModel>> getAllTransactions();

  /// Get transaction by ID
  Future<TransactionModel?> getTransactionById(String id);

  /// Get transactions by type (Buy/Sell)
  Future<List<TransactionModel>> getTransactionsByType(TransactionType type);

  /// Get transactions by customer
  Future<List<TransactionModel>> getTransactionsByCustomer(String customerId);

  /// Get transactions by date range
  Future<List<TransactionModel>> getTransactionsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    TransactionType? type,
  });

  /// Get today's transactions
  Future<List<TransactionModel>> getTodayTransactions({TransactionType? type});

  /// Insert new transaction with items
  Future<TransactionModel> insertTransaction(TransactionModel transaction);

  /// Update transaction
  Future<TransactionModel> updateTransaction(TransactionModel transaction);

  /// Delete transaction (soft delete)
  Future<bool> deleteTransaction(String id);

  /// Cancel transaction
  Future<bool> cancelTransaction(String id, String reason);

  /// Get transaction items
  Future<List<TransactionItemModel>> getTransactionItems(String transactionId);

  /// Add transaction item
  Future<TransactionItemModel> addTransactionItem(TransactionItemModel item);

  /// Update transaction item
  Future<TransactionItemModel> updateTransactionItem(TransactionItemModel item);

  /// Delete transaction item
  Future<bool> deleteTransactionItem(String id);

  /// Get unsynced transactions
  Future<List<TransactionModel>> getUnsyncedTransactions();

  /// Mark transaction as synced
  Future<void> markTransactionAsSynced(String id, String serverId);

  /// Get total amount by type for date range
  Future<Map<String, double>> getTotalsByTypeForDateRange({
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Get daily summary
  Future<Map<String, dynamic>> getDailySummary(DateTime date);

  /// Get monthly summary
  Future<Map<String, dynamic>> getMonthlySummary(int year, int month);

  /// Get transactions count
  Future<int> getTransactionsCount({TransactionType? type});

  /// Search transactions
  Future<List<TransactionModel>> searchTransactions(String query);

  /// Batch insert transactions (for sync)
  Future<void> batchInsertTransactions(List<TransactionModel> transactions);

  /// Clear all transactions
  Future<void> clearAllTransactions();

  /// Generate unique transaction number
  Future<String> generateTransactionNumber(TransactionType type);
}

class TransactionLocalDataSourceImpl implements TransactionLocalDataSource {
  final DbHelper dbHelper;

  TransactionLocalDataSourceImpl({required this.dbHelper});

  @override
  Future<List<TransactionModel>> getAllTransactions() async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        TransactionTable.tableName,
        where: '${TransactionTable.colIsDeleted} = ?',
        whereArgs: [0],
        orderBy: '${TransactionTable.colCreatedAt} DESC',
      );

      List<TransactionModel> transactions = [];
      for (final map in maps) {
        final transaction = TransactionModel.fromJson(map);
        final items = await getTransactionItems(transaction.id);
        transactions.add(transaction.copyWith(items: items));
      }

      return transactions;
    } catch (e) {
      throw CacheException(message: 'Failed to get transactions: ${e.toString()}');
    }
  }

  @override
  Future<TransactionModel?> getTransactionById(String id) async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        TransactionTable.tableName,
        where: '${TransactionTable.colId} = ? AND ${TransactionTable.colIsDeleted} = ?',
        whereArgs: [id, 0],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        final transaction = TransactionModel.fromJson(maps.first);
        final items = await getTransactionItems(id);
        return transaction.copyWith(items: items);
      }
      return null;
    } catch (e) {
      throw CacheException(message: 'Failed to get transaction: ${e.toString()}');
    }
  }

  @override
  Future<List<TransactionModel>> getTransactionsByType(TransactionType type) async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        TransactionTable.tableName,
        where: '${TransactionTable.colType} = ? AND ${TransactionTable.colIsDeleted} = ?',
        whereArgs: [type.name, 0],
        orderBy: '${TransactionTable.colCreatedAt} DESC',
      );

      List<TransactionModel> transactions = [];
      for (final map in maps) {
        final transaction = TransactionModel.fromJson(map);
        final items = await getTransactionItems(transaction.id);
        transactions.add(transaction.copyWith(items: items));
      }

      return transactions;
    } catch (e) {
      throw CacheException(message: 'Failed to get transactions by type: ${e.toString()}');
    }
  }

  @override
  Future<List<TransactionModel>> getTransactionsByCustomer(String customerId) async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        TransactionTable.tableName,
        where: '${TransactionTable.colCustomerId} = ? AND ${TransactionTable.colIsDeleted} = ?',
        whereArgs: [customerId, 0],
        orderBy: '${TransactionTable.colCreatedAt} DESC',
      );

      List<TransactionModel> transactions = [];
      for (final map in maps) {
        final transaction = TransactionModel.fromJson(map);
        final items = await getTransactionItems(transaction.id);
        transactions.add(transaction.copyWith(items: items));
      }

      return transactions;
    } catch (e) {
      throw CacheException(message: 'Failed to get transactions by customer: ${e.toString()}');
    }
  }

  @override
  Future<List<TransactionModel>> getTransactionsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    TransactionType? type,
  }) async {
    try {
      final db = await dbHelper.database;
      
      String where = '''
        ${TransactionTable.colCreatedAt} >= ? AND 
        ${TransactionTable.colCreatedAt} <= ? AND 
        ${TransactionTable.colIsDeleted} = ?
      ''';
      List<dynamic> whereArgs = [
        startDate.toIso8601String(),
        endDate.toIso8601String(),
        0,
      ];

      if (type != null) {
        where += ' AND ${TransactionTable.colType} = ?';
        whereArgs.add(type.name);
      }

      final List<Map<String, dynamic>> maps = await db.query(
        TransactionTable.tableName,
        where: where,
        whereArgs: whereArgs,
        orderBy: '${TransactionTable.colCreatedAt} DESC',
      );

      List<TransactionModel> transactions = [];
      for (final map in maps) {
        final transaction = TransactionModel.fromJson(map);
        final items = await getTransactionItems(transaction.id);
        transactions.add(transaction.copyWith(items: items));
      }

      return transactions;
    } catch (e) {
      throw CacheException(message: 'Failed to get transactions by date range: ${e.toString()}');
    }
  }

  @override
  Future<List<TransactionModel>> getTodayTransactions({TransactionType? type}) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    
    return getTransactionsByDateRange(
      startDate: startOfDay,
      endDate: endOfDay,
      type: type,
    );
  }

  @override
  Future<TransactionModel> insertTransaction(TransactionModel transaction) async {
    try {
      final db = await dbHelper.database;
      
      // Generate transaction number if not provided
      final transactionNumber = transaction.transactionNumber.isEmpty
          ? await generateTransactionNumber(transaction.type)
          : transaction.transactionNumber;

      final transactionWithTimestamp = transaction.copyWith(
        transactionNumber: transactionNumber,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isSynced: false,
      );

      await db.transaction((txn) async {
        // Insert transaction
        await txn.insert(
          TransactionTable.tableName,
          transactionWithTimestamp.toJsonWithoutItems(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Insert transaction items
        for (final item in transaction.items) {
          final itemWithTransactionId = item.copyWith(
            transactionId: transaction.id,
          );
          await txn.insert(
            TransactionTable.itemsTableName,
            itemWithTransactionId.toJson(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });

      return transactionWithTimestamp;
    } catch (e) {
      throw CacheException(message: 'Failed to insert transaction: ${e.toString()}');
    }
  }

  @override
  Future<TransactionModel> updateTransaction(TransactionModel transaction) async {
    try {
      final db = await dbHelper.database;
      
      final updatedTransaction = transaction.copyWith(
        updatedAt: DateTime.now(),
        isSynced: false,
      );

      await db.transaction((txn) async {
        // Update transaction
        await txn.update(
          TransactionTable.tableName,
          updatedTransaction.toJsonWithoutItems(),
          where: '${TransactionTable.colId} = ?',
          whereArgs: [transaction.id],
        );

        // Delete existing items
        await txn.delete(
          TransactionTable.itemsTableName,
          where: '${TransactionTable.colItemTransactionId} = ?',
          whereArgs: [transaction.id],
        );

        // Insert updated items
        for (final item in transaction.items) {
          await txn.insert(
            TransactionTable.itemsTableName,
            item.toJson(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });

      return updatedTransaction;
    } catch (e) {
      throw CacheException(message: 'Failed to update transaction: ${e.toString()}');
    }
  }

  @override
  Future<bool> deleteTransaction(String id) async {
    try {
      final db = await dbHelper.database;
      
      // Soft delete
      final count = await db.update(
        TransactionTable.tableName,
        {
          TransactionTable.colIsDeleted: 1,
          TransactionTable.colUpdatedAt: DateTime.now().toIso8601String(),
          TransactionTable.colIsSynced: 0,
        },
        where: '${TransactionTable.colId} = ?',
        whereArgs: [id],
      );

      return count > 0;
    } catch (e) {
      throw CacheException(message: 'Failed to delete transaction: ${e.toString()}');
    }
  }

  @override
  Future<bool> cancelTransaction(String id, String reason) async {
    try {
      final db = await dbHelper.database;
      
      final count = await db.update(
        TransactionTable.tableName,
        {
          TransactionTable.colStatus: TransactionStatus.cancelled.name,
          TransactionTable.colCancelReason: reason,
          TransactionTable.colUpdatedAt: DateTime.now().toIso8601String(),
          TransactionTable.colIsSynced: 0,
        },
        where: '${TransactionTable.colId} = ?',
        whereArgs: [id],
      );

      return count > 0;
    } catch (e) {
      throw CacheException(message: 'Failed to cancel transaction: ${e.toString()}');
    }
  }

  @override
  Future<List<TransactionItemModel>> getTransactionItems(String transactionId) async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        TransactionTable.itemsTableName,
        where: '${TransactionTable.colItemTransactionId} = ?',
        whereArgs: [transactionId],
      );

      return List.generate(maps.length, (i) {
        return TransactionItemModel.fromJson(maps[i]);
      });
    } catch (e) {
      throw CacheException(message: 'Failed to get transaction items: ${e.toString()}');
    }
  }

  @override
  Future<TransactionItemModel> addTransactionItem(TransactionItemModel item) async {
    try {
      final db = await dbHelper.database;
      
      await db.insert(
        TransactionTable.itemsTableName,
        item.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Mark parent transaction as unsynced
      await db.update(
        TransactionTable.tableName,
        {
          TransactionTable.colIsSynced: 0,
          TransactionTable.colUpdatedAt: DateTime.now().toIso8601String(),
        },
        where: '${TransactionTable.colId} = ?',
        whereArgs: [item.transactionId],
      );

      return item;
    } catch (e) {
      throw CacheException(message: 'Failed to add transaction item: ${e.toString()}');
    }
  }

  @override
  Future<TransactionItemModel> updateTransactionItem(TransactionItemModel item) async {
    try {
      final db = await dbHelper.database;
      
      await db.update(
        TransactionTable.itemsTableName,
        item.toJson(),
        where: '${TransactionTable.colItemId} = ?',
        whereArgs: [item.id],
      );

      // Mark parent transaction as unsynced
      await db.update(
        TransactionTable.tableName,
        {
          TransactionTable.colIsSynced: 0,
          TransactionTable.colUpdatedAt: DateTime.now().toIso8601String(),
        },
        where: '${TransactionTable.colId} = ?',
        whereArgs: [item.transactionId],
      );

      return item;
    } catch (e) {
      throw CacheException(message: 'Failed to update transaction item: ${e.toString()}');
    }
  }

  @override
  Future<bool> deleteTransactionItem(String id) async {
    try {
      final db = await dbHelper.database;
      
      // Get item first to get transaction ID
      final List<Map<String, dynamic>> items = await db.query(
        TransactionTable.itemsTableName,
        where: '${TransactionTable.colItemId} = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (items.isEmpty) return false;

      final transactionId = items.first[TransactionTable.colItemTransactionId];

      final count = await db.delete(
        TransactionTable.itemsTableName,
        where: '${TransactionTable.colItemId} = ?',
        whereArgs: [id],
      );

      // Mark parent transaction as unsynced
      if (count > 0) {
        await db.update(
          TransactionTable.tableName,
          {
            TransactionTable.colIsSynced: 0,
            TransactionTable.colUpdatedAt: DateTime.now().toIso8601String(),
          },
          where: '${TransactionTable.colId} = ?',
          whereArgs: [transactionId],
        );
      }

      return count > 0;
    } catch (e) {
      throw CacheException(message: 'Failed to delete transaction item: ${e.toString()}');
    }
  }

  @override
  Future<List<TransactionModel>> getUnsyncedTransactions() async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        TransactionTable.tableName,
        where: '${TransactionTable.colIsSynced} = ?',
        whereArgs: [0],
      );

      List<TransactionModel> transactions = [];
      for (final map in maps) {
        final transaction = TransactionModel.fromJson(map);
        final items = await getTransactionItems(transaction.id);
        transactions.add(transaction.copyWith(items: items));
      }

      return transactions;
    } catch (e) {
      throw CacheException(message: 'Failed to get unsynced transactions: ${e.toString()}');
    }
  }

  @override
  Future<void> markTransactionAsSynced(String id, String serverId) async {
    try {
      final db = await dbHelper.database;
      
      await db.update(
        TransactionTable.tableName,
        {
          TransactionTable.colServerId: serverId,
          TransactionTable.colIsSynced: 1,
          TransactionTable.colSyncedAt: DateTime.now().toIso8601String(),
        },
        where: '${TransactionTable.colId} = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw CacheException(message: 'Failed to mark transaction as synced: ${e.toString()}');
    }
  }

  @override
  Future<Map<String, double>> getTotalsByTypeForDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final db = await dbHelper.database;
      
      final buyResult = await db.rawQuery('''
        SELECT COALESCE(SUM(${TransactionTable.colTotalAmount}), 0) as total
        FROM ${TransactionTable.tableName}
        WHERE ${TransactionTable.colType} = ? 
          AND ${TransactionTable.colCreatedAt} >= ? 
          AND ${TransactionTable.colCreatedAt} <= ?
          AND ${TransactionTable.colStatus} = ?
          AND ${TransactionTable.colIsDeleted} = 0
      ''', [
        TransactionType.buy.name,
        startDate.toIso8601String(),
        endDate.toIso8601String(),
        TransactionStatus.completed.name,
      ]);

      final sellResult = await db.rawQuery('''
        SELECT COALESCE(SUM(${TransactionTable.colTotalAmount}), 0) as total
        FROM ${TransactionTable.tableName}
        WHERE ${TransactionTable.colType} = ? 
          AND ${TransactionTable.colCreatedAt} >= ? 
          AND ${TransactionTable.colCreatedAt} <= ?
          AND ${TransactionTable.colStatus} = ?
          AND ${TransactionTable.colIsDeleted} = 0
      ''', [
        TransactionType.sell.name,
        startDate.toIso8601String(),
        endDate.toIso8601String(),
        TransactionStatus.completed.name,
      ]);

      return {
        'buy': (buyResult.first['total'] as num?)?.toDouble() ?? 0.0,
        'sell': (sellResult.first['total'] as num?)?.toDouble() ?? 0.0,
      };
    } catch (e) {
      throw CacheException(message: 'Failed to get totals: ${e.toString()}');
    }
  }

  @override
  Future<Map<String, dynamic>> getDailySummary(DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final totals = await getTotalsByTypeForDateRange(
        startDate: startOfDay,
        endDate: endOfDay,
      );

      final transactions = await getTransactionsByDateRange(
        startDate: startOfDay,
        endDate: endOfDay,
      );

      return {
        'date': date.toIso8601String(),
        'totalBuy': totals['buy'],
        'totalSell': totals['sell'],
        'profit': (totals['sell'] ?? 0) - (totals['buy'] ?? 0),
        'transactionCount': transactions.length,
        'buyCount': transactions.where((t) => t.type == TransactionType.buy).length,
        'sellCount': transactions.where((t) => t.type == TransactionType.sell).length,
      };
    } catch (e) {
      throw CacheException(message: 'Failed to get daily summary: ${e.toString()}');
    }
  }

  @override
  Future<Map<String, dynamic>> getMonthlySummary(int year, int month) async {
    try {
      final startOfMonth = DateTime(year, month, 1);
      final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);

      final totals = await getTotalsByTypeForDateRange(
        startDate: startOfMonth,
        endDate: endOfMonth,
      );

      final transactions = await getTransactionsByDateRange(
        startDate: startOfMonth,
        endDate: endOfMonth,
      );

      // Get daily breakdown
      final List<Map<String, dynamic>> dailyBreakdown = [];
      for (int day = 1; day <= endOfMonth.day; day++) {
        final dayDate = DateTime(year, month, day);
        final daySummary = await getDailySummary(dayDate);
        dailyBreakdown.add(daySummary);
      }

      return {
        'year': year,
        'month': month,
        'totalBuy': totals['buy'],
        'totalSell': totals['sell'],
        'profit': (totals['sell'] ?? 0) - (totals['buy'] ?? 0),
        'transactionCount': transactions.length,
        'buyCount': transactions.where((t) => t.type == TransactionType.buy).length,
        'sellCount': transactions.where((t) => t.type == TransactionType.sell).length,
        'dailyBreakdown': dailyBreakdown,
      };
    } catch (e) {
      throw CacheException(message: 'Failed to get monthly summary: ${e.toString()}');
    }
  }

  @override
  Future<int> getTransactionsCount({TransactionType? type}) async {
    try {
      final db = await dbHelper.database;
      
      String query = 'SELECT COUNT(*) as count FROM ${TransactionTable.tableName} WHERE ${TransactionTable.colIsDeleted} = 0';
      List<dynamic> args = [];
      
      if (type != null) {
        query += ' AND ${TransactionTable.colType} = ?';
        args.add(type.name);
      }

      final result = await db.rawQuery(query, args);
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      throw CacheException(message: 'Failed to get transactions count: ${e.toString()}');
    }
  }

  @override
  Future<List<TransactionModel>> searchTransactions(String query) async {
    try {
      final db = await dbHelper.database;
      final searchQuery = '%$query%';
      
      final List<Map<String, dynamic>> maps = await db.query(
        TransactionTable.tableName,
        where: '''
          (${TransactionTable.colTransactionNumber} LIKE ? OR 
           ${TransactionTable.colNotes} LIKE ?) AND 
          ${TransactionTable.colIsDeleted} = ?
        ''',
        whereArgs: [searchQuery, searchQuery, 0],
        orderBy: '${TransactionTable.colCreatedAt} DESC',
        limit: 50,
      );

      List<TransactionModel> transactions = [];
      for (final map in maps) {
        final transaction = TransactionModel.fromJson(map);
        final items = await getTransactionItems(transaction.id);
        transactions.add(transaction.copyWith(items: items));
      }

      return transactions;
    } catch (e) {
      throw CacheException(message: 'Failed to search transactions: ${e.toString()}');
    }
  }

  @override
  Future<void> batchInsertTransactions(List<TransactionModel> transactions) async {
    try {
      final db = await dbHelper.database;
      
      await db.transaction((txn) async {
        for (final transaction in transactions) {
          await txn.insert(
            TransactionTable.tableName,
            transaction.copyWith(isSynced: true).toJsonWithoutItems(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          for (final item in transaction.items) {
            await txn.insert(
              TransactionTable.itemsTableName,
              item.toJson(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      });
    } catch (e) {
      throw CacheException(message: 'Failed to batch insert transactions: ${e.toString()}');
    }
  }

  @override
  Future<void> clearAllTransactions() async {
    try {
      final db = await dbHelper.database;
      await db.delete(TransactionTable.itemsTableName);
      await db.delete(TransactionTable.tableName);
    } catch (e) {
      throw CacheException(message: 'Failed to clear transactions: ${e.toString()}');
    }
  }

  @override
  Future<String> generateTransactionNumber(TransactionType type) async {
    try {
      final db = await dbHelper.database;
      final now = DateTime.now();
      final prefix = type == TransactionType.buy ? 'BUY' : 'SELL';
      final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      
      // Get count of transactions for today
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
      
      final result = await db.rawQuery('''
        SELECT COUNT(*) as count 
        FROM ${TransactionTable.tableName} 
        WHERE ${TransactionTable.colType} = ? 
          AND ${TransactionTable.colCreatedAt} >= ? 
          AND ${TransactionTable.colCreatedAt} <= ?
      ''', [type.name, startOfDay.toIso8601String(), endOfDay.toIso8601String()]);
      
      final count = (Sqflite.firstIntValue(result) ?? 0) + 1;
      
      return '$prefix-$dateStr-${count.toString().padLeft(4, '0')}';
    } catch (e) {
      // Fallback to timestamp-based number
      return '${type == TransactionType.buy ? 'BUY' : 'SELL'}-${DateTime.now().millisecondsSinceEpoch}';
    }
  }
}