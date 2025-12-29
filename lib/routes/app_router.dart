import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

// Core
import '../core/theme/app_colors.dart';

// Features - Auth
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';

// Features - Home
import '../features/home/presentation/screens/main_wrapper_screen.dart';
import '../features/home/presentation/screens/dashboard_screen.dart';

// Features - Buy
import '../features/buy/presentation/screens/buy_wrapper_screen.dart';
import '../features/buy/presentation/screens/buy_screen.dart';
import '../features/buy/presentation/screens/add_customer_screen.dart';
import '../features/buy/presentation/screens/add_stock_screen.dart';

// Features - Sell
import '../features/sell/presentation/screens/sell_wrapper_screen.dart';
import '../features/sell/presentation/screens/sell_screen.dart';

// Features - Stock
import '../features/stock/presentation/screens/stock_screen.dart';
import '../features/stock/presentation/screens/milling_screen.dart';

// Features - Customers
import '../features/customers/presentation/screens/customers_list_screen.dart';
import '../features/customers/presentation/screens/customer_detail_screen.dart';

// Features - Reports
import '../features/reports/presentation/screens/reports_screen.dart';
import '../features/reports/presentation/screens/daily_report_screen.dart';
import '../features/reports/presentation/screens/monthly_report_screen.dart';

// Features - Profile
import '../features/profile/presentation/screens/profile_screen.dart';

// Features - Super Admin
import '../features/super_admin/presentation/screens/admin_dashboard_screen.dart';
import '../features/super_admin/presentation/screens/companies_screen.dart';
import '../features/super_admin/presentation/screens/add_company_screen.dart';

// Routes
import 'route_names.dart';
import 'route_guards.dart';

// Injection
import '../injection_container.dart';

/// Global navigator key
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');
final GlobalKey<NavigatorState> _buyShellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'buyShell');
final GlobalKey<NavigatorState> _sellShellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'sellShell');
final GlobalKey<NavigatorState> _adminShellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'adminShell');

/// App Router configuration
class AppRouter {
  final AuthGuard _authGuard;

  AppRouter({required AuthGuard authGuard}) : _authGuard = authGuard;

  late final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: RouteNames.splash,
    debugLogDiagnostics: true,
    observers: [AppRouteObserver()],
    
    // Global redirect for authentication
    redirect: (context, state) => authRedirect(context, state, _authGuard),
    
    // Error page
    errorBuilder: (context, state) => ErrorScreen(error: state.error),
    
    routes: [
      // ==================== Auth Routes ====================
      GoRoute(
        path: RouteNames.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),

      // ==================== Main App Routes ====================
      GoRoute(
        path: RouteNames.home,
        name: 'home',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: RouteNames.stock,
        name: 'stock',
        builder: (context, state) => const StockScreen(),
        routes: [
          GoRoute(
            path: 'detail/:id',
            name: 'stockDetail',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return StockDetailScreen(stockId: id);
            },
          ),
          GoRoute(
            path: 'edit/:id',
            name: 'stockEdit',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return StockEditScreen(stockId: id);
            },
          ),
          GoRoute(
            path: 'milling',
            name: 'milling',
            builder: (context, state) => const MillingScreen(),
          ),
        ],
      ),
      GoRoute(
        path: RouteNames.reports,
        name: 'reports',
        builder: (context, state) => const ReportsScreen(),
        routes: [
          GoRoute(
            path: 'daily',
            name: 'dailyReport',
            builder: (context, state) => const DailyReportScreen(),
          ),
          GoRoute(
            path: 'monthly',
            name: 'monthlyReport',
            builder: (context, state) => const MonthlyReportScreen(),
          ),
        ],
      ),
      GoRoute(
        path: RouteNames.profile,
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),

      // ==================== Buy Routes ====================
      GoRoute(
        path: RouteNames.buy,
        name: 'buy',
        builder: (context, state) => const BuyScreen(),
      ),
      GoRoute(
        path: RouteNames.buyAddCustomer,
        name: 'buyAddCustomer',
        builder: (context, state) => const AddCustomerScreen(),
      ),
      GoRoute(
        path: RouteNames.buyAddStock,
        name: 'buyAddStock',
        builder: (context, state) => const AddStockScreen(),
      ),

      // Buy Receipt (Full Screen)
      GoRoute(
        path: '${RouteNames.buyReceipt}/:id',
        name: 'buyReceipt',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return BuyReceiptScreen(transactionId: id);
        },
      ),

      // ==================== Sell Routes ====================
      GoRoute(
        path: RouteNames.sell,
        name: 'sell',
        builder: (context, state) => const SellScreen(),
      ),

      // Sell Receipt (Full Screen)
      GoRoute(
        path: '${RouteNames.sellReceipt}/:id',
        name: 'sellReceipt',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return SellReceiptScreen(transactionId: id);
        },
      ),

      // ==================== Customers Routes ====================
      GoRoute(
        path: RouteNames.customers,
        name: 'customers',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CustomersListScreen(),
        routes: [
          GoRoute(
            path: 'add',
            name: 'customerAdd',
            builder: (context, state) => const CustomerAddScreen(),
          ),
          GoRoute(
            path: 'detail/:id',
            name: 'customerDetail',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return CustomerDetailScreen(customerId: id);
            },
          ),
          GoRoute(
            path: 'edit/:id',
            name: 'customerEdit',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return CustomerEditScreen(customerId: id);
            },
          ),
        ],
      ),

      // ==================== Super Admin Routes ====================
      GoRoute(
        path: RouteNames.adminDashboard,
        name: 'adminDashboard',
        redirect: (context, state) => superAdminRedirect(context, state, _authGuard),
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: RouteNames.adminCompanies,
        name: 'adminCompanies',
        redirect: (context, state) => superAdminRedirect(context, state, _authGuard),
        builder: (context, state) => const CompaniesScreen(),
        routes: [
          GoRoute(
            path: 'add',
            name: 'adminCompanyAdd',
            builder: (context, state) => const AddCompanyScreen(),
          ),
          GoRoute(
            path: ':id',
            name: 'adminCompanyDetail',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return CompanyDetailScreen(companyId: id);
            },
          ),
          GoRoute(
            path: 'edit/:id',
            name: 'adminCompanyEdit',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return AddCompanyScreen(companyId: id);
            },
          ),
        ],
      ),

      // ==================== Settings Route ====================
      GoRoute(
        path: RouteNames.settings,
        name: 'settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
}

