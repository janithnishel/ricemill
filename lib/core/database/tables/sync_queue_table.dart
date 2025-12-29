import 'package:rice_mill_erp/core/constants/enums.dart';

import '../../constants/db_constants.dart';
import '../../../data/models/sync_queue_model.dart';
import '../db_helper.dart';

class SyncQueueTable {
  final DbHelper _dbHelper;

  SyncQueueTable(this._dbHelper);

  // Table name
  static const String tableName = DbConstants.syncQueueTable;

  // Create table SQL
  static const String createTableSQL = '''
    CREATE TABLE $tableName (
      ${DbConstants.colLocalId} INTEGER PRIMARY KEY AUTOINCREMENT,
      ${DbConstants.colTableName} TEXT NOT NULL,
      ${DbConstants.colRecordLocalId} INTEGER NOT NULL,
      ${DbConstants.colOperation} TEXT NOT NULL,
      ${DbConstants.colData} TEXT NOT NULL,
      ${DbConstants.colRetryCount} INTEGER DEFAULT 0,
      ${DbConstants.colLastError} TEXT,
      ${DbConstants.colCreatedAt} TEXT NOT NULL,
      ${DbConstants.colUpdatedAt} TEXT
    )
  ''';

  // Create indexes SQL
  static List<String> get createIndexesSQL => [
    'CREATE INDEX ${DbConstants.idxSyncQueueTable} ON $tableName(${DbConstants.colTableName})',
    'CREATE INDEX ${DbConstants.idxSyncQueueOperation} ON $tableName(${DbConstants.colOperation})',
    'CREATE INDEX ${DbConstants.idxSyncQueueRetry} ON $tableName(${DbConstants.colRetryCount})',
    'CREATE INDEX idx_sync_queue_created ON $tableName(${DbConstants.colCreatedAt})',
  ];

  // ==================== CREATE ====================

  /// Add item to sync queue
  Future<int> add(SyncQueueModel item) async {
    final data = item.toMap();
    data.remove(DbConstants.colLocalId);
    return await _dbHelper.insert(tableName, data);
  }

  /// Add multiple items to sync queue
  Future<void> addBatch(List<SyncQueueModel> items) async {
    await _dbHelper.batch((batch) {
      for (final item in items) {
        final data = item.toMap();
        data.remove(DbConstants.colLocalId);
        batch.insert(tableName, data);
      }
    });
  }

  /// Queue a create operation
  Future<int> queueCreate({
    required String table,
    required int recordLocalId,
    required Map<String, dynamic> data,
  }) async {
    final item = SyncQueueModel.create(
      tableName: table,
      recordLocalId: recordLocalId,
      operation: SyncOperation.create,
      data: data,
    );
    return await add(item);
  }

  /// Queue an update operation
  Future<int> queueUpdate({
    required String table,
    required int recordLocalId,
    required Map<String, dynamic> data,
  }) async {
    // Check if there's a pending create for this record
    final existingCreate = await getByRecordAndOperation(
      table,
      recordLocalId,
      SyncOperation.create,
    );

    if (existingCreate != null) {
      // Update the pending create with new data
      return await updateData(existingCreate.localId!, data);
    }

    // Check if there's a pending update
    final existingUpdate = await getByRecordAndOperation(
      table,
      recordLocalId,
      SyncOperation.update,
    );

    if (existingUpdate != null) {
      // Update existing update operation
      return await updateData(existingUpdate.localId!, data);
    }

    // Create new update operation
    final item = SyncQueueModel.create(
      tableName: table,
      recordLocalId: recordLocalId,
      operation: SyncOperation.update,
      data: data,
    );
    return await add(item);
  }

  /// Queue a delete operation
  Future<int> queueDelete({
    required String table,
    required int recordLocalId,
    required Map<String, dynamic> data,
  }) async {
    // Remove any pending creates or updates for this record
    await removeByRecord(table, recordLocalId);

    final item = SyncQueueModel.create(
      tableName: table,
      recordLocalId: recordLocalId,
      operation: SyncOperation.delete,
      data: data,
    );
    return await add(item);
  }

  // ==================== READ ====================

  /// Get all pending sync items
  Future<List<SyncQueueModel>> getAll({
    int? limit,
    String orderBy = '${DbConstants.colCreatedAt} ASC',
  }) async {
    final results = await _dbHelper.query(
      tableName,
      orderBy: orderBy,
      limit: limit,
    );

    return results.map((map) => SyncQueueModel.fromMap(map)).toList();
  }

