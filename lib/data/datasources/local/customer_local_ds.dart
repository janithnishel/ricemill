// lib/data/datasources/local/customer_local_ds.dart

import 'package:sqflite/sqflite.dart';
import '../../../core/database/db_helper.dart';
import '../../../core/database/tables/customer_table.dart';
import '../../../core/constants/db_constants.dart';
import '../../../core/constants/enums.dart';
import '../../../core/errors/exceptions.dart';
import '../../models/customer_model.dart';

abstract class CustomerLocalDataSource {
  /// Get all customers from local database
  Future<List<CustomerModel>> getAllCustomers();

  /// Get customer by ID
  Future<CustomerModel?> getCustomerById(String id);

  /// Get customer by phone number
  Future<CustomerModel?> getCustomerByPhone(String phone);

  /// Search customers by name or phone
  Future<List<CustomerModel>> searchCustomers(String query);

  /// Insert new customer
  Future<CustomerModel> insertCustomer(CustomerModel customer);

  /// Update existing customer
  Future<CustomerModel> updateCustomer(CustomerModel customer);

  /// Delete customer by ID
  Future<bool> deleteCustomer(String id);

  /// Get all unsynced customers
  Future<List<CustomerModel>> getUnsyncedCustomers();

  /// Mark customer as synced
  Future<void> markCustomerAsSynced(String id, String serverId);

  /// Get customers count
  Future<int> getCustomersCount();

  /// Check if phone exists
  Future<bool> isPhoneExists(String phone, {String? excludeId});

  /// Get customers by type
  Future<List<CustomerModel>> getCustomersByType(CustomerType type);

  /// Get customers with outstanding balance
  Future<List<CustomerModel>> getCustomersWithBalance({String? type});

  /// Batch insert customers (for sync)
  Future<void> batchInsertCustomers(List<CustomerModel> customers);

  /// Clear all customers (for reset)
  Future<void> clearAllCustomers();
}

class CustomerLocalDataSourceImpl implements CustomerLocalDataSource {
  final DbHelper dbHelper;

  CustomerLocalDataSourceImpl({required this.dbHelper});

