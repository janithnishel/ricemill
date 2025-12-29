import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/enums.dart';
import '../../../../data/models/customer_model.dart';
import '../../../../data/models/inventory_item_model.dart';
import '../../../../data/models/transaction_item_model.dart';
import '../../../../data/models/transaction_model.dart';
import '../../../../domain/repositories/customer_repository.dart';
import '../../../../domain/repositories/inventory_repository.dart';
import '../../../../domain/repositories/transaction_repository.dart';
import 'buy_state.dart';

class BuyCubit extends Cubit<BuyState> {
  final CustomerRepository _customerRepository;
  final InventoryRepository _inventoryRepository;
  final TransactionRepository _transactionRepository;
  final Uuid _uuid = const Uuid();

  BuyCubit({
    required CustomerRepository customerRepository,
    required InventoryRepository inventoryRepository,
    required TransactionRepository transactionRepository,
  })  : _customerRepository = customerRepository,
        _inventoryRepository = inventoryRepository,
        _transactionRepository = transactionRepository,
        super(const BuyState());

  // Initialize / Load customers
  Future<void> initialize() async {
    emit(state.copyWith(status: BuyStatus.loading));

    final result = await _customerRepository.getAllCustomers();

    result.fold(
      (failure) => emit(state.copyWith(
        status: BuyStatus.error,
        errorMessage: failure.message,
      )),
      (customers) => emit(state.copyWith(
        status: BuyStatus.success,
        customers: customers.map((e) => CustomerModel(
          id: e.id,
          name: e.name,
          phone: e.phone,
          address: e.address,
          type: e.type,
          balance: e.balance,
          isActive: e.isActive,
          companyId: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        )).toList(),
      )),
    );
  }

  // Search customers
  Future<void> searchCustomers(String query) async {
    if (query.isEmpty) {
      emit(state.copyWith(isSearchingCustomer: false));
      await initialize();
      return;
    }

    emit(state.copyWith(isSearchingCustomer: true));

    final result = await _customerRepository.searchCustomers(query);

    result.fold(
      (failure) => emit(state.copyWith(
        isSearchingCustomer: false,
        errorMessage: failure.message,
      )),
      (customers) => emit(state.copyWith(
        isSearchingCustomer: false,
        customers: customers.map((e) => CustomerModel(
          id: e.id,
          name: e.name,
          phone: e.phone,
          address: e.address,
          type: e.type,
          balance: e.balance,
          isActive: e.isActive,
          companyId: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        )).toList(),
      )),
    );
  }

  // Check if phone exists
  Future<CustomerModel?> checkPhoneExists(String phone) async {
    final result = await _customerRepository.getCustomerByPhone(phone);
    return result.fold(
      (failure) => null,
      (customer) => customer != null ? CustomerModel(
        id: customer.id,
        name: customer.name,
        phone: customer.phone,
        address: customer.address,
        type: customer.type,
        balance: customer.balance,
        isActive: customer.isActive,
        companyId: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ) : null,
    );
  }

  // Select customer
  void selectCustomer(CustomerModel customer) {
    emit(state.copyWith(
      selectedCustomer: customer,
      currentStep: BuyStep.selectItem,
      clearError: true,
    ));
  }

  // Clear selected customer
  void clearCustomer() {
    emit(state.copyWith(
      clearCustomer: true,
      currentStep: BuyStep.selectCustomer,
    ));
  }

  // Select item type
  void selectItemType(ItemType type, {String? variety}) {
    final inventoryItemId = variety != null
        ? state.inventoryItems
            .firstWhere(
              (item) => item.type == type && item.variety == variety,
              orElse: () => InventoryItemModel.create(
                type: type,
                variety: variety,
                companyId: '',
              ),
            )
            .id
        : null;

    emit(state.copyWith(
      selectedItemType: type,
      selectedVariety: variety,
      currentInventoryItemId: inventoryItemId,
      currentStep: BuyStep.enterWeight,
      currentWeight: 0.0,
      currentBags: 0,
      clearError: true,
    ));
  }

  // Clear item selection
  void clearItemType() {
    emit(state.copyWith(
      clearCurrentItem: true,
      currentStep: BuyStep.selectItem,
      currentWeight: 0.0,
      currentBags: 0,
    ));
  }

  // Update current weight
  void updateWeight(double weight) {
    emit(state.copyWith(currentWeight: weight));
  }

