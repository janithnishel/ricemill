// lib/domain/entities/customer_entity.dart

import 'package:equatable/equatable.dart';
import '../../core/constants/enums.dart';

/// Customer Entity - Core business representation of a customer
/// Represents both buyers (we sell to them) and sellers (we buy from them)
class CustomerEntity extends Equatable {
  final String id;
  final String name;
  final String phone;
  final String? address;
  final CustomerType type;
  final double balance; // + means they owe us, - means we owe them
  final bool isActive;

  const CustomerEntity({
    required this.id,
    required this.name,
    required this.phone,
    this.address,
    this.type = CustomerType.farmer,
    this.balance = 0,
    this.isActive = true,
  });

  /// Check if customer is a farmer (paddy seller)
  bool get isFarmer => type == CustomerType.farmer;

  /// Check if customer is a trader (buys and sells)
  bool get isTrader => type == CustomerType.trader;

  /// Check if customer is a retailer (rice buyer)
  bool get isRetailer => type == CustomerType.retailer;

  /// Check if customer is a wholesaler (bulk buyer)
  bool get isWholesaler => type == CustomerType.wholesaler;

  /// Check if customer has outstanding balance
  bool get hasOutstandingBalance => balance != 0;

  /// Check if customer owes us money (positive balance)
  bool get customerOwesUs => balance > 0;

  /// Check if we owe the customer money (negative balance)
  bool get weOweCustomer => balance < 0;

  /// Get absolute balance amount
  double get absoluteBalance => balance.abs();

  /// Get formatted balance
  String get formattedBalance {
    final prefix = balance >= 0 ? '' : '-';
    return '${prefix}Rs. ${absoluteBalance.toStringAsFixed(2)}';
  }

  /// Get balance status text
  String get balanceStatus {
    if (balance == 0) return 'Settled';
    if (customerOwesUs) return 'Receivable';
    return 'Payable';
  }

  /// Get balance status text in Sinhala
  String get balanceStatusSinhala {
    if (balance == 0) return 'ගෙවා අවසන්';
    if (customerOwesUs) return 'ලබාගත යුතු';
    return 'ගෙවිය යුතු';
  }

  /// Get customer type display name
  String get typeDisplayName {
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

  /// Get customer type display name in Sinhala
  String get typeDisplayNameSinhala {
    switch (type) {
      case CustomerType.farmer:
        return 'ගොවියා';
      case CustomerType.trader:
        return 'වෙළඳුනා';
      case CustomerType.retailer:
        return 'සිල්ලර වෙළඳුනා';
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

  /// Get user initials for avatar fallback
  String get initials {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return 'C';

    final parts = trimmedName.split(' ');
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmedName[0].toUpperCase();
  }

  /// Get formatted phone number
  String get formattedPhone {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanPhone.length == 10) {
      // Sri Lankan mobile format: XXX XXX XXXX
      return '${cleanPhone.substring(0, 3)} ${cleanPhone.substring(3, 6)} ${cleanPhone.substring(6)}';
    } else if (cleanPhone.length == 9) {
      // Alternative format for 9 digits
      return '${cleanPhone.substring(0, 3)} ${cleanPhone.substring(3, 6)} ${cleanPhone.substring(6)}';
    } else if (cleanPhone.length >= 11 && cleanPhone.length <= 12) {
      // International format or landline with country code
      if (cleanPhone.startsWith('94') && cleanPhone.length == 11) {
        // Sri Lankan international format: +94 XX XXX XXXX
        final local = cleanPhone.substring(2);
        return '+94 ${local.substring(0, 2)} ${local.substring(2, 5)} ${local.substring(5)}';
      }
      // Return as-is for other international formats
      return cleanPhone;
    }
    // Return original for unrecognized formats
    return phone;
  }

  /// Get short address (first line or limited characters)
  String get shortAddress {
    if (address == null || address!.isEmpty) return '';
    final firstLine = address!.split('\n').first;
    if (firstLine.length <= 30) return firstLine;
    return '${firstLine.substring(0, 27)}...';
  }

  /// Check if customer can be used for buying transactions
  bool get canBuyFrom => isFarmer || isTrader;

  /// Check if customer can be used for selling transactions
  bool get canSellTo => isRetailer || isWholesaler || isTrader;

  /// Create a copy with updated fields
  CustomerEntity copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    CustomerType? type,
    double? balance,
    bool? isActive,
  }) {
    return CustomerEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Create an empty customer entity
  factory CustomerEntity.empty() {
    return const CustomerEntity(
      id: '',
      name: '',
      phone: '',
    );
  }

  /// Check if entity is empty/invalid
  bool get isEmpty => id.isEmpty;
  bool get isNotEmpty => id.isNotEmpty;

  /// Validate customer data
  CustomerValidationResult validate() {
    final errors = <String, String>{};

    if (name.trim().isEmpty) {
      errors['name'] = 'Name is required';
    } else if (name.trim().length < 2) {
      errors['name'] = 'Name must be at least 2 characters';
    }

    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanPhone.isEmpty) {
      errors['phone'] = 'Phone is required';
    } else if (cleanPhone.length < 9 || cleanPhone.length > 12) {
      errors['phone'] = 'Invalid phone number';
    }

    return CustomerValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        phone,
        address,
        type,
        balance,
        isActive,
      ];

  @override
  String toString() {
    return 'CustomerEntity(id: $id, name: $name, phone: $phone, type: $type, balance: $balance)';
  }
}

/// Customer validation result
class CustomerValidationResult {
  final bool isValid;
  final Map<String, String> errors;

  const CustomerValidationResult({
    required this.isValid,
    this.errors = const {},
  });

  String? getError(String field) => errors[field];

  bool hasError(String field) => errors.containsKey(field);
}
