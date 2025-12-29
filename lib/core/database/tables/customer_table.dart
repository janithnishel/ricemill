import '../../constants/db_constants.dart';
import '../../constants/enums.dart';
import '../../../data/models/customer_model.dart';
import '../db_helper.dart';

class CustomerTable {
  final DbHelper _dbHelper;

  CustomerTable(this._dbHelper);

  // Column constants to be used by callers (kept for backward compatibility)
  static const String colId = DbConstants.colLocalId;
  static const String colServerId = DbConstants.colServerId;
  static const String colName = DbConstants.colName;
  static const String colPhone = DbConstants.colPhone;
  static const String colAddress = DbConstants.colAddress;
  static const String colNic = DbConstants.colNic;
  static const String colIsDeleted = DbConstants.colIsDeleted;
  static const String colCreatedAt = DbConstants.colCreatedAt;
  static const String colUpdatedAt = DbConstants.colUpdatedAt;
  // Some codebases use an is_synced boolean and synced_at timestamp
  static const String colIsSynced = 'is_synced';
  static const String colSyncedAt = 'synced_at';

  // Table name
  static const String tableName = DbConstants.customersTable;

  // Create table SQL
  static const String createTableSQL = '''
    CREATE TABLE $tableName (
      ${DbConstants.colLocalId} INTEGER PRIMARY KEY AUTOINCREMENT,
      ${DbConstants.colServerId} TEXT,
      name TEXT NOT NULL,
      phone TEXT NOT NULL,
      address TEXT,
      nic TEXT,
      customer_type TEXT DEFAULT 'both',
      balance REAL DEFAULT 0.0,
      notes TEXT,
      is_active INTEGER DEFAULT 1,
      ${DbConstants.colCreatedAt} TEXT NOT NULL,
      ${DbConstants.colUpdatedAt} TEXT NOT NULL,
      ${DbConstants.colSyncStatus} TEXT DEFAULT 'pending',
      ${DbConstants.colIsDeleted} INTEGER DEFAULT 0
    )
  ''';

  // Create indexes SQL
  static const List<String> createIndexesSQL = [
    'CREATE INDEX idx_customers_phone ON $tableName(phone)',
    'CREATE INDEX idx_customers_name ON $tableName(name)',
    'CREATE INDEX idx_customers_sync ON $tableName(${DbConstants.colSyncStatus})',
    'CREATE INDEX idx_customers_active ON $tableName(is_active)',
    'CREATE UNIQUE INDEX idx_customers_phone_unique ON $tableName(phone) WHERE ${DbConstants.colIsDeleted} = 0',
  ];

  // ==================== CREATE ====================

  /// Insert a new customer
  Future<int> insert(CustomerModel customer) async {
    final data = customer.toMap();
    data.remove(DbConstants.colLocalId); // Remove for auto-increment
    return await _dbHelper.insert(tableName, data);
  }

  /// Insert multiple customers (batch)
  Future<List<int>> insertBatch(List<CustomerModel> customers) async {
    final results = <int>[];
    await _dbHelper.transaction((txn) async {
      for (final customer in customers) {
        final data = customer.toMap();
        data.remove(DbConstants.colLocalId);
        final id = await txn.insert(tableName, data);
        results.add(id);
      }
    });
    return results;
  }

  // ==================== READ ====================

  /// Get all customers
  Future<List<CustomerModel>> getAll({
    bool includeDeleted = false,
    bool activeOnly = true,
    int? limit,
    int? offset,
    String orderBy = 'name ASC',
  }) async {
    String? where;
    List<dynamic>? whereArgs;

    final conditions = <String>[];
    final args = <dynamic>[];

    if (!includeDeleted) {
      conditions.add('${DbConstants.colIsDeleted} = ?');
      args.add(0);
    }

    if (activeOnly) {
      conditions.add('is_active = ?');
      args.add(1);
    }

    if (conditions.isNotEmpty) {
      where = conditions.join(' AND ');
      whereArgs = args;
    }

    final results = await _dbHelper.query(
      tableName,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );

    return results.map((map) => CustomerModel.fromMap(map)).toList();
  }

