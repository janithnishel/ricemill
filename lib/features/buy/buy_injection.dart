// lib/features/buy/buy_injection.dart

import 'package:get_it/get_it.dart';
import '../../core/network/api_service.dart';
import '../../core/network/network_info.dart';
import '../../core/database/db_helper.dart';
import '../../data/datasources/local/customer_local_ds.dart';
import '../../data/datasources/local/inventory_local_ds.dart';
import '../../data/datasources/local/transaction_local_ds.dart';
import '../../data/datasources/remote/customer_remote_ds.dart';
import '../../data/datasources/remote/inventory_remote_ds.dart';
import '../../data/datasources/remote/transaction_remote_ds.dart';
import '../../data/repositories/customer_repository_impl.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../data/repositories/transaction_repository_impl.dart';
import '../../domain/repositories/customer_repository.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import 'presentation/cubit/buy_cubit.dart';
import 'presentation/cubit/customer_cubit.dart';

/// Buy feature dependency injection
/// Registers all dependencies required for the Buy module
class BuyInjection {
  static final GetIt _sl = GetIt.instance;

  /// Initialize all Buy feature dependencies
  static Future<void> init() async {
    // ==================== DATA SOURCES ====================
    
    // Register local data sources if not already registered
    _registerLocalDataSources();
    
    // Register remote data sources if not already registered
    _registerRemoteDataSources();

    // ==================== REPOSITORIES ====================
    
    _registerRepositories();

    // ==================== CUBITS ====================
    
    _registerCubits();
  }

  /// Register local data sources
  static void _registerLocalDataSources() {
    // Customer Local Data Source
    if (!_sl.isRegistered<CustomerLocalDataSource>()) {
      _sl.registerLazySingleton<CustomerLocalDataSource>(
        () => CustomerLocalDataSourceImpl(
          dbHelper: _sl<DbHelper>(),
        ),
      );
    }

    // Inventory Local Data Source
    if (!_sl.isRegistered<InventoryLocalDataSource>()) {
      _sl.registerLazySingleton<InventoryLocalDataSource>(
        () => InventoryLocalDataSourceImpl(
          dbHelper: _sl<DbHelper>(),
        ),
      );
    }

    // Transaction Local Data Source
    if (!_sl.isRegistered<TransactionLocalDataSource>()) {
      _sl.registerLazySingleton<TransactionLocalDataSource>(
        () => TransactionLocalDataSourceImpl(
          dbHelper: _sl<DbHelper>(),
        ),
      );
    }
  }

  /// Register remote data sources
  static void _registerRemoteDataSources() {
    // Customer Remote Data Source
    if (!_sl.isRegistered<CustomerRemoteDataSource>()) {
      _sl.registerLazySingleton<CustomerRemoteDataSource>(
        () => CustomerRemoteDataSourceImpl(
          apiService: _sl<ApiService>(),
        ),
      );
    }

    // Inventory Remote Data Source
    if (!_sl.isRegistered<InventoryRemoteDataSource>()) {
      _sl.registerLazySingleton<InventoryRemoteDataSource>(
        () => InventoryRemoteDataSourceImpl(
          apiService: _sl<ApiService>(),
        ),
      );
    }

    // Transaction Remote Data Source
    if (!_sl.isRegistered<TransactionRemoteDataSource>()) {
      _sl.registerLazySingleton<TransactionRemoteDataSource>(
        () => TransactionRemoteDataSourceImpl(
          apiService: _sl<ApiService>(),
        ),
      );
    }
  }

  /// Register repositories
  static void _registerRepositories() {
    // Customer Repository
    if (!_sl.isRegistered<CustomerRepository>()) {
      _sl.registerLazySingleton<CustomerRepository>(
        () => CustomerRepositoryImpl(
          remoteDataSource: _sl<CustomerRemoteDataSource>(),
          localDataSource: _sl<CustomerLocalDataSource>(),
          transactionLocalDataSource: _sl<TransactionLocalDataSource>(),
          networkInfo: _sl<NetworkInfo>(),
        ),
      );
    }

    // Inventory Repository
    if (!_sl.isRegistered<InventoryRepository>()) {
      _sl.registerLazySingleton<InventoryRepository>(
        () => InventoryRepositoryImpl(
          remoteDataSource: _sl<InventoryRemoteDataSource>(),
          localDataSource: _sl<InventoryLocalDataSource>(),
          networkInfo: _sl<NetworkInfo>(),
        ),
      );
    }

    // Transaction Repository
    if (!_sl.isRegistered<TransactionRepository>()) {
      _sl.registerLazySingleton<TransactionRepository>(
        () => TransactionRepositoryImpl(
          remoteDataSource: _sl<TransactionRemoteDataSource>(),
          localDataSource: _sl<TransactionLocalDataSource>(),
          inventoryLocalDataSource: _sl<InventoryLocalDataSource>(),
          customerLocalDataSource: _sl<CustomerLocalDataSource>(),
          networkInfo: _sl<NetworkInfo>(),
        ),
      );
    }
  }

