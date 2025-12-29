// lib/data/repositories/inventory_repository_impl.dart

import 'package:dartz/dartz.dart';
import '../../core/constants/enums.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../core/network/network_info.dart';
import '../../domain/entities/inventory_item_entity.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../datasources/local/inventory_local_ds.dart';
import '../datasources/remote/inventory_remote_ds.dart';
import '../models/inventory_item_model.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  final InventoryRemoteDataSource remoteDataSource;
  final InventoryLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  InventoryRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<InventoryItemEntity>>> getAllInventoryItems() async {
    try {
      final localItems = await localDataSource.getAllInventoryItems();

      // Sync in background if online
      if (await networkInfo.isConnected) {
        _syncInventoryInBackground();
      }

      return Right(localItems.map((i) => i.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, InventoryItemEntity>> getInventoryItemById(String id) async {
    try {
      final item = await localDataSource.getInventoryItemById(id);

      if (item != null) {
        return Right(item.toEntity());
      }

      // Try remote if online
      if (await networkInfo.isConnected) {
        try {
          final remoteItem = await remoteDataSource.getInventoryItemById(id);
          await localDataSource.insertInventoryItem(remoteItem.copyWith(isSynced: true));
          return Right(remoteItem.toEntity());
        } on NotFoundException {
          return Left(NotFoundFailure(message: 'Inventory item not found'));
        }
      }

      return Left(NotFoundFailure(message: 'Inventory item not found'));
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<InventoryItemEntity>>> getInventoryByType(ItemType type) async {
    try {
      final items = await localDataSource.getInventoryByType(type);
      return Right(items.map((i) => i.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<InventoryItemEntity>>> searchInventory(String query) async {
    try {
      final items = await localDataSource.searchInventory(query);
      return Right(items.map((i) => i.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, InventoryItemEntity>> addInventoryItem(InventoryItemModel item) async {
    try {
      final insertedItem = await localDataSource.insertInventoryItem(item);

      // Sync to server if online
      if (await networkInfo.isConnected) {
        try {
          final remoteItem = await remoteDataSource.createInventoryItem(insertedItem);
          final syncedItem = insertedItem.copyWith(
            serverId: remoteItem.serverId,
            isSynced: true,
            syncedAt: DateTime.now(),
          );
          await localDataSource.updateInventoryItem(syncedItem);
          return Right(syncedItem.toEntity());
        } catch (_) {
          return Right(insertedItem.toEntity());
        }
      }

      return Right(insertedItem.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, InventoryItemEntity>> updateInventoryItem(InventoryItemModel item) async {
    try {
      final updatedItem = await localDataSource.updateInventoryItem(item);

      if (await networkInfo.isConnected && item.serverId != null) {
        try {
          await remoteDataSource.updateInventoryItem(updatedItem);
          final syncedItem = updatedItem.copyWith(
            isSynced: true,
            syncedAt: DateTime.now(),
          );
          await localDataSource.updateInventoryItem(syncedItem);
          return Right(syncedItem.toEntity());
        } catch (_) {
          return Right(updatedItem.toEntity());
        }
      }

      return Right(updatedItem.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } on NotFoundException {
      return Left(NotFoundFailure(message: 'Inventory item not found'));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, InventoryItemEntity>> addStock({
    required String itemId,
    required double quantity,
    required int bags,
    required String transactionId,
  }) async {
    try {
      final updatedItem = await localDataSource.addStock(
        itemId: itemId,
        quantity: quantity,
        bags: bags,
        transactionId: transactionId,
      );

      // Sync to server if online
      if (await networkInfo.isConnected && updatedItem.serverId != null) {
        try {
          await remoteDataSource.addStock(
            itemId: updatedItem.serverId!,
            quantity: quantity,
            bags: bags,
            transactionId: transactionId,
          );
          
          final syncedItem = updatedItem.copyWith(
            isSynced: true,
            syncedAt: DateTime.now(),
          );
          await localDataSource.updateInventoryItem(syncedItem);
          return Right(syncedItem.toEntity());
        } catch (_) {
          return Right(updatedItem.toEntity());
        }
      }

      return Right(updatedItem.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } on NotFoundException {
      return Left(NotFoundFailure(message: 'Inventory item not found'));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, InventoryItemEntity>> deductStock({
    required String itemId,
    required double quantity,
    required int bags,
    required String transactionId,
  }) async {
    try {
      final updatedItem = await localDataSource.deductStock(
        itemId: itemId,
        quantity: quantity,
        bags: bags,
        transactionId: transactionId,
      );

      // Sync to server if online
      if (await networkInfo.isConnected && updatedItem.serverId != null) {
        try {
          await remoteDataSource.deductStock(
            itemId: updatedItem.serverId!,
            quantity: quantity,
            bags: bags,
            transactionId: transactionId,
          );
          
          final syncedItem = updatedItem.copyWith(
            isSynced: true,
            syncedAt: DateTime.now(),
          );
          await localDataSource.updateInventoryItem(syncedItem);
          return Right(syncedItem.toEntity());
        } catch (_) {
          return Right(updatedItem.toEntity());
        }
      }

      return Right(updatedItem.toEntity());
    } on CacheException catch (e) {
      if (e.message.contains('Insufficient stock')) {
        return Left(ValidationFailure(message: e.message));
      }
      return Left(CacheFailure(message: e.message));
    } on NotFoundException {
      return Left(NotFoundFailure(message: 'Inventory item not found'));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> deleteInventoryItem(String id) async {
    try {
      final item = await localDataSource.getInventoryItemById(id);
      if (item == null) {
        return Left(NotFoundFailure(message: 'Inventory item not found'));
      }

      await localDataSource.deleteInventoryItem(id);

      if (await networkInfo.isConnected && item.serverId != null) {
        try {
          await remoteDataSource.deleteInventoryItem(item.serverId!);
        } catch (_) {
          // Will be synced later
        }
      }

      return const Right(true);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<ItemType, double>>> getTotalStockByType() async {
    try {
      final totals = await localDataSource.getTotalStockByType();
      return Right(totals);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<InventoryItemEntity>>> getLowStockItems(double threshold) async {
    try {
      final items = await localDataSource.getLowStockItems(threshold);
      return Right(items.map((i) => i.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, InventoryItemModel>> getOrCreateInventoryItem({
    required ItemType type,
    required String variety,
    required String companyId,
  }) async {
    try {
      final item = await localDataSource.getOrCreateInventoryItem(
        type: type,
        variety: variety,
        companyId: companyId,
      );
      return Right(item);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getStockMovementHistory(String itemId) async {
    try {
      final history = await localDataSource.getStockMovementHistory(itemId);
      return Right(history);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> recordMilling({
    required String paddyItemId,
    required String riceItemId,
    required double paddyQuantity,
    required int paddyBags,
    required double riceQuantity,
    required int riceBags,
    required double wastageQuantity,
    String? notes,
  }) async {
    try {
      // Deduct paddy stock
      final paddyResult = await deductStock(
        itemId: paddyItemId,
        quantity: paddyQuantity,
        bags: paddyBags,
        transactionId: 'MILL_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (paddyResult.isLeft()) {
        return Left(paddyResult.fold((l) => l, (r) => UnknownFailure()));
      }

      // Add rice stock
      final riceResult = await addStock(
        itemId: riceItemId,
        quantity: riceQuantity,
        bags: riceBags,
        transactionId: 'MILL_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (riceResult.isLeft()) {
        // Rollback paddy deduction
        await addStock(
          itemId: paddyItemId,
          quantity: paddyQuantity,
          bags: paddyBags,
          transactionId: 'MILL_ROLLBACK_${DateTime.now().millisecondsSinceEpoch}',
        );
        return Left(riceResult.fold((l) => l, (r) => UnknownFailure()));
      }

      // Record milling on server if online
      if (await networkInfo.isConnected) {
        try {
          final paddyItem = await localDataSource.getInventoryItemById(paddyItemId);
          final riceItem = await localDataSource.getInventoryItemById(riceItemId);
          
          if (paddyItem?.serverId != null && riceItem?.serverId != null) {
            await remoteDataSource.recordMilling(
              paddyItemId: paddyItem!.serverId!,
              riceItemId: riceItem!.serverId!,
              paddyQuantity: paddyQuantity,
              paddyBags: paddyBags,
              riceQuantity: riceQuantity,
              riceBags: riceBags,
              wastageQuantity: wastageQuantity,
              notes: notes,
            );
          }
        } catch (_) {
          // Will be synced later
        }
      }

      return Right({
        'paddy_deducted': paddyQuantity,
        'rice_produced': riceQuantity,
        'wastage': wastageQuantity,
        'efficiency': (riceQuantity / paddyQuantity) * 100,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> syncInventory() async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure());
    }

    try {
      final unsyncedItems = await localDataSource.getUnsyncedInventoryItems();

      if (unsyncedItems.isNotEmpty) {
        final syncedItems = await remoteDataSource.syncInventory(unsyncedItems);

        for (final synced in syncedItems) {
          final localItem = unsyncedItems.firstWhere(
            (i) => i.id == synced.id || (i.variety == synced.variety && i.type == synced.type),
            orElse: () => synced,
          );

          await localDataSource.markInventoryItemAsSynced(
            localItem.id,
            synced.serverId ?? synced.id,
          );
        }
      }

      // Fetch server updates
      final remoteItems = await remoteDataSource.getAllInventoryItems();
      for (final remoteItem in remoteItems) {
        final localItem = await localDataSource.getInventoryItemById(remoteItem.id);
        if (localItem == null) {
          await localDataSource.insertInventoryItem(remoteItem.copyWith(isSynced: true));
        }
      }

      return const Right(null);
    } on SyncException catch (e) {
      return Left(SyncFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<InventoryItemModel>>> getUnsyncedInventoryItems() async {
    try {
      final items = await localDataSource.getUnsyncedInventoryItems();
      return Right(items);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getInventorySummary() async {
    try {
      final allItems = await localDataSource.getAllInventoryItems();
      final totalsByType = await localDataSource.getTotalStockByType();
      final lowStockItems = await localDataSource.getLowStockItems(100); // Default threshold

      final totalItems = allItems.length;
      final totalQuantity = totalsByType.values.fold<double>(0, (sum, value) => sum + value);
      final totalValue = allItems.fold<double>(0, (sum, item) =>
        sum + (item.currentQuantity * item.averagePricePerKg));

      final breakdownByType = <String, Map<String, dynamic>>{};
      for (final type in ItemType.values) {
        final typeItems = allItems.where((item) => item.type == type).toList();
        final typeQuantity = totalsByType[type] ?? 0;
        final typeValue = typeItems.fold<double>(0, (sum, item) =>
          sum + (item.currentQuantity * item.averagePricePerKg));

        breakdownByType[type.name] = {
          'count': typeItems.length,
          'quantity': typeQuantity,
          'value': typeValue,
          'avgPrice': typeItems.isNotEmpty ?
            typeItems.fold<double>(0, (sum, item) => sum + item.averagePricePerKg) / typeItems.length : 0,
        };
      }

      return Right({
        'totalItems': totalItems,
        'totalQuantity': totalQuantity,
        'totalValue': totalValue,
        'lowStockCount': lowStockItems.length,
        'breakdownByType': breakdownByType,
        'lastUpdated': DateTime.now().toIso8601String(),
      });
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<ItemType, double>>> getStockValueByType() async {
    try {
      final allItems = await localDataSource.getAllInventoryItems();
      final Map<ItemType, double> result = {};

      for (final type in ItemType.values) {
        final typeItems = allItems.where((item) => item.type == type);
        final typeValue = typeItems.fold<double>(0, (sum, item) =>
          sum + (item.currentQuantity * item.averagePricePerKg));
        result[type] = typeValue;
      }

      return Right(result);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getVarieties({ItemType? type}) async {
    try {
      final allItems = await localDataSource.getAllInventoryItems();
      final varieties = <String>{};

      if (type != null) {
        varieties.addAll(
          allItems.where((item) => item.type == type).map((item) => item.variety)
        );
      } else {
        varieties.addAll(allItems.map((item) => item.variety));
      }

      return Right(varieties.toList()..sort());
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> isVarietyExists({
    required String variety,
    required ItemType type,
  }) async {
    try {
      final allItems = await localDataSource.getAllInventoryItems();
      final exists = allItems.any((item) =>
        item.variety.toLowerCase() == variety.toLowerCase() && item.type == type);

      return Right(exists);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, InventoryItemEntity>> adjustStock({
    required String itemId,
    required double newQuantity,
    required int newBags,
    required String reason,
  }) async {
    try {
      final currentItem = await localDataSource.getInventoryItemById(itemId);
      if (currentItem == null) {
        return Left(NotFoundFailure(message: 'Inventory item not found'));
      }

      // Calculate adjustment amounts
      final quantityAdjustment = newQuantity - currentItem.currentQuantity;
      final bagsAdjustment = newBags - currentItem.currentBags;

      // Update the item
      final updatedItem = currentItem.copyWith(
        currentQuantity: newQuantity,
        currentBags: newBags,
        lastStockUpdateAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isSynced: false,
      );

      await localDataSource.updateInventoryItem(updatedItem);

      // Record stock movement
      await localDataSource.recordStockMovement(
        itemId: itemId,
        movementType: MovementType.adjustment,
        quantity: quantityAdjustment.abs(),
        bags: bagsAdjustment.abs(),
        transactionId: 'ADJ_${DateTime.now().millisecondsSinceEpoch}',
        notes: 'Stock adjustment: $reason',
      );

      // Stock adjustments are saved locally and will sync later
      // No immediate server sync for adjustments to avoid conflicts

      return Right(updatedItem.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  void _syncInventoryInBackground() async {
    try {
      await syncInventory();
    } catch (_) {}
  }
}
