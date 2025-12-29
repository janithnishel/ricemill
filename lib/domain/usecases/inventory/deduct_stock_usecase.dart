import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../core/errors/failures.dart';
import '../../entities/inventory_item_entity.dart';
import '../../repositories/inventory_repository.dart';
import '../usecase.dart';

// lib/domain/usecases/inventory/deduct_stock_usecase.dart

/// Deduct stock use case
/// Reduces stock quantity from an existing inventory item
class DeductStockUseCase implements UseCase<InventoryItemEntity, DeductStockParams> {
  final InventoryRepository repository;

  DeductStockUseCase({required this.repository});

  @override
  Future<Either<Failure, InventoryItemEntity>> call(DeductStockParams params) async {
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

    // Deduct stock using the repository method
    return await repository.deductStock(
      itemId: params.itemId,
      quantity: params.quantity,
      bags: params.bags,
      transactionId: params.transactionId,
    );
  }
}

/// Parameters for deducting stock
class DeductStockParams extends Equatable {
  final String itemId;
  final double quantity;
  final int bags;
  final String transactionId;

  const DeductStockParams({
    required this.itemId,
    required this.quantity,
    required this.bags,
    required this.transactionId,
  });

  @override
  List<Object?> get props => [itemId, quantity, bags, transactionId];
}
