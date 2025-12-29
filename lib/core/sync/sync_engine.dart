import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:rice_mill_erp/core/constants/enums.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/sync_queue_model.dart';
import '../constants/app_constants.dart';
import '../constants/db_constants.dart';
import '../database/db_helper.dart';
import '../database/tables/sync_queue_table.dart';
import '../errors/exceptions.dart';
import '../network/api_service.dart';
import '../network/network_info.dart';
import 'conflict_resolver.dart';
import 'sync_status.dart';

/// Main sync engine for offline-first synchronization
class SyncEngine extends ChangeNotifier {
  final DbHelper _dbHelper;
  final ApiService _apiService;
  final NetworkInfo _networkInfo;
  final SharedPreferences _prefs;
  final ConflictResolver _conflictResolver;
  final Logger _logger = Logger();

  // Sync state
  SyncStatusModel _status = const SyncStatusModel();
  bool _isSyncing = false;
  Timer? _syncTimer;
  StreamSubscription<bool>? _connectivitySubscription;
  CancelToken? _currentCancelToken;

  // Sync configuration
  final Duration syncInterval;
  final int maxRetries;
  final Duration retryDelay;
  final int batchSize;
  final List<String> syncOrder;

  // Callbacks
  void Function(SyncStatusModel)? onStatusChange;
  void Function(SyncResult)? onSyncComplete;
  void Function(SyncError)? onError;
  void Function(SyncConflict)? onConflict;

  SyncEngine({
    required DbHelper dbHelper,
    required ApiService apiService,
    required NetworkInfo networkInfo,
    required SharedPreferences prefs,
    ConflictResolver? conflictResolver,
    this.syncInterval = AppConstants.syncInterval,
    this.maxRetries = AppConstants.maxRetryAttempts,
    this.retryDelay = AppConstants.retryDelay,
    this.batchSize = 50,
    this.syncOrder = const [
      DbConstants.customersTable,
      DbConstants.inventoryTable,
      DbConstants.transactionsTable,
      DbConstants.transactionItemsTable,
    ],
    this.onStatusChange,
    this.onSyncComplete,
    this.onError,
    this.onConflict,
  })  : _dbHelper = dbHelper,
        _apiService = apiService,
        _networkInfo = networkInfo,
        _prefs = prefs,
        _conflictResolver = conflictResolver ?? 
            ConflictResolver(dbHelper: dbHelper) {
    _initConnectivityListener();
    _loadLastSyncTime();
  }

  // ==================== GETTERS ====================

  SyncStatusModel get status => _status;
  bool get isSyncing => _isSyncing;
  bool get isOnline => !_status.isOffline;
  int get pendingCount => _status.pendingCount;
  DateTime? get lastSyncTime => _status.lastSyncTime;
  List<SyncConflict> get conflicts => _conflictResolver.conflicts;
  bool get hasConflicts => _conflictResolver.hasUnresolvedConflicts;

  // ==================== INITIALIZATION ====================

  /// Initialize connectivity listener
  void _initConnectivityListener() {
    _connectivitySubscription = _networkInfo.onConnectivityChanged.listen(
      (isConnected) {
        if (isConnected) {
          _updateStatus(_status.copyWith(state: SyncState.idle, clearError: true));
          // Auto-sync when back online
          if (_status.hasPending) {
            syncNow();
          }
        } else {
          _updateStatus(_status.copyWith(state: SyncState.offline));
        }
      },
    );

    // Check initial connectivity
    _networkInfo.isConnected.then((isConnected) {
      if (!isConnected) {
        _updateStatus(_status.copyWith(state: SyncState.offline));
      }
    });
  }

  /// Load last sync time from preferences
  void _loadLastSyncTime() {
    final lastSync = _prefs.getString(AppConstants.lastSyncKey);
    if (lastSync != null) {
      try {
        final dateTime = DateTime.parse(lastSync);
        _updateStatus(_status.copyWith(lastSyncTime: dateTime));
      } catch (_) {}
    }
    
    // Load pending count
    _refreshPendingCount();
  }

  // ==================== PERIODIC SYNC ====================

  /// Start periodic sync
  void startPeriodicSync() {
    stopPeriodicSync();
    
    _syncTimer = Timer.periodic(syncInterval, (_) {
      if (!_isSyncing && _status.hasPending) {
        syncNow();
      }
    });
    
    _logger.i('Periodic sync started (interval: ${syncInterval.inMinutes}m)');
  }

