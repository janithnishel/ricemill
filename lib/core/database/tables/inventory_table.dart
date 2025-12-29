import '../../constants/db_constants.dart';
import '../../constants/enums.dart';
import '../../../data/models/inventory_item_model.dart';
import '../db_helper.dart';

class InventoryTable {
  final DbHelper _dbHelper;

  InventoryTable(this._dbHelper);

  // Table name
  static const String tableName = DbConstants.inventoryTable;
  static const String movementTableName = 'inventory_movements';

  // Column names
  static const String colId = DbConstants.colLocalId;
  static const String colServerId = DbConstants.colServerId;
  static const String colType = DbConstants.colItemType;
  static const String colItemName = DbConstants.colItemName;
  static const String colVariety = DbConstants.colVariety;
  static const String colCurrentQuantity = DbConstants.colQuantityKg;
  static const String colCurrentBags = DbConstants.colBagCount;
  static const String colAveragePricePerKg = DbConstants.colAverageBagWeight;
  static const String colMinStockLevel = DbConstants.colMinStockLevel;
  static const String colLocation = DbConstants.colLocation;
  static const String colCreatedAt = DbConstants.colCreatedAt;
  static const String colUpdatedAt = DbConstants.colUpdatedAt;
  static const String colIsSynced = 'is_synced';
  static const String colSyncStatus = DbConstants.colSyncStatus;
  static const String colSyncedAt = 'synced_at';
  static const String colIsDeleted = DbConstants.colIsDeleted;
  static const String colCompanyId = DbConstants.colCompanyId;

  // Create table SQL
  static const String createTableSQL = '''
    CREATE TABLE $tableName (
      ${DbConstants.colLocalId} INTEGER PRIMARY KEY AUTOINCREMENT,
      ${DbConstants.colServerId} TEXT,
      item_type TEXT NOT NULL,
      item_name TEXT NOT NULL,
      variety TEXT,
      quantity_kg REAL DEFAULT 0.0,
      bag_count INTEGER DEFAULT 0,
      average_bag_weight REAL DEFAULT 0.0,
      min_stock_level REAL DEFAULT 0.0,
      location TEXT,
      company_id TEXT,
      ${DbConstants.colCreatedAt} TEXT NOT NULL,
      ${DbConstants.colUpdatedAt} TEXT NOT NULL,
      is_synced INTEGER DEFAULT 0,
      ${DbConstants.colSyncStatus} TEXT DEFAULT 'pending',
      synced_at TEXT,
      ${DbConstants.colIsDeleted} INTEGER DEFAULT 0
    )
  ''';

  // Create indexes SQL
  static const List<String> createIndexesSQL = [
    'CREATE INDEX idx_inventory_type ON $tableName(item_type)',
    'CREATE INDEX idx_inventory_name ON $tableName(item_name)',
    'CREATE INDEX idx_inventory_variety ON $tableName(variety)',
    'CREATE INDEX idx_inventory_sync ON $tableName(${DbConstants.colSyncStatus})',
    'CREATE UNIQUE INDEX idx_inventory_unique ON $tableName(item_type, item_name, variety) WHERE ${DbConstants.colIsDeleted} = 0',
  ];

  // ==================== CREATE ====================

  /// Insert a new inventory item
  Future<int> insert(InventoryItemModel item) async {
    final data = item.toMap();
    data.remove(DbConstants.colLocalId);
    return await _dbHelper.insert(tableName, data);
  }

  /// Insert or update (upsert) based on type, name, variety
  Future<int> upsert(InventoryItemModel item) async {
    final existing = await getByTypeNameVariety(
      item.itemType,
      item.itemName,
      item.variety,
    );

    if (existing != null) {
      // Update existing
      final updated = existing.addStock(item.quantityKg, item.bagCount);
      return await update(updated);
    } else {
      // Insert new
      return await insert(item);
    }
  }

  // ==================== READ ====================

