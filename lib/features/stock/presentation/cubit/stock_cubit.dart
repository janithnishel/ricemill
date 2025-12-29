import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/enums.dart';
import '../../../../data/models/inventory_item_model.dart';
import '../../../../domain/repositories/inventory_repository.dart';
import '../../../../domain/repositories/auth_repository.dart';
import 'stock_state.dart';

class StockCubit extends Cubit<StockState> {
  final InventoryRepository _inventoryRepository;
  final AuthRepository _authRepository;

  StockCubit({
    required InventoryRepository inventoryRepository,
    required AuthRepository authRepository,
  })  : _inventoryRepository = inventoryRepository,
        _authRepository = authRepository,
        super(const StockState());

  /// Load all stock items from local database
  Future<void> loadStock() async {
    emit(state.copyWith(status: StockStatus.loading));

    try {
      // Get current user to obtain companyId
      final userResult = await _authRepository.getCurrentUser();
      String companyId = '';
      userResult.fold(
        (failure) => companyId = '', // Default if no user
        (user) => companyId = user.companyId,
      );

      final result = await _inventoryRepository.getAllInventoryItems();

      result.fold(
        (failure) => emit(state.copyWith(
          status: StockStatus.error,
          errorMessage: failure.message,
        )),
        (items) {
          // Convert entities to models
          final models = items.map((entity) =>
            InventoryItemModel.fromEntity(entity, companyId)
          ).toList();

          final totals = _calculateTotals(models);
          emit(state.copyWith(
            status: StockStatus.loaded,
            allItems: models,
            filteredItems: models,
            totalPaddyKg: totals['paddyKg'],
            totalRiceKg: totals['riceKg'],
            totalPaddyBags: totals['paddyBags'],
            totalRiceBags: totals['riceBags'],
          ));
        },
      );
    } catch (e) {
      emit(state.copyWith(
        status: StockStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Filter stock by type (All, Paddy, Rice)
  void filterByType(StockFilterType filterType) {
    List<InventoryItemModel> filtered;

    switch (filterType) {
      case StockFilterType.paddy:
        filtered = state.allItems
            .where((item) => item.itemType == ItemType.paddy)
            .toList();
        break;
      case StockFilterType.rice:
        filtered = state.allItems
            .where((item) => item.itemType == ItemType.rice)
            .toList();
        break;
      case StockFilterType.all:
        filtered = state.allItems;
        break;
    }

    // Apply search query if exists
    if (state.searchQuery.isNotEmpty) {
      filtered = filtered
          .where((item) =>
              item.name.toLowerCase().contains(state.searchQuery.toLowerCase()))
          .toList();
    }

    emit(state.copyWith(
      filterType: filterType,
      filteredItems: filtered,
    ));
  }

  /// Search stock items by name
  void searchStock(String query) {
    List<InventoryItemModel> filtered = state.allItems;

    // Apply type filter first
    switch (state.filterType) {
      case StockFilterType.paddy:
        filtered =
            filtered.where((item) => item.itemType == ItemType.paddy).toList();
        break;
      case StockFilterType.rice:
        filtered =
            filtered.where((item) => item.itemType == ItemType.rice).toList();
        break;
      case StockFilterType.all:
        break;
    }

    // Apply search query
    if (query.isNotEmpty) {
      filtered = filtered
          .where(
              (item) => item.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }

    emit(state.copyWith(
      searchQuery: query,
      filteredItems: filtered,
    ));
  }

  /// Refresh stock from server (sync)
  Future<void> refreshStock() async {
    emit(state.copyWith(isSynced: false));

    try {
      final result = await _inventoryRepository.syncInventory();

      result.fold(
        (failure) => emit(state.copyWith(
          isSynced: false,
          errorMessage: failure.message,
        )),
        (_) async {
          emit(state.copyWith(isSynced: true));
          await loadStock();
        },
      );
    } catch (e) {
      emit(state.copyWith(isSynced: false));
    }
  }

  /// Update stock item quantity (manual adjustment)
  Future<void> updateStockQuantity({
    required String itemId,
    required double newQuantityKg,
    required int newBags,
    String? reason,
  }) async {
    emit(state.copyWith(status: StockStatus.loading));

    try {
      final result = await _inventoryRepository.adjustStock(
        itemId: itemId,
        newQuantity: newQuantityKg,
        newBags: newBags,
        reason: reason ?? 'Manual adjustment',
      );

      result.fold(
        (failure) => emit(state.copyWith(
          status: StockStatus.error,
          errorMessage: failure.message,
        )),
        (_) => loadStock(),
      );
    } catch (e) {
      emit(state.copyWith(
        status: StockStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Add new stock item
  Future<void> addStockItem(InventoryItemModel item) async {
    emit(state.copyWith(status: StockStatus.loading));

    try {
      final result = await _inventoryRepository.addInventoryItem(item);

      result.fold(
        (failure) => emit(state.copyWith(
          status: StockStatus.error,
          errorMessage: failure.message,
        )),
        (_) => loadStock(),
      );
    } catch (e) {
      emit(state.copyWith(
        status: StockStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Delete stock item
  Future<void> deleteStockItem(String itemId) async {
    try {
      final result = await _inventoryRepository.deleteInventoryItem(itemId);

      result.fold(
        (failure) => emit(state.copyWith(errorMessage: failure.message)),
        (_) => loadStock(),
      );
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  /// Get stock summary for dashboard
  Map<String, dynamic> getStockSummary() {
    return {
      'totalPaddyKg': state.totalPaddyKg,
      'totalRiceKg': state.totalRiceKg,
      'totalPaddyBags': state.totalPaddyBags,
      'totalRiceBags': state.totalRiceBags,
      'itemCount': state.allItems.length,
      'paddyVarieties':
          state.allItems.where((i) => i.itemType == ItemType.paddy).length,
      'riceVarieties':
          state.allItems.where((i) => i.itemType == ItemType.rice).length,
    };
  }

  /// Calculate totals from items list
  Map<String, dynamic> _calculateTotals(List<InventoryItemModel> items) {
    double paddyKg = 0;
    double riceKg = 0;
    int paddyBags = 0;
    int riceBags = 0;

    for (var item in items) {
      if (item.itemType == ItemType.paddy) {
        paddyKg += item.totalWeightKg;
        paddyBags += item.totalBags;
      } else {
        riceKg += item.totalWeightKg;
        riceBags += item.totalBags;
      }
    }

    return {
      'paddyKg': paddyKg,
      'riceKg': riceKg,
      'paddyBags': paddyBags,
      'riceBags': riceBags,
    };
  }

  /// Get items for selling (only with available stock)
  List<InventoryItemModel> getAvailableItemsForSale() {
    return state.allItems.where((item) => item.totalWeightKg > 0).toList();
  }

  /// Get paddy items for milling
  List<InventoryItemModel> getPaddyForMilling() {
    return state.allItems
        .where(
            (item) => item.itemType == ItemType.paddy && item.totalWeightKg > 0)
        .toList();
  }

  /// Add stock manually (for receiving new stock)
  Future<void> addStock({
    required ItemType type,
    required String variety,
    required double quantity,
    required int bags,
    double? pricePerKg,
    String? notes,
  }) async {
    emit(state.copyWith(stockAddStatus: StockAddStatus.adding));

    try {
      // Get current user to obtain companyId
      final userResult = await _authRepository.getCurrentUser();
      String companyId = '';
      userResult.fold(
        (failure) => companyId = '', // Default if no user
        (user) => companyId = user.companyId,
      );

      // Get or create inventory item
      final result = await _inventoryRepository.getOrCreateInventoryItem(
        type: type,
        variety: variety,
        companyId: companyId,
      );

      await result.fold(
        (failure) async => emit(state.copyWith(
          stockAddStatus: StockAddStatus.failure,
          errorMessage: failure.message,
        )),
        (item) async {
          // Add stock to the item
          final addResult = await _inventoryRepository.addStock(
            itemId: item.id,
            quantity: quantity,
            bags: bags,
            transactionId: 'manual-${DateTime.now().millisecondsSinceEpoch}', // Manual transaction ID
          );

          addResult.fold(
            (failure) => emit(state.copyWith(
              stockAddStatus: StockAddStatus.failure,
              errorMessage: failure.message,
            )),
            (_) {
              emit(state.copyWith(
                stockAddStatus: StockAddStatus.success,
              ));
              // Reload stock to reflect the changes
              loadStock();
            },
          );
        },
      );
    } catch (e) {
      emit(state.copyWith(
        stockAddStatus: StockAddStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Reset stock add status
  void resetStockAddStatus() {
    emit(state.copyWith(stockAddStatus: StockAddStatus.initial, errorMessage: null));
  }

  /// Clear error message
  void clearError() {
    emit(state.copyWith(errorMessage: null));
  }
}