  /// Get customer by local ID
  Future<CustomerModel?> getById(int localId) async {
    final results = await _dbHelper.query(
      tableName,
      where: '${DbConstants.colLocalId} = ?',
      whereArgs: [localId],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return CustomerModel.fromMap(results.first);
  }

  /// Get customer by server ID
  Future<CustomerModel?> getByServerId(String serverId) async {
    final results = await _dbHelper.query(
      tableName,
      where: '${DbConstants.colServerId} = ?',
      whereArgs: [serverId],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return CustomerModel.fromMap(results.first);
  }

  /// Get customer by phone number
  Future<CustomerModel?> getByPhone(String phone) async {
    // Normalize phone number
    final normalizedPhone = _normalizePhone(phone);
    
    final results = await _dbHelper.query(
      tableName,
      where: '(phone = ? OR phone = ? OR phone = ?) AND ${DbConstants.colIsDeleted} = ?',
      whereArgs: [phone, normalizedPhone, '0$normalizedPhone', 0],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return CustomerModel.fromMap(results.first);
  }

  /// Search customers by name or phone
  Future<List<CustomerModel>> search(
    String query, {
    int limit = 20,
    bool activeOnly = true,
  }) async {
    if (query.isEmpty) return getAll(limit: limit, activeOnly: activeOnly);

    final searchQuery = '%$query%';
    
    String where = '(name LIKE ? OR phone LIKE ? OR address LIKE ?) AND ${DbConstants.colIsDeleted} = ?';
    List<dynamic> whereArgs = [searchQuery, searchQuery, searchQuery, 0];

    if (activeOnly) {
      where += ' AND is_active = ?';
      whereArgs.add(1);
    }

    final results = await _dbHelper.query(
      tableName,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'name ASC',
      limit: limit,
    );

    return results.map((map) => CustomerModel.fromMap(map)).toList();
  }

  /// Get customers by type
  Future<List<CustomerModel>> getByType(CustomerType type) async {
    final results = await _dbHelper.query(
      tableName,
      where: '(customer_type = ? OR customer_type = ?) AND ${DbConstants.colIsDeleted} = ? AND is_active = ?',
      whereArgs: [type.value, 'both', 0, 1],
      orderBy: 'name ASC',
    );

    return results.map((map) => CustomerModel.fromMap(map)).toList();
  }

  /// Get customers with pending balance
  Future<List<CustomerModel>> getWithBalance({bool positive = true}) async {
    final operator = positive ? '>' : '<';
    
    final results = await _dbHelper.query(
      tableName,
      where: 'balance $operator ? AND ${DbConstants.colIsDeleted} = ?',
      whereArgs: [0, 0],
      orderBy: 'balance ${positive ? 'DESC' : 'ASC'}',
    );

    return results.map((map) => CustomerModel.fromMap(map)).toList();
  }

  /// Get customers pending sync
  Future<List<CustomerModel>> getPendingSync() async {
    final results = await _dbHelper.query(
      tableName,
      where: '${DbConstants.colSyncStatus} != ?',
      whereArgs: [SyncStatus.synced.value],
    );

    return results.map((map) => CustomerModel.fromMap(map)).toList();
  }

  /// Get customer count
  Future<int> getCount({bool activeOnly = true}) async {
    String? where;
    List<dynamic>? whereArgs;

    if (activeOnly) {
      where = '${DbConstants.colIsDeleted} = ? AND is_active = ?';
      whereArgs = [0, 1];
    }

    return await _dbHelper.count(tableName, where: where, whereArgs: whereArgs);
  }

  // ==================== UPDATE ====================

  /// Update customer
  Future<int> update(CustomerModel customer) async {
    if (customer.localId == null) {
      throw ArgumentError('Customer localId cannot be null for update');
    }

    final data = customer.copyWith(
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    ).toMap();

    return await _dbHelper.update(
      tableName,
      data,
      where: '${DbConstants.colLocalId} = ?',
      whereArgs: [customer.localId],
    );
  }

  /// Update customer balance
  Future<int> updateBalance(int localId, double newBalance) async {
    return await _dbHelper.update(
      tableName,
      {
        'balance': newBalance,
        DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
        DbConstants.colSyncStatus: SyncStatus.pending.value,
      },
      where: '${DbConstants.colLocalId} = ?',
      whereArgs: [localId],
    );
  }

  /// Add to customer balance
  Future<int> addToBalance(int localId, double amount) async {
    final customer = await getById(localId);
    if (customer == null) return 0;

    return await updateBalance(localId, customer.balance + amount);
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

  /// Toggle customer active status
  Future<int> toggleActive(int localId) async {
    final customer = await getById(localId);
    if (customer == null) return 0;

    return await _dbHelper.update(
      tableName,
      {
        'is_active': customer.isActive ? 0 : 1,
        DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
        DbConstants.colSyncStatus: SyncStatus.pending.value,
      },
      where: '${DbConstants.colLocalId} = ?',
      whereArgs: [localId],
    );
  }

  // ==================== DELETE ====================

  /// Soft delete customer
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

  /// Hard delete customer (use with caution)
  Future<int> hardDelete(int localId) async {
    return await _dbHelper.delete(
      tableName,
      where: '${DbConstants.colLocalId} = ?',
      whereArgs: [localId],
    );
  }

  /// Restore soft-deleted customer
  Future<int> restore(int localId) async {
    return await _dbHelper.update(
      tableName,
      {
        DbConstants.colIsDeleted: 0,
        DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
        DbConstants.colSyncStatus: SyncStatus.pending.value,
      },
      where: '${DbConstants.colLocalId} = ?',
      whereArgs: [localId],
    );
  }

  // ==================== UTILITIES ====================

  /// Check if phone exists
  Future<bool> phoneExists(String phone, {int? excludeLocalId}) async {
    final normalizedPhone = _normalizePhone(phone);
    
    String where = '(phone = ? OR phone = ? OR phone = ?) AND ${DbConstants.colIsDeleted} = ?';
    List<dynamic> whereArgs = [phone, normalizedPhone, '0$normalizedPhone', 0];

    if (excludeLocalId != null) {
      where += ' AND ${DbConstants.colLocalId} != ?';
      whereArgs.add(excludeLocalId);
    }

    return await _dbHelper.exists(tableName, where: where, whereArgs: whereArgs);
  }

  /// Normalize phone number
  String _normalizePhone(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    
    // Remove country code if present
    if (cleaned.startsWith('94')) {
      cleaned = cleaned.substring(2);
    } else if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }
    
    return cleaned;
  }

  /// Clear all customers (for testing/reset)
  Future<void> clearAll() async {
    await _dbHelper.clearTable(tableName);
  }

  /// Get recently added customers
  Future<List<CustomerModel>> getRecent({int limit = 10}) async {
    final results = await _dbHelper.query(
      tableName,
      where: '${DbConstants.colIsDeleted} = ?',
      whereArgs: [0],
      orderBy: '${DbConstants.colCreatedAt} DESC',
      limit: limit,
    );

    return results.map((map) => CustomerModel.fromMap(map)).toList();
  }
}