  /// Get all inventory items
  Future<List<InventoryItemModel>> getAll({
    bool includeDeleted = false,
    ItemType? filterType,
    String orderBy = 'item_type, item_name ASC',
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];

    if (!includeDeleted) {
      conditions.add('${DbConstants.colIsDeleted} = ?');
      args.add(0);
    }

    if (filterType != null) {
      conditions.add('item_type = ?');
      args.add(filterType.value);
    }

    final results = await _dbHelper.query(
      tableName,
      where: conditions.isNotEmpty ? conditions.join(' AND ') : null,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: orderBy,
    );

    return results.map((map) => InventoryItemModel.fromMap(map)).toList();
  }

  /// Get inventory item by local ID
  Future<InventoryItemModel?> getById(int localId) async {
    final results = await _dbHelper.query(
      tableName,
      where: '${DbConstants.colLocalId} = ?',
      whereArgs: [localId],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return InventoryItemModel.fromMap(results.first);
  }

  /// Get inventory item by type, name, and variety
  Future<InventoryItemModel?> getByTypeNameVariety(
    ItemType type,
    String name,
    String? variety,
  ) async {
    String where;
    List<dynamic> whereArgs;

    if (variety != null) {
      where = 'item_type = ? AND item_name = ? AND variety = ? AND ${DbConstants.colIsDeleted} = ?';
      whereArgs = [type.value, name, variety, 0];
    } else {
      where = 'item_type = ? AND item_name = ? AND variety IS NULL AND ${DbConstants.colIsDeleted} = ?';
      whereArgs = [type.value, name, 0];
    }

    final results = await _dbHelper.query(
      tableName,
      where: where,
      whereArgs: whereArgs,
      limit: 1,
    );

    if (results.isEmpty) return null;
    return InventoryItemModel.fromMap(results.first);
  }

  /// Get items by type
  Future<List<InventoryItemModel>> getByType(ItemType type) async {
    final results = await _dbHelper.query(
      tableName,
      where: 'item_type = ? AND ${DbConstants.colIsDeleted} = ?',
      whereArgs: [type.value, 0],
      orderBy: 'item_name ASC',
    );

    return results.map((map) => InventoryItemModel.fromMap(map)).toList();
  }

  /// Get all paddy items
  Future<List<InventoryItemModel>> getPaddy() async {
    return await getByType(ItemType.paddy);
  }

  /// Get all rice items
  Future<List<InventoryItemModel>> getRice() async {
    return await getByType(ItemType.rice);
  }

  /// Get low stock items
  Future<List<InventoryItemModel>> getLowStock() async {
    final results = await _dbHelper.rawQuery('''
      SELECT * FROM $tableName 
      WHERE quantity_kg <= min_stock_level 
        AND min_stock_level > 0 
        AND ${DbConstants.colIsDeleted} = 0
      ORDER BY (min_stock_level - quantity_kg) DESC
    ''');

    return results.map((map) => InventoryItemModel.fromMap(map)).toList();
  }

  /// Get items with stock
  Future<List<InventoryItemModel>> getWithStock({ItemType? type}) async {
    String where = 'quantity_kg > 0 AND ${DbConstants.colIsDeleted} = 0';
    List<dynamic>? whereArgs;

    if (type != null) {
      where += ' AND item_type = ?';
      whereArgs = [type.value];
    }

    final results = await _dbHelper.query(
      tableName,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'item_type, item_name ASC',
    );

    return results.map((map) => InventoryItemModel.fromMap(map)).toList();
  }

  /// Search inventory
  Future<List<InventoryItemModel>> search(String query) async {
    if (query.isEmpty) return getAll();

    final searchQuery = '%$query%';

    final results = await _dbHelper.query(
      tableName,
      where: '(item_name LIKE ? OR variety LIKE ?) AND ${DbConstants.colIsDeleted} = ?',
      whereArgs: [searchQuery, searchQuery, 0],
      orderBy: 'item_type, item_name ASC',
    );

    return results.map((map) => InventoryItemModel.fromMap(map)).toList();
  }

  /// Get inventory pending sync
  Future<List<InventoryItemModel>> getPendingSync() async {
    final results = await _dbHelper.query(
      tableName,
      where: '${DbConstants.colSyncStatus} != ?',
      whereArgs: [SyncStatus.synced.value],
    );

    return results.map((map) => InventoryItemModel.fromMap(map)).toList();
  }

  /// Get total stock by type
  Future<Map<ItemType, double>> getTotalStockByType() async {
    final results = await _dbHelper.rawQuery('''
      SELECT item_type, SUM(quantity_kg) as total_kg
      FROM $tableName
      WHERE ${DbConstants.colIsDeleted} = 0
      GROUP BY item_type
    ''');

    final Map<ItemType, double> totals = {};
    for (final row in results) {
      final type = ItemType.fromString(row['item_type'] as String);
      totals[type] = (row['total_kg'] as num?)?.toDouble() ?? 0.0;
    }
    return totals;
  }

  /// Get stock summary
  Future<StockSummary> getStockSummary() async {
    final results = await _dbHelper.rawQuery('''
      SELECT 
        item_type,
        SUM(quantity_kg) as total_kg,
        SUM(bag_count) as total_bags,
        COUNT(*) as item_count
      FROM $tableName
      WHERE ${DbConstants.colIsDeleted} = 0
      GROUP BY item_type
    ''');

    double totalPaddyKg = 0;
    double totalRiceKg = 0;
    int totalPaddyBags = 0;
    int totalRiceBags = 0;
    int paddyVarieties = 0;
    int riceVarieties = 0;

    for (final row in results) {
      final type = row['item_type'] as String;
      if (type == ItemType.paddy.value) {
        totalPaddyKg = (row['total_kg'] as num?)?.toDouble() ?? 0;
        totalPaddyBags = row['total_bags'] as int? ?? 0;
        paddyVarieties = row['item_count'] as int? ?? 0;
      } else if (type == ItemType.rice.value) {
        totalRiceKg = (row['total_kg'] as num?)?.toDouble() ?? 0;
        totalRiceBags = row['total_bags'] as int? ?? 0;
        riceVarieties = row['item_count'] as int? ?? 0;
      }
    }

    return StockSummary(
      totalPaddyKg: totalPaddyKg,
      totalRiceKg: totalRiceKg,
      totalPaddyBags: totalPaddyBags,
      totalRiceBags: totalRiceBags,
      paddyVarieties: paddyVarieties,
      riceVarieties: riceVarieties,
    );
  }

  // ==================== UPDATE ====================

  /// Update inventory item
  Future<int> update(InventoryItemModel item) async {
    if (item.localId == null) {
      throw ArgumentError('Item localId cannot be null for update');
    }

    final data = item.copyWith(
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    ).toMap();

    return await _dbHelper.update(
      tableName,
      data,
      where: '${DbConstants.colLocalId} = ?',
      whereArgs: [item.localId],
    );
  }

  /// Add stock to item
  Future<int> addStock(
    int localId, {
    required double weightKg,
    required int bagCount,
  }) async {
    final item = await getById(localId);
    if (item == null) return 0;

    final updated = item.addStock(weightKg, bagCount);
    return await update(updated);
  }

  /// Add stock by type/name/variety (creates if not exists)
  Future<int> addStockByItem({
    required ItemType type,
    required String name,
    String? variety,
    required double weightKg,
    required int bagCount,
  }) async {
    final existing = await getByTypeNameVariety(type, name, variety);

    if (existing != null) {
      return await addStock(
        existing.localId!,
        weightKg: weightKg,
        bagCount: bagCount,
      );
    } else {
      // Create new inventory item
      final newItem = InventoryItemModel.create(
        itemType: type,
        itemName: name,
        variety: variety,
        quantityKg: weightKg,
        bagCount: bagCount,
      );
      return await insert(newItem);
    }
  }

  /// Deduct stock from item
  Future<int> deductStock(
    int localId, {
    required double weightKg,
    required int bagCount,
  }) async {
    final item = await getById(localId);
    if (item == null) return 0;

    // Check if enough stock
    if (item.quantityKg < weightKg) {
      throw InsufficientStockException(
        available: item.quantityKg,
        requested: weightKg,
      );
    }

    final updated = item.deductStock(weightKg, bagCount);
    return await update(updated);
  }

  /// Update stock directly
  Future<int> setStock(
    int localId, {
    required double weightKg,
    required int bagCount,
  }) async {
    final averageBagWeight = bagCount > 0 ? weightKg / bagCount : 0.0;

    return await _dbHelper.update(
      tableName,
      {
        'quantity_kg': weightKg,
        'bag_count': bagCount,
        'average_bag_weight': averageBagWeight,
        DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
        DbConstants.colSyncStatus: SyncStatus.pending.value,
      },
      where: '${DbConstants.colLocalId} = ?',
      whereArgs: [localId],
    );
  }

  /// Update min stock level
  Future<int> updateMinStockLevel(int localId, double level) async {
    return await _dbHelper.update(
      tableName,
      {
        'min_stock_level': level,
        DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
        DbConstants.colSyncStatus: SyncStatus.pending.value,
      },
      where: '${DbConstants.colLocalId} = ?',
      whereArgs: [localId],
    );
  }

  /// Update sync status
  Future<int> updateSyncStatus(int localId, SyncStatus status, {String? serverId}) async {
    final data = <String, dynamic>{
      DbConstants.colSyncStatus: status.value,
      DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
    };

    if (serverId != null) {
      data[DbConstants.colServerId] = serverId;
    }

    return await _dbHelper.update(
      tableName,
      data,
      where: '${DbConstants.colLocalId} = ?',
      whereArgs: [localId],
    );
  }

  // ==================== DELETE ====================

  /// Soft delete inventory item
  Future<int> softDelete(int localId) async {
    return await _dbHelper.update(
      tableName,
      {
        DbConstants.colIsDeleted: 1,
        DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
        DbConstants.colSyncStatus: SyncStatus.pending.value,
      },
      where: '${DbConstants.colLocalId} = ?',
      whereArgs: [localId],
    );
  }

  /// Hard delete inventory item
  Future<int> hardDelete(int localId) async {
    return await _dbHelper.delete(
      tableName,
      where: '${DbConstants.colLocalId} = ?',
      whereArgs: [localId],
    );
  }

  // ==================== UTILITIES ====================

  /// Check if item exists
  Future<bool> exists(ItemType type, String name, String? variety) async {
    final item = await getByTypeNameVariety(type, name, variety);
    return item != null;
  }

  /// Get available stock for selling
  Future<double> getAvailableStock(int localId) async {
    final item = await getById(localId);
    return item?.quantityKg ?? 0.0;
  }

  /// Clear all inventory (for testing/reset)
  Future<void> clearAll() async {
    await _dbHelper.clearTable(tableName);
  }
}

// Stock summary class
class StockSummary {
  final double totalPaddyKg;
  final double totalRiceKg;
  final int totalPaddyBags;
  final int totalRiceBags;
  final int paddyVarieties;
  final int riceVarieties;

  StockSummary({
    required this.totalPaddyKg,
    required this.totalRiceKg,
    required this.totalPaddyBags,
    required this.totalRiceBags,
    required this.paddyVarieties,
    required this.riceVarieties,
  });

  double get totalKg => totalPaddyKg + totalRiceKg;
  int get totalBags => totalPaddyBags + totalRiceBags;
  int get totalVarieties => paddyVarieties + riceVarieties;
}

// Exception for insufficient stock
class InsufficientStockException implements Exception {
  final double available;
  final double requested;

  InsufficientStockException({
    required this.available,
    required this.requested,
  });

  @override
  String toString() =>
      'Insufficient stock: Available $available kg, Requested $requested kg';
}
