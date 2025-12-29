// lib/features/sell/sell_injection.dart

import 'package:get_it/get_it.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';

import '../../core/utils/pdf_generator.dart';
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
import 'presentation/cubit/sell_cubit.dart';

final sl = GetIt.instance;

Future<void> initSellDependencies() async {
  // Data sources
  if (!sl.isRegistered<CustomerLocalDataSource>()) {
    sl.registerLazySingleton<CustomerLocalDataSource>(
      () => CustomerLocalDataSourceImpl(dbHelper: sl()),
    );
  }

  if (!sl.isRegistered<CustomerRemoteDataSource>()) {
    sl.registerLazySingleton<CustomerRemoteDataSource>(
      () => CustomerRemoteDataSourceImpl(apiService: sl()),
    );
  }

  if (!sl.isRegistered<InventoryLocalDataSource>()) {
    sl.registerLazySingleton<InventoryLocalDataSource>(
      () => InventoryLocalDataSourceImpl(dbHelper: sl()),
    );
  }

  if (!sl.isRegistered<InventoryRemoteDataSource>()) {
    sl.registerLazySingleton<InventoryRemoteDataSource>(
      () => InventoryRemoteDataSourceImpl(apiService: sl()),
    );
  }

  if (!sl.isRegistered<TransactionLocalDataSource>()) {
    sl.registerLazySingleton<TransactionLocalDataSource>(
      () => TransactionLocalDataSourceImpl(dbHelper: sl()),
    );
  }

  if (!sl.isRegistered<TransactionRemoteDataSource>()) {
    sl.registerLazySingleton<TransactionRemoteDataSource>(
      () => TransactionRemoteDataSourceImpl(apiService: sl()),
    );
  }

  // Repositories
  if (!sl.isRegistered<CustomerRepository>()) {
    sl.registerLazySingleton<CustomerRepository>(
      () => CustomerRepositoryImpl(
        localDataSource: sl(),
        remoteDataSource: sl(),
        transactionLocalDataSource: sl(),
        networkInfo: sl(),
      ),
    );
  }

  if (!sl.isRegistered<InventoryRepository>()) {
    sl.registerLazySingleton<InventoryRepository>(
      () => InventoryRepositoryImpl(
        localDataSource: sl(),
        remoteDataSource: sl(),
        networkInfo: sl(),
      ),
    );
  }

  if (!sl.isRegistered<TransactionRepository>()) {
    sl.registerLazySingleton<TransactionRepository>(
      () => TransactionRepositoryImpl(
        remoteDataSource: sl(),
        localDataSource: sl(),
        inventoryLocalDataSource: sl(),
        customerLocalDataSource: sl(),
        networkInfo: sl(),
      ),
    );
  }

  // Cubit
  sl.registerFactory<SellCubit>(
    () => SellCubit(
      customerRepository: sl(),
      inventoryRepository: sl(),
      transactionRepository: sl(),
    ),
  );
}

// Provider setup for sell feature
List<BlocProvider> sellProviders() {
  return [
    BlocProvider<SellCubit>(
      create: (context) => sl<SellCubit>(),
    ),
  ];
}

// Wrapper widget with providers
class SellFeatureWrapper extends StatelessWidget {
  final Widget child;

  const SellFeatureWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: sellProviders(),
      child: child,
    );
  }
}

// Extension for easy navigation with providers
extension SellNavigationExtension on BuildContext {
  void navigateToSell() {
    Navigator.push(
      this,
      MaterialPageRoute(
        builder: (context) => SellFeatureWrapper(
          child: const SizedBox(), // Replace with actual screen
        ),
      ),
    );
  }
}
