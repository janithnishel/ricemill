import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Core
import 'core/network/api_service.dart';
import 'core/network/network_info.dart';
import 'core/database/db_helper.dart';
import 'core/sync/sync_engine.dart';

// Data Sources - Local
import 'data/datasources/local/auth_local_ds.dart';
import 'data/datasources/local/customer_local_ds.dart';
import 'data/datasources/local/inventory_local_ds.dart';
import 'data/datasources/local/transaction_local_ds.dart';

// Data Sources - Remote
import 'data/datasources/remote/auth_remote_ds.dart';
import 'data/datasources/remote/customer_remote_ds.dart';
import 'data/datasources/remote/inventory_remote_ds.dart';
import 'data/datasources/remote/transaction_remote_ds.dart';

// Repositories
import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/customer_repository.dart';
import 'domain/repositories/inventory_repository.dart';
import 'domain/repositories/transaction_repository.dart';
import 'domain/repositories/report_repository.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/customer_repository_impl.dart';
import 'data/repositories/inventory_repository_impl.dart';
import 'data/repositories/transaction_repository_impl.dart';
import 'data/repositories/report_repository_impl.dart';

// Use Cases - Auth
import 'domain/usecases/auth/login_usecase.dart';
import 'domain/usecases/auth/logout_usecase.dart';
import 'domain/usecases/auth/check_auth_usecase.dart';

// Use Cases - Customer
import 'domain/usecases/customer/add_customer_usecase.dart';
import 'domain/usecases/customer/search_customer_usecase.dart';
import 'domain/usecases/customer/get_customers_usecase.dart';

// Use Cases - Inventory
import 'domain/usecases/inventory/add_stock_usecase.dart';
import 'domain/usecases/inventory/deduct_stock_usecase.dart';
import 'domain/usecases/inventory/get_stock_usecase.dart';

// Use Cases - Transaction
import 'domain/usecases/transaction/create_buy_transaction_usecase.dart';
import 'domain/usecases/transaction/create_sell_transaction_usecase.dart';
import 'domain/usecases/transaction/get_transactions_usecase.dart';

// Feature Injections
import 'features/auth/auth_injection.dart';
import 'features/home/home_injection.dart';
import 'features/buy/buy_injection.dart';
import 'features/sell/sell_injection.dart';
import 'features/stock/stock_injection.dart';
import 'features/customers/customers_injection.dart';
import 'features/reports/reports_injection.dart';
import 'features/profile/profile_injection.dart';
import 'features/super_admin/admin_injection.dart';

// Routes
import 'routes/app_router.dart';
import 'routes/route_guards.dart';

/// Global service locator instance
final GetIt sl = GetIt.instance;

/// Initialize all dependencies
Future<void> initDependencies() async {
  // ==================== External Dependencies ====================
  await _initExternalDependencies();

  // ==================== Core ====================
  await _initCore();

  // ==================== Data Sources ====================
  _initDataSources();

  // ==================== Repositories ====================
  _initRepositories();

  // ==================== Use Cases ====================
  _initUseCases();

  // ==================== Features ====================
  _initFeatures();

  // ==================== Routes ====================
  _initRoutes();
}

/// Initialize external dependencies (SharedPreferences, Database, etc.)
Future<void> _initExternalDependencies() async {
  // SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(sharedPreferences);

  // Connectivity
  sl.registerLazySingleton<Connectivity>(() => Connectivity());

  // Flutter Secure Storage
  sl.registerLazySingleton<FlutterSecureStorage>(() => const FlutterSecureStorage());

  // Database
  final database = await DbHelper().database;
  sl.registerSingleton<Database>(database);
}

/// Initialize core services
Future<void> _initCore() async {
  // Network Info
  sl.registerLazySingleton<NetworkInfo>(
    () => NetworkInfoImpl(sl<Connectivity>()),
  );

  // API Service
  sl.registerLazySingleton<ApiService>(
    () => ApiService(
      networkInfo: sl<NetworkInfo>(),
      secureStorage: sl<FlutterSecureStorage>(),
    ),
  );

  // Database Helper
  sl.registerLazySingleton<DbHelper>(
    () => DbHelper(),
  );

  // Sync Engine
  sl.registerLazySingleton<SyncEngine>(
    () => SyncEngine(
      dbHelper: sl<DbHelper>(),
      apiService: sl<ApiService>(),
      networkInfo: sl<NetworkInfo>(),
      prefs: sl<SharedPreferences>(),
    ),
  );
}

/// Initialize data sources
void _initDataSources() {
  // ========== Local Data Sources ==========
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(
      sharedPreferences: sl<SharedPreferences>(),
    ),
  );

  sl.registerLazySingleton<CustomerLocalDataSource>(
    () => CustomerLocalDataSourceImpl(dbHelper: sl<DbHelper>()),
  );

  sl.registerLazySingleton<InventoryLocalDataSource>(
    () => InventoryLocalDataSourceImpl(dbHelper: sl<DbHelper>()),
  );

  sl.registerLazySingleton<TransactionLocalDataSource>(
    () => TransactionLocalDataSourceImpl(dbHelper: sl<DbHelper>()),
  );

  // ========== Remote Data Sources ==========
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(apiService: sl<ApiService>()),
  );

  sl.registerLazySingleton<CustomerRemoteDataSource>(
    () => CustomerRemoteDataSourceImpl(apiService: sl<ApiService>()),
  );

  sl.registerLazySingleton<InventoryRemoteDataSource>(
    () => InventoryRemoteDataSourceImpl(apiService: sl<ApiService>()),
  );

  sl.registerLazySingleton<TransactionRemoteDataSource>(
    () => TransactionRemoteDataSourceImpl(apiService: sl<ApiService>()),
  );
}