  /// Get item by ID
  Future<SyncQueueModel?> getById(int localId) async {
    final results = await _dbHelper.query(
      tableName,
      where: '${DbConstants.colLocalId} = ?',
      whereArgs: [localId],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return SyncQueueModel.fromMap(results.first);
  }

  /// Get items by table name
  Future<List<SyncQueueModel>> getByTable(String table) async {
    final results = await _dbHelper.query(
      tableName,
      where: '${DbConstants.colTableName} = ?',
      whereArgs: [table],
      orderBy: '${DbConstants.colCreatedAt} ASC',
    );

    return results.map((map) => SyncQueueModel.fromMap(map)).toList();
  }

  /// Get item by record and operation
  Future<SyncQueueModel?> getByRecordAndOperation(
    String table,
    int recordLocalId,
    SyncOperation operation,
  ) async {
    final results = await _dbHelper.query(
      tableName,
      where: '${DbConstants.colTableName} = ? AND ${DbConstants.colRecordLocalId} = ? AND ${DbConstants.colOperation} = ?',
      whereArgs: [table, recordLocalId, operation.value],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return SyncQueueModel.fromMap(results.first);
  }

  /// Get items ready to sync (retry count < max)
  Future<List<SyncQueueModel>> getPendingItems({
    int maxRetries = 3,
    int? limit,
  }) async {
    final results = await _dbHelper.query(
      tableName,
      where: '${DbConstants.colRetryCount} < ?',
      whereArgs: [maxRetries],
      orderBy: '${DbConstants.colCreatedAt} ASC',
      limit: limit,
    );

    return results.map((map) => SyncQueueModel.fromMap(map)).toList();
  }

  /// Get failed items (retry count >= max)
  Future<List<SyncQueueModel>> getFailedItems({int maxRetries = 3}) async {
    final results = await _dbHelper.query(
      tableName,
      where: '${DbConstants.colRetryCount} >= ?',
      whereArgs: [maxRetries],
      orderBy: '${DbConstants.colCreatedAt} ASC',
    );

    return results.map((map) => SyncQueueModel.fromMap(map)).toList();
  }

  /// Get pending count
  Future<int> getPendingCount() async {
    return await _dbHelper.count(tableName);
  }

  /// Get count by table
  Future<int> getCountByTable(String table) async {
    return await _dbHelper.count(
      tableName,
      where: '${DbConstants.colTableName} = ?',
      whereArgs: [table],
    );
  }

  /// Check if has pending items
  Future<bool> hasPendingItems() async {
    final count = await getPendingCount();
    return count > 0;
  }

  // ==================== UPDATE ====================

  /// Update sync item
  Future<int> update(SyncQueueModel item) async {
    if (item.localId == null) {
      throw ArgumentError('Item localId cannot be null for update');
    }

    final data = item.copyWith(
      updatedAt: DateTime.now(),
    ).toMap();

    return await _dbHelper.update(
      tableName,
      data,
      where: '${DbConstants.colLocalId} = ?',
      whereArgs: [item.localId],
    );
  }

  /// Update item data
  Future<int> updateData(int localId, Map<String, dynamic> newData) async {
    final item = await getById(localId);
    if (item == null) return 0;

    // Merge data
    final mergedData = {...item.data, ...newData};

    return await _dbHelper.update(
      tableName,
      {
        DbConstants.colData: mergedData.toString(),
        DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: '${DbConstants.colLocalId} = ?',
      whereArgs: [localId],
    );
  }

  /// Increment retry count and set error
  Future<int> recordFailure(int localId, String error) async {
    final item = await getById(localId);
    if (item == null) return 0;

    return await _dbHelper.update(
      tableName,
      {
        DbConstants.colRetryCount: item.retryCount + 1,
        DbConstants.colLastError: error,
        DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: '${DbConstants.colLocalId} = ?',
      whereArgs: [localId],
    );
  }

  /// Reset retry count
  Future<int> resetRetryCount(int localId) async {
    return await _dbHelper.update(
      tableName,
      {
        DbConstants.colRetryCount: 0,
        DbConstants.colLastError: null,
        DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: '${DbConstants.colLocalId} = ?',
      whereArgs: [localId],
    );
  }

  /// Reset all failed items
  Future<int> resetAllFailed({int maxRetries = 3}) async {
    return await _dbHelper.update(
      tableName,
      {
        DbConstants.colRetryCount: 0,
        DbConstants.colLastError: null,
        DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: '${DbConstants.colRetryCount} >= ?',
      whereArgs: [maxRetries],
    );
  }

  // ==================== DELETE ====================

  /// Remove item by ID
  Future<int> remove(int localId) async {
    return await _dbHelper.delete(
      tableName,
      where: '${DbConstants.colLocalId} = ?',
      whereArgs: [localId],
    );
  }

  /// Remove items by record
  Future<int> removeByRecord(String table, int recordLocalId) async {
    return await _dbHelper.delete(
      tableName,
      where: '${DbConstants.colTableName} = ? AND ${DbConstants.colRecordLocalId} = ?',
      whereArgs: [table, recordLocalId],
    );
  }

  /// Remove items by table
  Future<int> removeByTable(String table) async {
    return await _dbHelper.delete(
      tableName,
      where: '${DbConstants.colTableName} = ?',
      whereArgs: [table],
    );
  }

  /// Remove synced items (for cleanup)
  Future<int> removeCompleted(List<int> localIds) async {
    if (localIds.isEmpty) return 0;

    final placeholders = List.generate(localIds.length, (_) => '?').join(', ');
    return await _dbHelper.rawDelete(
      'DELETE FROM $tableName WHERE ${DbConstants.colLocalId} IN ($placeholders)',
      localIds,
    );
  }

  /// Clear all sync queue
  Future<void> clearAll() async {
    await _dbHelper.clearTable(tableName);
  }

  /// Clear old failed items
  Future<int> clearOldFailed({
    int maxRetries = 3,
    Duration olderThan = const Duration(days: 7),
  }) async {
    final cutoffDate = DateTime.now().subtract(olderThan);

    return await _dbHelper.delete(
      tableName,
      where: '${DbConstants.colRetryCount} >= ? AND ${DbConstants.colCreatedAt} < ?',
      whereArgs: [maxRetries, cutoffDate.toIso8601String()],
    );
  }

  // ==================== BATCH OPERATIONS ====================

  /// Process and remove successfully synced items
  Future<void> markAsSynced(List<int> localIds) async {
    await removeCompleted(localIds);
  }

  /// Get grouped items by table for efficient syncing
  Future<Map<String, List<SyncQueueModel>>> getGroupedByTable() async {
    final items = await getAll();
    final grouped = <String, List<SyncQueueModel>>{};

    for (final item in items) {
      grouped.putIfAbsent(item.tableName, () => []).add(item);
    }

    return grouped;
  }
}
