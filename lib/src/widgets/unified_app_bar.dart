import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:yallashop_core/yallashop_core.dart';

import '../core/bloc/auth_bloc.dart';
import '../core/bloc/auth_state.dart';
import 'notification_bell.dart';

/// Unified app bar for the YallaShop customer app.
/// Supports different configurations for different screen types.
class UnifiedAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Type of app bar to render
  final UnifiedAppBarType type;

  /// Title to display
  final String? title;

  /// Subtitle to display (for cart, etc.)
  final String? subtitle;

  /// Whether to show the back button
  final bool showBackButton;

  /// Whether to show user avatar
  final bool showUserAvatar;

  /// Whether to show notification button
  final bool showNotification;

  /// Custom actions to show on the right
  final List<Widget>? actions;

  /// Leading widget (replaces back button if provided)
  final Widget? leading;

  /// Whether to automatically show back button when not on root
  final bool autoBackButton;

  /// Callback when back button is pressed
  final VoidCallback? onBackPressed;

  /// Callback when user avatar is tapped
  final VoidCallback? onAvatarTap;

  /// Callback when notification is tapped
  final VoidCallback? onNotificationTap;

  /// Background color
  final Color? backgroundColor;

  /// Elevation
  final double elevation;

  /// Whether to show scrolled under elevation
  final double scrolledUnderElevation;

  /// Whether to make the app bar opaque when scrolled (for screens with transparent background)
  final bool opaqueOnScroll;

  const UnifiedAppBar({
    super.key,
    this.type = UnifiedAppBarType.simple,
    this.title,
    this.subtitle,
    this.showBackButton = false,
    this.showUserAvatar = false,
    this.showNotification = false,
    this.actions,
    this.leading,
    this.autoBackButton = false,
    this.onBackPressed,
    this.onAvatarTap,
    this.onNotificationTap,
    this.backgroundColor,
    this.elevation = 0,
    this.scrolledUnderElevation = 1,
    this.opaqueOnScroll = false,
  });

  /// Factory for main screens with bottom navigation (Home, Categories, Cart, Orders)
  factory UnifiedAppBar.main({
    Key? key,
    String? title,
    String? subtitle,
    bool showNotification = true,
    bool showUserAvatar = true,
    VoidCallback? onAvatarTap,
    VoidCallback? onNotificationTap,
    List<Widget>? actions,
    Color? backgroundColor,
    bool opaqueOnScroll = false,
  }) {
    return UnifiedAppBar(
      key: key,
      type: UnifiedAppBarType.main,
      title: title,
      subtitle: subtitle,
      showNotification: showNotification,
      showUserAvatar: showUserAvatar,
      onAvatarTap: onAvatarTap,
      onNotificationTap: onNotificationTap,
      actions: actions,
      backgroundColor: backgroundColor,
      opaqueOnScroll: opaqueOnScroll,
    );
  }

  /// Factory for detail screens with back button
  factory UnifiedAppBar.detail({
    Key? key,
    required String title,
    String? subtitle,
    bool showNotification = false,
    bool showUserAvatar = false,
    bool showBackButton = true,
    VoidCallback? onBackPressed,
    VoidCallback? onAvatarTap,
    VoidCallback? onNotificationTap,
    List<Widget>? actions,
    Color? backgroundColor,
    bool opaqueOnScroll = false,
  }) {
    return UnifiedAppBar(
      key: key,
      type: UnifiedAppBarType.detail,
      title: title,
      subtitle: subtitle,
      showBackButton: showBackButton,
      showUserAvatar: showUserAvatar,
      showNotification: showNotification,
      onBackPressed: onBackPressed,
      onAvatarTap: onAvatarTap,
      onNotificationTap: onNotificationTap,
      actions: actions,
      backgroundColor: backgroundColor,
      opaqueOnScroll: opaqueOnScroll,
    );
  }

  /// Factory for simple screens with just title
  factory UnifiedAppBar.simple({
    Key? key,
    required String title,
    bool showBackButton = false,
    VoidCallback? onBackPressed,
    List<Widget>? actions,
    Color? backgroundColor,
    bool opaqueOnScroll = false,
  }) {
    return UnifiedAppBar(
      key: key,
      type: UnifiedAppBarType.simple,
      title: title,
      showBackButton: showBackButton,
      onBackPressed: onBackPressed,
      actions: actions,
      backgroundColor: backgroundColor,
      opaqueOnScroll: opaqueOnScroll,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine if we should show back button
    final canPop = Navigator.of(context).canPop();
    final shouldShowBack = showBackButton || (autoBackButton && canPop);

    // Build leading widget
    Widget? leadingWidget;
    if (leading != null) {
      leadingWidget = leading;
    } else if (shouldShowBack) {
      leadingWidget = IconButton(
        icon: const Icon(Icons.arrow_back, color: CustomerAppColors.onSurface, size: 24),
        onPressed: onBackPressed ?? () => context.pop(),
      );
    }

    // Build actions
    final List<Widget> actionWidgets = [];

    if (showNotification) {
      actionWidgets.add(
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: NotificationBell(
            onTap: onNotificationTap ?? () => context.push('/notifications'),
          ),
        ),
      );
    }

    if (actions != null) {
      actionWidgets.addAll(actions!);
    }

    // Build user avatar if needed
    Widget? avatarWidget;
    if (showUserAvatar) {
      String? avatarUrl;
      final authState = context.read<AuthBloc>().state;
      if (authState is Authenticated) {
        avatarUrl = authState.user.avatar;
      }

      avatarWidget = GestureDetector(
        onTap: onAvatarTap ?? () => context.push('/account'),
        child: Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: CustomerAppColors.primary.withValues(alpha: 0.1),
              width: 2,
            ),
            color: CustomerAppColors.surfaceContainerHigh,
          ),
          child: ClipOval(
            child: avatarUrl != null && avatarUrl.isNotEmpty
                ? Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
                  )
                : _buildDefaultAvatar(),
          ),
        ),
      );
    }

    // Build title section
    Widget? titleWidget;
    if (type == UnifiedAppBarType.main && title != null && subtitle != null) {
      titleWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            subtitle!,
            style: AppTypography.caption12.copyWith(
              color: CustomerAppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            title!,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: CustomerAppColors.onSurface,
            ),
          ),
        ],
      );
    } else if (type == UnifiedAppBarType.detail && subtitle != null) {
      titleWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title!,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: CustomerAppColors.onSurface,
            ),
          ),
          Text(
            subtitle!,
            style: AppTypography.caption12.copyWith(
              color: CustomerAppColors.textSecondary,
            ),
          ),
        ],
      );
    } else if (title != null) {
      titleWidget = Text(
        title!,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: CustomerAppColors.onSurface,
        ),
      );
    }

    if (titleWidget != null) {
      titleWidget = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: titleWidget,
      );
    }

    // When opaqueOnScroll is true and backgroundColor is transparent,
    // use a semi-transparent backdrop that becomes more opaque on scroll
    final effectiveBackground = (opaqueOnScroll && backgroundColor == Colors.transparent)
        ? CustomerAppColors.background.withValues(alpha: 0.85)
        : backgroundColor ?? CustomerAppColors.background;

    return AppBar(
      backgroundColor: effectiveBackground,
      elevation: elevation,
      scrolledUnderElevation: opaqueOnScroll ? 0 : scrolledUnderElevation,
      automaticallyImplyLeading: false,
      toolbarHeight: type == UnifiedAppBarType.main && subtitle != null ? 72 : 64,
      titleSpacing: 0,
      leading: leadingWidget,
      leadingWidth: leadingWidget != null ? 48 : 0,
      title: titleWidget,
      centerTitle: false,
      actions: [
        if (avatarWidget != null) avatarWidget,
        ...actionWidgets,
        if (actionWidgets.isNotEmpty || avatarWidget != null) const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            CustomerAppColors.primary,
            CustomerAppColors.accentGold,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.person,
          size: 18,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
    type == UnifiedAppBarType.main && subtitle != null ? 72 : 64,
  );
}

/// Type of app bar to render
enum UnifiedAppBarType {
  /// Main screens with bottom navigation (Home, Categories, Cart, Orders, Account)
  main,
  
  /// Detail screens with back button (Product detail, Order tracking, etc.)
  detail,
  
  /// Simple screens with just title
  simple,
}