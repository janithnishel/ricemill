// lib/data/models/customer_model.dart

import 'package:equatable/equatable.dart';
import '../../domain/entities/customer_entity.dart';
import '../../core/constants/db_constants.dart';
import '../../core/constants/enums.dart';

class CustomerModel extends Equatable {
  final int? localId;
  final String id;
  final String? serverId;
  final String name;
  final String phone;
  final String? secondaryPhone;
  final String? email;
  final String? address;
  final String? nicNumber;
  final CustomerType type;
  final String companyId;
  final double totalPurchases;      // Total amount we bought from them
  final double totalSales;          // Total amount we sold to them
  final double balance;             // Outstanding balance (+ they owe us, - we owe them)
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;
  final SyncStatus syncStatus;
  final DateTime? syncedAt;
  final bool isDeleted;

  const CustomerModel({
    this.localId,
    required this.id,
    this.serverId,
    required this.name,
    required this.phone,
    this.secondaryPhone,
    this.email,
    this.address,
    this.nicNumber,
    this.type = CustomerType.farmer,
    required this.companyId,
    this.totalPurchases = 0.0,
    this.totalSales = 0.0,
    this.balance = 0.0,
    this.notes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.syncStatus = SyncStatus.pending,
    this.syncedAt,
    this.isDeleted = false,
  });

