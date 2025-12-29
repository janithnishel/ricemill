import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../core/errors/failures.dart';
import '../../../core/constants/enums.dart';
import '../../../data/models/inventory_item_model.dart';
import '../../entities/inventory_item_entity.dart';
import '../../repositories/inventory_repository.dart';
import '../usecase.dart';

// lib/domain/usecases/inventory/add_stock_usecase.dart

/// Add stock use case
/// Adds stock to an existing inventory item
class AddStockUseCase implements UseCase<InventoryItemEntity, AddStockParams> {
  final InventoryRepository repository;

  AddStockUseCase({required this.repository});

  @override
  Future<Either<Failure, InventoryItemEntity>> call(AddStockParams params) async {
    // Validate inputs
    if (params.itemId.isEmpty) {
      return Left(ValidationFailure(message: 'Item ID is required'));
    }

    if (params.quantity <= 0) {
      return Left(ValidationFailure(message: 'Quantity must be greater than 0'));
    }

    if (params.bags < 0) {
      return Left(ValidationFailure(message: 'Bags cannot be negative'));
    }

    if (params.transactionId.isEmpty) {
      return Left(ValidationFailure(message: 'Transaction ID is required'));
    }

    // Add stock using the repository method
    return await repository.addStock(
      itemId: params.itemId,
      quantity: params.quantity,
      bags: params.bags,
      transactionId: params.transactionId,
    );
  }
}

/// Parameters for adding stock
class AddStockParams extends Equatable {
  final String itemId;
  final double quantity;
  final int bags;
  final String transactionId;

  const AddStockParams({
    required this.itemId,
    required this.quantity,
    required this.bags,
    required this.transactionId,
  });

  @override
  List<Object?> get props => [itemId, quantity, bags, transactionId];
}

/// Adjust stock use case
/// For manual stock adjustments (corrections, damage, etc.)
class AdjustStockUseCase implements UseCase<InventoryItemEntity, AdjustStockParams> {
  final InventoryRepository repository;

  AdjustStockUseCase({required this.repository});

  @override
  Future<Either<Failure, InventoryItemEntity>> call(AdjustStockParams params) async {
    if (params.itemId.isEmpty) {
      return Left(ValidationFailure(message: 'Item ID is required'));
    }

    if (params.reason.trim().isEmpty) {
      return Left(ValidationFailure(message: 'Adjustment reason is required'));
    }

    return await repository.adjustStock(
      itemId: params.itemId,
      newQuantity: params.newQuantity,
      newBags: params.newBags,
      reason: params.reason,
    );
  }
}

/// Parameters for adjusting stock
class AdjustStockParams extends Equatable {
  final String itemId;
  final double newQuantity;
  final int newBags;
  final String reason;

  const AdjustStockParams({
    required this.itemId,
    required this.newQuantity,
    required this.newBags,
    required this.reason,
  });

  @override
  List<Object?> get props => [itemId, newQuantity, newBags, reason];
}
