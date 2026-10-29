import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yallashop_core/yallashop_core.dart';

import '../core/cubit/notifications_cubit.dart';

/// Notification bell with a live unread-count badge driven by
/// [NotificationsCubit]. Shows no badge when the count is zero.
class NotificationBell extends StatelessWidget {
  final VoidCallback? onTap;
  final Color iconColor;
  final double iconSize;

  /// Optional custom icon/content to wrap with the badge (e.g. a styled
  /// circular container). When null, a default [IconButton] is rendered.
  final Widget? child;

  const NotificationBell({
    super.key,
    this.onTap,
    this.iconColor = CustomerAppColors.primary,
    this.iconSize = 28,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsCubit, NotificationsState>(
      builder: (context, state) {
        final count = state.unreadCount;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            child ??
                IconButton(
                  icon: Icon(
                    Icons.notifications_outlined,
                    color: iconColor,
                    size: iconSize,
                  ),
                  onPressed: onTap,
                ),
            if (count > 0)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                  decoration: BoxDecoration(
                    color: CustomerAppColors.error,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: CustomerAppColors.surfaceContainerLowest, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
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