  /// Create from JSON (API or Local DB)
  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id']?.toString() ?? '',
      serverId: json['server_id']?.toString(),
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      secondaryPhone: json['secondary_phone']?.toString(),
      email: json['email']?.toString(),
      address: json['address']?.toString(),
      nicNumber: json['nic_number']?.toString(),
      type: _parseCustomerType(json['type']),
      companyId: json['company_id']?.toString() ?? '',
      totalPurchases: _parseDouble(json['total_purchases']),
      totalSales: _parseDouble(json['total_sales']),
      balance: _parseDouble(json['balance']),
      notes: json['notes']?.toString(),
      isActive: json['is_active'] == true || json['is_active'] == 1,
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updated_at']) ?? DateTime.now(),
      isSynced: json['is_synced'] == true || json['is_synced'] == 1,
      syncStatus: _parseSyncStatus(json['sync_status']),
      syncedAt: _parseDateTime(json['synced_at']),
      isDeleted: json['is_deleted'] == true || json['is_deleted'] == 1,
    );
  }

  /// Convert to JSON for Local DB
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'server_id': serverId,
      'name': name,
      'phone': phone,
      'secondary_phone': secondaryPhone,
      'email': email,
      'address': address,
      'nic_number': nicNumber,
      'type': type.name,
      'company_id': companyId,
      'total_purchases': totalPurchases,
      'total_sales': totalSales,
      'balance': balance,
      'notes': notes,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
      'sync_status': syncStatus.value,
      'synced_at': syncedAt?.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  /// Create from DB map
  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    return CustomerModel(
      localId: (map[DbConstants.colLocalId] is int) ? map[DbConstants.colLocalId] as int : (map[DbConstants.colLocalId] != null ? int.tryParse(map[DbConstants.colLocalId].toString()) : null),
      id: map[DbConstants.colServerId]?.toString() ?? (map['id']?.toString() ?? ''),
      serverId: map[DbConstants.colServerId]?.toString(),
      name: map[DbConstants.colName]?.toString() ?? '',
      phone: map[DbConstants.colPhone]?.toString() ?? '',
      secondaryPhone: map['secondary_phone']?.toString(),
      email: map['email']?.toString(),
      address: map[DbConstants.colAddress]?.toString(),
      nicNumber: map[DbConstants.colNic]?.toString(),
      type: CustomerModel._parseCustomerType(map[DbConstants.colCustomerType] ?? map['type']),
      companyId: map[DbConstants.colCompanyId]?.toString() ?? '',
      totalPurchases: CustomerModel._parseDouble(map['total_purchases'] ?? map['totalPurchases']),
      totalSales: CustomerModel._parseDouble(map['total_sales'] ?? map['totalSales']),
      balance: CustomerModel._parseDouble(map[DbConstants.colBalance] ?? map['balance']),
      notes: map[DbConstants.colNotes]?.toString() ?? map['notes']?.toString(),
      isActive: (map['is_active'] == 1) || (map['is_active'] == true),
      createdAt: CustomerModel._parseDateTime(map[DbConstants.colCreatedAt]) ?? DateTime.now(),
      updatedAt: CustomerModel._parseDateTime(map[DbConstants.colUpdatedAt]) ?? DateTime.now(),
      isSynced: (map['is_synced'] == 1) || (map['is_synced'] == true),
      syncStatus: _parseSyncStatus(map[DbConstants.colSyncStatus] ?? map['sync_status']),
      syncedAt: CustomerModel._parseDateTime(map['synced_at']),
      isDeleted: (map[DbConstants.colIsDeleted] == 1) || (map[DbConstants.colIsDeleted] == true),
    );
  }

  /// Convert to DB map
  Map<String, dynamic> toMap() {
    return {
      DbConstants.colLocalId: localId,
      DbConstants.colServerId: serverId,
      DbConstants.colName: name,
      DbConstants.colPhone: phone,
      'secondary_phone': secondaryPhone,
      'email': email,
      DbConstants.colAddress: address,
      DbConstants.colNic: nicNumber,
      DbConstants.colCustomerType: type.name,
      DbConstants.colCompanyId: companyId,
      DbConstants.colBalance: balance,
      DbConstants.colNotes: notes,
      'is_active': isActive ? 1 : 0,
      DbConstants.colCreatedAt: createdAt.toIso8601String(),
      DbConstants.colUpdatedAt: updatedAt.toIso8601String(),
      DbConstants.colSyncStatus: syncStatus.value,
      'synced_at': syncedAt?.toIso8601String(),
      DbConstants.colIsDeleted: isDeleted ? 1 : 0,
    };
  }

  /// Convert to JSON for API
  Map<String, dynamic> toJsonForApi() {
    return {
      'name': name,
      'phone': phone,
      'secondary_phone': secondaryPhone,
      'email': email,
      'address': address,
      'nic_number': nicNumber,
      'type': type.name,
      'notes': notes,
      'is_active': isActive,
    };
  }

  /// Convert to JSON for Sync
  Map<String, dynamic> toJsonForSync() {
    return {
      'local_id': id,
      'server_id': serverId,
      'name': name,
      'phone': phone,
      'secondary_phone': secondaryPhone,
      'email': email,
      'address': address,
      'nic_number': nicNumber,
      'type': type.name,
      'total_purchases': totalPurchases,
      'total_sales': totalSales,
      'balance': balance,
      'notes': notes,
      'is_active': isActive,
      'is_deleted': isDeleted,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Convert to Entity
  CustomerEntity toEntity() {
    return CustomerEntity(
      id: id,
      name: name,
      phone: phone,
      address: address,
      type: type,
      balance: balance,
      isActive: isActive,
    );
  }

  /// Create from Entity
  factory CustomerModel.fromEntity(CustomerEntity entity, String companyId) {
    return CustomerModel(
      id: entity.id,
      name: entity.name,
      phone: entity.phone,
      address: entity.address,
      type: entity.type,
      companyId: companyId,
      balance: entity.balance,
      isActive: entity.isActive,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Create new customer with generated ID
  factory CustomerModel.create({
    required String name,
    required String phone,
    String? secondaryPhone,
    String? email,
    String? address,
    String? nicNumber,
    CustomerType type = CustomerType.farmer,
    required String companyId,
    String? notes,
  }) {
    final now = DateTime.now();
    return CustomerModel(
      id: 'CUST_${now.millisecondsSinceEpoch}',
      name: name,
      phone: phone.replaceAll(RegExp(r'[^\d+]'), ''),
      secondaryPhone: secondaryPhone?.replaceAll(RegExp(r'[^\d+]'), ''),
      email: email,
      address: address,
      nicNumber: nicNumber,
      type: type,
      companyId: companyId,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Copy with new values
  CustomerModel copyWith({
    String? id,
    String? serverId,
    String? name,
    String? phone,
    String? secondaryPhone,
    String? email,
    String? address,
    String? nicNumber,
    CustomerType? type,
    String? companyId,
    double? totalPurchases,
    double? totalSales,
    double? balance,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? localId,
    bool? isSynced,
    SyncStatus? syncStatus,
    DateTime? syncedAt,
    bool? isDeleted,
  }) {
    return CustomerModel(
      localId: localId ?? this.localId,
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      secondaryPhone: secondaryPhone ?? this.secondaryPhone,
      email: email ?? this.email,
      address: address ?? this.address,
      nicNumber: nicNumber ?? this.nicNumber,
      type: type ?? this.type,
      companyId: companyId ?? this.companyId,
      totalPurchases: totalPurchases ?? this.totalPurchases,
      totalSales: totalSales ?? this.totalSales,
      balance: balance ?? this.balance,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      syncStatus: syncStatus ?? this.syncStatus,
      syncedAt: syncedAt ?? this.syncedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  /// Update balance after transaction
  CustomerModel updateBalance({
    double? addPurchase,
    double? addSale,
    double? newBalance,
  }) {
    return copyWith(
      totalPurchases: addPurchase != null 
          ? totalPurchases + addPurchase 
          : totalPurchases,
      totalSales: addSale != null 
          ? totalSales + addSale 
          : totalSales,
      balance: newBalance ?? balance,
      updatedAt: DateTime.now(),
      isSynced: false,
    );
  }

  /// Helper to parse CustomerType
  static CustomerType _parseCustomerType(dynamic value) {
    if (value == null) return CustomerType.farmer;
    if (value is CustomerType) return value;

    final typeStr = value.toString().toLowerCase();
    switch (typeStr) {
      case 'farmer':
        return CustomerType.farmer;
      case 'trader':
        return CustomerType.trader;
      case 'retailer':
        return CustomerType.retailer;
      case 'wholesaler':
        return CustomerType.wholesaler;
      case 'buyer':
        return CustomerType.buyer;
      case 'seller':
        return CustomerType.seller;
      case 'both':
        return CustomerType.both;
      case 'miller':
        return CustomerType.wholesaler; // Map old 'miller' to 'wholesaler'
      default:
        return CustomerType.other;
    }
  }

  /// Helper to parse double
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Helper to parse DateTime
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static SyncStatus _parseSyncStatus(dynamic value) {
    if (value == null) return SyncStatus.pending;
    if (value is SyncStatus) return value;
    return SyncStatus.fromString(value.toString());
  }

  /// Get display type name (Sinhala)
  String get displayType {
    switch (type) {
      case CustomerType.farmer:
        return 'ගොවියා';
      case CustomerType.trader:
        return 'වෙළෙන්දා';
      case CustomerType.retailer:
        return 'සිල්ලර';
      case CustomerType.wholesaler:
        return 'තොග වෙළඳුනා';
      case CustomerType.buyer:
        return 'ගැනුම්කරු';
      case CustomerType.seller:
        return 'විකුණුම්කරු';
      case CustomerType.both:
        return 'දෙකම';
      case CustomerType.other:
        return 'වෙනත්';
    }
  }

  /// Get display type name (English)
  String get displayTypeEn {
    switch (type) {
      case CustomerType.farmer:
        return 'Farmer';
      case CustomerType.trader:
        return 'Trader';
      case CustomerType.retailer:
        return 'Retailer';
      case CustomerType.wholesaler:
        return 'Wholesaler';
      case CustomerType.buyer:
        return 'Buyer';
      case CustomerType.seller:
        return 'Seller';
      case CustomerType.both:
        return 'Both';
      case CustomerType.other:
        return 'Other';
    }
  }

  /// Get initials for avatar
  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'C';
  }

  /// Format phone for display
  String get formattedPhone {
    if (phone.length == 10) {
      return '${phone.substring(0, 3)} ${phone.substring(3, 6)} ${phone.substring(6)}';
    }
    return phone;
  }

  /// Check if customer has outstanding balance
  bool get hasOutstandingBalance => balance != 0;

  /// Check if we owe them money
  bool get weOweThem => balance < 0;

  /// Check if they owe us money
  bool get theyOweUs => balance > 0;

  /// Getters used by widgets
  bool get customerOwesUs => theyOweUs;
  double get absoluteBalance => balance.abs();
  String get typeDisplayName => displayType;
  String get shortAddress => address != null && address!.length > 30
      ? '${address!.substring(0, 30)}...'
      : (address ?? '');

  @override
  List<Object?> get props => [
        id,
        serverId,
        name,
        phone,
        type,
        companyId,
        balance,
        isActive,
        isSynced,
        isDeleted,
      ];

  @override
  String toString() => 'CustomerModel(id: $id, name: $name, phone: $phone)';
}
