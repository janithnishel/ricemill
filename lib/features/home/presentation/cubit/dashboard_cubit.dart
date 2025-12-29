// lib/features/home/presentation/cubit/dashboard_cubit.dart

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/enums.dart';
import '../../../../domain/repositories/transaction_repository.dart';
import '../../../../domain/repositories/inventory_repository.dart';
import '../../../../domain/repositories/customer_repository.dart';
import '../../../../domain/repositories/report_repository.dart';
import '../../../../domain/repositories/auth_repository.dart';
import '../../../../data/models/transaction_model.dart';
import 'dashboard_state.dart';

/// Dashboard Cubit - Manages dashboard business logic
class DashboardCubit extends Cubit<DashboardState> {
  final TransactionRepository _transactionRepository;
  final InventoryRepository _inventoryRepository;
  final CustomerRepository _customerRepository;
  final ReportRepository _reportRepository;
  final AuthRepository _authRepository;

  DashboardCubit({
    required TransactionRepository transactionRepository,
    required InventoryRepository inventoryRepository,
    required CustomerRepository customerRepository,
    required ReportRepository reportRepository,
    required AuthRepository authRepository,
  })  : _transactionRepository = transactionRepository,
        _inventoryRepository = inventoryRepository,
        _customerRepository = customerRepository,
        _reportRepository = reportRepository,
        _authRepository = authRepository,
        super(DashboardState.initial());

  /// Load dashboard data
  Future<void> loadDashboard() async {
    emit(state.copyWith(status: DashboardStatus.loading, clearError: true));

    try {
      await Future.wait([
        _loadTodaySummary(),
        _loadMonthlySummary(),
        _loadStockSummary(),
        _loadCustomerSummary(),
        _loadRecentTransactions(),
        _loadSyncStatus(),
      ]);

      emit(state.copyWith(status: DashboardStatus.loaded));
    } catch (e) {
      emit(state.copyWith(
        status: DashboardStatus.error,
        errorMessage: 'Failed to load dashboard: ${e.toString()}',
      ));
    }
  }

  /// Refresh dashboard data
  Future<void> refreshDashboard() async {
    emit(state.copyWith(status: DashboardStatus.refreshing));

    try {
      await Future.wait([
        _loadTodaySummary(),
        _loadMonthlySummary(),
        _loadStockSummary(),
        _loadCustomerSummary(),
        _loadRecentTransactions(),
        _loadSyncStatus(),
      ]);

      emit(state.copyWith(status: DashboardStatus.loaded));
    } catch (e) {
      emit(state.copyWith(
        status: DashboardStatus.loaded, // Keep loaded state on refresh error
        errorMessage: 'Failed to refresh: ${e.toString()}',
      ));
    }
  }

  /// Load today's summary
  Future<void> _loadTodaySummary() async {
    final result = await _transactionRepository.getDailySummary(DateTime.now());

    result.fold(
      (failure) {
        // Use default values on failure
      },
      (summary) {
        emit(state.copyWith(
          todayPurchases: (summary['totalBuy'] as num?)?.toDouble() ?? 0,
          todaySales: (summary['totalSell'] as num?)?.toDouble() ?? 0,
          todayProfit: (summary['profit'] as num?)?.toDouble() ?? 0,
          todayBuyCount: summary['buyCount'] as int? ?? 0,
          todaySellCount: summary['sellCount'] as int? ?? 0,
        ));
      },
    );
  }

  /// Load monthly summary
  Future<void> _loadMonthlySummary() async {
    final now = DateTime.now();
    final result = await _transactionRepository.getMonthlySummary(
      now.year,
      now.month,
    );

    result.fold(
      (failure) {
        // Use default values on failure
      },
      (summary) {
        emit(state.copyWith(
          monthlyPurchases: (summary['totalBuy'] as num?)?.toDouble() ?? 0,
          monthlySales: (summary['totalSell'] as num?)?.toDouble() ?? 0,
          monthlyProfit: (summary['profit'] as num?)?.toDouble() ?? 0,
          monthlyBuyCount: summary['buyCount'] as int? ?? 0,
          monthlySellCount: summary['sellCount'] as int? ?? 0,
        ));
      },
    );
  }

