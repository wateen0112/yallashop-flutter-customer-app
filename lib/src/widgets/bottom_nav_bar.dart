import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:yallashop_core/yallashop_core.dart';

import '../core/bloc/auth_bloc.dart';
import '../core/bloc/auth_state.dart';
import '../core/cubit/notifications_cubit.dart';

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  const AppBottomNavBar({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalization.of(context)!;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final isVendor = authState is Authenticated && authState.user.role == 'vendor';
        final isCourier = authState is Authenticated && authState.user.role == 'courier';

        final items = [
          _NavItem(icon: Icons.home_outlined, label: loc.getText('home'), route: '/'),
          _NavItem(icon: Icons.category_outlined, label: loc.getText('categories'), route: '/categories'),
          if (!isVendor && !isCourier)
            _NavItem(icon: Icons.shopping_cart_outlined, label: loc.getText('cart'), route: '/cart'),
          if (isVendor) ...[
            _NavItem(icon: Icons.inventory_2_outlined, label: loc.getText('myProducts'), route: '/my-products'),
            _NavItem(icon: Icons.receipt_outlined, label: loc.getText('orders'), route: '/vendor-orders'),
          ],
          if (isCourier)
            _NavItem(icon: Icons.local_shipping_outlined, label: loc.getText('delivery'), route: '/driver'),
          if (!isVendor && !isCourier)
            _NavItem(icon: Icons.receipt_outlined, label: loc.getText('orders'), route: '/orders'),
          _NavItem(icon: Icons.notifications_outlined, label: loc.getText('notifications'), route: '/notifications'),
          _NavItem(icon: Icons.person_outlined, label: loc.getText('account'), route: '/account'),
        ];

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  final isSelected = index == currentIndex;
                  return GestureDetector(
                    onTap: () => context.go(item.route),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? CustomerAppColors.primary.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (item.route == '/notifications')
                            _buildBadgedIcon(item, isSelected)
                          else
                            Icon(
                              item.icon,
                              color: isSelected
                                  ? CustomerAppColors.primary
                                  : CustomerAppColors.textSecondary,
                              size: 24,
                            ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            Text(
                              item.label,
                              style: TextStyle(
                                color: CustomerAppColors.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBadgedIcon(_NavItem item, bool isSelected) {
    final color = isSelected
        ? CustomerAppColors.primary
        : CustomerAppColors.textSecondary;
    return BlocBuilder<NotificationsCubit, NotificationsState>(
      builder: (context, state) {
        final count = state.unreadCount;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(item.icon, color: color, size: 24),
            if (count > 0)
              Positioned(
                top: -6,
                right: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                  decoration: BoxDecoration(
                    color: CustomerAppColors.error,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  const _NavItem({required this.icon, required this.label, required this.route});
}