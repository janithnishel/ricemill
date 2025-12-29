import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../core/errors/failures.dart';
import '../../../core/constants/enums.dart';
import '../../../data/models/customer_model.dart';
import '../../entities/customer_entity.dart';
import '../../repositories/customer_repository.dart';
import '../usecase.dart';

// lib/domain/usecases/customer/add_customer_usecase.dart

/// Add customer use case
/// Creates a new customer (buyer/seller)
class AddCustomerUseCase implements UseCase<CustomerEntity, AddCustomerParams> {
  final CustomerRepository repository;

  AddCustomerUseCase({required this.repository});

  @override
  Future<Either<Failure, CustomerEntity>> call(AddCustomerParams params) async {
    // Validate inputs
    if (params.name.trim().isEmpty) {
      return Left(ValidationFailure(message: 'Customer name is required'));
    }

    if (params.phone.trim().isEmpty) {
      return Left(ValidationFailure(message: 'Phone number is required'));
    }

    if (params.phone.length < 10) {
      return Left(ValidationFailure(message: 'Invalid phone number'));
    }

    // Check if customer with same phone already exists
    final existingResult = await repository.getCustomerByPhone(params.phone);

    return existingResult.fold(
      (failure) async {
        // Customer doesn't exist, proceed to create
        final customer = CustomerModel.create(
          name: params.name.trim(),
          phone: params.phone.trim(),
          email: params.email?.trim(),
          address: params.address?.trim(),
          nicNumber: params.nic?.trim(),
          type: params.customerType,
          companyId: 'current_company_id', // This should be injected or passed
          notes: params.notes?.trim(),
        );
        return await repository.addCustomer(customer);
      },
      (existingCustomer) {
        // Customer already exists
        return Left(DatabaseFailure.duplicateEntry());
      },
    );
  }
}

/// Parameters for adding a new customer
class AddCustomerParams extends Equatable {
  final String name;
  final String phone;
  final String? email;
  final String? address;
  final CustomerType customerType;
  final String? nic;
  final String? notes;

  const AddCustomerParams({
    required this.name,
    required this.phone,
    this.email,
    this.address,
    this.customerType = CustomerType.both,
    this.nic,
    this.notes,
  });

  @override
  List<Object?> get props => [
        name,
        phone,
        email,
        address,
        customerType,
        nic,
        notes,
      ];
}

/// Update customer use case
class UpdateCustomerUseCase implements UseCase<CustomerEntity, UpdateCustomerParams> {
  final CustomerRepository repository;

  UpdateCustomerUseCase({required this.repository});

  @override
  Future<Either<Failure, CustomerEntity>> call(UpdateCustomerParams params) async {
    if (params.id.isEmpty) {
      return Left(ValidationFailure(message: 'Customer ID is required'));
    }

    // For update, we need to get the full CustomerModel
    // Since repository only returns CustomerEntity, we'll need to modify this approach
    // For now, let's create a basic update by getting existing data and creating new model
    // This is a temporary solution - ideally the repository should provide update with individual params

    // Get existing customer entity
    final existingResult = await repository.getCustomerById(params.id);
    return existingResult.fold(
      (failure) => Left(failure),
      (existingCustomer) async {
        // Create CustomerModel from entity with updated fields
        // This assumes we have a way to convert - for now using placeholder values
        final existingModel = CustomerModel.fromEntity(existingCustomer, 'current_company_id');

        final updatedCustomer = existingModel.copyWith(
          name: params.name,
          phone: params.phone,
          email: params.email,
          address: params.address,
          nicNumber: params.nic,
          type: params.customerType,
          notes: params.notes,
          updatedAt: DateTime.now(),
          isSynced: false,
        );

        return await repository.updateCustomer(updatedCustomer);
      },
    );
  }
}

/// Parameters for updating a customer
class UpdateCustomerParams extends Equatable {
  final String id;
  final String? name;
  final String? phone;
  final String? email;
  final String? address;
  final CustomerType? customerType;
  final String? nic;
  final String? notes;

  const UpdateCustomerParams({
    required this.id,
    this.name,
    this.phone,
    this.email,
    this.address,
    this.customerType,
    this.nic,
    this.notes,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        phone,
        email,
        address,
        customerType,
        nic,
        notes,
      ];
}