  /// Stop periodic sync
  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _logger.i('Periodic sync stopped');
  }

  // ==================== SYNC OPERATIONS ====================

  /// Trigger immediate sync
  Future<SyncResult> syncNow({bool forceFull = false}) async {
    if (_isSyncing) {
      _logger.d('Sync already in progress');
      return SyncResult.failure(
        errors: [SyncError.create(
          tableName: '',
          operation: 'sync',
          message: 'Sync already in progress',
          isRetryable: false,
        )],
        duration: Duration.zero,
      );
    }

    if (!await _networkInfo.isConnected) {
      _updateStatus(SyncStatusModel.offline(pendingCount: _status.pendingCount));
      return SyncResult.failure(
        errors: [SyncError.create(
          tableName: '',
          operation: 'sync',
          message: 'No internet connection',
          isRetryable: true,
        )],
        duration: Duration.zero,
      );
    }

    _isSyncing = true;
    _currentCancelToken = CancelToken();
    final startTime = DateTime.now();
    
    _updateStatus(SyncStatusModel.syncing(
      phase: SyncPhase.preparing,
    ).copyWith(
      lastSyncTime: _status.lastSyncTime,
      startedAt: startTime,
    ));

    try {
      // Get pending items count
      final pendingCount = await _getPendingCount();
      _updateStatus(_status.copyWith(totalCount: pendingCount));

      int pushedCount = 0;
      int pulledCount = 0;
      final errors = <SyncError>[];

      // Phase 1: Push local changes
      _updateStatus(_status.copyWith(phase: SyncPhase.pushing));
      final pushResult = await _pushChanges();
      pushedCount = pushResult.successCount;
      errors.addAll(pushResult.errors);

      // Phase 2: Pull server changes
      _updateStatus(_status.copyWith(phase: SyncPhase.pulling));
      final pullResult = await _pullChanges(forceFull: forceFull);
      pulledCount = pullResult.successCount;
      errors.addAll(pullResult.errors);

      // Phase 3: Resolve conflicts
      if (_conflictResolver.hasUnresolvedConflicts) {
        _updateStatus(_status.copyWith(
          phase: SyncPhase.resolving,
          conflictCount: _conflictResolver.conflictCount,
        ));
        await _conflictResolver.resolveAllConflicts();
      }

      // Phase 4: Finalize
      _updateStatus(_status.copyWith(phase: SyncPhase.finalizing));
      
      // Save last sync time
      final now = DateTime.now();
      await _prefs.setString(AppConstants.lastSyncKey, now.toIso8601String());
      
      // Refresh pending count
      await _refreshPendingCount();

      final duration = DateTime.now().difference(startTime);
      final result = errors.isEmpty
          ? SyncResult.success(
              pushedCount: pushedCount,
              pulledCount: pulledCount,
              duration: duration,
            )
          : SyncResult(
              success: errors.length < pendingCount,
              pushedCount: pushedCount,
              pulledCount: pulledCount,
              failedCount: errors.length,
              errors: errors,
              duration: duration,
              completedAt: DateTime.now(),
            );

      _updateStatus(SyncStatusModel.success(
        syncedCount: pushedCount + pulledCount,
        lastSyncTime: now,
      ).copyWith(
        pendingCount: _status.pendingCount,
        conflictCount: _conflictResolver.conflictCount,
        resolvedConflictCount: _conflictResolver.resolvedCount,
      ));

      onSyncComplete?.call(result);
      _logger.i('Sync completed: pushed=$pushedCount, pulled=$pulledCount, '
          'errors=${errors.length}, duration=${duration.inSeconds}s');

      return result;
    } catch (e, stackTrace) {
      _logger.e('Sync failed', error: e, stackTrace: stackTrace);
      
      final errorMessage = e is SyncException ? e.message : e.toString();
      _updateStatus(SyncStatusModel.error(
        message: errorMessage,
        pendingCount: _status.pendingCount,
      ).copyWith(lastSyncTime: _status.lastSyncTime));

      return SyncResult.failure(
        errors: [SyncError.create(
          tableName: '',
          operation: 'sync',
          message: errorMessage,
        )],
        duration: DateTime.now().difference(startTime),
      );
    } finally {
      _isSyncing = false;
      _currentCancelToken = null;
    }
  }

  /// Cancel ongoing sync
  void cancelSync() {
    if (_isSyncing && _currentCancelToken != null) {
      _currentCancelToken!.cancel('User cancelled');
      _isSyncing = false;
      _updateStatus(_status.copyWith(state: SyncState.cancelled));
      _logger.i('Sync cancelled by user');
    }
  }

  // ==================== PUSH OPERATIONS ====================

  /// Push local changes to server
  Future<_SyncBatchResult> _pushChanges() async {
    final syncQueueTable = SyncQueueTable(_dbHelper);
    final pendingItems = await syncQueueTable.getPendingItems(
      maxRetries: maxRetries,
      limit: batchSize,
    );

    if (pendingItems.isEmpty) {
      return _SyncBatchResult.empty();
    }

    int successCount = 0;
    final errors = <SyncError>[];
    final processedIds = <int>[];

    // Group by table for efficient processing
    final groupedItems = <String, List<SyncQueueModel>>{};
    for (final item in pendingItems) {
      groupedItems.putIfAbsent(item.tableName, () => []).add(item);
    }

    // Process each table in order
    for (final tableName in syncOrder) {
      if (!groupedItems.containsKey(tableName)) continue;

      final tableItems = groupedItems[tableName]!;
      _updateStatus(_status.copyWith(currentTable: tableName));

      for (final item in tableItems) {
        try {
          await _processSyncItem(item);
          processedIds.add(item.localId!);
          successCount++;
          
          _updateStatus(_status.copyWith(
            syncedCount: _status.syncedCount + 1,
            progress: (_status.syncedCount + 1) / _status.totalCount,
          ));
        } catch (e) {
          final error = SyncError.create(
            tableName: item.tableName,
            recordId: item.recordLocalId,
            operation: item.operation.value,
            message: e.toString(),
          );
          errors.add(error);
          onError?.call(error);
          
          // Update retry count
          await syncQueueTable.recordFailure(item.localId!, e.toString());
        }
      }
    }

    // Remove successfully processed items
    if (processedIds.isNotEmpty) {
      await syncQueueTable.removeCompleted(processedIds);
    }

    return _SyncBatchResult(
      successCount: successCount,
      errors: errors,
    );
  }

  /// Process individual sync queue item
  Future<void> _processSyncItem(SyncQueueModel item) async {
    final endpoint = _getEndpointForTable(item.tableName);
    
    switch (item.operation) {
      case SyncOperation.create:
        await _handleCreate(item, endpoint);
        break;
        
      case SyncOperation.update:
        await _handleUpdate(item, endpoint);
        break;
        
      case SyncOperation.delete:
        await _handleDelete(item, endpoint);
        break;
    }
  }

  /// Handle create operation
  Future<void> _handleCreate(SyncQueueModel item, String endpoint) async {
    final result = await _apiService.post(
      endpoint,
      data: item.data,
    );

    await result.fold(
      (failure) => throw SyncException(message: failure.message),
      (response) async {
        if (response.success && response.data != null) {
          final serverId = response.data['id']?.toString();
          if (serverId != null) {
            await _dbHelper.update(
              item.tableName,
              {
                DbConstants.colServerId: serverId,
                DbConstants.colSyncStatus: 'synced',
                DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
              },
              where: '${DbConstants.colLocalId} = ?',
              whereArgs: [item.recordLocalId],
            );
          }
        }
      },
    );
  }

  /// Handle update operation
  Future<void> _handleUpdate(SyncQueueModel item, String endpoint) async {
    final serverId = item.data[DbConstants.colServerId];
    if (serverId == null) {
      throw SyncException(message: 'No server ID for update');
    }

    final result = await _apiService.put(
      '$endpoint/$serverId',
      data: item.data,
    );

    await result.fold(
      (failure) => throw SyncException(message: failure.message),
      (response) async {
        if (response.success) {
          await _dbHelper.update(
            item.tableName,
            {
              DbConstants.colSyncStatus: 'synced',
              DbConstants.colUpdatedAt: DateTime.now().toIso8601String(),
            },
            where: '${DbConstants.colLocalId} = ?',
            whereArgs: [item.recordLocalId],
          );
        }
      },
    );
  }

  /// Handle delete operation
  Future<void> _handleDelete(SyncQueueModel item, String endpoint) async {
    final serverId = item.data[DbConstants.colServerId];
    if (serverId == null) {
      // No server ID means never synced, just remove locally
      return;
    }

    final result = await _apiService.delete('$endpoint/$serverId');

    result.fold(
      (failure) {
        // If 404, item already deleted on server - that's ok
        if (failure.code != 404) {
          throw SyncException(message: failure.message);
        }
      },
      (_) {},
    );
  }

  // ==================== PULL OPERATIONS ====================

  /// Pull changes from server
  Future<_SyncBatchResult> _pullChanges({bool forceFull = false}) async {
    int successCount = 0;
    final errors = <SyncError>[];

    try {
      // Get last sync timestamp
      String? since;
      if (!forceFull && _status.lastSyncTime != null) {
        since = _status.lastSyncTime!.toIso8601String();
      }

      final result = await _apiService.get<Map<String, dynamic>>(
        '/sync/pull',
        queryParameters: {
          if (since != null) 'since': since,
        },
      );

      await result.fold(
        (failure) {
          errors.add(SyncError.create(
            tableName: '',
            operation: 'pull',
            message: failure.message,
          ));
        },
        (response) async {
          if (response.success && response.data != null) {
            final data = response.data!;
            
            // Process each table
            for (final tableName in syncOrder) {
              final records = data[tableName] as List<dynamic>?;
              if (records == null || records.isEmpty) continue;

              _updateStatus(_status.copyWith(currentTable: tableName));

              for (final record in records) {
                try {
                  await _upsertRecord(
                    tableName,
                    record as Map<String, dynamic>,
                  );
                  successCount++;
                } catch (e) {
                  errors.add(SyncError.create(
                    tableName: tableName,
                    operation: 'upsert',
                    message: e.toString(),
                  ));
                }
              }
            }
          }
        },
      );
    } catch (e) {
      errors.add(SyncError.create(
        tableName: '',
        operation: 'pull',
        message: e.toString(),
      ));
    }

    return _SyncBatchResult(
      successCount: successCount,
      errors: errors,
    );
  }

  /// Upsert record from server
  Future<void> _upsertRecord(
    String tableName,
    Map<String, dynamic> serverData,
  ) async {
    final serverId = serverData['id']?.toString();
    if (serverId == null) return;

    // Check for existing record
    final existing = await _dbHelper.query(
      tableName,
      where: '${DbConstants.colServerId} = ?',
      whereArgs: [serverId],
      limit: 1,
    );

    if (existing.isEmpty) {
      // Insert new record
      final localData = _mapServerDataToLocal(serverData);
      await _dbHelper.insert(tableName, localData);
    } else {
      final localRecord = existing.first;
      final localId = localRecord[DbConstants.colLocalId];
      final localSyncStatus = localRecord[DbConstants.colSyncStatus];

      // Check for conflict
      if (localSyncStatus == 'pending') {
        // Local has unsent changes - potential conflict
        final conflict = await _conflictResolver.detectConflict(
          tableName: tableName,
          localId: localId as int,
          localData: localRecord,
          serverData: serverData,
        );

        if (conflict != null) {
          onConflict?.call(conflict);
          return; // Let conflict resolver handle it
        }
      }

      // Update existing record
      final localData = _mapServerDataToLocal(serverData);
      await _dbHelper.update(
        tableName,
        localData,
        where: '${DbConstants.colLocalId} = ?',
        whereArgs: [localId],
      );
    }
  }

  // ==================== QUEUE OPERATIONS ====================

  /// Add item to sync queue
  Future<void> addToQueue({
    required String tableName,
    required int recordLocalId,
    required SyncOperation operation,
    required Map<String, dynamic> data,
  }) async {
    final syncQueueTable = SyncQueueTable(_dbHelper);
    
    switch (operation) {
      case SyncOperation.create:
        await syncQueueTable.queueCreate(
          table: tableName,
          recordLocalId: recordLocalId,
          data: data,
        );
        break;
        
      case SyncOperation.update:
        await syncQueueTable.queueUpdate(
          table: tableName,
          recordLocalId: recordLocalId,
          data: data,
        );
        break;
        
      case SyncOperation.delete:
        await syncQueueTable.queueDelete(
          table: tableName,
          recordLocalId: recordLocalId,
          data: data,
        );
        break;
    }

    await _refreshPendingCount();

    // Auto-sync if online
    if (await _networkInfo.isConnected && !_isSyncing) {
      // Debounce - sync after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        if (!_isSyncing && _status.hasPending) {
          syncNow();
        }
      });
    }
  }

  /// Get pending items count
  Future<int> _getPendingCount() async {
    final syncQueueTable = SyncQueueTable(_dbHelper);
    return await syncQueueTable.getPendingCount();
  }

  /// Refresh pending count in status
  Future<void> _refreshPendingCount() async {
    final count = await _getPendingCount();
    _updateStatus(_status.copyWith(pendingCount: count));
  }

  // ==================== UTILITIES ====================

  /// Update status and notify listeners
  void _updateStatus(SyncStatusModel newStatus) {
    _status = newStatus;
    onStatusChange?.call(newStatus);
    notifyListeners();
  }

  /// Get API endpoint for table
  String _getEndpointForTable(String tableName) {
    switch (tableName) {
      case DbConstants.customersTable:
        return '/customers';
      case DbConstants.inventoryTable:
        return '/inventory';
      case DbConstants.transactionsTable:
        return '/transactions';
      case DbConstants.transactionItemsTable:
        return '/transaction-items';
      default:
        return '/$tableName';
    }
  }

  /// Map server data to local format
  Map<String, dynamic> _mapServerDataToLocal(Map<String, dynamic> serverData) {
    final localData = Map<String, dynamic>.from(serverData);
    
    // Map 'id' to 'server_id'
    if (serverData.containsKey('id')) {
      localData[DbConstants.colServerId] = serverData['id'].toString();
      localData.remove('id');
    }
    
    // Map timestamps
    if (serverData.containsKey('created_at')) {
      localData[DbConstants.colCreatedAt] = serverData['created_at'];
    }
    if (serverData.containsKey('updated_at')) {
      localData[DbConstants.colUpdatedAt] = serverData['updated_at'];
    }
    
    // Set sync status
    localData[DbConstants.colSyncStatus] = 'synced';
    localData[DbConstants.colIsDeleted] = 0;
    
    return localData;
  }

  /// Force full sync (clear local and pull all)
  Future<SyncResult> forceFullSync() async {
    _logger.w('Starting full sync - this will overwrite local changes');
    
    // Clear sync queue
    final syncQueueTable = SyncQueueTable(_dbHelper);
    await syncQueueTable.clearAll();
    
    return await syncNow(forceFull: true);
  }

  /// Clear all sync data
  Future<void> clearSyncData() async {
    final syncQueueTable = SyncQueueTable(_dbHelper);
    await syncQueueTable.clearAll();
    await _prefs.remove(AppConstants.lastSyncKey);
    _conflictResolver.clearConflicts();
    _updateStatus(const SyncStatusModel());
    _logger.i('Sync data cleared');
  }

  /// Get sync statistics
  Future<Map<String, dynamic>> getSyncStats() async {
    final syncQueueTable = SyncQueueTable(_dbHelper);
    final pending = await syncQueueTable.getAll();
    
    final stats = <String, int>{};
    for (final item in pending) {
      stats[item.tableName] = (stats[item.tableName] ?? 0) + 1;
    }

    return {
      'pendingCount': pending.length,
      'byTable': stats,
      'conflictCount': _conflictResolver.conflictCount,
      'lastSyncTime': _status.lastSyncTime?.toIso8601String(),
      'isOnline': await _networkInfo.isConnected,
    };
  }

  @override
  void dispose() {
    stopPeriodicSync();
    _connectivitySubscription?.cancel();
    _currentCancelToken?.cancel();
    super.dispose();
  }
}

