import '../../constants/db_constants.dart';
import '../../constants/enums.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/models/transaction_item_model.dart';
import '../db_helper.dart';

class TransactionTable {
  final DbHelper _dbHelper;

  TransactionTable(this._dbHelper);

  // Table names
  static const String tableName = DbConstants.transactionsTable;
  static const String itemsTableName = DbConstants.transactionItemsTable;

  // Column names
  static const String colId = 'transaction_id';
  static const String colServerId = DbConstants.colServerId;
  static const String colTransactionNumber = 'transaction_number';
  static const String colType = 'transaction_type';
  static const String colStatus = 'status';
  static const String colCancelReason = 'cancel_reason';
  static const String colCustomerId = 'customer_local_id';
  static const String colCustomerName = 'customer_name';
  static const String colCustomerPhone = 'customer_phone';
  static const String colTotalWeightKg = 'total_weight_kg';
  static const String colTotalBags = 'total_bags';
  static const String colPricePerKg = 'price_per_kg';
  static const String colTotalAmount = 'total_amount';
  static const String colPaidAmount = 'paid_amount';
  static const String colPaymentStatus = 'payment_status';
  static const String colNotes = 'notes';
  static const String colTransactionDate = 'transaction_date';
  static const String colCreatedAt = DbConstants.colCreatedAt;
  static const String colUpdatedAt = DbConstants.colUpdatedAt;
  static const String colIsSynced = 'is_synced';
  static const String colSyncedAt = 'synced_at';
  static const String colIsDeleted = 'is_deleted';

  // Item table columns
  static const String colItemTransactionId = 'transaction_local_id';
  static const String colItemId = DbConstants.colLocalId;
  static const String colItemType = 'item_type';
  static const String colItemName = 'item_name';
  static const String colVariety = 'variety';
  static const String colWeightKg = 'weight_kg';
  static const String colBagCount = 'bag_count';
  static const String colAmount = 'amount';

  // Create transactions table SQL
  static const String createTableSQL = '''
    CREATE TABLE $tableName (
      ${DbConstants.colLocalId} INTEGER PRIMARY KEY AUTOINCREMENT,
      ${DbConstants.colServerId} TEXT,
      transaction_id TEXT UNIQUE NOT NULL,
      transaction_type TEXT NOT NULL,
      status TEXT DEFAULT 'pending',
      cancel_reason TEXT,
      customer_local_id INTEGER,
      customer_name TEXT,
      customer_phone TEXT,
      total_weight_kg REAL DEFAULT 0.0,
      total_bags INTEGER DEFAULT 0,
      price_per_kg REAL DEFAULT 0.0,
      total_amount REAL DEFAULT 0.0,
      paid_amount REAL DEFAULT 0.0,
      payment_status TEXT DEFAULT 'pending',
      notes TEXT,
      transaction_date TEXT NOT NULL,
      ${DbConstants.colCreatedAt} TEXT NOT NULL,
      ${DbConstants.colUpdatedAt} TEXT NOT NULL,
      is_synced INTEGER DEFAULT 0,
      ${DbConstants.colSyncStatus} TEXT DEFAULT 'pending',
      synced_at TEXT,
      ${DbConstants.colIsDeleted} INTEGER DEFAULT 0,
      FOREIGN KEY (customer_local_id) REFERENCES ${DbConstants.customersTable}(${DbConstants.colLocalId})
    )
  ''';

  // Create transaction items table SQL
  static const String createItemsTableSQL = '''
    CREATE TABLE $itemsTableName (
      ${DbConstants.colLocalId} INTEGER PRIMARY KEY AUTOINCREMENT,
      ${DbConstants.colServerId} TEXT,
      transaction_local_id INTEGER NOT NULL,
      item_type TEXT NOT NULL,
      item_name TEXT,
      variety TEXT,
      weight_kg REAL NOT NULL,
      bag_count INTEGER DEFAULT 1,
      price_per_kg REAL DEFAULT 0.0,
      amount REAL DEFAULT 0.0,
      ${DbConstants.colCreatedAt} TEXT NOT NULL,
      ${DbConstants.colSyncStatus} TEXT DEFAULT 'pending',
      FOREIGN KEY (transaction_local_id) REFERENCES $tableName(${DbConstants.colLocalId}) ON DELETE CASCADE
    )
  ''';