  // Update current bags
  void updateBags(int bags) {
    emit(state.copyWith(currentBags: bags));
  }

  // Add bag with weight
  void addBagWithWeight(double weight) {
    if (weight <= 0) return;

    final newItem = TempBuyItem(
      id: _uuid.v4(),
      itemType: state.selectedItemType!,
      variety: state.selectedVariety ?? '',
      inventoryItemId: state.currentInventoryItemId ?? '',
      bagWeights: [weight],
      totalWeight: weight,
    );

    final updatedItems = [...state.tempItems, newItem];
    _recalculateTotals(updatedItems);

    emit(state.copyWith(
      tempItems: updatedItems,
      currentWeight: 0.0,
      currentBags: state.currentBags + 1,
    ));
  }

  // Add current entry to temp list
  void addToTempList() {
    if (state.currentWeight <= 0 || state.selectedItemType == null) return;

    final bagCount = state.currentBags > 0 ? state.currentBags : 1;
    final averageWeight = state.currentWeight / bagCount;
    final bagWeights = List<double>.filled(bagCount, averageWeight);

    final newItem = TempBuyItem(
      id: _uuid.v4(),
      itemType: state.selectedItemType!,
      variety: state.selectedVariety ?? '',
      inventoryItemId: state.currentInventoryItemId ?? '',
      bagWeights: bagWeights,
      totalWeight: state.currentWeight,
    );

    final updatedItems = [...state.tempItems, newItem];
    _recalculateTotals(updatedItems);

    emit(state.copyWith(
      tempItems: updatedItems,
      currentWeight: 0.0,
      currentBags: 0,
      currentStep: BuyStep.selectItem,
      clearCurrentItem: true,
    ));
  }

  // Edit temp item
  void editTempItem(String id, double newWeight, int newBags) {
    final updatedItems = state.tempItems.map((item) {
      if (item.id == id) {
        final averageWeight = newBags > 0 ? newWeight / newBags : newWeight;
        final bagWeights = List<double>.filled(newBags > 0 ? newBags : 1, averageWeight);
        return item.copyWith(
          totalWeight: newWeight,
          bagWeights: bagWeights,
        );
      }
      return item;
    }).toList();

    _recalculateTotals(updatedItems);
    emit(state.copyWith(tempItems: updatedItems));
  }

  // Remove temp item
  void removeTempItem(String id) {
    final updatedItems = state.tempItems.where((item) => item.id != id).toList();
    _recalculateTotals(updatedItems);
    emit(state.copyWith(tempItems: updatedItems));
  }

  // Clear all temp items
  void clearTempItems() {
    emit(state.copyWith(
      tempItems: [],
      totalPaddyWeight: 0.0,
      totalRiceWeight: 0.0,
      totalBags: 0,
      totalAmount: 0.0,
      pricePerKg: 0.0,
    ));
  }

  // Set price per kg
  void setPricePerKg(double price) {
    final totalAmount = (state.totalPaddyWeight + state.totalRiceWeight) * price;
    emit(state.copyWith(
      pricePerKg: price,
      totalAmount: totalAmount,
    ));
  }

  // Go to review step
  void goToReview() {
    if (state.tempItems.isNotEmpty) {
      emit(state.copyWith(
        status: BuyStatus.reviewing,
        currentStep: BuyStep.review,
      ));
    }
  }

  // Recalculate totals
  void _recalculateTotals(List<TempBuyItem> items) {
    double paddyWeight = 0.0;
    double riceWeight = 0.0;
    int totalBags = 0;

    for (final item in items) {
      if (item.itemType == ItemType.paddy) {
        paddyWeight += item.weightKg;
      } else if (item.itemType == ItemType.rice) {
        riceWeight += item.weightKg;
      }
      totalBags += item.bagCount;
    }

    final totalAmount = (paddyWeight + riceWeight) * state.pricePerKg;

    emit(state.copyWith(
      totalPaddyWeight: paddyWeight,
      totalRiceWeight: riceWeight,
      totalBags: totalBags,
      totalAmount: totalAmount,
    ));
  }