// ==================== HELPER CLASSES ====================

/// Result of a sync batch operation
class _SyncBatchResult {
  final int successCount;
  final List<SyncError> errors;

  _SyncBatchResult({
    required this.successCount,
    required this.errors,
  });

  factory _SyncBatchResult.empty() => _SyncBatchResult(
        successCount: 0,
        errors: [],
      );

  bool get hasErrors => errors.isNotEmpty;
  int get failedCount => errors.length;
}

/// Cancel token for sync operations
class CancelToken {
  bool _isCancelled = false;
  String? _reason;

  bool get isCancelled => _isCancelled;
  String? get reason => _reason;

  void cancel([String? reason]) {
    _isCancelled = true;
    _reason = reason;
  }

  void throwIfCancelled() {
    if (_isCancelled) {
      throw SyncException(message: _reason ?? 'Sync cancelled');
    }
  }
}

// ==================== SYNC MIXIN ====================

/// Mixin for adding sync capability to repositories
mixin SyncableRepository {
  SyncEngine get syncEngine;
  String get tableName;

  /// Queue record for sync after create
  Future<void> queueCreate(int localId, Map<String, dynamic> data) async {
    await syncEngine.addToQueue(
      tableName: tableName,
      recordLocalId: localId,
      operation: SyncOperation.create,
      data: data,
    );
  }

  /// Queue record for sync after update
  Future<void> queueUpdate(int localId, Map<String, dynamic> data) async {
    await syncEngine.addToQueue(
      tableName: tableName,
      recordLocalId: localId,
      operation: SyncOperation.update,
      data: data,
    );
  }

  /// Queue record for sync after delete
  Future<void> queueDelete(int localId, Map<String, dynamic> data) async {
    await syncEngine.addToQueue(
      tableName: tableName,
      recordLocalId: localId,
      operation: SyncOperation.delete,
      data: data,
    );
  }
}