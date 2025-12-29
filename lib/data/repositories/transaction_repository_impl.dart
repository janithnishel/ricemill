// lib/data/repositories/transaction_repository_impl.dart

import 'package:dartz/dartz.dart';
import '../../core/constants/enums.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../core/network/network_info.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/local/transaction_local_ds.dart';
import '../datasources/local/inventory_local_ds.dart';
import '../datasources/local/customer_local_ds.dart';
import '../datasources/remote/transaction_remote_ds.dart';
import '../models/transaction_model.dart';
import '../models/transaction_item_model.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final TransactionRemoteDataSource remoteDataSource;
  final TransactionLocalDataSource localDataSource;
  final InventoryLocalDataSource inventoryLocalDataSource;
  final CustomerLocalDataSource customerLocalDataSource;
  final NetworkInfo networkInfo;

  TransactionRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.inventoryLocalDataSource,
    required this.customerLocalDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<TransactionEntity>>> getAllTransactions() async {
    try {
      final transactions = await localDataSource.getAllTransactions();

      if (await networkInfo.isConnected) {
        _syncTransactionsInBackground();
      }

      return Right(transactions.map((t) => t.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, TransactionEntity>> getTransactionById(String id) async {
    try {
      final transaction = await localDataSource.getTransactionById(id);

      if (transaction != null) {
        return Right(transaction.toEntity());
      }

      if (await networkInfo.isConnected) {
        try {
          final remoteTransaction = await remoteDataSource.getTransactionById(id);
          await localDataSource.insertTransaction(remoteTransaction.copyWith(isSynced: true));
          return Right(remoteTransaction.toEntity());
        } on NotFoundException {
          return Left(NotFoundFailure(message: 'Transaction not found'));
        }
      }

      return Left(NotFoundFailure(message: 'Transaction not found'));
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<TransactionEntity>>> getTransactionsByType(
    TransactionType type,
  ) async {
    try {
      final transactions = await localDataSource.getTransactionsByType(type);
      return Right(transactions.map((t) => t.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<TransactionEntity>>> getTransactionsByCustomer(
    String customerId,
  ) async {
    try {
      final transactions = await localDataSource.getTransactionsByCustomer(customerId);
      return Right(transactions.map((t) => t.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<TransactionEntity>>> getTransactionsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    TransactionType? type,
  }) async {
    try {
      final transactions = await localDataSource.getTransactionsByDateRange(
        startDate: startDate,
        endDate: endDate,
        type: type,
      );
      return Right(transactions.map((t) => t.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<TransactionEntity>>> getTodayTransactions({
    TransactionType? type,
  }) async {
    try {
      final transactions = await localDataSource.getTodayTransactions(type: type);
      return Right(transactions.map((t) => t.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, TransactionEntity>> createBuyTransaction({
    required String customerId,
    required String companyId,
    required String createdById,
    required List<TransactionItemModel> items,
    double discount = 0,
    double paidAmount = 0,
    PaymentMethod? paymentMethod,
    String? notes,
    String? vehicleNumber,
  }) async {
    try {
      // Validate items
      if (items.isEmpty) {
        return Left(ValidationFailure(message: 'At least one item is required'));
      }

      // Get customer name
      final customer = await customerLocalDataSource.getCustomerById(customerId);
      if (customer == null) {
        return Left(NotFoundFailure(message: 'Customer not found'));
      }

      // Generate transaction number
      final transactionNumber = await localDataSource.generateTransactionNumber(
        TransactionType.buy,
      );

      // Create transaction model
      final transaction = TransactionModel.createBuy(
        transactionNumber: transactionNumber,
        customerId: customerId,
        customerName: customer.name,
        companyId: companyId,
        createdBy: createdById,
        items: items,
        discount: discount,
        notes: notes,
      );

      // Insert transaction
      final insertedTransaction = await localDataSource.insertTransaction(transaction);

      // Update inventory - Add stock for each item
      for (final item in items) {
        await inventoryLocalDataSource.addStock(
          itemId: item.inventoryItemId,
          quantity: item.quantity,
          bags: item.bags,
          transactionId: insertedTransaction.id,
        );
      }

      // Update customer balance if there's due amount
      if (insertedTransaction.dueAmount > 0) {
        final updatedCustomer = customer.copyWith(
          balance: customer.balance - insertedTransaction.dueAmount, // We owe them
          totalPurchases: customer.totalPurchases + insertedTransaction.totalAmount,
          updatedAt: DateTime.now(),
          isSynced: false,
        );
        await customerLocalDataSource.updateCustomer(updatedCustomer);
      }

      // Sync to server if online
      if (await networkInfo.isConnected) {
        try {
          final remoteTransaction = await remoteDataSource.createTransaction(
            insertedTransaction,
          );
          final syncedTransaction = insertedTransaction.copyWith(
            serverId: remoteTransaction.serverId,
            isSynced: true,
            syncedAt: DateTime.now(),
          );
          await localDataSource.updateTransaction(syncedTransaction);
          return Right(syncedTransaction.toEntity());
        } catch (_) {
          return Right(insertedTransaction.toEntity());
        }
      }

      return Right(insertedTransaction.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, TransactionEntity>> createSellTransaction({
    required String customerId,
    required String companyId,
    required String createdById,
    required List<TransactionItemModel> items,
    double discount = 0,
    double paidAmount = 0,
    PaymentMethod? paymentMethod,
    String? notes,
    String? vehicleNumber,
  }) async {
    try {
      // Validate items
      if (items.isEmpty) {
        return Left(ValidationFailure(message: 'At least one item is required'));
      }

      // Validate stock availability
      for (final item in items) {
        final inventoryItem = await inventoryLocalDataSource.getInventoryItemById(
          item.inventoryItemId,
        );
        if (inventoryItem == null) {
          return Left(NotFoundFailure(message: 'Inventory item not found: ${item.variety}'));
        }
        if (inventoryItem.currentQuantity < item.quantity) {
          return Left(ValidationFailure(
            message: 'Insufficient stock for ${item.variety}. Available: ${inventoryItem.currentQuantity} kg',
          ));
        }
      }

      // Get customer name
      final customer = await customerLocalDataSource.getCustomerById(customerId);
      if (customer == null) {
        return Left(NotFoundFailure(message: 'Customer not found'));
      }

      // Generate transaction number
      final transactionNumber = await localDataSource.generateTransactionNumber(
        TransactionType.sell,
      );

      // Create transaction model
      final transaction = TransactionModel.createSell(
        transactionNumber: transactionNumber,
        customerId: customerId,
        customerName: customer.name,
        companyId: companyId,
        createdBy: createdById,
        items: items,
        discount: discount,
        notes: notes,
      );

      // Insert transaction
      final insertedTransaction = await localDataSource.insertTransaction(transaction);

      // Update inventory - Deduct stock for each item
      for (final item in items) {
        await inventoryLocalDataSource.deductStock(
          itemId: item.inventoryItemId,
          quantity: item.quantity,
          bags: item.bags,
          transactionId: insertedTransaction.id,
        );
      }

      // Update customer balance if there's due amount
      if (insertedTransaction.dueAmount > 0) {
        final updatedCustomer = customer.copyWith(
          balance: customer.balance + insertedTransaction.dueAmount, // They owe us
          totalSales: customer.totalSales + insertedTransaction.totalAmount,
          updatedAt: DateTime.now(),
          isSynced: false,
        );
        await customerLocalDataSource.updateCustomer(updatedCustomer);
      }

      // Sync to server if online
      if (await networkInfo.isConnected) {
        try {
          final remoteTransaction = await remoteDataSource.createTransaction(
            insertedTransaction,
          );
          final syncedTransaction = insertedTransaction.copyWith(
            serverId: remoteTransaction.serverId,
            isSynced: true,
            syncedAt: DateTime.now(),
          );
          await localDataSource.updateTransaction(syncedTransaction);
          return Right(syncedTransaction.toEntity());
        } catch (_) {
          return Right(insertedTransaction.toEntity());
        }
      }

      return Right(insertedTransaction.toEntity());
    } on CacheException catch (e) {
      if (e.message.contains('Insufficient stock')) {
        return Left(ValidationFailure(message: e.message));
      }
      return Left(CacheFailure(message: e.message));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, TransactionEntity>> updateTransaction(
    TransactionModel transaction,
  ) async {
    try {
      final existingTransaction = await localDataSource.getTransactionById(transaction.id);
      if (existingTransaction == null) {
        return Left(NotFoundFailure(message: 'Transaction not found'));
      }

      if (existingTransaction.status != TransactionStatus.pending) {
        return Left(ValidationFailure(
          message: 'Cannot update completed or cancelled transaction',
        ));
      }

      final updatedTransaction = await localDataSource.updateTransaction(transaction);

      if (await networkInfo.isConnected && transaction.serverId != null) {
        try {
          await remoteDataSource.updateTransaction(updatedTransaction);
          final syncedTransaction = updatedTransaction.copyWith(
            isSynced: true,
            syncedAt: DateTime.now(),
          );
          await localDataSource.updateTransaction(syncedTransaction);
          return Right(syncedTransaction.toEntity());
        } catch (_) {
          return Right(updatedTransaction.toEntity());
        }
      }

      return Right(updatedTransaction.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> cancelTransaction(String id, String reason) async {
    try {
      final transaction = await localDataSource.getTransactionById(id);
      if (transaction == null) {
        return Left(NotFoundFailure(message: 'Transaction not found'));
      }

      if (transaction.status == TransactionStatus.cancelled) {
        return Left(ValidationFailure(message: 'Transaction already cancelled'));
      }

      // Reverse inventory changes
      for (final item in transaction.items) {
        if (transaction.type == TransactionType.buy) {
          // Deduct stock that was added
          await inventoryLocalDataSource.deductStock(
            itemId: item.inventoryItemId,
            quantity: item.quantity,
            bags: item.bags,
            transactionId: '${id}_CANCEL',
          );
        } else {
          // Add back stock that was deducted
          await inventoryLocalDataSource.addStock(
            itemId: item.inventoryItemId,
            quantity: item.quantity,
            bags: item.bags,
            transactionId: '${id}_CANCEL',
          );
        }
      }

      // Reverse customer balance changes
      final customer = await customerLocalDataSource.getCustomerById(transaction.customerId);
      if (customer != null && transaction.dueAmount != 0) {
        double newBalance;
        if (transaction.type == TransactionType.buy) {
          newBalance = customer.balance + transaction.dueAmount;
        } else {
          newBalance = customer.balance - transaction.dueAmount;
        }
        await customerLocalDataSource.updateCustomer(customer.copyWith(
          balance: newBalance,
          updatedAt: DateTime.now(),
          isSynced: false,
        ));
      }

      // Cancel transaction
      await localDataSource.cancelTransaction(id, reason);

      // Sync to server
      if (await networkInfo.isConnected && transaction.serverId != null) {
        try {
          await remoteDataSource.cancelTransaction(transaction.serverId!, reason);
        } catch (_) {}
      }

      return const Right(true);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> deleteTransaction(String id) async {
    try {
      final transaction = await localDataSource.getTransactionById(id);
      if (transaction == null) {
        return Left(NotFoundFailure(message: 'Transaction not found'));
      }

      await localDataSource.deleteTransaction(id);

      if (await networkInfo.isConnected && transaction.serverId != null) {
        try {
          await remoteDataSource.deleteTransaction(transaction.serverId!);
        } catch (_) {}
      }

      return const Right(true);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, TransactionEntity>> addPayment({
    required String transactionId,
    required double amount,
    required PaymentMethod method,
    String? notes,
  }) async {
    try {
      final transaction = await localDataSource.getTransactionById(transactionId);
      if (transaction == null) {
        return Left(NotFoundFailure(message: 'Transaction not found'));
      }

      if (amount > transaction.dueAmount) {
        return Left(ValidationFailure(
          message: 'Payment amount exceeds due amount',
        ));
      }

      final newPaidAmount = transaction.paidAmount + amount;
      final newDueAmount = transaction.totalAmount - newPaidAmount;

      PaymentStatus newPaymentStatus;
      if (newDueAmount <= 0) {
        newPaymentStatus = PaymentStatus.completed;
      } else if (newPaidAmount > 0) {
        newPaymentStatus = PaymentStatus.partial;
      } else {
        newPaymentStatus = PaymentStatus.pending;
      }

      final updatedTransaction = transaction.copyWith(
        paidAmount: newPaidAmount,
        dueAmount: newDueAmount,
        paymentStatus: newPaymentStatus,
        paymentMethod: method,
        updatedAt: DateTime.now(),
        isSynced: false,
      );

      await localDataSource.updateTransaction(updatedTransaction);

      // Update customer balance
      final customer = await customerLocalDataSource.getCustomerById(transaction.customerId);
      if (customer != null) {
        double balanceChange;
        if (transaction.type == TransactionType.buy) {
          balanceChange = amount; // We paid them, reduce what we owe
        } else {
          balanceChange = -amount; // They paid us, reduce what they owe
        }

        await customerLocalDataSource.updateCustomer(customer.copyWith(
          balance: customer.balance + balanceChange,
          updatedAt: DateTime.now(),
          isSynced: false,
        ));
      }

      // Sync to server
      if (await networkInfo.isConnected && transaction.serverId != null) {
        try {
          await remoteDataSource.addPayment(
            transactionId: transaction.serverId!,
            amount: amount,
            method: method,
            notes: notes,
          );
          final syncedTransaction = updatedTransaction.copyWith(
            isSynced: true,
            syncedAt: DateTime.now(),
          );
          await localDataSource.updateTransaction(syncedTransaction);
          return Right(syncedTransaction.toEntity());
        } catch (_) {
          return Right(updatedTransaction.toEntity());
        }
      }

      return Right(updatedTransaction.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getDailySummary(DateTime date) async {
    try {
      final summary = await localDataSource.getDailySummary(date);
      return Right(summary);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getMonthlySummary(int year, int month) async {
    try {
      final summary = await localDataSource.getMonthlySummary(year, month);
      return Right(summary);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, double>>> getTotalsByTypeForDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final totals = await localDataSource.getTotalsByTypeForDateRange(
        startDate: startDate,
        endDate: endDate,
      );
      return Right(totals);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<TransactionEntity>>> searchTransactions(String query) async {
    try {
      final transactions = await localDataSource.searchTransactions(query);
      return Right(transactions.map((t) => t.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> getTransactionsCount({TransactionType? type}) async {
    try {
      final count = await localDataSource.getTransactionsCount(type: type);
      return Right(count);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> generateTransactionNumber(TransactionType type) async {
    try {
      final number = await localDataSource.generateTransactionNumber(type);
      return Right(number);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> syncTransactions() async {
    if (!await networkInfo.isConnected) {
      return Left(NetworkFailure());
    }

    try {
      final unsyncedTransactions = await localDataSource.getUnsyncedTransactions();

      if (unsyncedTransactions.isNotEmpty) {
        final syncedTransactions = await remoteDataSource.syncTransactions(
          unsyncedTransactions,
        );

        for (final synced in syncedTransactions) {
          final localTxn = unsyncedTransactions.firstWhere(
            (t) => t.id == synced.id || t.transactionNumber == synced.transactionNumber,
            orElse: () => synced,
          );

          await localDataSource.markTransactionAsSynced(
            localTxn.id,
            synced.serverId ?? synced.id,
          );
        }
      }

      return const Right(null);
    } on SyncException catch (e) {
      return Left(SyncFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<TransactionModel>>> getUnsyncedTransactions() async {
    try {
      final transactions = await localDataSource.getUnsyncedTransactions();
      return Right(transactions);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<TransactionEntity>>> getPendingTransactions() async {
    try {
      final allTransactions = await localDataSource.getAllTransactions();
      final pendingTransactions = allTransactions
          .where((t) => t.status == TransactionStatus.pending)
          .toList();
      return Right(pendingTransactions.map((t) => t.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<TransactionEntity>>> getTransactionsWithDue() async {
    try {
      final allTransactions = await localDataSource.getAllTransactions();
      final transactionsWithDue = allTransactions
          .where((t) => t.dueAmount > 0)
          .toList();
      return Right(transactionsWithDue.map((t) => t.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, TransactionEntity>> completeTransaction(String id) async {
    try {
      final transaction = await localDataSource.getTransactionById(id);
      if (transaction == null) {
        return Left(NotFoundFailure(message: 'Transaction not found'));
      }

      if (transaction.status != TransactionStatus.pending) {
        return Left(ValidationFailure(
          message: 'Only pending transactions can be completed',
        ));
      }

      final completedTransaction = transaction.copyWith(
        status: TransactionStatus.completed,
        updatedAt: DateTime.now(),
        isSynced: false,
      );

      await localDataSource.updateTransaction(completedTransaction);

      // Sync to server if online
      if (await networkInfo.isConnected && transaction.serverId != null) {
        try {
          await remoteDataSource.completeTransaction(transaction.serverId!);
          final syncedTransaction = completedTransaction.copyWith(
            isSynced: true,
            syncedAt: DateTime.now(),
          );
          await localDataSource.updateTransaction(syncedTransaction);
          return Right(syncedTransaction.toEntity());
        } catch (_) {
          return Right(completedTransaction.toEntity());
        }
      }

      return Right(completedTransaction.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<TransactionEntity>>> getRecentTransactions({
    int limit = 10,
    TransactionType? type,
  }) async {
    try {
      final allTransactions = type != null
          ? await localDataSource.getTransactionsByType(type)
          : await localDataSource.getAllTransactions();

      final recentTransactions = allTransactions.take(limit).toList();
      return Right(recentTransactions.map((t) => t.toEntity()).toList());
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<TransactionItemModel>>> getTransactionItems(
    String transactionId,
  ) async {
    try {
      final items = await localDataSource.getTransactionItems(transactionId);
      return Right(items);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, TransactionEntity>> duplicateTransaction(
    String transactionId,
  ) async {
    try {
      final originalTransaction = await localDataSource.getTransactionById(transactionId);
      if (originalTransaction == null) {
        return Left(NotFoundFailure(message: 'Transaction not found'));
      }

      // Generate new transaction number
      final transactionNumber = await localDataSource.generateTransactionNumber(
        originalTransaction.type,
      );

      // Create duplicate transaction
      final duplicatedTransaction = originalTransaction.copyWith(
        id: '', // Will be set by database
        transactionNumber: transactionNumber,
        status: TransactionStatus.pending,
        paymentStatus: PaymentStatus.pending,
        paidAmount: 0,
        dueAmount: originalTransaction.totalAmount,
        serverId: null,
        isSynced: false,
        syncedAt: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final insertedTransaction = await localDataSource.insertTransaction(duplicatedTransaction);

      return Right(insertedTransaction.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  void _syncTransactionsInBackground() async {
    try {
      await syncTransactions();
    } catch (_) {}
  }
}