  // Finalize and save transaction
  Future<void> finalizeTransaction() async {
    if (!state.canFinalize) return;

    emit(state.copyWith(isSaving: true));

    try {
      // Generate transaction ID
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final transactionId = '${AppConstants.buyTransactionPrefix}-$timestamp';

      // Convert temp items to transaction items
      final transactionItems = state.tempItems.map((item) {
        return item.toTransactionItem(transactionId);
      }).toList();

      // Create transaction
      final transaction = TransactionModel.createBuy(
        transactionNumber: transactionId,
        customerId: state.selectedCustomer?.id ?? '',
        customerName: state.selectedCustomer?.name,
        customerPhone: state.selectedCustomer?.phone,
        companyId: '', // TODO: Get from auth state or config
        createdBy: '', // TODO: Get from auth state
        items: transactionItems,
        discount: 0.0,
        notes: null,
      );

      // Save transaction
      final result = await _transactionRepository.createBuyTransaction(
        customerId: state.selectedCustomer?.id ?? '',
        companyId: '', // TODO: Get from auth state or config
        createdById: '', // TODO: Get from auth state
        items: transactionItems,
        discount: 0.0,
        paidAmount: 0.0,
        paymentMethod: null,
        notes: null,
      );

      await result.fold(
        (failure) async {
          emit(state.copyWith(
            isSaving: false,
            status: BuyStatus.error,
            errorMessage: failure.message,
          ));
        },
        (savedTransaction) async {
          // Update inventory (add stock)
          for (final item in transactionItems) {
            await _inventoryRepository.addStock(
              itemId: item.inventoryItemId,
              quantity: item.quantity,
              bags: item.bags,
              transactionId: transactionId,
            );
          }

          emit(state.copyWith(
            isSaving: false,
            status: BuyStatus.success,
            currentStep: BuyStep.complete,
            transactionId: transactionId,
          ));
        },
      );
    } catch (e) {
      emit(state.copyWith(
        isSaving: false,
        status: BuyStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  // Reset for new transaction
  void resetForNewTransaction() {
    emit(const BuyState());
    initialize();
  }

  // Go back to adding items from review
  void backToAddingItems() {
    emit(state.copyWith(status: BuyStatus.addingItems));
  }

  // Go back to previous step
  void goBack() {
    switch (state.currentStep) {
      case BuyStep.selectItem:
        emit(state.copyWith(currentStep: BuyStep.selectCustomer));
        break;
      case BuyStep.enterWeight:
        emit(state.copyWith(
          currentStep: BuyStep.selectItem,
          clearCurrentItem: true,
          currentWeight: 0.0,
          currentBags: 0,
        ));
        break;
      case BuyStep.review:
        emit(state.copyWith(currentStep: BuyStep.selectItem));
        break;
      case BuyStep.complete:
        resetForNewTransaction();
        break;
      default:
        break;
    }
  }

  // Clear error message
  void clearError() {
    emit(state.copyWith(clearError: true));
  }

  // Complete buy transaction
  Future<void> completeBuyTransaction() async {
    if (!state.canFinalize) return;

    emit(state.copyWith(status: BuyStatus.processing));

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final transactionNumber = '${AppConstants.buyTransactionPrefix}-$timestamp';

      final transactionItems = state.tempItems.map((item) {
        return TransactionItemModel.create(
          transactionId: transactionNumber,
          inventoryItemId: item.inventoryItemId,
          itemType: item.itemType,
          variety: item.variety,
          bags: item.bagsCount,
          quantity: item.totalWeight,
          pricePerKg: item.pricePerKg,
        );
      }).toList();

      final result = await _transactionRepository.createBuyTransaction(
        customerId: state.selectedCustomer?.id ?? '',
        companyId: '', // TODO: Get from auth state or config
        createdById: '', // TODO: Get from auth state
        items: transactionItems,
        discount: state.discount,
        paidAmount: state.paidAmount,
        paymentMethod: state.paymentMethod,
        notes: state.notes,
      );

      await result.fold(
        (failure) async {
          emit(state.copyWith(
            status: BuyStatus.error,
            errorMessage: failure.message,
          ));
        },
        (savedTransaction) async {
          // Update inventory
          for (final item in transactionItems) {
            await _inventoryRepository.addStock(
              itemId: item.inventoryItemId,
              quantity: item.quantity,
              bags: item.bags,
              transactionId: transactionNumber,
            );
          }

          emit(state.copyWith(
            status: BuyStatus.success,
            createdTransactionNumber: transactionNumber,
          ));
        },
      );
    } catch (e) {
      emit(state.copyWith(
        status: BuyStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }
}