  // Create indexes SQL
  static const List<String> createIndexesSQL = [
    'CREATE INDEX idx_transactions_type ON $tableName(transaction_type)',
    'CREATE INDEX idx_transactions_date ON $tableName(transaction_date)',
    'CREATE INDEX idx_transactions_customer ON $tableName(customer_local_id)',
    'CREATE INDEX idx_transactions_payment ON $tableName(payment_status)',
    'CREATE INDEX idx_transactions_sync ON $tableName(${DbConstants.colSyncStatus})',
    'CREATE INDEX idx_transactions_is_synced ON $tableName(is_synced)',
    'CREATE INDEX idx_transaction_items_txn ON $itemsTableName(transaction_local_id)',
    'CREATE INDEX idx_transaction_items_type ON $itemsTableName(item_type)',
  ];

  // ==================== CREATE ====================

  /// Insert a new transaction with items
  Future<int> insert(TransactionModel transaction) async {
    return await _dbHelper.transaction((txn) async {
      // Insert transaction
      final txnData = transaction.toMap();
      txnData.remove(DbConstants.colLocalId);
      
      final transactionLocalId = await txn.insert(tableName, txnData);

      // Insert transaction items
      for (final item in transaction.items) {
        final itemData = item.copyWith(
          transactionLocalId: transactionLocalId,
        ).toMap();
        itemData.remove(DbConstants.colLocalId);
        
        await txn.insert(itemsTableName, itemData);
      }

      return transactionLocalId;
    });
  }

  // ==================== READ ====================

  /// Get all transactions
  Future<List<TransactionModel>> getAll({
    bool includeDeleted = false,
    TransactionType? filterType,
    PaymentStatus? filterPayment,
    int? limit,
    int? offset,
    String orderBy = 'transaction_date DESC',
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];

    if (!includeDeleted) {
      conditions.add('${DbConstants.colIsDeleted} = ?');
      args.add(0);
    }

    if (filterType != null) {
      conditions.add('transaction_type = ?');
      args.add(filterType.value);
    }

    if (filterPayment != null) {
      conditions.add('payment_status = ?');
      args.add(filterPayment.value);
    }

    final results = await _dbHelper.query(
      tableName,
      where: conditions.isNotEmpty ? conditions.join(' AND ') : null,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );

    final transactions = <TransactionModel>[];
    for (final map in results) {
      final transaction = TransactionModel.fromMap(map);
      final items = await getTransactionItems(transaction.localId!);
      transactions.add(transaction.copyWith(items: items));
    }

    return transactions;
  }

  /// Get transaction by local ID
  Future<TransactionModel?> getById(int localId) async {
    final results = await _dbHelper.query(
      tableName,
      where: '${DbConstants.colLocalId} = ?',
      whereArgs: [localId],
      limit: 1,
    );

    if (results.isEmpty) return null;

    final transaction = TransactionModel.fromMap(results.first);
    final items = await getTransactionItems(localId);
    return transaction.copyWith(items: items);
  }

  /// Get transaction by transaction ID
  Future<TransactionModel?> getByTransactionId(String transactionId) async {
    final results = await _dbHelper.query(
      tableName,
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
      limit: 1,
    );

    if (results.isEmpty) return null;

    final transaction = TransactionModel.fromMap(results.first);
    final items = await getTransactionItems(transaction.localId!);
    return transaction.copyWith(items: items);
  }

  /// Get transaction items
  Future<List<TransactionItemModel>> getTransactionItems(int transactionLocalId) async {
    final results = await _dbHelper.query(
      itemsTableName,
      where: 'transaction_local_id = ?',
      whereArgs: [transactionLocalId],
      orderBy: '${DbConstants.colCreatedAt} ASC',
    );

    return results.map((map) => TransactionItemModel.fromMap(map)).toList();
  }

  /// Get transactions by customer
  Future<List<TransactionModel>> getByCustomer(int customerLocalId, {int? limit}) async {
    final results = await _dbHelper.query(
      tableName,
      where: 'customer_local_id = ? AND ${DbConstants.colIsDeleted} = ?',
      whereArgs: [customerLocalId, 0],
      orderBy: 'transaction_date DESC',
      limit: limit,
    );

    final transactions = <TransactionModel>[];
    for (final map in results) {
      final transaction = TransactionModel.fromMap(map);
      final items = await getTransactionItems(transaction.localId!);
      transactions.add(transaction.copyWith(items: items));
    }

    return transactions;
  }

