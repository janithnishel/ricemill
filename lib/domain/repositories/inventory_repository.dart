// lib/domain/repositories/inventory_repository.dart

import 'package:dartz/dartz.dart';
import '../../core/constants/enums.dart';
import '../../core/errors/failures.dart';
import '../../data/models/inventory_item_model.dart';
import '../entities/inventory_item_entity.dart';

/// Abstract repository interface for inventory operations
/// Handles all stock management operations with offline-first support
abstract class InventoryRepository {
  /// Get all inventory items
  /// 
  /// Returns list of [InventoryItemEntity] from local database
  /// Triggers background sync if online
  Future<Either<Failure, List<InventoryItemEntity>>> getAllInventoryItems();

  /// Get inventory item by ID
  /// 
  /// Parameters:
  /// - [id]: Inventory item's unique identifier
  /// 
  /// Returns [InventoryItemEntity] if found
  Future<Either<Failure, InventoryItemEntity>> getInventoryItemById(String id);

  /// Get inventory items by type
  /// 
  /// Parameters:
  /// - [type]: Item type (paddy or rice)
  /// 
  /// Returns list of inventory items of the specified type
  Future<Either<Failure, List<InventoryItemEntity>>> getInventoryByType(
    ItemType type,
  );

  /// Search inventory items
  /// 
  /// Parameters:
  /// - [query]: Search query string
  /// 
  /// Returns list of matching inventory items
  Future<Either<Failure, List<InventoryItemEntity>>> searchInventory(
    String query,
  );

  /// Add a new inventory item
  /// 
  /// Parameters:
  /// - [item]: Inventory item model to add
  /// 
  /// Returns the created [InventoryItemEntity]
  Future<Either<Failure, InventoryItemEntity>> addInventoryItem(
    InventoryItemModel item,
  );

  /// Update an existing inventory item
  /// 
  /// Parameters:
  /// - [item]: Inventory item model with updated data
  /// 
  /// Returns the updated [InventoryItemEntity]
  Future<Either<Failure, InventoryItemEntity>> updateInventoryItem(
    InventoryItemModel item,
  );

  /// Add stock to an inventory item (for Buy operations)
  /// 
  /// Parameters:
  /// - [itemId]: Inventory item's unique identifier
  /// - [quantity]: Quantity to add in kg
  /// - [bags]: Number of bags
  /// - [transactionId]: Associated transaction ID
  /// 
  /// Returns the updated [InventoryItemEntity]
  Future<Either<Failure, InventoryItemEntity>> addStock({
    required String itemId,
    required double quantity,
    required int bags,
    required String transactionId,
  });

  /// Deduct stock from an inventory item (for Sell operations)
  /// 
  /// Parameters:
  /// - [itemId]: Inventory item's unique identifier
  /// - [quantity]: Quantity to deduct in kg
  /// - [bags]: Number of bags
  /// - [transactionId]: Associated transaction ID
  /// 
  /// Returns the updated [InventoryItemEntity]
  /// Fails if insufficient stock
  Future<Either<Failure, InventoryItemEntity>> deductStock({
    required String itemId,
    required double quantity,
    required int bags,
    required String transactionId,
  });

  /// Delete an inventory item (soft delete)
  /// 
  /// Parameters:
  /// - [id]: Inventory item's unique identifier
  /// 
  /// Returns true if successful
  Future<Either<Failure, bool>> deleteInventoryItem(String id);

  /// Get total stock by item type
  /// 
  /// Returns a map with ItemType as key and total quantity as value
  Future<Either<Failure, Map<ItemType, double>>> getTotalStockByType();

  /// Get low stock items
  /// 
  /// Parameters:
  /// - [threshold]: Minimum quantity threshold (default 100kg)
  /// 
  /// Returns list of items below the threshold
  Future<Either<Failure, List<InventoryItemEntity>>> getLowStockItems(
    double threshold,
  );

  /// Get or create inventory item by type and variety
  /// 
  /// If item doesn't exist, creates a new one with zero quantity
  /// 
  /// Parameters:
  /// - [type]: Item type (paddy or rice)
  /// - [variety]: Variety name
  /// - [companyId]: Company ID
  /// 
  /// Returns existing or newly created [InventoryItemModel]
  Future<Either<Failure, InventoryItemModel>> getOrCreateInventoryItem({
    required ItemType type,
    required String variety,
    required String companyId,
  });

  /// Get stock movement history for an item
  /// 
  /// Parameters:
  /// - [itemId]: Inventory item's unique identifier
  /// 
  /// Returns list of stock movements
  Future<Either<Failure, List<Map<String, dynamic>>>> getStockMovementHistory(
    String itemId,
  );

  /// Record milling operation (convert paddy to rice)
  /// 
  /// Parameters:
  /// - [paddyItemId]: Paddy inventory item ID
  /// - [riceItemId]: Rice inventory item ID
  /// - [paddyQuantity]: Paddy quantity to mill (kg)
  /// - [paddyBags]: Paddy bags count
  /// - [riceQuantity]: Rice quantity produced (kg)
  /// - [riceBags]: Rice bags count
  /// - [wastageQuantity]: Wastage amount (kg)
  /// - [notes]: Optional notes
  /// 
  /// Returns milling result with efficiency calculations
  Future<Either<Failure, Map<String, dynamic>>> recordMilling({
    required String paddyItemId,
    required String riceItemId,
    required double paddyQuantity,
    required int paddyBags,
    required double riceQuantity,
    required int riceBags,
    required double wastageQuantity,
    String? notes,
  });

  /// Sync inventory with server
  /// 
  /// Uploads unsynced items and downloads updates from server
  Future<Either<Failure, void>> syncInventory();

  /// Get unsynced inventory items
  /// 
  /// Returns list of items that haven't been synced to server
  Future<Either<Failure, List<InventoryItemModel>>> getUnsyncedInventoryItems();

  /// Get inventory summary
  /// 
  /// Returns summary with total stock, value, and breakdown by type
  Future<Either<Failure, Map<String, dynamic>>> getInventorySummary();

  /// Get stock value by type
  /// 
  /// Returns total monetary value of stock by type
  Future<Either<Failure, Map<ItemType, double>>> getStockValueByType();

  /// Get varieties list
  /// 
  /// Parameters:
  /// - [type]: Optional filter by item type
  /// 
  /// Returns list of unique varieties
  Future<Either<Failure, List<String>>> getVarieties({ItemType? type});

  /// Check if variety exists
  /// 
  /// Parameters:
  /// - [variety]: Variety name
  /// - [type]: Item type
  /// 
  /// Returns true if variety exists
  Future<Either<Failure, bool>> isVarietyExists({
    required String variety,
    required ItemType type,
  });

  /// Adjust stock (for corrections/adjustments)
  /// 
  /// Parameters:
  /// - [itemId]: Inventory item's unique identifier
  /// - [newQuantity]: New quantity to set
  /// - [newBags]: New bags count
  /// - [reason]: Reason for adjustment
  /// 
  /// Returns the updated [InventoryItemEntity]
  Future<Either<Failure, InventoryItemEntity>> adjustStock({
    required String itemId,
    required double newQuantity,
    required int newBags,
    required String reason,
  });
}