// ==================== Placeholder Screens ====================
// These should be replaced with actual implementations

class ErrorScreen extends StatelessWidget {
  final Exception? error;

  const ErrorScreen({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
        backgroundColor: AppColors.error,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              const Text(
                'Oops! Something went wrong',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                error?.toString() ?? 'Page not found',
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go(RouteNames.home),
                child: const Text('Go to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StockDetailScreen extends StatelessWidget {
  final String stockId;
  const StockDetailScreen({super.key, required this.stockId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Stock Detail: $stockId')),
      body: Center(child: Text('Stock ID: $stockId')),
    );
  }
}

class StockEditScreen extends StatelessWidget {
  final String stockId;
  const StockEditScreen({super.key, required this.stockId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit Stock: $stockId')),
      body: Center(child: Text('Edit Stock ID: $stockId')),
    );
  }
}

class BuyReceiptScreen extends StatelessWidget {
  final String transactionId;
  const BuyReceiptScreen({super.key, required this.transactionId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buy Receipt')),
      body: Center(child: Text('Transaction ID: $transactionId')),
    );
  }
}

class SellReceiptScreen extends StatelessWidget {
  final String transactionId;
  const SellReceiptScreen({super.key, required this.transactionId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sell Receipt')),
      body: Center(child: Text('Transaction ID: $transactionId')),
    );
  }
}

class CustomerAddScreen extends StatelessWidget {
  const CustomerAddScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Customer')),
      body: const Center(child: Text('Add Customer Form')),
    );
  }
}

class CustomerEditScreen extends StatelessWidget {
  final String customerId;
  const CustomerEditScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Customer')),
      body: Center(child: Text('Customer ID: $customerId')),
    );
  }
}

class CompanyDetailScreen extends StatelessWidget {
  final String companyId;
  const CompanyDetailScreen({super.key, required this.companyId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Company Detail')),
      body: Center(child: Text('Company ID: $companyId')),
    );
  }
}

class AdminWrapperScreen extends StatelessWidget {
  final Widget child;
  const AdminWrapperScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _getSelectedIndex(context),
        onDestinationSelected: (index) => _onDestinationSelected(context, index),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.adminPrimary.withOpacity(0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.business_outlined),
            selectedIcon: Icon(Icons.business),
            label: 'Companies',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/admin/companies')) return 1;
    if (location.startsWith('/admin/reports')) return 2;
    if (location.startsWith('/admin/settings')) return 3;
    return 0;
  }

  void _onDestinationSelected(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(RouteNames.adminDashboard);
        break;
      case 1:
        context.go(RouteNames.adminCompanies);
        break;
      case 2:
        context.go(RouteNames.adminReports);
        break;
      case 3:
        context.go(RouteNames.adminSettings);
        break;
    }
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(child: Text('Settings Screen')),
    );
  }
}