  /// Get transactions by type
  Future<List<TransactionModel>> getByType(TransactionType type, {int? limit}) async {
    return await getAll(filterType: type, limit: limit);
  }

  /// Get buy transactions
  Future<List<TransactionModel>> getBuyTransactions({int? limit}) async {
    return await getByType(TransactionType.buy, limit: limit);
  }

  /// Get sell transactions
  Future<List<TransactionModel>> getSellTransactions({int? limit}) async {
    return await getByType(TransactionType.sell, limit: limit);
  }

  /// Get transactions by date range
  Future<List<TransactionModel>> getByDateRange(
    DateTime startDate,
    DateTime endDate, {
    TransactionType? type,
  }) async {
    final conditions = <String>[
      'transaction_date >= ?',
      'transaction_date <= ?',
      '${DbConstants.colIsDeleted} = ?',
    ];
    final args = <dynamic>[
      startDate.toIso8601String(),
      endDate.toIso8601String(),
      0,
    ];

    if (type != null) {
      conditions.add('transaction_type = ?');
      args.add(type.value);
    }

    final results = await _dbHelper.query(
      tableName,
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'transaction_date DESC',
    );

    final transactions = <TransactionModel>[];
    for (final map in results) {
      final transaction = TransactionModel.fromMap(map);
      final items = await getTransactionItems(transaction.localId!);
      transactions.add(transaction.copyWith(items: items));
    }

    return transactions;
  }

