// lib/data/datasources/local/inventory_local_ds.dart

import 'package:sqflite/sqflite.dart';
import '../../../core/database/db_helper.dart';
import '../../../core/database/tables/inventory_table.dart';
import '../../../core/constants/enums.dart';
import '../../../core/errors/exceptions.dart';
import '../../models/inventory_item_model.dart';

abstract class InventoryLocalDataSource {
  /// Get all inventory items
  Future<List<InventoryItemModel>> getAllInventoryItems();

  /// Get inventory item by ID
  Future<InventoryItemModel?> getInventoryItemById(String id);

  /// Get inventory items by type (Paddy/Rice)
  Future<List<InventoryItemModel>> getInventoryByType(ItemType type);

  /// Get inventory items by variety
  Future<List<InventoryItemModel>> getInventoryByVariety(String variety);

  /// Insert new inventory item
  Future<InventoryItemModel> insertInventoryItem(InventoryItemModel item);

  /// Update inventory item
  Future<InventoryItemModel> updateInventoryItem(InventoryItemModel item);

  /// Add stock to existing item (Buy operation)
  Future<InventoryItemModel> addStock({
    required String itemId,
    required double quantity,
    required int bags,
    required String transactionId,
  });

  /// Deduct stock from existing item (Sell operation)
  Future<InventoryItemModel> deductStock({
    required String itemId,
    required double quantity,
    required int bags,
    required String transactionId,
  });

  /// Delete inventory item
  Future<bool> deleteInventoryItem(String id);

  /// Get unsynced inventory items
  Future<List<InventoryItemModel>> getUnsyncedInventoryItems();

  /// Mark inventory item as synced
  Future<void> markInventoryItemAsSynced(String id, String serverId);

  /// Get total stock by type
  Future<Map<ItemType, double>> getTotalStockByType();

  /// Get low stock items (below threshold)
  Future<List<InventoryItemModel>> getLowStockItems(double threshold);

  /// Search inventory items
  Future<List<InventoryItemModel>> searchInventory(String query);

  /// Get or create inventory item by type and variety
  Future<InventoryItemModel> getOrCreateInventoryItem({
    required ItemType type,
    required String variety,
    required String companyId,
  });

  /// Batch insert inventory items (for sync)
  Future<void> batchInsertInventoryItems(List<InventoryItemModel> items);

  /// Clear all inventory
  Future<void> clearAllInventory();

  /// Get stock movement history for an item
  Future<List<Map<String, dynamic>>> getStockMovementHistory(String itemId);

  /// Record stock movement
  Future<void> recordStockMovement({
    required String itemId,
    required MovementType movementType,
    required double quantity,
    required int bags,
    required String transactionId,
    String? notes,
  });

  /// Get unique varieties
  Future<List<String>> getVarieties({ItemType? type});

  /// Check if variety exists
  Future<bool> isVarietyExists({
    required String variety,
    required ItemType type,
  });

  /// Adjust stock (set new quantity and bags)
  Future<InventoryItemModel> adjustStock({
    required String itemId,
    required double newQuantity,
    required int newBags,
    required String reason,
  });
}

class InventoryLocalDataSourceImpl implements InventoryLocalDataSource {
  final DbHelper dbHelper;

  InventoryLocalDataSourceImpl({required this.dbHelper});

