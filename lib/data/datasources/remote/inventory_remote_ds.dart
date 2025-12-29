// lib/data/datasources/remote/inventory_remote_ds.dart

import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../core/network/api_service.dart';
import '../../../core/network/api_response.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/enums.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/errors/failures.dart';
import '../../models/inventory_item_model.dart';

abstract class InventoryRemoteDataSource {
  /// Get all inventory items from server
  Future<List<InventoryItemModel>> getAllInventoryItems({
    int page = 1,
    int limit = 50,
  });

  /// Get inventory item by ID from server
  Future<InventoryItemModel> getInventoryItemById(String id);

  /// Get inventory by type (Paddy/Rice)
  Future<List<InventoryItemModel>> getInventoryByType(ItemType type);

  /// Search inventory items
  Future<List<InventoryItemModel>> searchInventory(String query);

  /// Create new inventory item on server
  Future<InventoryItemModel> createInventoryItem(InventoryItemModel item);

  /// Update inventory item on server
  Future<InventoryItemModel> updateInventoryItem(InventoryItemModel item);

  /// Add stock on server
  Future<InventoryItemModel> addStock({
    required String itemId,
    required double quantity,
    required int bags,
    required String transactionId,
    String? notes,
  });

  /// Deduct stock on server
  Future<InventoryItemModel> deductStock({
    required String itemId,
    required double quantity,
    required int bags,
    required String transactionId,
    String? notes,
  });

  /// Delete inventory item on server
  Future<bool> deleteInventoryItem(String id);

  /// Sync inventory items
  Future<List<InventoryItemModel>> syncInventory(List<InventoryItemModel> items);

  /// Get inventory updated after a specific date
  Future<List<InventoryItemModel>> getInventoryUpdatedAfter(DateTime dateTime);

  /// Get stock summary
  Future<Map<String, dynamic>> getStockSummary();

  /// Get low stock items
  Future<List<InventoryItemModel>> getLowStockItems(double threshold);

  /// Get stock movement history
  Future<List<Map<String, dynamic>>> getStockMovementHistory({
    required String itemId,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int limit = 50,
  });

  /// Record milling operation
  Future<Map<String, dynamic>> recordMilling({
    required String paddyItemId,
    required String riceItemId,
    required double paddyQuantity,
    required int paddyBags,
    required double riceQuantity,
    required int riceBags,
    required double wastageQuantity,
    String? notes,
  });

  /// Get milling history
  Future<List<Map<String, dynamic>>> getMillingHistory({
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int limit = 50,
  });
}

class InventoryRemoteDataSourceImpl implements InventoryRemoteDataSource {
  final ApiService apiService;

  InventoryRemoteDataSourceImpl({required this.apiService});

  /// Helper method to convert Failure to appropriate exception
  Exception _mapFailureToException(Failure failure) {
    if (failure is NetworkFailure) {
      return NetworkException(message: failure.message);
    } else if (failure is AuthFailure) {
      return AuthException(
        message: failure.message,
        statusCode: failure.code,
      );
    } else if (failure is ValidationFailure) {
      return ValidationException(
        message: failure.message,
        errors: failure.fieldErrors,
      );
    } else if (failure is ServerFailure) {
      return ServerException(
        message: failure.message,
        statusCode: failure.code,
      );
    } else {
      return ServerException(message: failure.message);
    }
  }

