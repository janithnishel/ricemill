import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/shared_widgets/sync_status_indicator.dart';
import '../../../../core/shared_widgets/empty_state_widget.dart';
import '../../../../core/shared_widgets/loading_overlay.dart';
import '../../../../core/sync/sync_status.dart';
import '../cubit/stock_cubit.dart';
import '../cubit/stock_state.dart';
import '../widgets/stock_filter.dart';
import '../widgets/stock_item_card.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  @override
  void initState() {
    super.initState();
    context.read<StockCubit>().loadStock();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: BlocConsumer<StockCubit, StockState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: AppColors.error,
              ),
            );
            context.read<StockCubit>().clearError();
          }
        },
        builder: (context, state) {
          return LoadingOverlay(
            isLoading: state.status == StockStatus.loading,
            child: RefreshIndicator(
              onRefresh: () => context.read<StockCubit>().refreshStock(),
              color: AppColors.primary,
              child: CustomScrollView(
                slivers: [
                  // Summary Cards
                  SliverToBoxAdapter(
                    child: _buildSummarySection(state),
                  ),

                  // Filter Section
                  SliverToBoxAdapter(
                    child: StockFilter(
                      selectedFilter: state.filterType,
                      searchQuery: state.searchQuery,
                      onFilterChanged: (filter) {
                        context.read<StockCubit>().filterByType(filter);
                      },
                      onSearchChanged: (query) {
                        context.read<StockCubit>().searchStock(query);
                      },
                    ),
                  ),

                  // Stock Items List
                  if (state.filteredItems.isEmpty)
                    SliverFillRemaining(
                      child: EmptyStateWidget(
                        icon: Icons.inventory_2_outlined,
                        title: 'No Stock Found',
                        subtitle: state.searchQuery.isNotEmpty
                            ? 'No items match your search'
                            : 'Add stock to get started',
                        actionLabel: 'Add Stock',
                        onAction: () => context.push('/buy/add-stock'),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(AppDimensions.paddingM),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = state.filteredItems[index];
                            return Padding(
                              padding: const EdgeInsets.only(
                                  bottom: AppDimensions.paddingS),
                              child: StockItemCard(
                                item: item,
                                onTap: () => _showItemDetails(item),
                                onEdit: () => _editItem(item),
                              ),
                            );
                          },
                          childCount: state.filteredItems.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/stock/milling'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.settings_suggest, color: Colors.white),
        label: const Text(
          'Milling',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('Stock Inventory'),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        BlocBuilder<StockCubit, StockState>(
          builder: (context, state) {
            return SyncStatusIndicator(
              status: state.isSynced
                  ? SyncStatusModel.success()
                  : SyncStatusModel.idle(),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => context.push('/buy/add-stock'),
          tooltip: 'Add Stock',
        ),
      ],
    );
  }

  Widget _buildSummarySection(StockState state) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              title: 'Paddy Stock',
              weightKg: state.totalPaddyKg,
              bags: state.totalPaddyBags,
              color: AppColors.paddyColor,
              icon: Icons.grass,
            ),
          ),
          const SizedBox(width: AppDimensions.paddingM),
          Expanded(
            child: _buildSummaryCard(
              title: 'Rice Stock',
              weightKg: state.totalRiceKg,
              bags: state.totalRiceBags,
              color: AppColors.riceColor,
              icon: Icons.rice_bowl,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required double weightKg,
    required int bags,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingM),
          Text(
            '${weightKg.toStringAsFixed(1)} kg',
            style: AppTextStyles.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$bags Bags',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showItemDetails(dynamic item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ItemDetailsSheet(item: item),
    );
  }

  void _editItem(dynamic item) {
    // Navigate to edit screen
    context.push('/stock/edit/${item.id}');
  }
}

class _ItemDetailsSheet extends StatelessWidget {
  final dynamic item;

  const _ItemDetailsSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.paddingL),
          Text(
            item.name,
            style: AppTextStyles.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppDimensions.paddingM),
          _buildDetailRow('Type', item.itemType.toString().split('.').last),
          _buildDetailRow('Weight', '${item.totalWeightKg.toStringAsFixed(2)} kg'),
          _buildDetailRow('Bags', '${item.totalBags}'),
          _buildDetailRow('Price/kg', 'Rs. ${item.pricePerKg.toStringAsFixed(2)}'),
          _buildDetailRow('Last Updated', _formatDate(item.updatedAt)),
          const SizedBox(height: AppDimensions.paddingL),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    // Handle adjustment
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Adjust Stock'),
                ),
              ),
              const SizedBox(width: AppDimensions.paddingM),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/sell');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  icon: const Icon(Icons.sell, color: Colors.white),
                  label: const Text('Sell', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingM),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          Text(value, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
