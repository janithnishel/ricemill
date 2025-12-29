// TODO: Implement AdminRepository interface
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../data/models/company_model.dart';
// import '../../../../domain/repositories/admin_repository.dart';
import 'admin_state.dart';

class AdminCubit extends Cubit<AdminState> {
  // final AdminRepository _adminRepository;
  final _uuid = const Uuid();

  AdminCubit() : super(const AdminState());

  /// Load dashboard data
  Future<void> loadDashboard() async {
    emit(state.copyWith(status: AdminStatus.loading));

    try {
      // TODO: Implement AdminRepository
      await Future.delayed(const Duration(seconds: 1)); // Mock delay
      final companies = <CompanyModel>[]; // Mock data
      final stats = AdminDashboardStats.fromCompanies(companies);
      emit(state.copyWith(
        status: AdminStatus.loaded,
        allCompanies: companies,
        filteredCompanies: companies,
        dashboardStats: stats,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AdminStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Load all companies
  Future<void> loadCompanies() async {
    emit(state.copyWith(status: AdminStatus.loading));

    try {
      // TODO: Implement AdminRepository
      await Future.delayed(const Duration(seconds: 1)); // Mock delay
      final companies = <CompanyModel>[]; // Mock data
      emit(state.copyWith(
        status: AdminStatus.loaded,
        allCompanies: companies,
        filteredCompanies: _applyFilters(companies, state.currentFilter, state.searchQuery),
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AdminStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Refresh companies
  Future<void> refreshCompanies() async {
    emit(state.copyWith(isRefreshing: true));
    await loadCompanies();
    emit(state.copyWith(isRefreshing: false));
  }

  /// Filter companies by status
  void filterCompanies(CompanyFilter filter) {
    final filtered = _applyFilters(state.allCompanies, filter, state.searchQuery);
    emit(state.copyWith(
      currentFilter: filter,
      filteredCompanies: filtered,
    ));
  }

  /// Search companies
  void searchCompanies(String query) {
    final filtered = _applyFilters(state.allCompanies, state.currentFilter, query);
    emit(state.copyWith(
      searchQuery: query,
      filteredCompanies: filtered,
    ));
  }

  /// Apply filters and search
  List<CompanyModel> _applyFilters(
    List<CompanyModel> companies,
    CompanyFilter filter,
    String query,
  ) {
    var filtered = companies;

    // Apply status filter
    switch (filter) {
      case CompanyFilter.active:
        filtered = filtered.where((c) => c.status == CompanyStatus.active).toList();
        break;
      case CompanyFilter.inactive:
        filtered = filtered.where((c) => c.status == CompanyStatus.inactive).toList();
        break;
      case CompanyFilter.pending:
        filtered = filtered.where((c) => c.status == CompanyStatus.pending).toList();
        break;
      case CompanyFilter.all:
        break;
    }

    // Apply search query
    if (query.isNotEmpty) {
      filtered = filtered.where((c) {
        final searchLower = query.toLowerCase();
        return c.name.toLowerCase().contains(searchLower) ||
            (c.ownerName?.toLowerCase().contains(searchLower) ?? false) ||
            (c.email?.toLowerCase().contains(searchLower) ?? false) ||
            c.phone.contains(query) ||
            (c.address?.toLowerCase().contains(searchLower) ?? false);
      }).toList();
    }

    return filtered;
  }

  /// Select a company for viewing/editing
  void selectCompany(CompanyModel company) {
    emit(state.copyWith(selectedCompany: company));
  }

  /// Clear selected company
  void clearSelectedCompany() {
    emit(state.copyWith(clearSelectedCompany: true));
  }

  /// Create new company
  Future<bool> createCompany({
    required String name,
    required String ownerName,
    required String email,
    required String phone,
    required String password,
    String? address,
    String? registrationNumber,
    String? logoUrl,
  }) async {
    emit(state.copyWith(status: AdminStatus.creating));

    try {
      // TODO: Implement AdminRepository
      await Future.delayed(const Duration(seconds: 1)); // Mock delay

      final company = CompanyModel(
        id: _uuid.v4(),
        name: name,
        ownerName: ownerName,
        email: email,
        phone: phone,
        address: address ?? '',
        registrationNumber: registrationNumber,
        logoUrl: logoUrl,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final updatedList = [...state.allCompanies, company];
      emit(state.copyWith(
        status: AdminStatus.success,
        allCompanies: updatedList,
        filteredCompanies: _applyFilters(updatedList, state.currentFilter, state.searchQuery),
        successMessage: 'Company "${company.name}" created successfully!',
      ));
      return true;
    } catch (e) {
      emit(state.copyWith(
        status: AdminStatus.error,
        errorMessage: e.toString(),
      ));
      return false;
    }
  }

  /// Update company details
  Future<bool> updateCompany(CompanyModel company) async {
    emit(state.copyWith(status: AdminStatus.updating));

    try {
      // TODO: Implement AdminRepository
      await Future.delayed(const Duration(seconds: 1)); // Mock delay
      final updatedCompany = company.copyWith(updatedAt: DateTime.now());
      final updatedList = state.allCompanies.map((c) {
        return c.id == company.id ? updatedCompany : c;
      }).toList();

      emit(state.copyWith(
        status: AdminStatus.success,
        allCompanies: updatedList,
        filteredCompanies: _applyFilters(updatedList, state.currentFilter, state.searchQuery),
        selectedCompany: updatedCompany,
        successMessage: 'Company updated successfully!',
      ));
      return true;
    } catch (e) {
      emit(state.copyWith(
        status: AdminStatus.error,
        errorMessage: e.toString(),
      ));
      return false;
    }
  }

  /// Update company status
  Future<bool> updateCompanyStatus(String companyId, CompanyStatus newStatus) async {
    emit(state.copyWith(status: AdminStatus.updating));

    try {
      // TODO: Implement AdminRepository
      await Future.delayed(const Duration(seconds: 1)); // Mock delay
      final updatedList = state.allCompanies.map((c) {
        return c.id == companyId
            ? c.copyWith(status: newStatus, updatedAt: DateTime.now())
            : c;
      }).toList();

      emit(state.copyWith(
        status: AdminStatus.success,
        allCompanies: updatedList,
        filteredCompanies: _applyFilters(updatedList, state.currentFilter, state.searchQuery),
        successMessage: 'Company status updated to ${newStatus.displayName}!',
      ));
      return true;
    } catch (e) {
      emit(state.copyWith(
        status: AdminStatus.error,
        errorMessage: e.toString(),
      ));
      return false;
    }
  }

  /// Delete company
  Future<bool> deleteCompany(String companyId) async {
    emit(state.copyWith(status: AdminStatus.deleting));

    try {
      // TODO: Implement AdminRepository
      await Future.delayed(const Duration(seconds: 1)); // Mock delay
      final updatedList = state.allCompanies.where((c) => c.id != companyId).toList();

      emit(state.copyWith(
        status: AdminStatus.success,
        allCompanies: updatedList,
        filteredCompanies: _applyFilters(updatedList, state.currentFilter, state.searchQuery),
        clearSelectedCompany: true,
        successMessage: 'Company deleted successfully!',
      ));
      return true;
    } catch (e) {
      emit(state.copyWith(
        status: AdminStatus.error,
        errorMessage: e.toString(),
      ));
      return false;
    }
  }

  /// Reset company password
  Future<bool> resetCompanyPassword(String companyId, String newPassword) async {
    try {
      // TODO: Implement AdminRepository
      await Future.delayed(const Duration(seconds: 1)); // Mock delay
      emit(state.copyWith(successMessage: 'Password reset successfully!'));
      return true;
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
      return false;
    }
  }

  /// Get company by ID
  CompanyModel? getCompanyById(String id) {
    try {
      return state.allCompanies.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Clear messages
  void clearMessages() {
    emit(state.copyWith(clearMessages: true));
  }

  /// Clear error
  void clearError() {
    emit(state.copyWith(errorMessage: null));
  }
}
