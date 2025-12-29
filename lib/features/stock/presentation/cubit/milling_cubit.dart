import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/enums.dart';
import '../../../../data/models/inventory_item_model.dart';
import '../../../../domain/repositories/inventory_repository.dart';
import 'milling_state.dart';

class MillingCubit extends Cubit<MillingState> {
  final InventoryRepository _inventoryRepository;
  final _uuid = const Uuid();

  MillingCubit({required InventoryRepository inventoryRepository})
      : _inventoryRepository = inventoryRepository,
        super(const MillingState());

  /// Load available paddy for milling
  Future<void> loadAvailablePaddy() async {
    emit(state.copyWith(status: MillingStatus.loading));

    try {
      final result = await _inventoryRepository.getInventoryByType(ItemType.paddy);

      result.fold(
        (failure) => emit(state.copyWith(
          status: MillingStatus.error,
          errorMessage: failure.message,
        )),
        (paddyItems) {
          final available =
              paddyItems.where((item) => item.currentQuantity > 0)
                  .map((entity) => InventoryItemModel.fromEntity(entity, ''))
                  .toList();
          emit(state.copyWith(
            status: MillingStatus.initial,
            availablePaddy: available,
            batchNumber: _generateBatchNumber(),
            millingDate: DateTime.now(),
          ));
        },
      );
    } catch (e) {
      emit(state.copyWith(
        status: MillingStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Select paddy for milling
  void selectPaddy(InventoryItemModel paddy) {
    emit(state.copyWith(
      selectedPaddy: paddy,
      inputPaddyKg: 0.0,
      inputPaddyBags: 0,
    ));
  }

  /// Clear selected paddy
  void clearSelectedPaddy() {
    emit(state.copyWith(
      clearSelectedPaddy: true,
      inputPaddyKg: 0.0,
      inputPaddyBags: 0,
    ));
  }

  /// Update input paddy weight
  void updateInputWeight(double weightKg) {
    if (state.selectedPaddy == null) return;

    // Validate against available stock
    final maxWeight = state.selectedPaddy!.currentQuantity;
    final validWeight = weightKg > maxWeight ? maxWeight : weightKg;

    // Calculate estimated bags (assuming average 50kg per bag)
    final estimatedBags = (validWeight / 50).floor();

    emit(state.copyWith(
      inputPaddyKg: validWeight,
      inputPaddyBags: estimatedBags,
    ));
  }

  /// Update input paddy bags
  void updateInputBags(int bags) {
    if (state.selectedPaddy == null) return;

    // Calculate weight from bags (assuming average 50kg per bag)
    final estimatedWeight = bags * 50.0;
    final maxWeight = state.selectedPaddy!.currentQuantity;
    final validWeight =
        estimatedWeight > maxWeight ? maxWeight : estimatedWeight;

    emit(state.copyWith(
      inputPaddyBags: bags,
      inputPaddyKg: validWeight,
    ));
  }

  /// Update milling percentage
  void updateMillingPercentage(double percentage) {
    if (percentage < 50 || percentage > 75) return;

    emit(state.copyWith(millingPercentage: percentage));
  }

  /// Update actual output values
  void updateActualOutput({
    double? riceKg,
    double? brokenRiceKg,
    double? huskKg,
    double? wastageKg,
  }) {
    emit(state.copyWith(
      outputRiceKg: riceKg ?? state.outputRiceKg,
      brokenRiceKg: brokenRiceKg ?? state.brokenRiceKg,
      huskKg: huskKg ?? state.huskKg,
      wastageKg: wastageKg ?? state.wastageKg,
    ));
  }

  /// Process milling - deduct paddy and add rice
  Future<bool> processMilling() async {
    if (!state.canProcess) {
      emit(state.copyWith(
        status: MillingStatus.error,
        errorMessage: 'Invalid milling parameters',
      ));
      return false;
    }

    emit(state.copyWith(status: MillingStatus.processing));

    try {
      // 1. Deduct paddy from inventory
      final deductResult = await _inventoryRepository.deductStock(
        itemId: state.selectedPaddy!.id,
        quantity: state.inputPaddyKg,
        bags: state.inputPaddyBags,
        transactionId: _uuid.v4(),
      );

      final deductSuccess = deductResult.fold(
        (failure) {
          emit(state.copyWith(
            status: MillingStatus.error,
            errorMessage: 'Failed to deduct paddy stock: ${failure.message}',
          ));
          return false;
        },
        (_) => true,
      );

      if (!deductSuccess) return false;

      // 2. Add rice to inventory
      final riceOutput = state.outputRiceKg > 0
          ? state.outputRiceKg
          : state.expectedRiceKg;

      final riceItem = InventoryItemModel(
        id: _uuid.v4(),
        type: ItemType.rice,
        variety: '${state.selectedPaddy!.variety} Rice',
        companyId: '', // TODO: Get from auth state
        currentQuantity: riceOutput,
        currentBags: (riceOutput / 50).floor(),
        averagePricePerKg: 0, // To be set when selling
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isSynced: false,
      );

      final addResult = await _inventoryRepository.addInventoryItem(riceItem);

      final addSuccess = addResult.fold(
        (failure) {
          emit(state.copyWith(
            status: MillingStatus.error,
            errorMessage: 'Failed to add rice stock: ${failure.message}',
          ));
          return false;
        },
        (_) => true,
      );

      if (!addSuccess) return false;

      // 3. Record milling transaction
      await _recordMillingTransaction();

      emit(state.copyWith(status: MillingStatus.success));
      return true;
    } catch (e) {
      emit(state.copyWith(
        status: MillingStatus.error,
        errorMessage: e.toString(),
      ));
      return false;
    }
  }

  /// Record milling transaction for reports
  Future<void> _recordMillingTransaction() async {
    // This would save milling details to a milling_transactions table
    // for reporting and tracking purposes
  }

  /// Generate batch number for milling
  String _generateBatchNumber() {
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return 'ML-$dateStr-$timeStr';
  }

  /// Calculate milling efficiency
  double calculateEfficiency() {
    if (state.inputPaddyKg <= 0 || state.outputRiceKg <= 0) {
      return state.millingPercentage;
    }
    return (state.outputRiceKg / state.inputPaddyKg) * 100;
  }

  /// Reset milling form
  void resetMilling() {
    emit(MillingState(
      availablePaddy: state.availablePaddy,
      batchNumber: _generateBatchNumber(),
      millingDate: DateTime.now(),
    ));
  }

  /// Clear error
  void clearError() {
    emit(state.copyWith(errorMessage: null));
  }
}
