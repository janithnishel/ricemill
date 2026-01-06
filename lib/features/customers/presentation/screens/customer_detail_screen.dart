// lib/features/customers/presentation/screens/customer_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/shared_widgets/confirmation_dialog.dart';
import '../../../../core/shared_widgets/loading_overlay.dart';
import '../../../../core/constants/enums.dart';
import '../../../../routes/route_names.dart';
import '../../../../data/models/customer_model.dart';
import '../../../../domain/entities/customer_entity.dart';
import '../cubit/customers_cubit.dart';
import '../cubit/customers_state.dart';

class CustomerDetailScreen extends StatefulWidget {
  final String customerId;

  const CustomerDetailScreen({
    super.key,
    required this.customerId,
  });

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Load customer detail
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomersCubit>().loadCustomerDetail(widget.customerId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CustomersCubit, CustomersState>(
      listenWhen: (previous, current) =>
          previous.formStatus != current.formStatus,
      listener: (context, state) {
        if (state.formStatus == CustomerFormStatus.success) {
          if (state.formSuccessMessage?.contains('deleted') == true) {
            if (GoRouter.of(context).canPop()) {
              context.pop();
            } else {
              context.go(RouteNames.customers);
            }
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.formSuccessMessage ?? 'Success'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state.detailStatus == CustomerDetailStatus.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (state.detailStatus == CustomerDetailStatus.error ||
            state.selectedCustomer == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Customer')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    state.errorMessage ?? 'Customer not found',
                    style: AppTextStyles.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      if (GoRouter.of(context).canPop()) {
                        context.pop();
                      } else {
                        context.go(RouteNames.customers);
                      }
                    },
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        final customer = state.selectedCustomer!;

        return LoadingOverlay(
          isLoading: state.isSubmitting,
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                _buildAppBar(customer),
                _buildQuickStats(customer),
                _buildTabBar(),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildInfoTab(customer),
                  _buildTransactionsTab(state),
                  _buildBalanceTab(customer),
                ],
              ),
            ),
            bottomNavigationBar: _buildBottomActions(customer),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(CustomerEntity customer) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: _getTypeColor(customer.type),
      foregroundColor: AppColors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _getTypeColor(customer.type),
                _getTypeColor(customer.type).withOpacity(0.8),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Avatar
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        customer.initials,
                        style: AppTextStyles.headlineMedium.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Name
                  Text(
                    customer.name,
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  
                  // Type badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      customer.typeDisplayName,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => _editCustomer(customer),
          tooltip: 'Edit',
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            switch (value) {
              case 'delete':
                _deleteCustomer(customer);
                break;
              case 'share':
                _shareCustomer(customer);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  Icon(Icons.share),
                  SizedBox(width: 12),
                  Text('Share'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: AppColors.error),
                  SizedBox(width: 12),
                  Text('Delete', style: TextStyle(color: AppColors.error)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickStats(CustomerEntity customer) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(AppDimensions.paddingMedium),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildStatItem(
                icon: Icons.account_balance_wallet,
                label: 'Balance',
                value: customer.formattedBalance,
                valueColor: customer.balance >= 0
                    ? AppColors.success
                    : AppColors.error,
              ),
            ),
            Container(
              width: 1,
              height: 50,
              color: AppColors.divider,
            ),
            Expanded(
              child: _buildStatItem(
                icon: Icons.receipt_long,
                label: 'Transactions',
                value: '0', // Will be updated with actual count
              ),
            ),
            Container(
              width: 1,
              height: 50,
              color: AppColors.divider,
            ),
            Expanded(
              child: _buildStatItem(
                icon: Icons.timeline,
                label: 'Status',
                value: customer.balanceStatus,
                valueColor: _getBalanceStatusColor(customer.balance),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: AppTextStyles.titleSmall.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _TabBarDelegate(
        child: Container(
          color: AppColors.background,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'Info'),
              Tab(text: 'Transactions'),
              Tab(text: 'Balance'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTab(CustomerEntity customer) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Contact Info Card
          _buildInfoCard(
            title: 'Contact Information',
            icon: Icons.contact_phone,
            children: [
              _buildInfoRow(
                icon: Icons.phone,
                label: 'Phone',
                value: customer.formattedPhone,
                onTap: () => _callCustomer(customer.phone),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.call, color: AppColors.success),
                      onPressed: () => _callCustomer(customer.phone),
                      iconSize: 20,
                    ),
                    IconButton(
                      icon: const Icon(Icons.message, color: AppColors.info),
                      onPressed: () => _messageCustomer(customer.phone),
                      iconSize: 20,
                    ),
                  ],
                ),
              ),
              if (customer.address != null && customer.address!.isNotEmpty)
                _buildInfoRow(
                  icon: Icons.location_on,
                  label: 'Address',
                  value: customer.address!,
                  onTap: () => _copyToClipboard(customer.address!),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Type Info Card
          _buildInfoCard(
            title: 'Customer Type',
            icon: Icons.category,
            children: [
              _buildInfoRow(
                icon: _getTypeIcon(customer.type),
                label: 'Type',
                value: customer.typeDisplayName,
              ),
              _buildInfoRow(
                icon: Icons.info,
                label: 'Type (Sinhala)',
                value: customer.typeDisplayNameSinhala,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Business Info Card
          _buildInfoCard(
            title: 'Business Summary',
            icon: Icons.business,
            children: [
              _buildInfoRow(
                icon: Icons.shopping_cart,
                label: 'Can Buy From',
                value: customer.canBuyFrom ? 'Yes' : 'No',
                valueColor: customer.canBuyFrom
                    ? AppColors.success
                    : AppColors.error,
              ),
              _buildInfoRow(
                icon: Icons.sell,
                label: 'Can Sell To',
                value: customer.canSellTo ? 'Yes' : 'No',
                valueColor: customer.canSellTo
                    ? AppColors.success
                    : AppColors.error,
              ),
              _buildInfoRow(
                icon: Icons.check_circle,
                label: 'Status',
                value: customer.isActive ? 'Active' : 'Inactive',
                valueColor: customer.isActive
                    ? AppColors.success
                    : AppColors.error,
              ),
            ],
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: valueColor ?? AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsTab(CustomersState state) {
    if (state.customerTransactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              'No transactions yet',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      itemCount: state.customerTransactions.length,
      itemBuilder: (context, index) {
        final transaction = state.customerTransactions[index];
        return _buildTransactionCard(transaction);
      },
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final type = transaction['type'] as String? ?? 'buy';
    final isBuy = type.toLowerCase() == 'buy';
    final amount = (transaction['amount'] as num?)?.toDouble() ?? 0;
    final date = transaction['date'] != null
        ? DateTime.parse(transaction['date'].toString())
        : DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isBuy ? AppColors.error : AppColors.success)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isBuy ? Icons.arrow_downward : Icons.arrow_upward,
              color: isBuy ? AppColors.error : AppColors.success,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBuy ? 'Purchase' : 'Sale',
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  DateFormat('MMM d, yyyy').format(date),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Rs. ${amount.toStringAsFixed(2)}',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: isBuy ? AppColors.error : AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceTab(CustomerEntity customer) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      child: Column(
        children: [
          // Balance Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: customer.balance >= 0
                    ? [AppColors.success, AppColors.success.withOpacity(0.8)]
                    : [AppColors.error, AppColors.error.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (customer.balance >= 0
                          ? AppColors.success
                          : AppColors.error)
                      .withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Current Balance',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  customer.formattedBalance,
                  style: AppTextStyles.displaySmall.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    customer.balanceStatus,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Balance explanation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.info.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.info),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    customer.customerOwesUs
                        ? 'This customer owes you Rs. ${customer.absoluteBalance.toStringAsFixed(2)}'
                        : customer.weOweCustomer
                            ? 'You owe this customer Rs. ${customer.absoluteBalance.toStringAsFixed(2)}'
                            : 'This customer has no outstanding balance',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.info,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action buttons
          if (customer.hasOutstandingBalance) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _recordPayment(customer),
                icon: const Icon(Icons.payments),
                label: Text(
                  customer.customerOwesUs
                      ? 'Record Payment Received'
                      : 'Record Payment Made',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomActions(CustomerEntity customer) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (customer.canBuyFrom)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _createBuyTransaction(customer),
                icon: const Icon(Icons.shopping_cart),
                label: const Text('Buy'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          if (customer.canBuyFrom && customer.canSellTo)
            const SizedBox(width: 12),
          if (customer.canSellTo)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _createSellTransaction(customer),
                icon: const Icon(Icons.sell),
                label: const Text('Sell'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Helper methods
  Color _getTypeColor(CustomerType type) {
    switch (type) {
      case CustomerType.farmer:
        return AppColors.success;
      case CustomerType.trader:
        return AppColors.info;
      case CustomerType.retailer:
        return AppColors.warning;
      case CustomerType.wholesaler:
        return AppColors.primary;
      case CustomerType.buyer:
        return AppColors.info;
      case CustomerType.seller:
        return AppColors.success;
      case CustomerType.both:
        return AppColors.warning;
      case CustomerType.other:
        return AppColors.textSecondary;
    }
  }

  IconData _getTypeIcon(CustomerType type) {
    switch (type) {
      case CustomerType.farmer:
        return Icons.agriculture;
      case CustomerType.trader:
        return Icons.swap_horiz;
      case CustomerType.retailer:
        return Icons.store;
      case CustomerType.wholesaler:
        return Icons.warehouse;
      case CustomerType.buyer:
        return Icons.shopping_bag;
      case CustomerType.seller:
        return Icons.sell;
      case CustomerType.both:
        return Icons.business;
      case CustomerType.other:
        return Icons.person;
    }
  }

  Color _getBalanceStatusColor(double balance) {
    if (balance > 0) return AppColors.success;
    if (balance < 0) return AppColors.error;
    return AppColors.textSecondary;
  }

  void _callCustomer(String phone) {
    debugPrint('Calling $phone');
  }

  void _messageCustomer(String phone) {
    debugPrint('Messaging $phone');
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _editCustomer(CustomerEntity customer) {
    context.push('/customers/${customer.id}/edit');
  }

  Future<void> _deleteCustomer(CustomerEntity customer) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete Customer?',
      message: 'Are you sure you want to delete ${customer.name}? This action cannot be undone.',
      confirmLabel: 'Delete',
      isDangerous: true,
      icon: Icons.delete_outline,
    );

    if (confirmed && mounted) {
      context.read<CustomersCubit>().deleteCustomer(customer.id);
    }
  }

  void _shareCustomer(CustomerEntity customer) {
    debugPrint('Sharing ${customer.name}');
  }

  void _recordPayment(CustomerEntity customer) {
    debugPrint('Recording payment for ${customer.name}');
  }

  void _createBuyTransaction(CustomerEntity customer) {
    context.push('/buy', extra: {'customerId': customer.id});
  }

  void _createSellTransaction(CustomerEntity customer) {
    context.push('/sell', extra: {'customerId': customer.id});
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _TabBarDelegate({required this.child});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  double get maxExtent => 48;

  @override
  double get minExtent => 48;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}
