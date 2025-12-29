// lib/data/models/transaction_item_model.dart

import 'package:equatable/equatable.dart';
import '../../core/constants/enums.dart';
import '../../core/constants/db_constants.dart';
import '../../domain/entities/transaction_entity.dart';

class TransactionItemModel extends Equatable {
  final int? localId;
  final String id;
  final String transactionId;
  final String inventoryItemId;
  final String? inventoryServerId;
  final ItemType itemType;            // Paddy or Rice
  final String variety;               // Item variety name
  final int bags;                     // Number of bags
  final double quantity;              // Weight in KG
  final double pricePerKg;            // Price per KG
  final double totalAmount;           // Total = quantity * pricePerKg
  final double? grossWeight;          // Gross weight (with bag)
  final double? tareWeight;           // Bag/container weight
  final double? moisturePercentage;   // Moisture content for paddy
  final double? deductionPercentage;  // Quality deduction percentage
  final double? deductionAmount;      // Deducted amount
  final String? notes;
  final DateTime createdAt;
  final SyncStatus syncStatus;

  const TransactionItemModel({
    this.localId,
    required this.id,
    required this.transactionId,
    required this.inventoryItemId,
    this.inventoryServerId,
    required this.itemType,
    required this.variety,
    required this.bags,
    required this.quantity,
    required this.pricePerKg,
    required this.totalAmount,
    this.grossWeight,
    this.tareWeight,
    this.moisturePercentage,
    this.deductionPercentage,
    this.deductionAmount,
    this.notes,
    required this.createdAt,
    this.syncStatus = SyncStatus.pending,
  });

  /// Create from JSON (API or Local DB)
  factory TransactionItemModel.fromJson(Map<String, dynamic> json) {
    return TransactionItemModel(
      id: json['id']?.toString() ?? '',
      transactionId: json['transaction_id']?.toString() ?? '',
      inventoryItemId: json['inventory_item_id']?.toString() ?? '',
      inventoryServerId: json['inventory_server_id']?.toString(),
      itemType: _parseItemType(json['item_type']),
      variety: json['variety']?.toString() ?? '',
      bags: _parseInt(json['bags']),
      quantity: _parseDouble(json['quantity']),
      pricePerKg: _parseDouble(json['price_per_kg']),
      totalAmount: _parseDouble(json['total_amount']),
      grossWeight: json['gross_weight'] != null 
          ? _parseDouble(json['gross_weight']) 
          : null,
      tareWeight: json['tare_weight'] != null 
          ? _parseDouble(json['tare_weight']) 
          : null,
      moisturePercentage: json['moisture_percentage'] != null 
          ? _parseDouble(json['moisture_percentage']) 
          : null,
      deductionPercentage: json['deduction_percentage'] != null 
          ? _parseDouble(json['deduction_percentage']) 
          : null,
      deductionAmount: json['deduction_amount'] != null 
          ? _parseDouble(json['deduction_amount']) 
          : null,
      notes: json['notes']?.toString(),
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
    );
  }

  /// Convert to JSON for Local DB
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'inventory_item_id': inventoryItemId,
      'inventory_server_id': inventoryServerId,
      'item_type': itemType.name,
      'variety': variety,
      'bags': bags,
      'quantity': quantity,
      'price_per_kg': pricePerKg,
      'total_amount': totalAmount,
      'gross_weight': grossWeight,
      'tare_weight': tareWeight,
      'moisture_percentage': moisturePercentage,
      'deduction_percentage': deductionPercentage,
      'deduction_amount': deductionAmount,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Convert to JSON for API
  Map<String, dynamic> toJsonForApi() {
    return {
      'inventory_item_id': inventoryItemId,
      'item_type': itemType.name,
      'variety': variety,
      'bags': bags,
      'quantity': quantity,
      'price_per_kg': pricePerKg,
      'total_amount': totalAmount,
      'gross_weight': grossWeight,
      'tare_weight': tareWeight,
      'moisture_percentage': moisturePercentage,
      'deduction_percentage': deductionPercentage,
      'deduction_amount': deductionAmount,
      'notes': notes,
    };
  }

