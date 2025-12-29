// lib/data/repositories/report_repository_impl.dart

import 'package:dartz/dartz.dart';
import '../../core/constants/enums.dart' hide ReportType;
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../core/network/network_info.dart';
import '../../core/utils/pdf_generator.dart';
import '../../domain/repositories/report_repository.dart';
import '../datasources/local/transaction_local_ds.dart';
import '../datasources/local/inventory_local_ds.dart';
import '../datasources/local/customer_local_ds.dart';
import '../datasources/remote/transaction_remote_ds.dart';
import '../models/report_model.dart';
import '../models/customer_model.dart';

class ReportRepositoryImpl implements ReportRepository {
  final TransactionRemoteDataSource remoteDataSource;
  final TransactionLocalDataSource transactionLocalDataSource;
  final InventoryLocalDataSource inventoryLocalDataSource;
  final CustomerLocalDataSource customerLocalDataSource;
  final NetworkInfo networkInfo;

  ReportRepositoryImpl({
    required this.remoteDataSource,
    required this.transactionLocalDataSource,
    required this.inventoryLocalDataSource,
    required this.customerLocalDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, ReportModel>> generateDailyReport({
    required DateTime date,
    required String companyId,
    required String generatedById,
  }) async {
    try {
      // Get daily summary from local data
      final summary = await transactionLocalDataSource.getDailySummary(date);
      
      // Get transactions for the day
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
      
      final transactions = await transactionLocalDataSource.getTransactionsByDateRange(
        startDate: startOfDay,
        endDate: endOfDay,
      );

      // Get stock totals
      final stockTotals = await inventoryLocalDataSource.getTotalStockByType();

      // Get customer count
      final customerCount = await customerLocalDataSource.getCustomersCount();

      // Build report summary
      final reportSummary = ReportSummary(
        totalPurchases: (summary['totalBuy'] as num?)?.toDouble() ?? 0,
        totalSales: (summary['totalSell'] as num?)?.toDouble() ?? 0,
        grossProfit: (summary['profit'] as num?)?.toDouble() ?? 0,
        purchaseCount: summary['buyCount'] as int? ?? 0,
        saleCount: summary['sellCount'] as int? ?? 0,
        totalPaddyStock: stockTotals[ItemType.paddy] ?? 0,
        totalRiceStock: stockTotals[ItemType.rice] ?? 0,
      );

      // Build report items
      final reportItems = <ReportItem>[];
      
      // Add transaction summaries as items
      for (final txn in transactions) {
        reportItems.add(ReportItem(
          id: txn.id,
          label: '${txn.type == TransactionType.buy ? "Buy" : "Sell"} - ${txn.customerName ?? "Unknown"}',
          description: txn.transactionNumber,
          value: txn.totalAmount,
          unit: 'currency',
          metadata: {
            'type': txn.type.name,
            'customer_id': txn.customerId,
            'items_count': txn.items.length,
          },
        ));
      }

      // Create report
      final report = ReportModel.createDaily(
        date: date,
        companyId: companyId,
        generatedById: generatedById,
        summary: reportSummary,
        items: reportItems,
      );

      return Right(report);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, ReportModel>> generateMonthlyReport({
    required int year,
    required int month,
    required String companyId,
    required String generatedById,
  }) async {
    try {
      // Get monthly summary from local data
      final summary = await transactionLocalDataSource.getMonthlySummary(year, month);
      
      // Get transactions for the month
      final startOfMonth = DateTime(year, month, 1);
      final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);
      
      final transactions = await transactionLocalDataSource.getTransactionsByDateRange(
        startDate: startOfMonth,
        endDate: endOfMonth,
      );

      // Get stock totals
      final stockTotals = await inventoryLocalDataSource.getTotalStockByType();

      // Calculate totals from transactions
      double totalPaddyBought = 0;
      double totalRiceSold = 0;

      for (final txn in transactions) {
        for (final item in txn.items) {
          if (txn.type == TransactionType.buy && item.itemType == ItemType.paddy) {
            totalPaddyBought += item.quantity;
          } else if (txn.type == TransactionType.sell && item.itemType == ItemType.rice) {
            totalRiceSold += item.quantity;
          }
        }
      }

      // Build report summary
      final reportSummary = ReportSummary(
        totalPurchases: (summary['totalBuy'] as num?)?.toDouble() ?? 0,
        totalSales: (summary['totalSell'] as num?)?.toDouble() ?? 0,
        grossProfit: (summary['profit'] as num?)?.toDouble() ?? 0,
        purchaseCount: summary['buyCount'] as int? ?? 0,
        saleCount: summary['sellCount'] as int? ?? 0,
        totalPaddyBought: totalPaddyBought,
        totalRiceSold: totalRiceSold,
        totalPaddyStock: stockTotals[ItemType.paddy] ?? 0,
        totalRiceStock: stockTotals[ItemType.rice] ?? 0,
      );

      // Build daily breakdown as report items
      final dailyBreakdown = summary['dailyBreakdown'] as List<Map<String, dynamic>>? ?? [];
      final reportItems = <ReportItem>[];

      for (int i = 0; i < dailyBreakdown.length; i++) {
        final day = dailyBreakdown[i];
        final dayProfit = (day['profit'] as num?)?.toDouble() ?? 0;
        
        // Calculate change from previous day
        double? changePercentage;
        if (i > 0) {
          final prevProfit = (dailyBreakdown[i - 1]['profit'] as num?)?.toDouble() ?? 0;
          if (prevProfit != 0) {
            changePercentage = ((dayProfit - prevProfit) / prevProfit.abs()) * 100;
          }
        }

        reportItems.add(ReportItem(
          id: 'day_${i + 1}',
          label: 'Day ${i + 1}',
          description: day['date']?.toString(),
          value: dayProfit,
          previousValue: i > 0 
              ? (dailyBreakdown[i - 1]['profit'] as num?)?.toDouble()
              : null,
          changePercentage: changePercentage,
          unit: 'currency',
          metadata: {
            'buy_count': day['buyCount'],
            'sell_count': day['sellCount'],
            'total_buy': day['totalBuy'],
            'total_sell': day['totalSell'],
          },
        ));
      }

      // Create chart data
      final chartData = <String, dynamic>{
        'daily_profit': dailyBreakdown.map((d) => d['profit']).toList(),
        'daily_sales': dailyBreakdown.map((d) => d['totalSell']).toList(),
        'daily_purchases': dailyBreakdown.map((d) => d['totalBuy']).toList(),
      };

      // Create report
      final report = ReportModel.createMonthly(
        year: year,
        month: month,
        companyId: companyId,
        generatedById: generatedById,
        summary: reportSummary,
        items: reportItems,
      ).copyWith(charts: chartData);

      return Right(report);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, ReportModel>> generateCustomReport({
    required DateTime startDate,
    required DateTime endDate,
    required ReportCategory category,
    required String companyId,
    required String generatedById,
  }) async {
    try {
      final transactions = await transactionLocalDataSource.getTransactionsByDateRange(
        startDate: startDate,
        endDate: endDate,
      );

      final totals = await transactionLocalDataSource.getTotalsByTypeForDateRange(
        startDate: startDate,
        endDate: endDate,
      );

      final stockTotals = await inventoryLocalDataSource.getTotalStockByType();

      final reportSummary = ReportSummary(
        totalPurchases: totals['buy'] ?? 0,
        totalSales: totals['sell'] ?? 0,
        grossProfit: (totals['sell'] ?? 0) - (totals['buy'] ?? 0),
        purchaseCount: transactions.where((t) => t.type == TransactionType.buy).length,
        saleCount: transactions.where((t) => t.type == TransactionType.sell).length,
        totalPaddyStock: stockTotals[ItemType.paddy] ?? 0,
        totalRiceStock: stockTotals[ItemType.rice] ?? 0,
      );

      final reportItems = <ReportItem>[];
      
      switch (category) {
        case ReportCategory.sales:
          final salesTxns = transactions.where((t) => t.type == TransactionType.sell);
          for (final txn in salesTxns) {
            reportItems.add(ReportItem(
              id: txn.id,
              label: txn.customerName ?? 'Unknown',
              description: txn.transactionNumber,
              value: txn.totalAmount,
              unit: 'currency',
            ));
          }
          break;
          
        case ReportCategory.purchases:
          final buyTxns = transactions.where((t) => t.type == TransactionType.buy);
          for (final txn in buyTxns) {
            reportItems.add(ReportItem(
              id: txn.id,
              label: txn.customerName ?? 'Unknown',
              description: txn.transactionNumber,
              value: txn.totalAmount,
              unit: 'currency',
            ));
          }
          break;
          
        case ReportCategory.inventory:
          final inventoryItems = await inventoryLocalDataSource.getAllInventoryItems();
          for (final item in inventoryItems) {
            reportItems.add(ReportItem(
              id: item.id,
              label: item.displayName,
              description: item.variety,
              value: item.currentQuantity,
              unit: 'kg',
              metadata: {
                'bags': item.currentBags,
                'type': item.type.name,
              },
            ));
          }
          break;
          
        case ReportCategory.customer:
          final customers = await customerLocalDataSource.getAllCustomers();
          for (final customer in customers) {
            reportItems.add(ReportItem(
              id: customer.id,
              label: customer.name,
              description: customer.phone,
              value: customer.balance,
              unit: 'currency',
              metadata: {
                'total_purchases': customer.totalPurchases,
                'total_sales': customer.totalSales,
              },
            ));
          }
          break;
          
        case ReportCategory.financial:
          reportItems.addAll([
            ReportItem(
              id: 'total_purchases',
              label: 'Total Purchases',
              value: totals['buy'] ?? 0,
              unit: 'currency',
            ),
            ReportItem(
              id: 'total_sales',
              label: 'Total Sales',
              value: totals['sell'] ?? 0,
              unit: 'currency',
            ),
            ReportItem(
              id: 'gross_profit',
              label: 'Gross Profit',
              value: (totals['sell'] ?? 0) - (totals['buy'] ?? 0),
              unit: 'currency',
            ),
          ]);
          break;
      }

      final now = DateTime.now();
      final report = ReportModel(
        id: 'RPT_${now.millisecondsSinceEpoch}',
        type: ReportType.custom,
        category: category,
        title: '${category.name.toUpperCase()} Report',
        startDate: startDate,
        endDate: endDate,
        companyId: companyId,
        generatedById: generatedById,
        summary: reportSummary,
        items: reportItems,
        generatedAt: now,
      );

      return Right(report);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getDashboardSummary() async {
    try {
      final now = DateTime.now();
      
      // Today's summary
      final todaySummary = await transactionLocalDataSource.getDailySummary(now);
      
      // This month's summary
      final monthlySummary = await transactionLocalDataSource.getMonthlySummary(
        now.year,
        now.month,
      );

      // Stock summary
      final stockTotals = await inventoryLocalDataSource.getTotalStockByType();
      final lowStockItems = await inventoryLocalDataSource.getLowStockItems(100); // 100kg threshold

      // Customer count
      final customerCount = await customerLocalDataSource.getCustomersCount();

      // Recent transactions
      final recentTransactions = await transactionLocalDataSource.getTodayTransactions();

      return Right({
        'today': todaySummary,
        'month': monthlySummary,
        'stock': {
          'paddy': stockTotals[ItemType.paddy] ?? 0,
          'rice': stockTotals[ItemType.rice] ?? 0,
          'low_stock_count': lowStockItems.length,
        },
        'customers': {
          'total': customerCount,
        },
        'recent_transactions': recentTransactions.take(5).map((t) => {
          'id': t.id,
          'type': t.type.name,
          'customer': t.customerName,
          'amount': t.totalAmount,
          'date': t.transactionDate.toIso8601String(),
        }).toList(),
      });
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Use remote if online for more accurate stats
      if (await networkInfo.isConnected) {
        try {
          final stats = await remoteDataSource.getTransactionStatistics(
            startDate: startDate,
            endDate: endDate,
          );
          return Right(stats);
        } catch (_) {
          // Fall back to local
        }
      }

      // Calculate local statistics
      final now = DateTime.now();
      final effectiveStartDate = startDate ?? DateTime(now.year, now.month, 1);
      final effectiveEndDate = endDate ?? now;

      final totals = await transactionLocalDataSource.getTotalsByTypeForDateRange(
        startDate: effectiveStartDate,
        endDate: effectiveEndDate,
      );

      final transactions = await transactionLocalDataSource.getTransactionsByDateRange(
        startDate: effectiveStartDate,
        endDate: effectiveEndDate,
      );

      // Calculate averages
      final buyTransactions = transactions.where((t) => t.type == TransactionType.buy).toList();
      final sellTransactions = transactions.where((t) => t.type == TransactionType.sell).toList();

      final avgBuyAmount = buyTransactions.isNotEmpty
          ? buyTransactions.fold<double>(0, (sum, t) => sum + t.totalAmount) / buyTransactions.length
          : 0.0;
          
      final avgSellAmount = sellTransactions.isNotEmpty
          ? sellTransactions.fold<double>(0, (sum, t) => sum + t.totalAmount) / sellTransactions.length
          : 0.0;

      return Right({
        'period': {
          'start': effectiveStartDate.toIso8601String(),
          'end': effectiveEndDate.toIso8601String(),
        },
        'totals': {
          'purchases': totals['buy'] ?? 0,
          'sales': totals['sell'] ?? 0,
          'profit': (totals['sell'] ?? 0) - (totals['buy'] ?? 0),
        },
        'counts': {
          'total_transactions': transactions.length,
          'buy_count': buyTransactions.length,
          'sell_count': sellTransactions.length,
        },
        'averages': {
          'avg_buy_amount': avgBuyAmount,
          'avg_sell_amount': avgSellAmount,
        },
      });
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> exportReportToPdf(ReportModel report) async {
    try {
      final pdfPath = await PdfGenerator.generateReportPdf(report);
      return Right(pdfPath);
    } catch (e) {
      return Left(UnknownFailure(message: 'Failed to generate PDF: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, String>> exportReportToExcel(ReportModel report) async {
    try {
      // This would use a library like excel or syncfusion_flutter_xlsio
      // For now, return a placeholder
      return Left(UnknownFailure(message: 'Excel export not implemented yet'));
    } catch (e) {
      return Left(UnknownFailure(message: 'Failed to generate Excel: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, String>> generateInvoicePdf(String transactionId) async {
    try {
      final transaction = await transactionLocalDataSource.getTransactionById(transactionId);
      if (transaction == null) {
        return Left(NotFoundFailure(message: 'Transaction not found'));
      }

      final pdfData = await PdfGenerator.generateReceipt(transaction: transaction);
      final fileName = 'invoice_${transaction.transactionId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = await PdfGenerator.saveToFile(pdfData, fileName);
      return Right(file.path);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: 'Failed to generate invoice: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getProfitLossReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final transactions = await transactionLocalDataSource.getTransactionsByDateRange(
        startDate: startDate,
        endDate: endDate,
      );

      final totals = await transactionLocalDataSource.getTotalsByTypeForDateRange(
        startDate: startDate,
        endDate: endDate,
      );

      double totalRevenue = 0;
      double totalCost = 0;
      double grossProfit = 0;

      for (final txn in transactions) {
        if (txn.type == TransactionType.sell) {
          totalRevenue += txn.totalAmount;
        } else if (txn.type == TransactionType.buy) {
          totalCost += txn.totalAmount;
        }
      }

      grossProfit = totalRevenue - totalCost;

      return Right({
        'period': {
          'start': startDate.toIso8601String(),
          'end': endDate.toIso8601String(),
        },
        'revenue': totalRevenue,
        'cost': totalCost,
        'gross_profit': grossProfit,
        'transactions': transactions.length,
      });
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getStockReport({
    DateTime? date,
  }) async {
    try {
      final effectiveDate = date ?? DateTime.now();
      final stockTotals = await inventoryLocalDataSource.getTotalStockByType();
      final allItems = await inventoryLocalDataSource.getAllInventoryItems();

      double totalValue = 0;
      for (final item in allItems) {
        totalValue += item.currentQuantity * (item.averagePricePerKg ?? 0);
      }

      return Right({
        'date': effectiveDate.toIso8601String(),
        'total_stock': {
          'paddy': stockTotals[ItemType.paddy] ?? 0,
          'rice': stockTotals[ItemType.rice] ?? 0,
        },
        'total_value': totalValue,
        'items_count': allItems.length,
        'items': allItems.map((item) => {
          'id': item.id,
          'name': item.displayName,
          'type': item.type.name,
          'quantity': item.currentQuantity,
          'bags': item.currentBags,
          'average_price': item.averagePricePerKg,
          'value': item.currentQuantity * (item.averagePricePerKg ?? 0),
        }).toList(),
      });
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getCustomerReport({
    String? customerId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final customers = customerId != null
          ? [(await customerLocalDataSource.getCustomerById(customerId))].where((c) => c != null).cast<CustomerModel>().toList()
          : await customerLocalDataSource.getAllCustomers();

      if (customerId != null && customers.isEmpty) {
        return Left(NotFoundFailure(message: 'Customer not found'));
      }

      final effectiveStartDate = startDate ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
      final effectiveEndDate = endDate ?? DateTime.now();

      final reportData = <Map<String, dynamic>>[];

      for (final customer in customers) {
        final allCustomerTransactions = await transactionLocalDataSource.getTransactionsByCustomer(customer.id);

        // Filter by date range
        final customerTransactions = allCustomerTransactions.where((transaction) {
          final transactionDate = transaction.transactionDate;
          return transactionDate.isAfter(effectiveStartDate.subtract(const Duration(days: 1))) &&
                 transactionDate.isBefore(effectiveEndDate.add(const Duration(days: 1)));
        }).toList();

        final totalPurchases = customerTransactions
            .where((t) => t.type == TransactionType.buy)
            .fold<double>(0, (sum, t) => sum + t.totalAmount);

        final totalSales = customerTransactions
            .where((t) => t.type == TransactionType.sell)
            .fold<double>(0, (sum, t) => sum + t.totalAmount);

        reportData.add({
          'customer': {
            'id': customer.id,
            'name': customer.name,
            'phone': customer.phone,
            'balance': customer.balance,
          },
          'period': {
            'start': effectiveStartDate.toIso8601String(),
            'end': effectiveEndDate.toIso8601String(),
          },
          'transactions': {
            'total_count': customerTransactions.length,
            'purchase_count': customerTransactions.where((t) => t.type == TransactionType.buy).length,
            'sale_count': customerTransactions.where((t) => t.type == TransactionType.sell).length,
          },
          'amounts': {
            'total_purchases': totalPurchases,
            'total_sales': totalSales,
            'net_amount': totalSales - totalPurchases,
          },
        });
      }

      return Right({
        'customers': reportData,
        'summary': {
          'total_customers': customers.length,
          'period': {
            'start': effectiveStartDate.toIso8601String(),
            'end': effectiveEndDate.toIso8601String(),
          },
        },
      });
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getSalesReport({
    required DateTime startDate,
    required DateTime endDate,
    String groupBy = 'day',
  }) async {
    try {
      final transactions = await transactionLocalDataSource.getTransactionsByDateRange(
        startDate: startDate,
        endDate: endDate,
      );

      final salesTransactions = transactions.where((t) => t.type == TransactionType.sell).toList();

      final groupedData = <String, Map<String, dynamic>>{};

      for (final txn in salesTransactions) {
        String key;
        switch (groupBy) {
          case 'customer':
            key = txn.customerName ?? 'Unknown';
            break;
          case 'variety':
            key = txn.items.isNotEmpty ? txn.items.first.variety : 'Unknown';
            break;
          case 'week':
            final weekStart = txn.transactionDate.subtract(Duration(days: txn.transactionDate.weekday - 1));
            key = weekStart.toIso8601String().substring(0, 10);
            break;
          case 'month':
            key = '${txn.transactionDate.year}-${txn.transactionDate.month.toString().padLeft(2, '0')}';
            break;
          default: // 'day'
            key = txn.transactionDate.toIso8601String().substring(0, 10);
        }

        if (!groupedData.containsKey(key)) {
          groupedData[key] = {
            'group': key,
            'total_amount': 0.0,
            'transaction_count': 0,
            'total_weight': 0.0,
            'transactions': <Map<String, dynamic>>[],
          };
        }

        groupedData[key]!['total_amount'] += txn.totalAmount;
        groupedData[key]!['transaction_count'] += 1;
        groupedData[key]!['total_weight'] += txn.items.fold<double>(0, (sum, item) => sum + item.quantity);

        groupedData[key]!['transactions'].add({
          'id': txn.id,
          'customer': txn.customerName,
          'amount': txn.totalAmount,
          'weight': txn.items.fold<double>(0, (sum, item) => sum + item.quantity),
          'date': txn.transactionDate.toIso8601String(),
        });
      }

      return Right({
        'period': {
          'start': startDate.toIso8601String(),
          'end': endDate.toIso8601String(),
        },
        'grouped_by': groupBy,
        'total_sales': salesTransactions.fold<double>(0, (sum, t) => sum + t.totalAmount),
        'total_transactions': salesTransactions.length,
        'groups': groupedData.values.toList(),
      });
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getPurchaseReport({
    required DateTime startDate,
    required DateTime endDate,
    String groupBy = 'day',
  }) async {
    try {
      final transactions = await transactionLocalDataSource.getTransactionsByDateRange(
        startDate: startDate,
        endDate: endDate,
      );

      final purchaseTransactions = transactions.where((t) => t.type == TransactionType.buy).toList();

      final groupedData = <String, Map<String, dynamic>>{};

      for (final txn in purchaseTransactions) {
        String key;
        switch (groupBy) {
          case 'customer':
            key = txn.customerName ?? 'Unknown';
            break;
          case 'variety':
            key = txn.items.isNotEmpty ? txn.items.first.variety : 'Unknown';
            break;
          case 'week':
            final weekStart = txn.transactionDate.subtract(Duration(days: txn.transactionDate.weekday - 1));
            key = weekStart.toIso8601String().substring(0, 10);
            break;
          case 'month':
            key = '${txn.transactionDate.year}-${txn.transactionDate.month.toString().padLeft(2, '0')}';
            break;
          default: // 'day'
            key = txn.transactionDate.toIso8601String().substring(0, 10);
        }

        if (!groupedData.containsKey(key)) {
          groupedData[key] = {
            'group': key,
            'total_amount': 0.0,
            'transaction_count': 0,
            'total_weight': 0.0,
            'transactions': <Map<String, dynamic>>[],
          };
        }

        groupedData[key]!['total_amount'] += txn.totalAmount;
        groupedData[key]!['transaction_count'] += 1;
        groupedData[key]!['total_weight'] += txn.items.fold<double>(0, (sum, item) => sum + item.quantity);

        groupedData[key]!['transactions'].add({
          'id': txn.id,
          'customer': txn.customerName,
          'amount': txn.totalAmount,
          'weight': txn.items.fold<double>(0, (sum, item) => sum + item.quantity),
          'date': txn.transactionDate.toIso8601String(),
        });
      }

      return Right({
        'period': {
          'start': startDate.toIso8601String(),
          'end': endDate.toIso8601String(),
        },
        'grouped_by': groupBy,
        'total_purchases': purchaseTransactions.fold<double>(0, (sum, t) => sum + t.totalAmount),
        'total_transactions': purchaseTransactions.length,
        'groups': groupedData.values.toList(),
      });
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getMillingReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final transactions = await transactionLocalDataSource.getTransactionsByDateRange(
        startDate: startDate,
        endDate: endDate,
      );

      double totalPaddyProcessed = 0;
      double totalRiceProduced = 0;

      for (final txn in transactions) {
        if (txn.type == TransactionType.buy) {
          // Paddy purchases
          for (final item in txn.items) {
            if (item.itemType == ItemType.paddy) {
              totalPaddyProcessed += item.quantity;
            }
          }
        } else if (txn.type == TransactionType.sell) {
          // Rice sales
          for (final item in txn.items) {
            if (item.itemType == ItemType.rice) {
              totalRiceProduced += item.quantity;
            }
          }
        }
      }

      final millingRatio = totalPaddyProcessed > 0 ? totalRiceProduced / totalPaddyProcessed : 0.0;

      return Right({
        'period': {
          'start': startDate.toIso8601String(),
          'end': endDate.toIso8601String(),
        },
        'paddy_processed': totalPaddyProcessed,
        'rice_produced': totalRiceProduced,
        'milling_ratio': millingRatio,
        'efficiency_percentage': millingRatio * 100,
      });
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getOutstandingBalancesReport({
    String? type,
  }) async {
    try {
      final customers = await customerLocalDataSource.getAllCustomers();

      final receivable = <Map<String, dynamic>>[];
      final payable = <Map<String, dynamic>>[];

      for (final customer in customers) {
        if (customer.balance > 0) {
          receivable.add({
            'customer_id': customer.id,
            'customer_name': customer.name,
            'amount': customer.balance,
            'phone': customer.phone,
          });
        } else if (customer.balance < 0) {
          payable.add({
            'customer_id': customer.id,
            'customer_name': customer.name,
            'amount': customer.balance.abs(),
            'phone': customer.phone,
          });
        }
      }

      final result = <String, dynamic>{
        'receivable': receivable,
        'payable': payable,
        'total_receivable': receivable.fold<double>(0, (sum, c) => sum + c['amount']),
        'total_payable': payable.fold<double>(0, (sum, c) => sum + c['amount']),
        'net_balance': receivable.fold<double>(0, (sum, c) => sum + c['amount']) -
                      payable.fold<double>(0, (sum, c) => sum + c['amount']),
      };

      if (type == 'receivable') {
        return Right({'receivable': receivable, 'total': result['total_receivable']});
      } else if (type == 'payable') {
        return Right({'payable': payable, 'total': result['total_payable']});
      } else {
        return Right(result);
      }
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getTopPerformersReport({
    required String type,
    required DateTime startDate,
    required DateTime endDate,
    int limit = 10,
  }) async {
    try {
      final transactions = await transactionLocalDataSource.getTransactionsByDateRange(
        startDate: startDate,
        endDate: endDate,
      );

      switch (type) {
        case 'customers':
          final customerStats = <String, Map<String, dynamic>>{};

          for (final txn in transactions) {
            final customerId = txn.customerId;
            final customerName = txn.customerName ?? 'Unknown';

            if (!customerStats.containsKey(customerId)) {
              customerStats[customerId] = {
                'customer_id': customerId,
                'customer_name': customerName,
                'total_amount': 0.0,
                'transaction_count': 0,
                'total_weight': 0.0,
              };
            }

            customerStats[customerId]!['total_amount'] += txn.totalAmount;
            customerStats[customerId]!['transaction_count'] += 1;
            customerStats[customerId]!['total_weight'] += txn.items.fold<double>(0, (sum, item) => sum + item.quantity);
          }

          final sorted = customerStats.values.toList()
            ..sort((a, b) => (b['total_amount'] as double).compareTo(a['total_amount'] as double));

          return Right(sorted.take(limit).toList());

        case 'products':
        case 'varieties':
          final varietyStats = <String, Map<String, dynamic>>{};

          for (final txn in transactions) {
            for (final item in txn.items) {
              final variety = item.variety;

              if (!varietyStats.containsKey(variety)) {
                varietyStats[variety] = {
                  'variety': variety,
                  'total_amount': 0.0,
                  'total_weight': 0.0,
                  'transaction_count': 0,
                };
              }

              varietyStats[variety]!['total_amount'] += item.quantity * item.pricePerKg;
              varietyStats[variety]!['total_weight'] += item.quantity;
              varietyStats[variety]!['transaction_count'] += 1;
            }
          }

          final sorted = varietyStats.values.toList()
            ..sort((a, b) => (b['total_weight'] as double).compareTo(a['total_weight'] as double));

          return Right(sorted.take(limit).toList());

        default:
          return Left(ValidationFailure.invalid('type', 'Invalid type: $type'));
      }
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getComparisonReport({
    required DateTime period1Start,
    required DateTime period1End,
    required DateTime period2Start,
    required DateTime period2End,
  }) async {
    try {
      // Get data for period 1
      final period1Transactions = await transactionLocalDataSource.getTransactionsByDateRange(
        startDate: period1Start,
        endDate: period1End,
      );
      final period1Totals = await transactionLocalDataSource.getTotalsByTypeForDateRange(
        startDate: period1Start,
        endDate: period1End,
      );

      // Get data for period 2
      final period2Transactions = await transactionLocalDataSource.getTransactionsByDateRange(
        startDate: period2Start,
        endDate: period2End,
      );
      final period2Totals = await transactionLocalDataSource.getTotalsByTypeForDateRange(
        startDate: period2Start,
        endDate: period2End,
      );

      final period1Sales = period1Totals['sell'] ?? 0.0;
      final period1Purchases = period1Totals['buy'] ?? 0.0;
      final period1Profit = period1Sales - period1Purchases;

      final period2Sales = period2Totals['sell'] ?? 0.0;
      final period2Purchases = period2Totals['buy'] ?? 0.0;
      final period2Profit = period2Sales - period2Purchases;

      double salesChange = 0;
      double purchaseChange = 0;
      double profitChange = 0;

      if (period1Sales != 0) {
        salesChange = ((period2Sales - period1Sales) / period1Sales) * 100;
      }
      if (period1Purchases != 0) {
        purchaseChange = ((period2Purchases - period1Purchases) / period1Purchases) * 100;
      }
      if (period1Profit != 0) {
        profitChange = ((period2Profit - period1Profit) / period1Profit) * 100;
      }

      return Right({
        'period1': {
          'start': period1Start.toIso8601String(),
          'end': period1End.toIso8601String(),
          'sales': period1Sales,
          'purchases': period1Purchases,
          'profit': period1Profit,
          'transactions': period1Transactions.length,
        },
        'period2': {
          'start': period2Start.toIso8601String(),
          'end': period2End.toIso8601String(),
          'sales': period2Sales,
          'purchases': period2Purchases,
          'profit': period2Profit,
          'transactions': period2Transactions.length,
        },
        'changes': {
          'sales_percentage': salesChange,
          'purchases_percentage': purchaseChange,
          'profit_percentage': profitChange,
        },
      });
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getTrendReport({
    required int months,
    required String metric,
  }) async {
    try {
      final trends = <Map<String, dynamic>>[];
      final now = DateTime.now();

      for (int i = months - 1; i >= 0; i--) {
        final monthStart = DateTime(now.year, now.month - i, 1);
        final monthEnd = DateTime(now.year, now.month - i + 1, 0, 23, 59, 59);

        final totals = await transactionLocalDataSource.getTotalsByTypeForDateRange(
          startDate: monthStart,
          endDate: monthEnd,
        );

        double value;
        switch (metric) {
          case 'sales':
            value = totals['sell'] ?? 0.0;
            break;
          case 'purchases':
            value = totals['buy'] ?? 0.0;
            break;
          case 'profit':
            value = (totals['sell'] ?? 0.0) - (totals['buy'] ?? 0.0);
            break;
          case 'stock':
            final stockTotals = await inventoryLocalDataSource.getTotalStockByType();
            value = (stockTotals[ItemType.paddy] ?? 0) + (stockTotals[ItemType.rice] ?? 0);
            break;
          default:
            value = 0.0;
        }

        trends.add({
          'month': '${monthStart.year}-${monthStart.month.toString().padLeft(2, '0')}',
          'metric': metric,
          'value': value,
          'period': {
            'start': monthStart.toIso8601String(),
            'end': monthEnd.toIso8601String(),
          },
        });
      }

      return Right(trends);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ReportModel>>> getSavedReports({
    ReportType? type,
    int limit = 20,
  }) async {
    // TODO: Implement saved reports storage and retrieval
    return Left(UnknownFailure(message: 'Saved reports feature not implemented yet'));
  }

  @override
  Future<Either<Failure, ReportModel>> saveReport(ReportModel report) async {
    // TODO: Implement report saving functionality
    return Left(UnknownFailure(message: 'Save report feature not implemented yet'));
  }

  @override
  Future<Either<Failure, bool>> deleteReport(String reportId) async {
    // TODO: Implement report deletion functionality
    return Left(UnknownFailure(message: 'Delete report feature not implemented yet'));
  }

  @override
  Future<Either<Failure, bool>> shareReport({
    required String reportId,
    required String method,
    String? recipient,
  }) async {
    // TODO: Implement report sharing functionality
    return Left(UnknownFailure(message: 'Share report feature not implemented yet'));
  }

  @override
  Future<Either<Failure, String>> scheduleReport({
    required ReportType type,
    required String frequency,
    required List<String> recipients,
  }) async {
    // TODO: Implement report scheduling functionality
    return Left(UnknownFailure(message: 'Schedule report feature not implemented yet'));
  }

  @override
  Future<Either<Failure, bool>> cancelScheduledReport(String scheduleId) async {
    // TODO: Implement cancel scheduled report functionality
    return Left(UnknownFailure(message: 'Cancel scheduled report feature not implemented yet'));
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getScheduledReports() async {
    // TODO: Implement get scheduled reports functionality
    return Left(UnknownFailure(message: 'Get scheduled reports feature not implemented yet'));
  }
}
