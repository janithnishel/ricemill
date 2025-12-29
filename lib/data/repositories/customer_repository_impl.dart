// lib/data/repositories/customer_repository_impl.dart

import 'package:dartz/dartz.dart';
import '../../core/constants/enums.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../core/network/network_info.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/repositories/customer_repository.dart';
import '../datasources/local/customer_local_ds.dart';
import '../datasources/local/transaction_local_ds.dart';
import '../datasources/remote/customer_remote_ds.dart';
import '../models/customer_model.dart';
import '../models/sync_queue_model.dart';

class CustomerRepositoryImpl implements CustomerRepository {
  final CustomerRemoteDataSource remoteDataSource;
  final CustomerLocalDataSource localDataSource;
  final TransactionLocalDataSource transactionLocalDataSource;
  final NetworkInfo networkInfo;

  CustomerRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.transactionLocalDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<CustomerEntity>>> getAllCustomers() async {
    try {
      // Always return local data first for offline-first approach
      final localCustomers = await localDataSource.getAllCustomers();

      // If online, try to sync in background
      if (await networkInfo.isConnected) {
        _syncCustomersInBackground();
      }

      return Right(localCustomers.map((c) => c.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, CustomerEntity>> getCustomerById(String id) async {
    try {
      final customer = await localDataSource.getCustomerById(id);
      
      if (customer != null) {
        return Right(customer.toEntity());
      }

      // If not found locally and online, try remote
      if (await networkInfo.isConnected) {
        try {
          final remoteCustomer = await remoteDataSource.getCustomerById(id);
          await localDataSource.insertCustomer(remoteCustomer.copyWith(isSynced: true));
          return Right(remoteCustomer.toEntity());
        } on NotFoundException {
          return Left(NotFoundFailure(message: 'Customer not found'));
        }
      }

      return Left(NotFoundFailure(message: 'Customer not found'));
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, CustomerEntity?>> getCustomerByPhone(String phone) async {
    try {
      final customer = await localDataSource.getCustomerByPhone(phone);
      
      if (customer != null) {
        return Right(customer.toEntity());
      }

      // If not found locally and online, try remote
      if (await networkInfo.isConnected) {
        final remoteCustomer = await remoteDataSource.getCustomerByPhone(phone);
        if (remoteCustomer != null) {
          await localDataSource.insertCustomer(remoteCustomer.copyWith(isSynced: true));
          return Right(remoteCustomer.toEntity());
        }
      }

      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<CustomerEntity>>> searchCustomers(String query) async {
    try {
      final customers = await localDataSource.searchCustomers(query);
      return Right(customers.map((c) => c.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, CustomerEntity>> addCustomer(CustomerModel customer) async {
    try {
      // Check if phone exists
      final existingCustomer = await localDataSource.getCustomerByPhone(customer.phone);
      if (existingCustomer != null) {
        return Left(ValidationFailure(
          message: 'Customer with this phone already exists',
          fieldErrors: {'phone': ['Phone number already in use']},
        ));
      }

      // Insert locally first
      final insertedCustomer = await localDataSource.insertCustomer(customer);

      // If online, sync to server
      if (await networkInfo.isConnected) {
        try {
          final remoteCustomer = await remoteDataSource.createCustomer(insertedCustomer);
          final syncedCustomer = insertedCustomer.copyWith(
            serverId: remoteCustomer.serverId,
            isSynced: true,
            syncedAt: DateTime.now(),
          );
          await localDataSource.updateCustomer(syncedCustomer);
          return Right(syncedCustomer.toEntity());
        } catch (e) {
          // Failed to sync, but local save succeeded
          // Will be synced later
          return Right(insertedCustomer.toEntity());
        }
      }

      return Right(insertedCustomer.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(message: e.message, fieldErrors: e.errors));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, CustomerEntity>> updateCustomer(CustomerModel customer) async {
    try {
      // Check if phone exists for another customer
      if (await localDataSource.isPhoneExists(customer.phone, excludeId: customer.id)) {
        return Left(ValidationFailure(
          message: 'Phone number already in use by another customer',
          fieldErrors: {'phone': ['Phone number already in use']},
        ));
      }

      // Update locally first
      final updatedCustomer = await localDataSource.updateCustomer(customer);

      // If online, sync to server
      if (await networkInfo.isConnected && customer.serverId != null) {
        try {
          final remoteCustomer = await remoteDataSource.updateCustomer(updatedCustomer);
          final syncedCustomer = updatedCustomer.copyWith(
            isSynced: true,
            syncedAt: DateTime.now(),
          );
          await localDataSource.updateCustomer(syncedCustomer);
          return Right(syncedCustomer.toEntity());
        } catch (e) {
          // Failed to sync, but local update succeeded
          return Right(updatedCustomer.toEntity());
        }
      }

      return Right(updatedCustomer.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } on NotFoundException {
      return Left(NotFoundFailure(message: 'Customer not found'));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> deleteCustomer(String id) async {
    try {
      // Get customer first
      final customer = await localDataSource.getCustomerById(id);
      if (customer == null) {
        return Left(NotFoundFailure(message: 'Customer not found'));
      }

      // Soft delete locally
      await localDataSource.deleteCustomer(id);

      // If online and has server ID, delete on server
      if (await networkInfo.isConnected && customer.serverId != null) {
        try {
          await remoteDataSource.deleteCustomer(customer.serverId!);
        } catch (e) {
          // Failed to delete on server, will be synced later
        }
      }

      return const Right(true);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> isPhoneExists(String phone, {String? excludeId}) async {
    try {
      final exists = await localDataSource.isPhoneExists(phone, excludeId: excludeId);
      return Right(exists);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> getCustomersCount() async {
    try {
      final count = await localDataSource.getCustomersCount();
      return Right(count);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<CustomerModel>>> getUnsyncedCustomers() async {
    try {
      final customers = await localDataSource.getUnsyncedCustomers();
      return Right(customers);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> syncCustomers() async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure());
    }

    try {
      // Get unsynced customers
      final unsyncedCustomers = await localDataSource.getUnsyncedCustomers();

      if (unsyncedCustomers.isEmpty) {
        // Just fetch updates from server
        await _fetchServerUpdates();
        return const Right(null);
      }

      // Sync to server
      final syncedCustomers = await remoteDataSource.syncCustomers(unsyncedCustomers);

      // Update local records with server IDs
      for (final synced in syncedCustomers) {
        // Find local customer by matching local_id
        final localCustomer = unsyncedCustomers.firstWhere(
          (c) => c.id == synced.id || c.phone == synced.phone,
          orElse: () => synced,
        );

        await localDataSource.markCustomerAsSynced(
          localCustomer.id,
          synced.serverId ?? synced.id,
        );
      }

      // Fetch any updates from server
      await _fetchServerUpdates();

      return const Right(null);
    } on SyncException catch (e) {
      return Left(SyncFailure(message: e.message));
    } on NetworkException {
      return Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, CustomerEntity>> updateCustomerBalance({
    required String customerId,
    required double amount,
    required bool isCredit,
  }) async {
    try {
      final customer = await localDataSource.getCustomerById(customerId);
      if (customer == null) {
        return Left(NotFoundFailure(message: 'Customer not found'));
      }

      final newBalance = isCredit
          ? customer.balance + amount
          : customer.balance - amount;

      final updatedCustomer = customer.copyWith(
        balance: newBalance,
        updatedAt: DateTime.now(),
        isSynced: false,
      );

      await localDataSource.updateCustomer(updatedCustomer);
      return Right(updatedCustomer.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<CustomerEntity>>> getCustomersByType(
    CustomerType type,
  ) async {
    try {
      final customers = await localDataSource.getCustomersByType(type);
      return Right(customers.map((c) => c.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<CustomerEntity>>> getCustomersWithBalance({
    String? type,
  }) async {
    try {
      final customers = await localDataSource.getCustomersWithBalance(type: type);
      return Right(customers.map((c) => c.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getCustomerTransactionHistory({
    required String customerId,
    int limit = 50,
  }) async {
    try {
      final transactions = await transactionLocalDataSource.getTransactionsByCustomer(customerId);

      // Take only the most recent transactions up to the limit
      final recentTransactions = transactions.take(limit).toList();

      // Convert to summary format
      final history = recentTransactions.map((transaction) {
        return {
          'id': transaction.id,
          'transaction_number': transaction.transactionNumber,
          'type': transaction.type.name,
          'total_amount': transaction.totalAmount,
          'date': transaction.transactionDate.toIso8601String(),
          'status': transaction.status.name,
          'items_count': transaction.items.length,
        };
      }).toList();

      return Right(history);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<CustomerEntity>>> getTopCustomers({
    String? type,
    int limit = 10,
  }) async {
    try {
      // Get all transactions to calculate customer transaction volumes
      final allTransactions = await transactionLocalDataSource.getAllTransactions();

      // Filter by type if specified
      final filteredTransactions = type != null
          ? allTransactions.where((t) => t.type.name == type).toList()
          : allTransactions;

      // Calculate total transaction amount per customer
      final customerTotals = <String, double>{};
      for (final transaction in filteredTransactions) {
        if (transaction.customerId != null) {
          customerTotals[transaction.customerId!] =
              (customerTotals[transaction.customerId!] ?? 0) + transaction.totalAmount;
        }
      }

      // Sort customers by total transaction amount (descending)
      final sortedEntries = customerTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final sortedCustomerIds = sortedEntries
          .take(limit)
          .map((e) => e.key)
          .toList();

      // Get customer details
      final topCustomers = <CustomerModel>[];
      for (final customerId in sortedCustomerIds) {
        final customer = await localDataSource.getCustomerById(customerId);
        if (customer != null) {
          topCustomers.add(customer);
        }
      }

      return Right(topCustomers.map((c) => c.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  /// Sync customers in background
  void _syncCustomersInBackground() async {
    try {
      await syncCustomers();
    } catch (_) {
      // Ignore errors in background sync
    }
  }

  /// Fetch updates from server
  Future<void> _fetchServerUpdates() async {
    try {
      // Get last sync time from local storage
      // For now, fetch all and use upsert logic
      final remoteCustomers = await remoteDataSource.getAllCustomers();
      
      for (final remoteCustomer in remoteCustomers) {
        final localCustomer = await localDataSource.getCustomerByPhone(remoteCustomer.phone);
        
        if (localCustomer == null) {
          // New customer from server
          await localDataSource.insertCustomer(remoteCustomer.copyWith(isSynced: true));
        } else if (!localCustomer.isSynced) {
          // Local has unsynced changes, need conflict resolution
          // For now, server wins if server is newer
          if (remoteCustomer.updatedAt.isAfter(localCustomer.updatedAt)) {
            await localDataSource.updateCustomer(remoteCustomer.copyWith(
              id: localCustomer.id,
              isSynced: true,
            ));
          }
        } else {
          // Local is synced, update from server
          await localDataSource.updateCustomer(remoteCustomer.copyWith(
            id: localCustomer.id,
            isSynced: true,
          ));
        }
      }
    } catch (_) {
      // Ignore errors in fetching updates
    }
  }
}