/// Initialize repositories
void _initRepositories() {
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      localDataSource: sl<AuthLocalDataSource>(),
      remoteDataSource: sl<AuthRemoteDataSource>(),
      networkInfo: sl<NetworkInfo>(),
    ),
  );

  sl.registerLazySingleton<CustomerRepository>(
    () => CustomerRepositoryImpl(
      localDataSource: sl<CustomerLocalDataSource>(),
      remoteDataSource: sl<CustomerRemoteDataSource>(),
      transactionLocalDataSource: sl<TransactionLocalDataSource>(),
      networkInfo: sl<NetworkInfo>(),
    ),
  );

  sl.registerLazySingleton<InventoryRepository>(
    () => InventoryRepositoryImpl(
      localDataSource: sl<InventoryLocalDataSource>(),
      remoteDataSource: sl<InventoryRemoteDataSource>(),
      networkInfo: sl<NetworkInfo>(),
    ),
  );

  sl.registerLazySingleton<TransactionRepository>(
    () => TransactionRepositoryImpl(
      localDataSource: sl<TransactionLocalDataSource>(),
      remoteDataSource: sl<TransactionRemoteDataSource>(),
      inventoryLocalDataSource: sl<InventoryLocalDataSource>(),
      customerLocalDataSource: sl<CustomerLocalDataSource>(),
      networkInfo: sl<NetworkInfo>(),
    ),
  );

  sl.registerLazySingleton<ReportRepository>(
    () => ReportRepositoryImpl(
      remoteDataSource: sl<TransactionRemoteDataSource>(),
      transactionLocalDataSource: sl<TransactionLocalDataSource>(),
      inventoryLocalDataSource: sl<InventoryLocalDataSource>(),
      customerLocalDataSource: sl<CustomerLocalDataSource>(),
      networkInfo: sl<NetworkInfo>(),
    ),
  );
}

/// Initialize use cases
void _initUseCases() {
  // ========== Auth Use Cases ==========
  sl.registerLazySingleton(() => LoginUseCase(repository: sl<AuthRepository>()));
  sl.registerLazySingleton(() => LogoutUseCase(repository: sl<AuthRepository>()));
  sl.registerLazySingleton(() => CheckAuthUseCase(repository: sl<AuthRepository>()));

  // ========== Customer Use Cases ==========
  sl.registerLazySingleton(() => AddCustomerUseCase(repository: sl<CustomerRepository>()));
  sl.registerLazySingleton(() => SearchCustomerUseCase(repository: sl<CustomerRepository>()));
  sl.registerLazySingleton(() => GetCustomersUseCase(repository: sl<CustomerRepository>()));

  // ========== Inventory Use Cases ==========
  sl.registerLazySingleton(() => AddStockUseCase(repository: sl<InventoryRepository>()));
  sl.registerLazySingleton(() => DeductStockUseCase(repository: sl<InventoryRepository>()));
  sl.registerLazySingleton(() => GetStockUseCase(repository: sl<InventoryRepository>()));

  // ========== Transaction Use Cases ==========
  sl.registerLazySingleton(() => CreateBuyTransactionUseCase(
    transactionRepository: sl<TransactionRepository>(),
    inventoryRepository: sl<InventoryRepository>(),
  ));
  sl.registerLazySingleton(() => CreateSellTransactionUseCase(
    transactionRepository: sl<TransactionRepository>(),
    inventoryRepository: sl<InventoryRepository>(),
  ));
  sl.registerLazySingleton(() => GetAllTransactionsUseCase(repository: sl<TransactionRepository>()));
}

/// Initialize feature-specific dependencies
Future<void> _initFeatures() async {
  await AuthInjection.init();
  await HomeInjection.init();
  await BuyInjection.init();
  initSellDependencies();
  initStockInjection(sl);
  await CustomersInjection.init();
  await ReportsInjection.init();
  await ProfileInjection.init();
  initAdminInjection(sl);
}

/// Initialize routes
void _initRoutes() {
  // Auth Guard
  sl.registerLazySingleton<AuthGuard>(
    () => AuthGuard(authLocalDataSource: sl<AuthLocalDataSource>()),
  );

  // App Router
  sl.registerLazySingleton<AppRouter>(
    () => AppRouter(authGuard: sl<AuthGuard>()),
  );
}

/// Reset all dependencies (useful for testing or logout)
Future<void> resetDependencies() async {
  await sl.reset();
  await initDependencies();
}

/// Dispose specific feature dependencies
Future<void> disposeFeature(String feature) async {
  switch (feature) {
    case 'auth':
      await AuthInjection.reset();
      break;
    case 'buy':
      await BuyInjection.reset();
      break;
    case 'sell':
      // Sell injection doesn't have dispose function, assuming no cleanup needed
      break;
    case 'stock':
      disposeStockInjection(sl);
      break;
    case 'customers':
      await CustomersInjection.reset();
      break;
    case 'reports':
      // Reports injection doesn't have reset method
      break;
    case 'profile':
      await ProfileInjection.reset();
      break;
    case 'admin':
      disposeAdminInjection(sl);
      break;
  }
}