  /// Load stock summary
  Future<void> _loadStockSummary() async {
    // Get stock by type
    final stockResult = await _inventoryRepository.getTotalStockByType();
    stockResult.fold(
      (failure) {},
      (stockByType) {
        final paddyStock = stockByType[ItemType.paddy] ?? 0;
        final riceStock = stockByType[ItemType.rice] ?? 0;

        emit(state.copyWith(
          totalPaddyStock: paddyStock,
          totalRiceStock: riceStock,
        ));
      },
    );

    // Get low stock items
    final lowStockResult = await _inventoryRepository.getLowStockItems(100);
    lowStockResult.fold(
      (failure) {},
      (items) {
        emit(state.copyWith(
          lowStockCount: items.length,
        ));
      },
    );

    // Get stock value
    final valueResult = await _inventoryRepository.getStockValueByType();
    valueResult.fold(
      (failure) {},
      (valueByType) {
        double totalValue = 0;
        valueByType.forEach((key, value) {
          totalValue += value;
        });

        emit(state.copyWith(totalStockValue: totalValue));
      },
    );
  }

  /// Load customer summary
  Future<void> _loadCustomerSummary() async {
    // Get customer count
    final countResult = await _customerRepository.getCustomersCount();
    countResult.fold(
      (failure) {},
      (count) {
        emit(state.copyWith(totalCustomers: count));
      },
    );

    // Get customers with balance for receivables/payables
    final receivablesResult = await _customerRepository.getCustomersWithBalance(
      type: 'receivable',
    );
    receivablesResult.fold(
      (failure) {},
      (customers) {
        double totalReceivables = 0;
        for (final customer in customers) {
          if (customer.balance > 0) {
            totalReceivables += customer.balance;
          }
        }
        emit(state.copyWith(totalReceivables: totalReceivables));
      },
    );

    final payablesResult = await _customerRepository.getCustomersWithBalance(
      type: 'payable',
    );
    payablesResult.fold(
      (failure) {},
      (customers) {
        double totalPayables = 0;
        for (final customer in customers) {
          if (customer.balance < 0) {
            totalPayables += customer.balance.abs();
          }
        }
        emit(state.copyWith(totalPayables: totalPayables));
      },
    );
  }

  /// Load recent transactions
  Future<void> _loadRecentTransactions() async {
    final result = await _transactionRepository.getRecentTransactions(limit: 10);

    result.fold(
      (failure) {},
      (transactions) {
        // Convert entities to models (if needed) or use directly
        final transactionModels = transactions
            .map((e) => TransactionModel(
                  id: e.id,
                  transactionNumber: e.transactionNumber,
                  type: e.type,
                  customerId: e.customerId,
                  customerName: e.customerName,
                  companyId: '',
                  createdBy: '',
                  items: [],
                  totalAmount: e.totalAmount,
                  paidAmount: e.paidAmount,
                  dueAmount: e.totalAmount - e.paidAmount,
                  status: e.status,
                  transactionDate: e.transactionDate,
                  createdAt: e.transactionDate,
                  updatedAt: e.transactionDate,
                ))
            .toList();

        emit(state.copyWith(recentTransactions: transactionModels));
      },
    );
  }

  /// Load sync status
  Future<void> _loadSyncStatus() async {
    // Get last sync time
    final lastSyncResult = await _authRepository.getLastSyncTime();
    lastSyncResult.fold(
      (failure) {},
      (lastSync) {
        emit(state.copyWith(lastSyncTime: lastSync));
      },
    );

    // Get pending sync count
    int pendingCount = 0;

    final unsyncedCustomers = await _customerRepository.getUnsyncedCustomers();
    unsyncedCustomers.fold((l) {}, (customers) {
      pendingCount += customers.length;
    });

    final unsyncedTransactions =
        await _transactionRepository.getUnsyncedTransactions();
    unsyncedTransactions.fold((l) {}, (transactions) {
      pendingCount += transactions.length;
    });

    emit(state.copyWith(
      pendingSyncCount: pendingCount,
      isSynced: pendingCount == 0,
    ));
  }

  /// Sync all pending data
  Future<void> syncData() async {
    emit(state.copyWith(status: DashboardStatus.refreshing));

    try {
      // Sync customers
      await _customerRepository.syncCustomers();

      // Sync transactions
      await _transactionRepository.syncTransactions();

      // Sync inventory
      await _inventoryRepository.syncInventory();

      // Save sync time
      await _authRepository.saveLastSyncTime(DateTime.now());

      // Reload dashboard
      await refreshDashboard();
    } catch (e) {
      emit(state.copyWith(
        status: DashboardStatus.loaded,
        errorMessage: 'Sync failed: ${e.toString()}',
      ));
    }
  }

  /// Change selected date
  void changeDate(DateTime date) {
    emit(state.copyWith(selectedDate: date));
    _loadTodaySummary();
  }

  /// Clear error
  void clearError() {
    emit(state.copyWith(clearError: true));
  }
}
