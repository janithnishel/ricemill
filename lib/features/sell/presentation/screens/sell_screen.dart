// lib/features/sell/presentation/screens/sell_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/shared_widgets/custom_keyboard/custom_keyboard.dart';
import '../../../../core/shared_widgets/custom_keyboard/keyboard_controller.dart';
import '../../../../core/shared_widgets/loading_overlay.dart';
import '../../../../core/shared_widgets/empty_state_widget.dart';
import '../../../../data/models/customer_model.dart';
import '../cubit/sell_cubit.dart';
import '../cubit/sell_state.dart';
import '../widgets/stock_selector.dart';
import '../widgets/sell_items_table.dart';
import '../widgets/sell_summary_card.dart';

class SellScreen extends StatefulWidget {
  const SellScreen({super.key});

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _bagsController = TextEditingController();
  final FocusNode _quantityFocus = FocusNode();
  final FocusNode _priceFocus = FocusNode();

  late final KeyboardController _quantityKeyboardController;
  late final KeyboardController _priceKeyboardController;

  String _activeField = 'quantity';

  @override
  void initState() {
    super.initState();
    context.read<SellCubit>().initialize();
    _bagsController.text = '1';
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _bagsController.dispose();
    _quantityFocus.dispose();
    _priceFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SellCubit, SellState>(
      listener: (context, state) {
        // Update controllers when stock item is selected
        if (state.selectedStockItem != null) {
          _priceController.text = state.inputPrice > 0 
              ? state.inputPrice.toStringAsFixed(2) 
              : '';
          _quantityController.text = '';
        }
        
        // Clear controllers when item is added
        if (state.successMessage == 'Item added successfully') {
          _quantityController.clear();
          _priceController.clear();
          _bagsController.text = '1';
        }
      },
      builder: (context, state) {
        return LoadingOverlay(
          isLoading: state.status == SellStatus.processing,
          child: _buildContent(context, state),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, SellState state) {
    switch (state.currentStep) {
      case SellStep.selectCustomer:
        return _buildCustomerSelection(context, state);
      case SellStep.selectItems:
        return _buildItemSelection(context, state);
      case SellStep.review:
        return _buildReview(context, state);
      case SellStep.complete:
        return _buildComplete(context, state);
    }
  }

  // Step 1: Customer Selection
  Widget _buildCustomerSelection(BuildContext context, SellState state) {
    return Column(
      children: [
          // Search bar
        Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          child: TextField(
            onChanged: (value) => context.read<SellCubit>().searchCustomers(value),
            decoration: InputDecoration(
              hintText: 'Search customer by name or phone...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusM),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
          ),
        ),

        // Customer list
        Expanded(
          child: state.filteredCustomers.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.people_outline,
                  title: 'No Customers Found',
                  subtitle: 'Add a new customer or try different search',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingM,
                  ),
                  itemCount: state.filteredCustomers.length,
                  itemBuilder: (context, index) {
                    final customer = state.filteredCustomers[index];
                    return _CustomerCard(
                      customer: customer,
                      onTap: () => context.read<SellCubit>().selectCustomer(customer),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // Step 2: Item Selection
  Widget _buildItemSelection(BuildContext context, SellState state) {
    return Column(
      children: [
        // Selected customer bar
        _buildSelectedCustomerBar(context, state),
        
        // Main content
        Expanded(
          child: Row(
            children: [
              // Left side: Stock selector
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    // Stock selector
                    Expanded(
                      child: StockSelector(
                        availableStock: state.availableStock,
                        selectedItem: state.selectedStockItem,
                        onItemSelected: (item) {
                          context.read<SellCubit>().selectStockItem(item);
                        },
                      ),
                    ),
                    
                    // Input section
                    if (state.selectedStockItem != null)
                      _buildInputSection(context, state),
                  ],
                ),
              ),
              
              // Right side: Cart
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: Border(
                      left: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Cart header
                      Container(
                      padding: const EdgeInsets.all(AppDimensions.paddingM),
                        color: AppColors.primary.withOpacity(0.1),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Cart Items',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (state.sellItems.isNotEmpty)
                              TextButton(
                                onPressed: () {
                                  context.read<SellCubit>().clearAllItems();
                                },
                                child: const Text(
                                  'Clear All',
                                  style: TextStyle(color: AppColors.error),
                                ),
                              ),
                          ],
                        ),
                      ),
                      
                      // Cart items
                      Expanded(
                        child: SellItemsTable(
                          items: state.sellItems,
                          onEdit: (item) => _showEditDialog(context, item),
                          onRemove: (itemId) {
                            context.read<SellCubit>().removeItem(itemId);
                          },
                        ),
                      ),
                      
                      // Summary card
                      SellSummaryCard(
                        totalItems: state.sellItems.length,
                        totalWeight: state.grandTotalWeight,
                        totalBags: state.grandTotalBags,
                        totalAmount: state.grandTotal,
                        onCheckout: state.canFinalize
                            ? () => context.read<SellCubit>().goToReview()
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedCustomerBar(BuildContext context, SellState state) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingS),
      color: AppColors.primary.withOpacity(0.1),
      child: Row(
        children: [
          const Icon(Icons.person, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.selectedCustomer?.name ?? 'No Customer Selected',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  state.selectedCustomer?.phone ?? '',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => context.read<SellCubit>().clearCustomer(),
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: const Text('Change'),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection(BuildContext context, SellState state) {
    final stockItem = state.selectedStockItem!;
    
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected item info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: stockItem.type == 'rice' 
                      ? AppColors.riceColor 
                      : AppColors.paddyColor,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                ),
                child: Text(
                  stockItem.type.name.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${stockItem.itemName} - ${stockItem.variety}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                'Available: ${stockItem.currentQuantity.toStringAsFixed(2)} kg',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppDimensions.paddingM),
          
          // Input fields row
          Row(
            children: [
              // Bags input
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bags',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _bagsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              
              // Quantity input
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Weight (kg)',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _quantityController,
                      focusNode: _quantityFocus,
                      readOnly: true,
                      onTap: () {
                        setState(() => _activeField = 'quantity');
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: _activeField == 'quantity' 
                                ? AppColors.primary 
                                : Colors.grey,
                            width: _activeField == 'quantity' ? 2 : 1,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        suffixText: 'kg',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              
              // Price input
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Price/kg',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _priceController,
                      focusNode: _priceFocus,
                      readOnly: true,
                      onTap: () {
                        setState(() => _activeField = 'price');
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: _activeField == 'price' 
                                ? AppColors.primary 
                                : Colors.grey,
                            width: _activeField == 'price' ? 2 : 1,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        prefixText: 'Rs.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              
              // Total display
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Rs. ${state.currentItemTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppDimensions.paddingM),

          // TODO: Implement Custom Keyboard with proper KeyboardController
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(AppDimensions.radiusM),
            ),
            child: const Center(
              child: Text('Custom Keyboard - To be implemented'),
            ),
          ),
        ],
      ),
    );
  }

  void _handleKeyPress(BuildContext context, String key) {
    final cubit = context.read<SellCubit>();
    
    if (_activeField == 'quantity') {
      final currentValue = _quantityController.text;
      final newValue = currentValue + key;
      _quantityController.text = newValue;
      cubit.updateQuantity(double.tryParse(newValue) ?? 0);
    } else if (_activeField == 'price') {
      final currentValue = _priceController.text;
      final newValue = currentValue + key;
      _priceController.text = newValue;
      cubit.updatePrice(double.tryParse(newValue) ?? 0);
    }
  }

  void _handleDelete(BuildContext context) {
    final cubit = context.read<SellCubit>();
    
    if (_activeField == 'quantity') {
      if (_quantityController.text.isNotEmpty) {
        final newValue = _quantityController.text.substring(
          0,
          _quantityController.text.length - 1,
        );
        _quantityController.text = newValue;
        cubit.updateQuantity(double.tryParse(newValue) ?? 0);
      }
    } else if (_activeField == 'price') {
      if (_priceController.text.isNotEmpty) {
        final newValue = _priceController.text.substring(
          0,
          _priceController.text.length - 1,
        );
        _priceController.text = newValue;
        cubit.updatePrice(double.tryParse(newValue) ?? 0);
      }
    }
  }

  void _handleClear(BuildContext context) {
    final cubit = context.read<SellCubit>();
    
    if (_activeField == 'quantity') {
      _quantityController.clear();
      cubit.updateQuantity(0);
    } else if (_activeField == 'price') {
      _priceController.clear();
      cubit.updatePrice(0);
    }
  }

  void _showEditDialog(BuildContext context, SellItemEntry item) {
    final quantityController = TextEditingController(
      text: item.quantity.toStringAsFixed(2),
    );
    final priceController = TextEditingController(
      text: item.pricePerKg.toStringAsFixed(2),
    );
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${item.itemName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity (kg)',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Price per kg',
                prefixText: 'Rs. ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final quantity = double.tryParse(quantityController.text);
              final price = double.tryParse(priceController.text);
              
              if (quantity != null && price != null) {
                context.read<SellCubit>().editItem(
                  item.id,
                  quantity: quantity,
                  price: price,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  // Step 3: Review
  Widget _buildReview(BuildContext context, SellState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: const Icon(Icons.person, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.selectedCustomer?.name ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          state.selectedCustomer?.phone ?? '',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: AppDimensions.paddingM),

          // Items list
          const Text(
            'Order Items',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          Card(
            child: Column(
              children: state.sellItems.map((item) {
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: item.itemType == 'rice'
                          ? AppColors.riceColor.withOpacity(0.1)
                          : AppColors.paddyColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      item.itemType == 'rice' ? Icons.rice_bowl : Icons.grass,
                      color: item.itemType == 'rice'
                          ? AppColors.riceColor
                          : AppColors.paddyColor,
                    ),
                  ),
                  title: Text(item.itemName),
                  subtitle: Text(
                    '${item.bags} bags • ${item.quantity.toStringAsFixed(2)} kg × Rs.${item.pricePerKg.toStringAsFixed(2)}',
                  ),
                  trailing: Text(
                    'Rs.${item.totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: AppDimensions.paddingM),

          // Summary
          Card(
            color: AppColors.primary.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Column(
                children: [
                  _buildSummaryRow('Total Items', '${state.sellItems.length}'),
                  _buildSummaryRow('Total Bags', '${state.grandTotalBags}'),
                  _buildSummaryRow(
                    'Total Weight',
                    '${state.grandTotalWeight.toStringAsFixed(2)} kg',
                  ),
                  const Divider(),
                  _buildSummaryRow(
                    'Grand Total',
                    'Rs.${state.grandTotal.toStringAsFixed(2)}',
                    isTotal: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingL),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.read<SellCubit>().goBackToItems(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Back to Edit'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => context.read<SellCubit>().finalizeSale(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Confirm & Generate Invoice',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 24 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isTotal ? AppColors.primary : null,
            ),
          ),
        ],
      ),
    );
  }

  // Step 4: Complete
  Widget _buildComplete(BuildContext context, SellState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 80,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Sale Completed!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Invoice: ${state.generatedInvoiceId}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Rs.${state.grandTotal.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 32),
            
            // Sync status
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: state.isSynced
                    ? AppColors.success.withOpacity(0.1)
                    : AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    state.isSynced ? Icons.cloud_done : Icons.cloud_off,
                    color: state.isSynced ? AppColors.success : AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    state.isSynced ? 'Synced to cloud' : 'Pending sync',
                    style: TextStyle(
                      color: state.isSynced ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => context.read<SellCubit>().printReceipt(),
                  icon: const Icon(Icons.print),
                  label: const Text('Print'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () => context.read<SellCubit>().shareReceipt(),
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            TextButton(
              onPressed: () => context.read<SellCubit>().resetForNewSale(),
              child: const Text(
                'Start New Sale',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Customer Card Widget
class _CustomerCard extends StatelessWidget {
  final CustomerModel customer;
  final VoidCallback onTap;

  const _CustomerCard({
    required this.customer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: Text(
            customer.name[0].toUpperCase(),
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          customer.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(customer.phone),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