  @override
  Future<List<InventoryItemModel>> getAllInventoryItems({
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final either = await apiService.get(
        ApiEndpoints.inventory,
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
        },
      );

      return either.fold(
        (failure) => throw _mapFailureToException(failure),
        (response) {
          if (response.success && response.data != null) {
            final List<dynamic> inventoryJson = response.data['items'] ?? response.data;
            return inventoryJson
                .map((json) => InventoryItemModel.fromJson(json as Map<String, dynamic>))
                .toList();
          }

          throw ServerException(
            message: response.message ?? 'Failed to fetch inventory',
            statusCode: response.statusCode,
          );
        },
      );
    } on SocketException {
      throw NetworkException();
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(message: 'Failed to fetch inventory: ${e.toString()}');
    }
  }

  @override
  Future<InventoryItemModel> getInventoryItemById(String id) async {
    try {
      final either = await apiService.get(
        '${ApiEndpoints.inventory}/$id',
      );

      return either.fold(
        (failure) => throw _mapFailureToException(failure),
        (response) {
          if (response.success && response.data != null) {
            return InventoryItemModel.fromJson(response.data);
          }

          if (response.statusCode == 404) {
            throw NotFoundException(message: 'Inventory item not found');
          }

          throw ServerException(
            message: response.message ?? 'Failed to fetch inventory item',
            statusCode: response.statusCode,
          );
        },
      );
    } on SocketException {
      throw NetworkException();
    } on ServerException {
      rethrow;
    } on NotFoundException {
      rethrow;
    } catch (e) {
      throw ServerException(message: 'Failed to fetch inventory item: ${e.toString()}');
    }
  }

  @override
  Future<List<InventoryItemModel>> getInventoryByType(ItemType type) async {
    try {
      final either = await apiService.get(
        ApiEndpoints.stockByType(type.name),
        queryParameters: {'type': type.name},
      );

      return either.fold(
        (failure) => throw _mapFailureToException(failure),
        (response) {
          if (response.success && response.data != null) {
            final List<dynamic> inventoryJson = response.data['items'] ?? response.data;
            return inventoryJson
                .map((json) => InventoryItemModel.fromJson(json as Map<String, dynamic>))
                .toList();
          }

          throw ServerException(
            message: response.message ?? 'Failed to fetch inventory by type',
            statusCode: response.statusCode,
          );
        },
      );
    } on SocketException {
      throw NetworkException();
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(message: 'Failed to fetch inventory by type: ${e.toString()}');
    }
  }

  @override
  Future<List<InventoryItemModel>> searchInventory(String query) async {
    try {
      final either = await apiService.get(
        ApiEndpoints.searchInventory,
        queryParameters: {'q': query},
      );

      return either.fold(
        (failure) => throw _mapFailureToException(failure),
        (response) {
          if (response.success && response.data != null) {
            final List<dynamic> inventoryJson = response.data['items'] ?? response.data;
            return inventoryJson
                .map((json) => InventoryItemModel.fromJson(json as Map<String, dynamic>))
                .toList();
          }

          throw ServerException(
            message: response.message ?? 'Failed to search inventory',
            statusCode: response.statusCode,
          );
        },
      );
    } on SocketException {
      throw NetworkException();
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(message: 'Failed to search inventory: ${e.toString()}');
    }
  }

  @override
  Future<InventoryItemModel> createInventoryItem(InventoryItemModel item) async {
    try {
      final either = await apiService.post(
        ApiEndpoints.inventory,
        data: item.toJsonForApi(),
      );

      return either.fold(
        (failure) => throw _mapFailureToException(failure),
        (response) {
          if (response.success && response.data != null) {
            return InventoryItemModel.fromJson(response.data);
          }

          if (response.statusCode == 409) {
            throw ValidationException(
              message: 'Inventory item with this variety already exists',
              errors: {'variety': ['Already exists']},
            );
          }

          if (response.statusCode == 422) {
            throw ValidationException(
              message: response.message ?? 'Validation failed',
              errors: _parseValidationErrors(response.data),
            );
          }

          throw ServerException(
            message: response.message ?? 'Failed to create inventory item',
            statusCode: response.statusCode,
          );
        },
      );
    } on SocketException {
      throw NetworkException();
    } on ServerException {
      rethrow;
    } on ValidationException {
      rethrow;
    } catch (e) {
      throw ServerException(message: 'Failed to create inventory item: ${e.toString()}');
    }
  }

  @override
  Future<InventoryItemModel> updateInventoryItem(InventoryItemModel item) async {
    try {
      final serverId = item.serverId ?? item.id;

      final either = await apiService.put(
        '${ApiEndpoints.inventory}/$serverId',
        data: item.toJsonForApi(),
      );

      return either.fold(
        (failure) => throw _mapFailureToException(failure),
        (response) {
          if (response.success && response.data != null) {
            return InventoryItemModel.fromJson(response.data);
          }

          if (response.statusCode == 404) {
            throw NotFoundException(message: 'Inventory item not found');
          }

          throw ServerException(
            message: response.message ?? 'Failed to update inventory item',
            statusCode: response.statusCode,
          );
        },
      );
    } on SocketException {
      throw NetworkException();
    } on ServerException {
      rethrow;
    } on NotFoundException {
      rethrow;
    } catch (e) {
      throw ServerException(message: 'Failed to update inventory item: ${e.toString()}');
    }
  }

  @override
  Future<InventoryItemModel> addStock({
    required String itemId,
    required double quantity,
    required int bags,
    required String transactionId,
    String? notes,
  }) async {
    try {
      final either = await apiService.post(
        ApiEndpoints.inventoryAddStock,
        data: {
          'item_id': itemId,
          'quantity': quantity,
          'bags': bags,
          'transaction_id': transactionId,
          'notes': notes,
          'movement_type': MovementType.stockIn.name,
        },
      );

      return either.fold(
        (failure) => throw _mapFailureToException(failure),
        (response) {
          if (response.success && response.data != null) {
            return InventoryItemModel.fromJson(response.data);
          }

          if (response.statusCode == 404) {
            throw NotFoundException(message: 'Inventory item not found');
          }

          throw ServerException(
            message: response.message ?? 'Failed to add stock',
            statusCode: response.statusCode,
          );
        },
      );
    } on SocketException {
      throw NetworkException();
    } on ServerException {
      rethrow;
    } on NotFoundException {
      rethrow;
    } catch (e) {
      throw ServerException(message: 'Failed to add stock: ${e.toString()}');
    }
  }

  @override
  Future<InventoryItemModel> deductStock({
    required String itemId,
    required double quantity,
    required int bags,
    required String transactionId,
    String? notes,
  }) async {
    try {
      final either = await apiService.post(
        ApiEndpoints.inventoryDeductStock,
        data: {
          'item_id': itemId,
          'quantity': quantity,
          'bags': bags,
          'transaction_id': transactionId,
          'notes': notes,
          'movement_type': MovementType.stockOut.name,
        },
      );

      return either.fold(
        (failure) => throw _mapFailureToException(failure),
        (response) {
          if (response.success && response.data != null) {
            return InventoryItemModel.fromJson(response.data);
          }

          if (response.statusCode == 404) {
            throw NotFoundException(message: 'Inventory item not found');
          }

          if (response.statusCode == 400) {
            throw ValidationException(
              message: response.message ?? 'Insufficient stock',
              errors: {'quantity': ['Insufficient stock']},
            );
          }

          throw ServerException(
            message: response.message ?? 'Failed to deduct stock',
            statusCode: response.statusCode,
          );
        },
      );
    } on SocketException {
      throw NetworkException();
    } on ServerException {
      rethrow;
    } on NotFoundException {
      rethrow;
    } on ValidationException {
      rethrow;
    } catch (e) {
      throw ServerException(message: 'Failed to deduct stock: ${e.toString()}');
    }
  }

  @override
  Future<bool> deleteInventoryItem(String id) async {
    try {
      final either = await apiService.delete(
        '${ApiEndpoints.inventory}/$id',
      );

      return either.fold(
        (failure) => throw _mapFailureToException(failure),
        (response) {
          if (response.success) {
            return true;
          }

          if (response.statusCode == 404) {
            throw NotFoundException(message: 'Inventory item not found');
          }

          throw ServerException(
            message: response.message ?? 'Failed to delete inventory item',
            statusCode: response.statusCode,
          );
        },
      );
    } on SocketException {
      throw NetworkException();
    } on ServerException {
      rethrow;
    } on NotFoundException {
      rethrow;
    } catch (e) {
      throw ServerException(message: 'Failed to delete inventory item: ${e.toString()}');
    }
  }

  @override
  Future<List<InventoryItemModel>> syncInventory(List<InventoryItemModel> items) async {
    try {
      final either = await apiService.post(
        ApiEndpoints.inventorySync,
        data: {
          'items': items.map((i) => i.toJsonForSync()).toList(),
        },
      );

      return either.fold(
        (failure) => throw _mapFailureToException(failure),
        (response) {
          if (response.success && response.data != null) {
            final List<dynamic> syncedJson = response.data['synced'] ?? [];
            return syncedJson
                .map((json) => InventoryItemModel.fromJson(json as Map<String, dynamic>))
                .toList();
          }

          throw SyncException(
            message: response.message ?? 'Failed to sync inventory',
          );
        },
      );
    } on SocketException {
      throw NetworkException();
    } on SyncException {
      rethrow;
    } catch (e) {
      throw SyncException(message: 'Failed to sync inventory: ${e.toString()}');
    }
  }

  @override
  Future<List<InventoryItemModel>> getInventoryUpdatedAfter(DateTime dateTime) async {
    try {
      final either = await apiService.get(
        ApiEndpoints.inventoryUpdates,
        queryParameters: {
          'updated_after': dateTime.toIso8601String(),
        },
      );

      return either.fold(
        (failure) => throw _mapFailureToException(failure),
        (response) {
          if (response.success && response.data != null) {
            final List<dynamic> inventoryJson = response.data['items'] ?? response.data;
            return inventoryJson
                .map((json) => InventoryItemModel.fromJson(json as Map<String, dynamic>))
                .toList();
          }

          throw ServerException(
            message: response.message ?? 'Failed to fetch inventory updates',
            statusCode: response.statusCode,
          );
        },
      );
    } on SocketException {
      throw NetworkException();
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(message: 'Failed to fetch inventory updates: ${e.toString()}');
    }
  }

  @override
  Future<Map<String, dynamic>> getStockSummary() async {
    try {
      final either = await apiService.get(
        ApiEndpoints.inventorySummary,
      );

      return either.fold(
        (failure) => throw _mapFailureToException(failure),
        (response) {
          if (response.success && response.data != null) {
            return response.data as Map<String, dynamic>;
          }

          throw ServerException(
            message: response.message ?? 'Failed to fetch stock summary',
            statusCode: response.statusCode,
          );
        },
      );
    } on SocketException {
      throw NetworkException();
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(message: 'Failed to fetch stock summary: ${e.toString()}');
    }
  }

  @override
  Future<List<InventoryItemModel>> getLowStockItems(double threshold) async {
    try {
      final either = await apiService.get(
        ApiEndpoints.lowStock,
        queryParameters: {'threshold': threshold.toString()},
      );

      return either.fold(
        (failure) => throw _mapFailureToException(failure),
        (response) {
          if (response.success && response.data != null) {
            final List<dynamic> inventoryJson = response.data['items'] ?? response.data;
            return inventoryJson
                .map((json) => InventoryItemModel.fromJson(json as Map<String, dynamic>))
                .toList();
          }

          throw ServerException(
            message: response.message ?? 'Failed to fetch low stock items',
            statusCode: response.statusCode,
          );
        },
      );
    } on SocketException {
      throw NetworkException();
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(message: 'Failed to fetch low stock items: ${e.toString()}');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getStockMovementHistory({
    required String itemId,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (startDate != null) {
        queryParams['start_date'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['end_date'] = endDate.toIso8601String();
      }

      final either = await apiService.get(
        '${ApiEndpoints.inventory}/$itemId/movements',
        queryParameters: queryParams,
      );

      return either.fold(
        (failure) => throw _mapFailureToException(failure),
        (response) {
          if (response.success && response.data != null) {
            final List<dynamic> movementsJson = response.data['movements'] ?? response.data;
            return movementsJson.cast<Map<String, dynamic>>();
          }

          throw ServerException(
            message: response.message ?? 'Failed to fetch stock movement history',
            statusCode: response.statusCode,
          );
        },
      );
    } on SocketException {
      throw NetworkException();
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(message: 'Failed to fetch stock movement history: ${e.toString()}');
    }
  }

  @override
  Future<Map<String, dynamic>> recordMilling({
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
      final either = await apiService.post(
        ApiEndpoints.inventoryMilling,
        data: {
          'paddy_item_id': paddyItemId,
          'rice_item_id': riceItemId,
          'paddy_quantity': paddyQuantity,
          'paddy_bags': paddyBags,
          'rice_quantity': riceQuantity,
          'rice_bags': riceBags,
          'wastage_quantity': wastageQuantity,
          'notes': notes,
          'milled_at': DateTime.now().toIso8601String(),
        },
      );

      return either.fold(
        (failure) => throw _mapFailureToException(failure),
        (response) {
          if (response.success && response.data != null) {
            return response.data as Map<String, dynamic>;
          }

          if (response.statusCode == 400) {
            throw ValidationException(
              message: response.message ?? 'Insufficient paddy stock for milling',
              errors: {'paddy_quantity': ['Insufficient stock']},
            );
          }

          throw ServerException(
            message: response.message ?? 'Failed to record milling',
            statusCode: response.statusCode,
          );
        },
      );
    } on SocketException {
      throw NetworkException();
    } on ServerException {
      rethrow;
    } on ValidationException {
      rethrow;
    } catch (e) {
      throw ServerException(message: 'Failed to record milling: ${e.toString()}');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getMillingHistory({
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (startDate != null) {
        queryParams['start_date'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['end_date'] = endDate.toIso8601String();
      }

      final either = await apiService.get(
        ApiEndpoints.inventoryMillingHistory,
        queryParameters: queryParams,
      );

      return either.fold(
        (failure) => throw _mapFailureToException(failure),
        (response) {
          if (response.success && response.data != null) {
            final List<dynamic> millingJson = response.data['milling_records'] ?? response.data;
            return millingJson.cast<Map<String, dynamic>>();
          }

          throw ServerException(
            message: response.message ?? 'Failed to fetch milling history',
            statusCode: response.statusCode,
          );
        },
      );
    } on SocketException {
      throw NetworkException();
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(message: 'Failed to fetch milling history: ${e.toString()}');
    }
  }

  /// Parse validation errors from API response
  Map<String, List<String>>? _parseValidationErrors(dynamic data) {
    if (data is Map && data.containsKey('errors')) {
      final errors = data['errors'];
      if (errors is Map) {
        return errors.map((key, value) => MapEntry(
          key.toString(),
          value is List ? value.map((e) => e.toString()).toList() : [value.toString()],
        ));
      }
    }
    return null;
  }
}