  /// Register cubits
  static void _registerCubits() {
    // Buy Cubit - Factory (new instance each time)
    _sl.registerFactory<BuyCubit>(
      () => BuyCubit(
        transactionRepository: _sl<TransactionRepository>(),
        inventoryRepository: _sl<InventoryRepository>(),
        customerRepository: _sl<CustomerRepository>(),
      ),
    );

    // Customer Cubit - Factory (new instance each time)
    _sl.registerFactory<CustomerCubit>(
      () => CustomerCubit(
        customerRepository: _sl<CustomerRepository>(),
        authRepository: _sl<AuthRepository>(),
      ),
    );
  }

  /// Get BuyCubit instance
  static BuyCubit get buyCubit => _sl<BuyCubit>();

  /// Get CustomerCubit instance
  static CustomerCubit get customerCubit => _sl<CustomerCubit>();

  /// Get CustomerRepository instance
  static CustomerRepository get customerRepository => _sl<CustomerRepository>();

  /// Get InventoryRepository instance
  static InventoryRepository get inventoryRepository => _sl<InventoryRepository>();

  /// Get TransactionRepository instance
  static TransactionRepository get transactionRepository => _sl<TransactionRepository>();

  /// Reset all Buy feature dependencies (for testing)
  static Future<void> reset() async {
    // Unregister cubits
    if (_sl.isRegistered<BuyCubit>()) {
      _sl.unregister<BuyCubit>();
    }
    if (_sl.isRegistered<CustomerCubit>()) {
      _sl.unregister<CustomerCubit>();
    }

    // Note: We don't unregister repositories and data sources
    // as they might be used by other features
  }

  /// Reset all dependencies including shared ones (for testing only)
  static Future<void> resetAll() async {
    // Cubits
    if (_sl.isRegistered<BuyCubit>()) {
      _sl.unregister<BuyCubit>();
    }
    if (_sl.isRegistered<CustomerCubit>()) {
      _sl.unregister<CustomerCubit>();
    }

    // Repositories
    if (_sl.isRegistered<TransactionRepository>()) {
      _sl.unregister<TransactionRepository>();
    }
    if (_sl.isRegistered<InventoryRepository>()) {
      _sl.unregister<InventoryRepository>();
    }
    if (_sl.isRegistered<CustomerRepository>()) {
      _sl.unregister<CustomerRepository>();
    }

    // Remote Data Sources
    if (_sl.isRegistered<TransactionRemoteDataSource>()) {
      _sl.unregister<TransactionRemoteDataSource>();
    }
    if (_sl.isRegistered<InventoryRemoteDataSource>()) {
      _sl.unregister<InventoryRemoteDataSource>();
    }
    if (_sl.isRegistered<CustomerRemoteDataSource>()) {
      _sl.unregister<CustomerRemoteDataSource>();
    }

    // Local Data Sources
    if (_sl.isRegistered<TransactionLocalDataSource>()) {
      _sl.unregister<TransactionLocalDataSource>();
    }
    if (_sl.isRegistered<InventoryLocalDataSource>()) {
      _sl.unregister<InventoryLocalDataSource>();
    }
    if (_sl.isRegistered<CustomerLocalDataSource>()) {
      _sl.unregister<CustomerLocalDataSource>();
    }
  }

  /// Check if all dependencies are registered
  static bool get isInitialized {
    return _sl.isRegistered<BuyCubit>() &&
        _sl.isRegistered<CustomerCubit>() &&
        _sl.isRegistered<TransactionRepository>() &&
        _sl.isRegistered<InventoryRepository>() &&
        _sl.isRegistered<CustomerRepository>();
  }
}