  /// Get today's transactions
  Future<List<TransactionModel>> getTodayTransactions({TransactionType? type}) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    return await getByDateRange(startOfDay, endOfDay, type: type);
  }

  /// Get pending payment transactions
  Future<List<TransactionModel>> getPendingPayments() async {
    return await getAll(filterPayment: PaymentStatus.pending);
  }

  /// Get transactions pending sync
  Future<List<TransactionModel>> getPendingSync() async {
    final results = await _dbHelper.query(
      tableName,
      where: '${DbConstants.colSyncStatus} != ?',
      whereArgs: [SyncStatus.synced.value],
    );

    final transactions = <TransactionModel>[];
    for (final map in results) {
      final transaction = TransactionModel.fromMap(map);
      final items = await getTransactionItems(transaction.localId!);
      transactions.add(transaction.copyWith(items: items));
    }

    return transactions;
  }

  /// Get transaction count
  Future<int> getCount({TransactionType? type, bool todayOnly = false}) async {
    final conditions = <String>['${DbConstants.colIsDeleted} = ?'];
    final args = <dynamic>[0];

    if (type != null) {
      conditions.add('transaction_type = ?');
      args.add(type.value);
    }

    if (todayOnly) {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      conditions.add('transaction_date >= ?');
      args.add(startOfDay.toIso8601String());
    }

    return await _dbHelper.count(
      tableName,
      where: conditions.join(' AND '),
      whereArgs: args,
    );
  }

  /// Get transaction summary for date range
  Future<TransactionSummary> getSummary({
    DateTime? startDate,
    DateTime? endDate,
    TransactionType? type,
  }) async {
    String where = '${DbConstants.colIsDeleted} = ?';
    List<dynamic> whereArgs = [0];

    if (startDate != null) {
      where += ' AND transaction_date >= ?';
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      where += ' AND transaction_date <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    if (type != null) {
      where += ' AND transaction_type = ?';
      whereArgs.add(type.value);
    }

    final results = await _dbHelper.rawQuery('''
      SELECT 
        transaction_type,
        COUNT(*) as count,
        SUM(total_weight_kg) as total_weight,
        SUM(total_bags) as total_bags,
        SUM(total_amount) as total_amount,
        SUM(paid_amount) as paid_amount
      FROM $tableName
      WHERE $where
      GROUP BY transaction_type
    ''', whereArgs);

    double buyAmount = 0;
    double sellAmount = 0;
    double buyWeight = 0;
    double sellWeight = 0;
    int buyCount = 0;
    int sellCount = 0;

    for (final row in results) {
      final txnType = row['transaction_type'] as String;
      if (txnType == TransactionType.buy.value) {
        buyAmount = (row['total_amount'] as num?)?.toDouble() ?? 0;
        buyWeight = (row['total_weight'] as num?)?.toDouble() ?? 0;
        buyCount = row['count'] as int? ?? 0;
      } else if (txnType == TransactionType.sell.value) {
        sellAmount = (row['total_amount'] as num?)?.toDouble() ?? 0;
        sellWeight = (row['total_weight'] as num?)?.toDouble() ?? 0;
        sellCount = row['count'] as int? ?? 0;
      }
    }

    return TransactionSummary(
      buyAmount: buyAmount,
      sellAmount: sellAmount,
      buyWeight: buyWeight,
      sellWeight: sellWeight,
      buyCount: buyCount,
      sellCount: sellCount,
    );
  }

  // ==================== UPDATE ====================

  /// Update transaction
  Future<int> update(TransactionModel transaction) async {
    if (transaction.localId == null) {
      throw ArgumentError('Transaction localId cannot be null for update');
    }

    final data = transaction.copyWith(
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    ).toMap();

    return await _dbHelper.update(
      tableName,
      data,
      where: '${DbConstants.colLocalId} = ?',
      whereArgs: [transaction.localId],
    );
  }

  /// Update payment
  Future<int> updatePayment(
    int localId, {
    required double paidAmount,
    PaymentStatus? status,
  }) async {
    final transaction = await getById(localId);
    if (transaction == null) return 0;

    final newPaidAmount = paidAmount;
    PaymentStatus newStatus;

    if (status != null) {
      newStatus = status;
    } else {
      if (newPaidAmount >= transaction.totalAmount) {
        newStatus = PaymentStatus.completed;
      } else if (newPaidAmount > 0) {
        newStatus = PaymentStatus.partial;
      } else {
        newStatus = PaymentStatus.pending;
      }
    }

    return await _dbHelper.update(
      tableName,
      {
        'paid_amount': newPaidAmount,
        'payment_status': newStatus.value,
        DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
        DbConstants.colSyncStatus: SyncStatus.pending.value,
      },
      where: '${DbConstants.colLocalId} = ?',
      whereArgs: [localId],
    );
  }

  /// Add payment
  Future<int> addPayment(int localId, double amount) async {
    final transaction = await getById(localId);
    if (transaction == null) return 0;

    final newPaidAmount = transaction.paidAmount + amount;
    return await updatePayment(localId, paidAmount: newPaidAmount);
  }

  /// Update sync status
  Future<int> updateSyncStatus(
    int localId,
    SyncStatus status, {
    String? serverId,
  }) async {
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

  /// Soft delete transaction
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

  /// Hard delete transaction (cascade deletes items)
  Future<int> hardDelete(int localId) async {
    return await _dbHelper.transaction((txn) async {
      // Delete items first
      await txn.delete(
        itemsTableName,
        where: 'transaction_local_id = ?',
        whereArgs: [localId],
      );
      
      // Delete transaction
      return await txn.delete(
        tableName,
        where: '${DbConstants.colLocalId} = ?',
        whereArgs: [localId],
      );
    });
  }

  // ==================== UTILITIES ====================

  /// Generate next transaction ID
  Future<String> generateTransactionId(TransactionType type) async {
    final prefix = type == TransactionType.buy ? 'BUY' : 'SELL';
    final today = DateTime.now();
    final datePrefix = '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';
    
    // Get count for today
    final count = await getCount(type: type, todayOnly: true);
    final sequence = (count + 1).toString().padLeft(4, '0');
    
    return '$prefix-$datePrefix-$sequence';
  }

  /// Clear all transactions (for testing/reset)
  Future<void> clearAll() async {
    await _dbHelper.clearTable(itemsTableName);
    await _dbHelper.clearTable(tableName);
  }

  /// Get recent transactions
  Future<List<TransactionModel>> getRecent({int limit = 10}) async {
    return await getAll(limit: limit);
  }
}

// Transaction summary class
class TransactionSummary {
  final double buyAmount;
  final double sellAmount;
  final double buyWeight;
  final double sellWeight;
  final int buyCount;
  final int sellCount;

  TransactionSummary({
    required this.buyAmount,
    required this.sellAmount,
    required this.buyWeight,
    required this.sellWeight,
    required this.buyCount,
    required this.sellCount,
  });

  double get netAmount => sellAmount - buyAmount;
  double get netWeight => buyWeight - sellWeight; // Stock change
  int get totalCount => buyCount + sellCount;
}
