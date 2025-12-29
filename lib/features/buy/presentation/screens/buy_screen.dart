// lib/features/buy/presentation/screens/buy_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/shared_widgets/loading_overlay.dart';
import '../../../../core/shared_widgets/confirmation_dialog.dart';
import '../cubit/buy_cubit.dart';
import '../cubit/buy_state.dart';
import '../widgets/customer_selector.dart';
import '../widgets/item_selector.dart';
import '../widgets/temp_items_table.dart';
import '../widgets/weight_input_widget.dart';
import '../widgets/buy_summary_card.dart';
import '../widgets/price_input_dialog.dart';

class BuyScreen extends StatefulWidget {
  const BuyScreen({super.key});

  @override
  State<BuyScreen> createState() => _BuyScreenState();
}

class _BuyScreenState extends State<BuyScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BuyCubit, BuyState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.errorMessage != current.errorMessage ||
          previous.editingItemIndex != current.editingItemIndex,
      listener: (context, state) {
        // Handle errors
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.read<BuyCubit>().clearError();
        }

        // Show price input dialog
        if (state.editingItemIndex != null) {
          _showPriceInputDialog(context, state);
        }

        // Handle success
        if (state.status == BuyStatus.success) {
          _showSuccessDialog(context, state);
        }
      },
      builder: (context, state) {
        return LoadingOverlay(
          isLoading: state.isProcessing,
          message: 'Processing transaction...',
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: _buildAppBar(state),
            body: _buildBody(state),
            bottomNavigationBar: state.status == BuyStatus.reviewing
                ? _buildReviewBottomBar(state)
                : null,
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuyState state) {
    String title;
    String subtitle;

    switch (state.status) {
      case BuyStatus.reviewing:
        title = 'Review Order';
        subtitle = 'ඇණවුම සමාලෝචනය';
        break;
      case BuyStatus.success:
        title = 'Order Complete';
        subtitle = 'ඇණවුම සම්පූර්ණයි';
        break;
      default:
        title = 'Buy / Purchase';
        subtitle = 'මිලදී ගැනීම';
    }

    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.white),
        onPressed: () {
          if (state.status == BuyStatus.reviewing) {
            context.read<BuyCubit>().backToAddingItems();
          } else if (state.hasItems) {
            _showExitConfirmation(context);
          } else {
            context.pop();
          }
        },
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            subtitle,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
      actions: [
        if (state.hasItems && state.status != BuyStatus.reviewing)
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.white),
            onPressed: () => _showClearConfirmation(context),
            tooltip: 'Clear all',
          ),
      ],
    );
  }

  Widget _buildBody(BuyState state) {
    if (state.status == BuyStatus.reviewing) {
      return _buildReviewScreen(state);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Customer Selector
          CustomerSelector(
            selectedCustomer: state.selectedCustomer,
            onCustomerSelected: (customer) {
              context.read<BuyCubit>().selectCustomer(customer);
            },
            onAddNewCustomer: () {
              // Navigate to add customer tab
              context.go('/buy/add-customer');
            },
          ),
          const SizedBox(height: 20),

          // Item Selector
          if (state.selectedCustomer != null) ...[
            ItemSelector(
              selectedType: state.selectedItemType,
              selectedVariety: state.selectedVariety,
              onTypeChanged: (type) {
                context.read<BuyCubit>().selectItemType(type);
              },
              onVarietyChanged: (variety) {
                context.read<BuyCubit>().selectItemType(state.selectedItemType!, variety: variety);
              },
            ),
            const SizedBox(height: 20),
          ],

          // Weight Input
          if (state.selectedVariety != null) ...[
            WeightInputWidget(
              entries: state.currentBagWeights.map((weight) => WeightEntry(id: 'w_${DateTime.now().millisecondsSinceEpoch}', weight: weight)).toList(),
              onEntriesChanged: (entries) {
                final weights = entries.map((e) => e.weight).toList();
                context.read<BuyCubit>().updateWeight(weights.fold(0.0, (sum, w) => sum + w));
                // TODO: Update bag count and weights in state
              },
            ),
            const SizedBox(height: 20),
          ],

          // Temporary Items Table
          if (state.tempItems.isNotEmpty) ...[
            // TODO: Implement TempItemsTable with correct API
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text('Items: ${state.tempItems.length}'),
                  Text('Total: Rs. ${state.totalAmount.toStringAsFixed(2)}'),
                  ElevatedButton(
                    onPressed: () {
                      // TODO: Implement proceed to review
                    },
                    child: const Text('Proceed to Review'),
                  ),
                ],
              ),
            ),
          ],

          // Empty state
          if (state.tempItems.isEmpty && state.selectedCustomer != null)
            _buildEmptyItemsHint(),

          const SizedBox(height: 100), // Bottom padding for nav bar
        ],
      ),
    );
  }

  Widget _buildEmptyItemsHint() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.shopping_basket_outlined,
            size: 48,
            color: AppColors.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'No items added yet',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select item type and variety above, then add bag weights',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewScreen(BuyState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Customer info card
          _buildCustomerInfoCard(state),
          const SizedBox(height: 16),

          // Items summary
          _buildItemsSummaryCard(state),
          const SizedBox(height: 16),

          // Payment details
          _buildPaymentCard(state),
          const SizedBox(height: 16),

          // Additional info
          _buildAdditionalInfoCard(state),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildCustomerInfoCard(BuyState state) {
    return Container(
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.person,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.selectedCustomer!.name,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  state.selectedCustomer!.formattedPhone,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (state.selectedCustomer!.address != null)
                  Text(
                    state.selectedCustomer!.address!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textHint,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSummaryCard(BuyState state) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Items (${state.tempItems.length})',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${state.totalBags} bags | ${state.totalWeight.toStringAsFixed(2)} kg',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ...state.tempItems.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: item.itemType == ItemType.paddy
                            ? AppColors.warning.withOpacity(0.1)
                            : AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        item.itemType == ItemType.paddy
                            ? Icons.grass
                            : Icons.rice_bowl,
                        color: item.itemType == ItemType.paddy
                            ? AppColors.warning
                            : AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.displayName,
                            style: AppTextStyles.titleSmall,
                          ),
                          Text(
                            '${item.bagsCount} bags × ${item.formattedWeight} @ ${item.formattedPrice}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      item.formattedTotal,
                      style: AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal',
                style: AppTextStyles.titleMedium,
              ),
              Text(
                state.formattedSubtotal,
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(BuyState state) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Details',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Discount input
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Discount (Rs.)',
                    prefixIcon: Icon(Icons.discount),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final discount = double.tryParse(value) ?? 0;
                    // TODO: context.read<BuyCubit>().updateDiscount(discount);
                  },
                ),
              ),
              const SizedBox(width: 12),
              const Text('OR'),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Discount (%)',
                    suffixText: '%',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final percentage = double.tryParse(value) ?? 0;
                    // TODO: context.read<BuyCubit>().updateDiscountPercentage(percentage);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Payment method
          DropdownButtonFormField<PaymentMethod>(
            decoration: const InputDecoration(
              labelText: 'Payment Method',
              prefixIcon: Icon(Icons.payment),
            ),
            value: state.paymentMethod,
            items: PaymentMethod.values.map((method) {
              return DropdownMenuItem(
                value: method,
                child: Text(method.name.toUpperCase()),
              );
            }).toList(),
            onChanged: (method) {
              if (method != null) {
                // TODO: context.read<BuyCubit>().updatePaymentMethod(method);
              }
            },
          ),
          const SizedBox(height: 16),

          // Paid amount
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Paid Amount',
                    prefixIcon: Icon(Icons.payments),
                    prefixText: 'Rs. ',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final amount = double.tryParse(value) ?? 0;
                    // TODO: context.read<BuyCubit>().updatePaidAmount(amount);
                  },
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  // TODO: context.read<BuyCubit>().setFullPayment();
                },
                child: const Text('Full'),
              ),
            ],
          ),

          const Divider(height: 32),

          // Summary
          _buildSummaryRow('Subtotal', state.formattedSubtotal),
          if (state.calculatedDiscount > 0)
            _buildSummaryRow(
              'Discount',
              '- ${state.formattedDiscount}',
              valueColor: AppColors.success,
            ),
          _buildSummaryRow(
            'Total',
            state.formattedTotal,
            isTotal: true,
          ),
          _buildSummaryRow('Paid', state.formattedPaid),
          _buildSummaryRow(
            'Due',
            state.formattedDue,
            valueColor: state.dueAmount > 0 ? AppColors.error : AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    Color? valueColor,
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isTotal
                ? AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)
                : AppTextStyles.bodyMedium,
          ),
          Text(
            value,
            style: (isTotal
                    ? AppTextStyles.titleLarge
                    : AppTextStyles.titleSmall)
                .copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfoCard(BuyState state) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Additional Information',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Vehicle Number',
              prefixIcon: Icon(Icons.local_shipping),
              hintText: 'e.g., WP ABC-1234',
            ),
            onChanged: (value) {
              // TODO: context.read<BuyCubit>().updateVehicleNumber(value);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Notes',
              prefixIcon: Icon(Icons.note),
              hintText: 'Additional notes...',
            ),
            maxLines: 3,
            onChanged: (value) {
              // TODO: context.read<BuyCubit>().updateNotes(value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReviewBottomBar(BuyState state) {
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
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Amount',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    state.formattedTotal,
                    style: AppTextStyles.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: state.isProcessing
                    ? null
                    : () {
                        context.read<BuyCubit>().completeBuyTransaction();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle),
                    const SizedBox(width: 8),
                    Text(
                      'Complete',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPriceInputDialog(BuildContext context, BuyState state) {
    if (state.editingItemIndex == null) return;
    final item = state.tempItems[state.editingItemIndex!];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PriceInputDialog(
        itemType: item.itemType,
        variety: item.variety,
        totalWeight: item.totalWeight,
        bags: item.bagsCount,
        initialPrice: item.pricePerKg,
        // TODO: Add proper callbacks
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, BuyState state) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: AppColors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Transaction Complete!',
              style: AppTextStyles.headlineSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Transaction #${state.createdTransactionNumber}',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.read<BuyCubit>().resetForNewTransaction();
                    },
                    child: const Text('New Transaction'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // TODO: Generate and show PDF
                      context.read<BuyCubit>().resetForNewTransaction();
                    },
                    child: const Text('Print Bill'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showExitConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Discard Transaction?',
        message: 'You have unsaved items. Are you sure you want to go back?',
        confirmLabel: 'Discard',
        cancelLabel: 'Stay',
        isDangerous: true,
        onConfirm: () {
          Navigator.pop(context);
          context.read<BuyCubit>().resetForNewTransaction();
          context.pop();
        },
      ),
    );
  }

  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Clear All Items?',
        message: 'This will remove all items from the current transaction.',
        confirmLabel: 'Clear',
        cancelLabel: 'Cancel',
        isDangerous: true,
        onConfirm: () {
          Navigator.pop(context);
          context.read<BuyCubit>().resetForNewTransaction();
        },
      ),
    );
  }
}