  /// Convert to JSON for Sync
  Map<String, dynamic> toJsonForSync() {
    return {
      'local_id': id,
      'transaction_local_id': transactionId,
      'inventory_item_id': inventoryItemId,
      'inventory_server_id': inventoryServerId,
      'item_type': itemType.name,
      'variety': variety,
      'bags': bags,
      'quantity': quantity,
      'price_per_kg': pricePerKg,
      'total_amount': totalAmount,
      'gross_weight': grossWeight,
      'tare_weight': tareWeight,
      'moisture_percentage': moisturePercentage,
      'deduction_percentage': deductionPercentage,
      'deduction_amount': deductionAmount,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Convert to Entity
  TransactionItemEntity toEntity() {
    return TransactionItemEntity(
      id: id,
      itemType: itemType,
      variety: variety,
      bags: bags,
      totalWeight: quantity,
      pricePerKg: pricePerKg,
      totalPrice: totalAmount,
    );
  }

  /// Create new transaction item
  factory TransactionItemModel.create({
    required String transactionId,
    required String inventoryItemId,
    String? inventoryServerId,
    required ItemType itemType,
    required String variety,
    required int bags,
    required double quantity,
    required double pricePerKg,
    double? grossWeight,
    double? tareWeight,
    double? moisturePercentage,
    double? deductionPercentage,
    String? notes,
  }) {
    final now = DateTime.now();
    
    // Calculate net weight if gross and tare provided
    double netQuantity = quantity;
    if (grossWeight != null && tareWeight != null) {
      netQuantity = grossWeight - tareWeight;
    }

    // Calculate deduction if percentage provided
    double? deductionAmount;
    double finalQuantity = netQuantity;
    if (deductionPercentage != null && deductionPercentage > 0) {
      deductionAmount = netQuantity * (deductionPercentage / 100);
      finalQuantity = netQuantity - deductionAmount;
    }

    final totalAmount = finalQuantity * pricePerKg;

    return TransactionItemModel(
      id: 'ITEM_${now.millisecondsSinceEpoch}',
      transactionId: transactionId,
      inventoryItemId: inventoryItemId,
      inventoryServerId: inventoryServerId,
      itemType: itemType,
      variety: variety,
      bags: bags,
      quantity: finalQuantity,
      pricePerKg: pricePerKg,
      totalAmount: totalAmount,
      grossWeight: grossWeight,
      tareWeight: tareWeight,
      moisturePercentage: moisturePercentage,
      deductionPercentage: deductionPercentage,
      deductionAmount: deductionAmount,
      notes: notes,
      createdAt: now,
    );
  }

  /// Copy with new values
  TransactionItemModel copyWith({
    int? localId,
    String? id,
    String? transactionId,
    String? inventoryItemId,
    String? inventoryServerId,
    ItemType? itemType,
    String? variety,
    int? bags,
    double? quantity,
    double? pricePerKg,
    double? totalAmount,
    double? grossWeight,
    double? tareWeight,
    double? moisturePercentage,
    double? deductionPercentage,
    double? deductionAmount,
    String? notes,
    DateTime? createdAt,
    SyncStatus? syncStatus,
    // legacy alias used by table code
    int? transactionLocalId,
  }) {
    return TransactionItemModel(
      localId: localId ?? this.localId,
      id: id ?? this.id,
      transactionId: transactionId ?? (transactionLocalId != null ? transactionLocalId.toString() : this.transactionId),
      inventoryItemId: inventoryItemId ?? this.inventoryItemId,
      inventoryServerId: inventoryServerId ?? this.inventoryServerId,
      itemType: itemType ?? this.itemType,
      variety: variety ?? this.variety,
      bags: bags ?? this.bags,
      quantity: quantity ?? this.quantity,
      pricePerKg: pricePerKg ?? this.pricePerKg,
      totalAmount: totalAmount ?? this.totalAmount,
      grossWeight: grossWeight ?? this.grossWeight,
      tareWeight: tareWeight ?? this.tareWeight,
      moisturePercentage: moisturePercentage ?? this.moisturePercentage,
      deductionPercentage: deductionPercentage ?? this.deductionPercentage,
      deductionAmount: deductionAmount ?? this.deductionAmount,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  /// Create from DB map
  factory TransactionItemModel.fromMap(Map<String, dynamic> map) {
    return TransactionItemModel(
      localId: (map[DbConstants.colLocalId] is int) ? map[DbConstants.colLocalId] as int : (map[DbConstants.colLocalId] != null ? int.tryParse(map[DbConstants.colLocalId].toString()) : null),
      id: map[DbConstants.colServerId]?.toString() ?? map['id']?.toString() ?? 'ITEM_${DateTime.now().millisecondsSinceEpoch}',
      transactionId: (map['transaction_local_id'] ?? map['transaction_id'])?.toString() ?? '',
      inventoryItemId: map['inventory_item_id']?.toString() ?? '',
      inventoryServerId: map['inventory_server_id']?.toString(),
      itemType: _parseItemType(map['item_type'] ?? map['item_type']),
      variety: map['variety']?.toString() ?? '',
      bags: _parseInt(map['bag_count'] ?? map['bags']),
      quantity: _parseDouble(map['weight_kg'] ?? map['quantity']),
      pricePerKg: _parseDouble(map['price_per_kg'] ?? map['price']),
      totalAmount: _parseDouble(map['amount'] ?? map['total_amount']),
      grossWeight: map['gross_weight'] != null ? _parseDouble(map['gross_weight']) : null,
      tareWeight: map['tare_weight'] != null ? _parseDouble(map['tare_weight']) : null,
      moisturePercentage: map['moisture_percentage'] != null ? _parseDouble(map['moisture_percentage']) : null,
      deductionPercentage: map['deduction_percentage'] != null ? _parseDouble(map['deduction_percentage']) : null,
      deductionAmount: map['deduction_amount'] != null ? _parseDouble(map['deduction_amount']) : null,
      notes: map['notes']?.toString(),
      createdAt: _parseDateTime(map[DbConstants.colCreatedAt]) ?? DateTime.now(),
      syncStatus: _parseSyncStatus(map[DbConstants.colSyncStatus] ?? map['sync_status']),
    );
  }

  /// Convert to DB map
  Map<String, dynamic> toMap() {
    return {
      DbConstants.colLocalId: localId,
      DbConstants.colServerId: inventoryServerId,
      'transaction_local_id': int.tryParse(transactionId) ?? transactionId,
      'item_type': itemType.name,
      'item_name': variety,
      'variety': variety,
      'weight_kg': quantity,
      'bag_count': bags,
      'price_per_kg': pricePerKg,
      'amount': totalAmount,
      DbConstants.colCreatedAt: createdAt.toIso8601String(),
      DbConstants.colSyncStatus: syncStatus.value,
    };
  }

  /// Update with recalculation
  TransactionItemModel updateWithRecalculation({
    int? bags,
    double? quantity,
    double? pricePerKg,
    double? grossWeight,
    double? tareWeight,
    double? deductionPercentage,
  }) {
    final newBags = bags ?? this.bags;
    final newGrossWeight = grossWeight ?? this.grossWeight;
    final newTareWeight = tareWeight ?? this.tareWeight;
    final newDeductionPercentage = deductionPercentage ?? this.deductionPercentage;
    final newPricePerKg = pricePerKg ?? this.pricePerKg;

    // Calculate net weight
    double newQuantity = quantity ?? this.quantity;
    if (newGrossWeight != null && newTareWeight != null) {
      newQuantity = newGrossWeight - newTareWeight;
    }

    // Apply deduction
    double? newDeductionAmount;
    double finalQuantity = newQuantity;
    if (newDeductionPercentage != null && newDeductionPercentage > 0) {
      newDeductionAmount = newQuantity * (newDeductionPercentage / 100);
      finalQuantity = newQuantity - newDeductionAmount;
    }

    final newTotalAmount = finalQuantity * newPricePerKg;

    return copyWith(
      bags: newBags,
      quantity: finalQuantity,
      pricePerKg: newPricePerKg,
      totalAmount: newTotalAmount,
      grossWeight: newGrossWeight,
      tareWeight: newTareWeight,
      deductionPercentage: newDeductionPercentage,
      deductionAmount: newDeductionAmount,
    );
  }

  /// Parse helpers
  static ItemType _parseItemType(dynamic value) {
    if (value == null) return ItemType.paddy;
    if (value is ItemType) return value;
    return value.toString().toLowerCase() == 'rice' 
        ? ItemType.rice 
        : ItemType.paddy;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

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

  /// Display helpers
  String get displayItemType => itemType == ItemType.paddy ? 'Paddy' : 'Rice';
  String get displayItemTypeSi => itemType == ItemType.paddy ? 'වී' : 'සහල්';

  String get formattedQuantity => '${quantity.toStringAsFixed(2)} kg';
  String get formattedPricePerKg => 'Rs. ${pricePerKg.toStringAsFixed(2)}';
  String get formattedTotalAmount => 'Rs. ${totalAmount.toStringAsFixed(2)}';

  double get averageWeightPerBag => bags > 0 ? quantity / bags : 0;

  /// Check if has deductions
  bool get hasDeductions => 
      deductionPercentage != null && deductionPercentage! > 0;

  /// Check if has moisture info
  bool get hasMoistureInfo => moisturePercentage != null;

  @override
  List<Object?> get props => [
        id,
        transactionId,
        inventoryItemId,
        itemType,
        variety,
        bags,
        quantity,
        pricePerKg,
        totalAmount,
      ];

  @override
  String toString() => 
      'TransactionItemModel(id: $id, type: ${itemType.name}, variety: $variety, qty: $quantity kg, total: $totalAmount)';

  /// Backwards-compatible getters used by older code
  String get displayName => variety;
  double get weightKg => quantity;
  int get bagCount => bags;
  double get amount => totalAmount;
  String get itemName => variety;

  // Getters used by widgets
  double get totalWeight => quantity;
  double get totalPrice => totalAmount;
}