  @override
  Future<List<CustomerModel>> getAllCustomers() async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        CustomerTable.tableName,
        where: '${CustomerTable.colIsDeleted} = ?',
        whereArgs: [0],
        orderBy: '${CustomerTable.colName} ASC',
      );

      return List.generate(maps.length, (i) {
        return CustomerModel.fromJson(maps[i]);
      });
    } catch (e) {
      throw CacheException(message: 'Failed to get customers: ${e.toString()}');
    }
  }

  @override
  Future<CustomerModel?> getCustomerById(String id) async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        CustomerTable.tableName,
        where: '${CustomerTable.colId} = ? AND ${CustomerTable.colIsDeleted} = ?',
        whereArgs: [id, 0],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return CustomerModel.fromJson(maps.first);
      }
      return null;
    } catch (e) {
      throw CacheException(message: 'Failed to get customer by ID: ${e.toString()}');
    }
  }

  @override
  Future<CustomerModel?> getCustomerByPhone(String phone) async {
    try {
      final db = await dbHelper.database;
      
      // Clean phone number - remove spaces and special characters
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
      
      final List<Map<String, dynamic>> maps = await db.query(
        CustomerTable.tableName,
        where: '${CustomerTable.colPhone} = ? AND ${CustomerTable.colIsDeleted} = ?',
        whereArgs: [cleanPhone, 0],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return CustomerModel.fromJson(maps.first);
      }
      return null;
    } catch (e) {
      throw CacheException(message: 'Failed to get customer by phone: ${e.toString()}');
    }
  }

  @override
  Future<List<CustomerModel>> searchCustomers(String query) async {
    try {
      final db = await dbHelper.database;
      final searchQuery = '%$query%';
      
      final List<Map<String, dynamic>> maps = await db.query(
        CustomerTable.tableName,
        where: '''
          (${CustomerTable.colName} LIKE ? OR 
           ${CustomerTable.colPhone} LIKE ? OR 
           ${CustomerTable.colAddress} LIKE ?) AND 
          ${CustomerTable.colIsDeleted} = ?
        ''',
        whereArgs: [searchQuery, searchQuery, searchQuery, 0],
        orderBy: '${CustomerTable.colName} ASC',
        limit: 50,
      );

      return List.generate(maps.length, (i) {
        return CustomerModel.fromJson(maps[i]);
      });
    } catch (e) {
      throw CacheException(message: 'Failed to search customers: ${e.toString()}');
    }
  }

  @override
  Future<CustomerModel> insertCustomer(CustomerModel customer) async {
    try {
      final db = await dbHelper.database;
      
      // Check if phone already exists
      final existing = await getCustomerByPhone(customer.phone);
      if (existing != null) {
        throw CacheException(message: 'Customer with this phone already exists');
      }

      final customerWithTimestamp = customer.copyWith(
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isSynced: false,
      );

      await db.insert(
        CustomerTable.tableName,
        customerWithTimestamp.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return customerWithTimestamp;
    } catch (e) {
      if (e is CacheException) rethrow;
      throw CacheException(message: 'Failed to insert customer: ${e.toString()}');
    }
  }

  @override
  Future<CustomerModel> updateCustomer(CustomerModel customer) async {
    try {
      final db = await dbHelper.database;
      
      // Check if phone exists for another customer
      if (await isPhoneExists(customer.phone, excludeId: customer.id)) {
        throw CacheException(message: 'Phone number already in use by another customer');
      }

      final updatedCustomer = customer.copyWith(
        updatedAt: DateTime.now(),
        isSynced: false,
      );

      final count = await db.update(
        CustomerTable.tableName,
        updatedCustomer.toJson(),
        where: '${CustomerTable.colId} = ?',
        whereArgs: [customer.id],
      );

      if (count == 0) {
        throw CacheException(message: 'Customer not found');
      }

      return updatedCustomer;
    } catch (e) {
      if (e is CacheException) rethrow;
      throw CacheException(message: 'Failed to update customer: ${e.toString()}');
    }
  }

  @override
  Future<bool> deleteCustomer(String id) async {
    try {
      final db = await dbHelper.database;
      
      // Soft delete - just mark as deleted
      final count = await db.update(
        CustomerTable.tableName,
        {
          CustomerTable.colIsDeleted: 1,
          CustomerTable.colUpdatedAt: DateTime.now().toIso8601String(),
          CustomerTable.colIsSynced: 0,
        },
        where: '${CustomerTable.colId} = ?',
        whereArgs: [id],
      );

      return count > 0;
    } catch (e) {
      throw CacheException(message: 'Failed to delete customer: ${e.toString()}');
    }
  }

  @override
  Future<List<CustomerModel>> getUnsyncedCustomers() async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        CustomerTable.tableName,
        where: '${CustomerTable.colIsSynced} = ?',
        whereArgs: [0],
      );

      return List.generate(maps.length, (i) {
        return CustomerModel.fromJson(maps[i]);
      });
    } catch (e) {
      throw CacheException(message: 'Failed to get unsynced customers: ${e.toString()}');
    }
  }

  @override
  Future<void> markCustomerAsSynced(String id, String serverId) async {
    try {
      final db = await dbHelper.database;
      
      await db.update(
        CustomerTable.tableName,
        {
          CustomerTable.colServerId: serverId,
          CustomerTable.colIsSynced: 1,
          CustomerTable.colSyncedAt: DateTime.now().toIso8601String(),
        },
        where: '${CustomerTable.colId} = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw CacheException(message: 'Failed to mark customer as synced: ${e.toString()}');
    }
  }

  @override
  Future<int> getCustomersCount() async {
    try {
      final db = await dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${CustomerTable.tableName} WHERE ${CustomerTable.colIsDeleted} = 0',
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      throw CacheException(message: 'Failed to get customers count: ${e.toString()}');
    }
  }

  @override
  Future<bool> isPhoneExists(String phone, {String? excludeId}) async {
    try {
      final db = await dbHelper.database;
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
      
      String where = '${CustomerTable.colPhone} = ? AND ${CustomerTable.colIsDeleted} = ?';
      List<dynamic> whereArgs = [cleanPhone, 0];
      
      if (excludeId != null) {
        where += ' AND ${CustomerTable.colId} != ?';
        whereArgs.add(excludeId);
      }

      final List<Map<String, dynamic>> maps = await db.query(
        CustomerTable.tableName,
        where: where,
        whereArgs: whereArgs,
        limit: 1,
      );

      return maps.isNotEmpty;
    } catch (e) {
      throw CacheException(message: 'Failed to check phone exists: ${e.toString()}');
    }
  }

  @override
  Future<List<CustomerModel>> getCustomersByType(CustomerType type) async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        CustomerTable.tableName,
        where: '(customer_type = ? OR customer_type = ?) AND ${CustomerTable.colIsDeleted} = ? AND is_active = ?',
        whereArgs: [type.value, 'both', 0, 1],
        orderBy: '${CustomerTable.colName} ASC',
      );

      return List.generate(maps.length, (i) {
        return CustomerModel.fromJson(maps[i]);
      });
    } catch (e) {
      throw CacheException(message: 'Failed to get customers by type: ${e.toString()}');
    }
  }

  @override
  Future<List<CustomerModel>> getCustomersWithBalance({String? type}) async {
    try {
      final db = await dbHelper.database;

      String where = '${CustomerTable.colIsDeleted} = ? AND is_active = ?';
      List<dynamic> whereArgs = [0, 1];

      if (type == 'receivable') {
        // Customers who owe us (positive balance)
        where += ' AND balance > ?';
        whereArgs.add(0);
      } else if (type == 'payable') {
        // We owe customers (negative balance)
        where += ' AND balance < ?';
        whereArgs.add(0);
      } else {
        // Any balance != 0
        where += ' AND balance != ?';
        whereArgs.add(0);
      }

      final List<Map<String, dynamic>> maps = await db.query(
        CustomerTable.tableName,
        where: where,
        whereArgs: whereArgs,
        orderBy: 'ABS(balance) DESC, ${CustomerTable.colName} ASC',
      );

      return List.generate(maps.length, (i) {
        return CustomerModel.fromJson(maps[i]);
      });
    } catch (e) {
      throw CacheException(message: 'Failed to get customers with balance: ${e.toString()}');
    }
  }

  @override
  Future<void> batchInsertCustomers(List<CustomerModel> customers) async {
    try {
      final db = await dbHelper.database;

      await db.transaction((txn) async {
        final batch = txn.batch();

        for (final customer in customers) {
          batch.insert(
            CustomerTable.tableName,
            customer.copyWith(isSynced: true).toJson(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        await batch.commit(noResult: true);
      });
    } catch (e) {
      throw CacheException(message: 'Failed to batch insert customers: ${e.toString()}');
    }
  }

  @override
  Future<void> clearAllCustomers() async {
    try {
      final db = await dbHelper.database;
      await db.delete(CustomerTable.tableName);
    } catch (e) {
      throw CacheException(message: 'Failed to clear customers: ${e.toString()}');
    }
  }
}
