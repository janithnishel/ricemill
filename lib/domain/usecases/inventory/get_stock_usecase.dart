import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../core/errors/failures.dart';
import '../../../core/constants/enums.dart';
import '../../entities/inventory_item_entity.dart';
import '../../repositories/inventory_repository.dart';
import '../usecase.dart';

// lib/domain/usecases/inventory/get_stock_usecase.dart

/// Get all stock use case
/// Returns all inventory items
class GetStockUseCase implements UseCase<List<InventoryItemEntity>, NoParams> {
  final InventoryRepository repository;

  GetStockUseCase({required this.repository});

  @override
  Future<Either<Failure, List<InventoryItemEntity>>> call(NoParams params) async {
    return await repository.getAllInventoryItems();
  }
}

/// Get stock by ID use case
class GetStockByIdUseCase implements UseCase<InventoryItemEntity, String> {
  final InventoryRepository repository;

  GetStockByIdUseCase({required this.repository});

  @override
  Future<Either<Failure, InventoryItemEntity>> call(String itemId) async {
    if (itemId.isEmpty) {
      return Left(ValidationFailure(message: 'Item ID is required'));
    }

    return await repository.getInventoryItemById(itemId);
  }
}

/// Get stock by type use case
class GetStockByTypeUseCase implements UseCase<List<InventoryItemEntity>, ItemType> {
  final InventoryRepository repository;

  GetStockByTypeUseCase({required this.repository});

  @override
  Future<Either<Failure, List<InventoryItemEntity>>> call(ItemType itemType) async {
    return await repository.getInventoryByType(itemType);
  }
}

/// Search stock use case
class SearchStockUseCase implements UseCase<List<InventoryItemEntity>, String> {
  final InventoryRepository repository;

  SearchStockUseCase({required this.repository});

  @override
  Future<Either<Failure, List<InventoryItemEntity>>> call(String query) async {
    if (query.trim().isEmpty) {
      return await repository.getAllInventoryItems();
    }

    return await repository.searchInventory(query.trim());
  }
}
