import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/bloc/auth_bloc.dart';
import '../core/bloc/auth_state.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/courier_register_screen.dart';
import '../screens/auth/vendor_register_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/category/categories_screen.dart';
import '../screens/category/category_products_screen.dart';
import '../screens/product/product_detail_screen.dart';
import '../screens/cart/cart_screen.dart';
import '../screens/checkout/checkout_screen.dart';
import '../screens/orders/orders_screen.dart';
import '../screens/orders/order_tracking_screen.dart';
import '../screens/wishlist/wishlist_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/account/account_screen.dart';
import '../screens/account/edit_profile_screen.dart';
import '../screens/account/addresses/addresses_screen.dart';
import '../screens/account/addresses/add_edit_address_screen.dart';
import '../screens/vendor/my_products_screen.dart';
import '../screens/vendor/vendor_product_form_screen.dart';
import '../screens/vendor/vendor_profile_screen.dart';
import '../screens/vendor/orders/vendor_orders_screen.dart';
import '../screens/vendor/orders/vendor_order_tracking_screen.dart';
import '../screens/driver/driver_dashboard_screen.dart';
import '../screens/driver/driver_task_detail_screen.dart';
import '../screens/driver/driver_earnings_screen.dart';

const _protectedRoutes = <String>{
  '/cart',
  '/checkout',
  '/orders',
  '/wishlist',
  '/account',
  '/addresses',
  '/my-products',
  '/my-products/new',
  '/vendor-orders',
  '/driver',
  '/driver/earnings',
  '/notifications',
};

const _vendorOnlyRoutes = <String>{
  '/my-products/new',
  '/vendor-orders',
};

const _driverOnlyRoutes = <String>{
  '/driver',
  '/driver/earnings',
};

bool _isProtectedRoute(String location) {
  final path = Uri.parse(location).path;
  if (_protectedRoutes.contains(path)) return true;
  if (path.startsWith('/order/')) return true;
  if (path.startsWith('/my-products/') && path.endsWith('/edit')) return true;
  if (path.startsWith('/driver/task/')) return true;
  if (path.startsWith('/vendor-order/')) return true;
  return false;
}

bool _isVendorOnlyRoute(String location) {
  final path = Uri.parse(location).path;
  if (_vendorOnlyRoutes.contains(path)) return true;
  if (path.startsWith('/my-products/') && path.endsWith('/edit')) return true;
  if (path.startsWith('/vendor-order/')) return true;
  return false;
}

bool _isDriverOnlyRoute(String location) {
  final path = Uri.parse(location).path;
  if (_driverOnlyRoutes.contains(path)) return true;
  if (path.startsWith('/driver/task/')) return true;
  return false;
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final authState = context.read<AuthBloc>().state;
    final isLoggedIn = authState is Authenticated;
    final isOnLogin = state.matchedLocation == '/login';

    if (!isLoggedIn && _isProtectedRoute(state.matchedLocation)) {
      return '/login';
    }

    if (isLoggedIn && isOnLogin) {
      final user = (authState as Authenticated).user;
      if (user.role == 'vendor') return '/vendor-orders';
      if (user.role == 'courier') return '/driver';
      return '/';
    }

    // Vendor-only route guard
    if (isLoggedIn && _isVendorOnlyRoute(state.matchedLocation)) {
      if (authState is! Authenticated || authState.user.role != 'vendor') {
        return '/';
      }
    }

    // Driver-only route guard
    if (isLoggedIn && _isDriverOnlyRoute(state.matchedLocation)) {
      if (authState is! Authenticated || authState.user.role != 'courier') {
        return '/';
      }
    }

    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
    GoRoute(path: '/register/courier', builder: (_, __) => const CourierRegisterScreen()),
    GoRoute(path: '/register/vendor', builder: (_, __) => const VendorRegisterScreen()),
    GoRoute(path: '/categories', builder: (_, __) => const CategoriesScreen()),
    GoRoute(
      path: '/categories/:id',
      builder: (_, state) => CategoryProductsScreen(
        categoryId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/product/:id',
      builder: (_, state) => ProductDetailScreen(
        productId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/store/:id',
      builder: (_, state) => VendorProfileScreen(
        storeId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(path: '/cart', builder: (_, __) => const CartScreen()),
    GoRoute(path: '/checkout', builder: (_, __) => const CheckoutScreen()),
    GoRoute(path: '/orders', builder: (_, __) => const OrdersScreen()),
    GoRoute(
      path: '/order/:id',
      builder: (_, state) => OrderTrackingScreen(
        orderId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(path: '/wishlist', builder: (_, __) => const WishlistScreen()),
    GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
    GoRoute(path: '/my-products', builder: (_, __) => const MyProductsScreen()),
    GoRoute(
      path: '/my-products/new',
      builder: (_, __) => const VendorProductFormScreen(),
    ),
    GoRoute(
      path: '/my-products/:id/edit',
      builder: (_, state) => VendorProductFormScreen(
        productId: int.parse(state.pathParameters['id']!),
      ),
    ),
    // Vendor Orders routes
    GoRoute(path: '/vendor-orders', builder: (_, __) => const VendorOrdersScreen()),
    GoRoute(
      path: '/vendor-order/:id',
      builder: (_, state) => VendorOrderTrackingScreen(
        orderId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(path: '/account', builder: (_, __) => const AccountScreen()),
    GoRoute(path: '/account/edit-profile', builder: (_, __) => const EditProfileScreen()),
    GoRoute(path: '/addresses', builder: (_, __) => const AddressesScreen()),
    GoRoute(path: '/account/add-address', builder: (_, __) => const AddEditAddressScreen()),
    GoRoute(
      path: '/account/edit-address/:id',
      builder: (_, state) => AddEditAddressScreen(
        addressId: int.parse(state.pathParameters['id']!),
      ),
    ),
    // Driver routes
    GoRoute(path: '/driver', builder: (_, __) => const DriverDashboardScreen()),
    GoRoute(path: '/driver/earnings', builder: (_, __) => const DriverEarningsScreen()),
    GoRoute(
      path: '/driver/task/:id',
      builder: (_, state) => DriverTaskDetailScreen(
        taskId: state.pathParameters['id']!,
      ),
    ),
  ],
);