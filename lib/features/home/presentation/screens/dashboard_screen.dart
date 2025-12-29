// lib/features/home/presentation/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/shared_widgets/sync_status_indicator.dart';
import '../../../../core/sync/sync_status.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../cubit/dashboard_cubit.dart';
import '../cubit/dashboard_state.dart';
import '../widgets/action_card.dart';
import '../widgets/summary_card.dart';
import '../widgets/recent_transactions.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: RefreshIndicator(
            onRefresh: () => context.read<DashboardCubit>().refreshDashboard(),
            color: AppColors.primary,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // App Bar
                _buildAppBar(state),

                // Content
                SliverPadding(
                  padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Sync Status
                      if (!state.isSynced) _buildSyncBanner(state),

                      // Quick Actions - Buy & Sell
                      _buildQuickActions(),
                      const SizedBox(height: 20),

                      // Today's Summary
                      _buildSectionTitle('Today\'s Summary', 'අද දින සාරාංශය'),
                      const SizedBox(height: 12),
                      _buildTodaySummary(state),
                      const SizedBox(height: 20),

                      // Stock Overview
                      _buildSectionTitle('Stock Overview', 'තොග දළ විශ්ලේෂණය'),
                      const SizedBox(height: 12),
                      _buildStockOverview(state),
                      const SizedBox(height: 20),

                      // Monthly Summary
                      _buildSectionTitle('This Month', 'මෙම මාසය'),
                      const SizedBox(height: 12),
                      _buildMonthlySummary(state),
                      const SizedBox(height: 20),

                      // Recent Transactions
                      _buildSectionTitle(
                        'Recent Transactions',
                        'මෑත ගනුදෙනු',
                        onViewAll: () => context.push('/reports'),
                      ),
                      const SizedBox(height: 12),
                      RecentTransactions(
                        transactions: state.recentTransactions,
                        isLoading: state.isLoading,
                      ),

                      // Bottom padding
                      const SizedBox(height: 100),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(DashboardState state) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primaryDark,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  BlocBuilder<AuthCubit, AuthState>(
                    builder: (context, authState) {
                      return Row(
                        children: [
                          // Avatar
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                authState.user?.initials ?? 'U',
                                style: AppTextStyles.titleMedium.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Greeting
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  state.greeting,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.white.withOpacity(0.8),
                                  ),
                                ),
                                Text(
                                  authState.user?.name ?? 'User',
                                  style: AppTextStyles.titleMedium.copyWith(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Sync indicator
                          SyncStatusIndicator(
                            status: SyncStatusModel.idle(
                              pendingCount: state.pendingSyncCount,
                              lastSyncTime: state.lastSyncTime,
                            ),
                            onTap: () {
                              context.read<DashboardCubit>().syncData();
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: AppColors.white),
          onPressed: () {
            // TODO: Show notifications
          },
        ),
      ],
    );
  }

  Widget _buildSyncBanner(DashboardState state) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: AppColors.warning, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${state.pendingSyncCount} items pending sync',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.warning,
              ),
            ),
          ),
          TextButton(
            onPressed: () => context.read<DashboardCubit>().syncData(),
            child: const Text('Sync Now'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: ActionCard(
            title: 'Buy',
            subtitle: 'මිලදී ගැනීම',
            icon: Icons.shopping_cart,
            color: AppColors.success,
            onTap: () => context.push('/buy'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ActionCard(
            title: 'Sell',
            subtitle: 'විකිණීම',
            icon: Icons.sell,
            color: AppColors.info,
            onTap: () => context.push('/sell'),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(
    String title,
    String subtitle, {
    VoidCallback? onViewAll,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        if (onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('View All'),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward, size: 16),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTodaySummary(DashboardState state) {
    return Row(
      children: [
        Expanded(
          child: SummaryCard(
            title: 'Purchases',
            value: state.formattedTodayPurchases,
            subtitle: '${state.todayBuyCount} transactions',
            icon: Icons.arrow_downward,
            iconColor: AppColors.error,
            backgroundColor: AppColors.error.withOpacity(0.1),
            isLoading: state.isLoading,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SummaryCard(
            title: 'Sales',
            value: state.formattedTodaySales,
            subtitle: '${state.todaySellCount} transactions',
            icon: Icons.arrow_upward,
            iconColor: AppColors.success,
            backgroundColor: AppColors.success.withOpacity(0.1),
            isLoading: state.isLoading,
          ),
        ),
      ],
    );
  }

  Widget _buildStockOverview(DashboardState state) {
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
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStockItem(
                  'Paddy',
                  'වී',
                  state.formattedPaddyStock,
                  Icons.grass,
                  AppColors.warning,
                  state.isLoading,
                ),
              ),
              Container(
                width: 1,
                height: 60,
                color: AppColors.divider,
              ),
              Expanded(
                child: _buildStockItem(
                  'Rice',
                  'සහල්',
                  state.formattedRiceStock,
                  Icons.rice_bowl,
                  AppColors.primary,
                  state.isLoading,
                ),
              ),
            ],
          ),
          if (state.hasLowStock) ...[
            const Divider(height: 24),
            InkWell(
              onTap: () => context.push('/stock'),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.warning_amber,
                      color: AppColors.warning,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${state.lowStockCount} items low on stock',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward,
                      color: AppColors.warning,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStockItem(
    String title,
    String subtitle,
    String value,
    IconData icon,
    Color color,
    bool isLoading,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            subtitle,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 4),
          if (isLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Text(
              value,
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMonthlySummary(DashboardState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMonthlyItem(
                'Purchases',
                state.formattedMonthlyPurchases,
                Icons.arrow_downward,
                state.isLoading,
              ),
              _buildMonthlyItem(
                'Sales',
                state.formattedMonthlySales,
                Icons.arrow_upward,
                state.isLoading,
              ),
              _buildMonthlyItem(
                'Profit',
                state.formattedMonthlyProfit,
                Icons.trending_up,
                state.isLoading,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  '${state.monthlyBuyCount}',
                  'Buy Orders',
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: AppColors.white.withOpacity(0.3),
                ),
                _buildStatItem(
                  '${state.monthlySellCount}',
                  'Sell Orders',
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: AppColors.white.withOpacity(0.3),
                ),
                _buildStatItem(
                  '${state.totalCustomers}',
                  'Customers',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyItem(
    String label,
    String value,
    IconData icon,
    bool isLoading,
  ) {
    return Column(
      children: [
        Icon(icon, color: AppColors.white.withOpacity(0.7), size: 18),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.white.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 4),
        if (isLoading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
            ),
          )
        else
          Text(
            value,
            style: AppTextStyles.titleSmall.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}
