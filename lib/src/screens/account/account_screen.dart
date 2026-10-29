import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:yallashop_core/yallashop_core.dart';

import '../../core/bloc/auth_bloc.dart';
import '../../core/bloc/auth_event.dart';
import '../../core/bloc/auth_state.dart';
import 'currency_settings_screen.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/unified_app_bar.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Unauthenticated) {
          context.go('/login');
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is Authenticated) {
            return _AccountContent(user: state.user);
          }
          final loc = AppLocalization.of(context)!;
          return Scaffold(
            backgroundColor: CustomerAppColors.background,
            appBar: UnifiedAppBar.simple(
              title: loc.getText('myAccount'),
            ),
            body: Center(child: Text(loc.getText('pleaseLogIn'))),
          );
        },
      ),
    );
  }
}

class _AccountContent extends StatelessWidget {
  final User user;
  const _AccountContent({required this.user});

  void _showLanguagePicker(BuildContext context) {
    final localeProvider = LocaleProvider.of(context);
    if (localeProvider == null) return;
    final loc = AppLocalization.of(context)!;

    showModalBottomSheet(
      context: context,
      backgroundColor: CustomerAppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppDimensions.md),
                child: Text(
                  loc.getText('selectLanguage'),
                  style: AppTypography.h2_18,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(loc.getText('langEnglish')),
                trailing: localeProvider.locale.languageCode == 'en'
                    ? const Icon(Icons.check, color: CustomerAppColors.primary)
                    : null,
                onTap: () {
                  localeProvider.onLocaleChanged(const Locale('en'));
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(loc.getText('langArabic')),
                trailing: localeProvider.locale.languageCode == 'ar'
                    ? const Icon(Icons.check, color: CustomerAppColors.primary)
                    : null,
                onTap: () {
                  localeProvider.onLocaleChanged(const Locale('ar'));
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: AppDimensions.md),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalization.of(context)!;
    return Scaffold(
      backgroundColor: CustomerAppColors.background,
      appBar: UnifiedAppBar.main(
        title: loc.getText('myAccount'),
        showNotification: false,
        showUserAvatar: false,
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Profile Header Section
          _buildProfileHeader(context, loc),
          const SizedBox(height: 24),

          // Wallet Balance Card
          _buildWalletCard(context, loc),
          const SizedBox(height: 16),

          // Menu Sections
          _buildMenuSection(context, loc, [
            if (user.role == 'vendor')
              _AccountMenuItem(
                icon: Icons.inventory_2_outlined,
                title: loc.getText('myProducts'),
                onTap: () => context.push('/my-products'),
              ),
            _AccountMenuItem(
              icon: Icons.receipt_long_outlined,
              title: loc.getText('orderHistory'),
              onTap: () => context.push('/orders'),
            ),
            if (user.role != 'vendor')
              _AccountMenuItem(
                icon: Icons.favorite_outline,
                title: loc.getText('wishlist'),
                onTap: () => context.push('/wishlist'),
              ),
            _AccountMenuItem(
              icon: Icons.location_on_outlined,
              title: loc.getText('addresses'),
              onTap: () => context.push('/addresses'),
            ),
          ]),
          const SizedBox(height: 16),

          _buildMenuSection(context, loc, [
            _AccountMenuItem(
              icon: Icons.language_outlined,
              title: loc.getText('selectLanguage'),
              onTap: () => _showLanguagePicker(context),
            ),
            _AccountMenuItem(
              icon: Icons.notifications_outlined,
              title: loc.getText('notifications'),
              onTap: () => context.push('/notifications'),
            ),
            _AccountMenuItem(
              icon: Icons.settings_outlined,
              title: loc.getText('settings'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CurrencySettingsScreen(),
                  ),
                );
              },
            ),
          ]),
          const SizedBox(height: 16),

          _buildMenuSection(context, loc, [
            _AccountMenuItem(
              icon: Icons.help_outline,
              title: loc.getText('helpAndSupport'),
              onTap: () {},
            ),
            _AccountMenuItem(
              icon: Icons.info_outline,
              title: loc.getText('about'),
              onTap: () {},
            ),
          ]),
          const SizedBox(height: 32),

          // Logout Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: OutlinedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Text(loc.getText('logout')),
                  content: Text(loc.getText('areYouSureLogout')),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(loc.getText('cancel')),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.read<AuthBloc>().add(const LogoutRequested());
                      },
                      child: Text(
                        loc.getText('logout'),
                        style: const TextStyle(color: CustomerAppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: CustomerAppColors.error,
                side: const BorderSide(color: CustomerAppColors.error, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: AppTypography.body14.copyWith(fontWeight: FontWeight.w600),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.logout, size: 20),
                  const SizedBox(width: 8),
                  Text(loc.getText('logout')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 4),
    );
  }

  Widget _buildProfileHeader(BuildContext context, AppLocalization loc) {
    return GestureDetector(
      onTap: () => context.push('/account/edit-profile'),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        decoration: BoxDecoration(
          color: CustomerAppColors.background,
        ),
        child: Column(
          children: [
            // Avatar
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: CustomerAppColors.primary,
                      width: 3,
                    ),
                    gradient: LinearGradient(
                      colors: [
                        CustomerAppColors.primary.withValues(alpha: 0.15),
                        CustomerAppColors.accentGold.withValues(alpha: 0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: ClipOval(
                    child: user.avatar != null && user.avatar!.isNotEmpty
                        ? Image.network(
                            user.avatar!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
                          )
                        : user.email != null && user.email!.isNotEmpty
                            ? Image.network(
                                'https://api.dicebear.com/7.x/initials/svg?seed=${Uri.encodeComponent(user.name)}&backgroundColor=FF3B5C%2CF6A623&textColor=ffffff',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
                              )
                            : _buildDefaultAvatar(),
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: CustomerAppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: CustomerAppColors.background, width: 2),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Name
            Text(
              user.name,
              style: AppTypography.h1_22.copyWith(
                fontWeight: FontWeight.w700,
                color: CustomerAppColors.secondary,
              ),
            ),
            const SizedBox(height: 4),

            // Email
            if (user.email != null && user.email!.isNotEmpty)
              Text(
                user.email!,
                style: AppTypography.body14.copyWith(
                  color: CustomerAppColors.textSecondary,
                ),
              )
            else
              Text(
                user.phone ?? '',
                style: AppTypography.body14.copyWith(
                  color: CustomerAppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
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
          size: 40,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildWalletCard(BuildContext context, AppLocalization loc) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            CustomerAppColors.primary,
            CustomerAppColors.primary.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: CustomerAppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.getText('walletBalance'),
                  style: AppTypography.caption12.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${loc.getText('currency')}0.00',
                  style: AppTypography.h1_22.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.chevron_right,
                color: Colors.white,
                size: 22,
              ),
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(
    BuildContext context,
    AppLocalization loc,
    List<_AccountMenuItem> items,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: CustomerAppColors.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: items.map((item) => _MenuItemWidget(item: item)).toList(),
      ),
    );
  }
}

class _AccountMenuItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _AccountMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });
}

class _MenuItemWidget extends StatelessWidget {
  final _AccountMenuItem item;
  const _MenuItemWidget({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: CustomerAppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                item.icon,
                color: CustomerAppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                item.title,
                style: AppTypography.body14.copyWith(
                  color: CustomerAppColors.secondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: CustomerAppColors.textSecondary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}