  @override
  Future<List<InventoryItemModel>> getAllInventoryItems() async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        InventoryTable.tableName,
        where: '${InventoryTable.colIsDeleted} = ?',
        whereArgs: [0],
        orderBy: '${InventoryTable.colType} ASC, ${InventoryTable.colVariety} ASC',
      );

      return List.generate(maps.length, (i) {
        return InventoryItemModel.fromJson(maps[i]);
      });
    } catch (e) {
      throw CacheException(message: 'Failed to get inventory items: ${e.toString()}');
    }
  }

  @override
  Future<InventoryItemModel?> getInventoryItemById(String id) async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        InventoryTable.tableName,
        where: '${InventoryTable.colId} = ? AND ${InventoryTable.colIsDeleted} = ?',
        whereArgs: [id, 0],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return InventoryItemModel.fromJson(maps.first);
      }
      return null;
    } catch (e) {
      throw CacheException(message: 'Failed to get inventory item: ${e.toString()}');
    }
  }

  @override
  Future<List<InventoryItemModel>> getInventoryByType(ItemType type) async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        InventoryTable.tableName,
        where: '${InventoryTable.colType} = ? AND ${InventoryTable.colIsDeleted} = ?',
        whereArgs: [type.name, 0],
        orderBy: '${InventoryTable.colVariety} ASC',
      );

      return List.generate(maps.length, (i) {
        return InventoryItemModel.fromJson(maps[i]);
      });
    } catch (e) {
      throw CacheException(message: 'Failed to get inventory by type: ${e.toString()}');
    }
  }

  @override
  Future<List<InventoryItemModel>> getInventoryByVariety(String variety) async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        InventoryTable.tableName,
        where: '${InventoryTable.colVariety} = ? AND ${InventoryTable.colIsDeleted} = ?',
        whereArgs: [variety, 0],
      );

      return List.generate(maps.length, (i) {
        return InventoryItemModel.fromJson(maps[i]);
      });
    } catch (e) {
      throw CacheException(message: 'Failed to get inventory by variety: ${e.toString()}');
    }
  }

  @override
  Future<InventoryItemModel> insertInventoryItem(InventoryItemModel item) async {
    try {
      final db = await dbHelper.database;
      
      final itemWithTimestamp = item.copyWith(
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isSynced: false,
      );

      await db.insert(
        InventoryTable.tableName,
        itemWithTimestamp.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Record initial stock movement
      if (item.currentQuantity > 0) {
        await recordStockMovement(
          itemId: item.id,
          movementType: MovementType.initial,
          quantity: item.currentQuantity,
          bags: item.currentBags,
          transactionId: 'INIT_${item.id}',
          notes: 'Initial stock entry',
        );
      }

      return itemWithTimestamp;
    } catch (e) {
      throw CacheException(message: 'Failed to insert inventory item: ${e.toString()}');
    }
  }

  @override
  Future<InventoryItemModel> updateInventoryItem(InventoryItemModel item) async {
    try {
      final db = await dbHelper.database;
      
      final updatedItem = item.copyWith(
        updatedAt: DateTime.now(),
        isSynced: false,
      );

      final count = await db.update(
        InventoryTable.tableName,
        updatedItem.toJson(),
        where: '${InventoryTable.colId} = ?',
        whereArgs: [item.id],
      );

      if (count == 0) {
        throw CacheException(message: 'Inventory item not found');
      }

      return updatedItem;
    } catch (e) {
      if (e is CacheException) rethrow;
      throw CacheException(message: 'Failed to update inventory item: ${e.toString()}');
    }
  }

  @override
  Future<InventoryItemModel> addStock({
    required String itemId,
    required double quantity,
    required int bags,
    required String transactionId,
  }) async {
    try {
      final db = await dbHelper.database;
      
      // Get current item
      final currentItem = await getInventoryItemById(itemId);
      if (currentItem == null) {
        throw CacheException(message: 'Inventory item not found');
      }

      // Calculate new values
      final newQuantity = currentItem.currentQuantity + quantity;
      final newBags = currentItem.currentBags + bags;

      // Update item
      final updatedItem = currentItem.copyWith(
        currentQuantity: newQuantity,
        currentBags: newBags,
        lastStockUpdateAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isSynced: false,
      );

      await db.update(
        InventoryTable.tableName,
        updatedItem.toJson(),
        where: '${InventoryTable.colId} = ?',
        whereArgs: [itemId],
      );

      // Record stock movement
      await recordStockMovement(
        itemId: itemId,
        movementType: MovementType.stockIn,
        quantity: quantity,
        bags: bags,
        transactionId: transactionId,
        notes: 'Stock added via purchase',
      );

      return updatedItem;
    } catch (e) {
      if (e is CacheException) rethrow;
      throw CacheException(message: 'Failed to add stock: ${e.toString()}');
    }
  }

  @override
  Future<InventoryItemModel> deductStock({
    required String itemId,
    required double quantity,
    required int bags,
    required String transactionId,
  }) async {
    try {
      final db = await dbHelper.database;
      
      // Get current item
      final currentItem = await getInventoryItemById(itemId);
      if (currentItem == null) {
        throw CacheException(message: 'Inventory item not found');
      }

      // Check if sufficient stock available
      if (currentItem.currentQuantity < quantity) {
        throw CacheException(
          message: 'Insufficient stock. Available: ${currentItem.currentQuantity} kg',
        );
      }

      // Calculate new values
      final newQuantity = currentItem.currentQuantity - quantity;
      final newBags = currentItem.currentBags - bags;

      // Update item
      final updatedItem = currentItem.copyWith(
        currentQuantity: newQuantity,
        currentBags: newBags < 0 ? 0 : newBags,
        lastStockUpdateAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isSynced: false,
      );

      await db.update(
        InventoryTable.tableName,
        updatedItem.toJson(),
        where: '${InventoryTable.colId} = ?',
        whereArgs: [itemId],
      );

      // Record stock movement
      await recordStockMovement(
        itemId: itemId,
        movementType: MovementType.stockOut,
        quantity: quantity,
        bags: bags,
        transactionId: transactionId,
        notes: 'Stock deducted via sale',
      );

      return updatedItem;
    } catch (e) {
      if (e is CacheException) rethrow;
      throw CacheException(message: 'Failed to deduct stock: ${e.toString()}');
    }
  }

  @override
  Future<bool> deleteInventoryItem(String id) async {
    try {
      final db = await dbHelper.database;
      
      // Soft delete
      final count = await db.update(
        InventoryTable.tableName,
        {
          InventoryTable.colIsDeleted: 1,
          InventoryTable.colUpdatedAt: DateTime.now().toIso8601String(),
          InventoryTable.colIsSynced: 0,
        },
        where: '${InventoryTable.colId} = ?',
        whereArgs: [id],
      );

      return count > 0;
    } catch (e) {
      throw CacheException(message: 'Failed to delete inventory item: ${e.toString()}');
    }
  }

  @override
  Future<List<InventoryItemModel>> getUnsyncedInventoryItems() async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        InventoryTable.tableName,
        where: '${InventoryTable.colIsSynced} = ?',
        whereArgs: [0],
      );

      return List.generate(maps.length, (i) {
        return InventoryItemModel.fromJson(maps[i]);
      });
    } catch (e) {
      throw CacheException(message: 'Failed to get unsynced inventory: ${e.toString()}');
    }
  }

  @override
  Future<void> markInventoryItemAsSynced(String id, String serverId) async {
    try {
      final db = await dbHelper.database;
      
      await db.update(
        InventoryTable.tableName,
        {
          InventoryTable.colServerId: serverId,
          InventoryTable.colIsSynced: 1,
          InventoryTable.colSyncedAt: DateTime.now().toIso8601String(),
        },
        where: '${InventoryTable.colId} = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw CacheException(message: 'Failed to mark inventory as synced: ${e.toString()}');
    }
  }

  @override
  Future<Map<ItemType, double>> getTotalStockByType() async {
    try {
      final db = await dbHelper.database;
      
      final Map<ItemType, double> result = {};
      
      for (final type in ItemType.values) {
        final queryResult = await db.rawQuery('''
          SELECT COALESCE(SUM(${InventoryTable.colCurrentQuantity}), 0) as total
          FROM ${InventoryTable.tableName}
          WHERE ${InventoryTable.colType} = ? AND ${InventoryTable.colIsDeleted} = 0
        ''', [type.name]);
        
        result[type] = (queryResult.first['total'] as num?)?.toDouble() ?? 0.0;
      }

      return result;
    } catch (e) {
      throw CacheException(message: 'Failed to get total stock by type: ${e.toString()}');
    }
  }

  @override
  Future<List<InventoryItemModel>> getLowStockItems(double threshold) async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        InventoryTable.tableName,
        where: '''
          ${InventoryTable.colCurrentQuantity} < ? AND 
          ${InventoryTable.colIsDeleted} = ?
        ''',
        whereArgs: [threshold, 0],
        orderBy: '${InventoryTable.colCurrentQuantity} ASC',
      );

      return List.generate(maps.length, (i) {
        return InventoryItemModel.fromJson(maps[i]);
      });
    } catch (e) {
      throw CacheException(message: 'Failed to get low stock items: ${e.toString()}');
    }
  }

  @override
  Future<List<InventoryItemModel>> searchInventory(String query) async {
    try {
      final db = await dbHelper.database;
      final searchQuery = '%$query%';
      
      final List<Map<String, dynamic>> maps = await db.query(
        InventoryTable.tableName,
        where: '''
          (${InventoryTable.colVariety} LIKE ? OR 
           ${InventoryTable.colType} LIKE ?) AND 
          ${InventoryTable.colIsDeleted} = ?
        ''',
        whereArgs: [searchQuery, searchQuery, 0],
        orderBy: '${InventoryTable.colVariety} ASC',
      );

      return List.generate(maps.length, (i) {
        return InventoryItemModel.fromJson(maps[i]);
      });
    } catch (e) {
      throw CacheException(message: 'Failed to search inventory: ${e.toString()}');
    }
  }

  @override
  Future<InventoryItemModel> getOrCreateInventoryItem({
    required ItemType type,
    required String variety,
    required String companyId,
  }) async {
    try {
      final db = await dbHelper.database;
      
      // Try to find existing item
      final List<Map<String, dynamic>> maps = await db.query(
        InventoryTable.tableName,
        where: '''
          ${InventoryTable.colType} = ? AND 
          ${InventoryTable.colVariety} = ? AND 
          ${InventoryTable.colCompanyId} = ? AND
          ${InventoryTable.colIsDeleted} = ?
        ''',
        whereArgs: [type.name, variety, companyId, 0],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return InventoryItemModel.fromJson(maps.first);
      }

      // Create new item
      final newItem = InventoryItemModel(
        id: 'INV_${DateTime.now().millisecondsSinceEpoch}',
        type: type,
        variety: variety,
        companyId: companyId,
        currentQuantity: 0,
        currentBags: 0,
        averagePricePerKg: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isSynced: false,
      );

      await db.insert(
        InventoryTable.tableName,
        newItem.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return newItem;
    } catch (e) {
      throw CacheException(message: 'Failed to get or create inventory item: ${e.toString()}');
    }
  }

  @override
  Future<void> batchInsertInventoryItems(List<InventoryItemModel> items) async {
    try {
      final db = await dbHelper.database;
      
      await db.transaction((txn) async {
        final batch = txn.batch();
        
        for (final item in items) {
          batch.insert(
            InventoryTable.tableName,
            item.copyWith(isSynced: true).toJson(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        
        await batch.commit(noResult: true);
      });
    } catch (e) {
      throw CacheException(message: 'Failed to batch insert inventory: ${e.toString()}');
    }
  }

  @override
  Future<void> clearAllInventory() async {
    try {
      final db = await dbHelper.database;
      await db.delete(InventoryTable.tableName);
      await db.delete(InventoryTable.movementTableName);
    } catch (e) {
      throw CacheException(message: 'Failed to clear inventory: ${e.toString()}');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getStockMovementHistory(String itemId) async {
    try {
      final db = await dbHelper.database;
      
      final List<Map<String, dynamic>> maps = await db.query(
        InventoryTable.movementTableName,
        where: 'item_id = ?',
        whereArgs: [itemId],
        orderBy: 'created_at DESC',
        limit: 100,
      );

      return maps;
    } catch (e) {
      throw CacheException(message: 'Failed to get stock movement history: ${e.toString()}');
    }
  }

  @override
  Future<void> recordStockMovement({
    required String itemId,
    required MovementType movementType,
    required double quantity,
    required int bags,
    required String transactionId,
    String? notes,
  }) async {
    try {
      final db = await dbHelper.database;

      await db.insert(
        InventoryTable.movementTableName,
        {
          'id': 'MOV_${DateTime.now().millisecondsSinceEpoch}',
          'item_id': itemId,
          'movement_type': movementType.name,
          'quantity': quantity,
          'bags': bags,
          'transaction_id': transactionId,
          'notes': notes,
          'created_at': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      throw CacheException(message: 'Failed to record stock movement: ${e.toString()}');
    }
  }

  @override
  Future<List<String>> getVarieties({ItemType? type}) async {
    try {
      final db = await dbHelper.database;
      String query = 'SELECT DISTINCT ${InventoryTable.colVariety} FROM ${InventoryTable.tableName} WHERE ${InventoryTable.colIsDeleted} = 0';
      List<dynamic> args = [0];
      if (type != null) {
        query += ' AND ${InventoryTable.colType} = ?';
        args.add(type.name);
      }
      query += ' ORDER BY ${InventoryTable.colVariety} ASC';

      final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);
      return maps.map((map) => map[InventoryTable.colVariety] as String).toList();
    } catch (e) {
      throw CacheException(message: 'Failed to get varieties: ${e.toString()}');
    }
  }

  @override
  Future<bool> isVarietyExists({
    required String variety,
    required ItemType type,
  }) async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        InventoryTable.tableName,
        columns: [InventoryTable.colId],
        where: '${InventoryTable.colVariety} = ? AND ${InventoryTable.colType} = ? AND ${InventoryTable.colIsDeleted} = ?',
        whereArgs: [variety, type.name, 0],
        limit: 1,
      );
      return maps.isNotEmpty;
    } catch (e) {
      throw CacheException(message: 'Failed to check if variety exists: ${e.toString()}');
    }
  }

  @override
  Future<InventoryItemModel> adjustStock({
    required String itemId,
    required double newQuantity,
    required int newBags,
    required String reason,
  }) async {
    try {
      final db = await dbHelper.database;

      // Get current item
      final currentItem = await getInventoryItemById(itemId);
      if (currentItem == null) {
        throw CacheException(message: 'Inventory item not found');
      }

      // Calculate differences for stock movement
      final quantityDiff = newQuantity - currentItem.currentQuantity;
      final bagsDiff = newBags - currentItem.currentBags;

      // Update item
      final updatedItem = currentItem.copyWith(
        currentQuantity: newQuantity,
        currentBags: newBags,
        lastStockUpdateAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isSynced: false,
      );

      await db.update(
        InventoryTable.tableName,
        updatedItem.toJson(),
        where: '${InventoryTable.colId} = ?',
        whereArgs: [itemId],
      );

      // Record stock movement as adjustment
      await recordStockMovement(
        itemId: itemId,
        movementType: MovementType.adjustment,
        quantity: quantityDiff,
        bags: bagsDiff,
        transactionId: 'ADJ_${DateTime.now().millisecondsSinceEpoch}',
        notes: reason,
      );

      return updatedItem;
    } catch (e) {
      if (e is CacheException) rethrow;
      throw CacheException(message: 'Failed to adjust stock: ${e.toString()}');
    }
  }
}
