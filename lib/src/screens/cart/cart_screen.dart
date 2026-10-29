import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:yallashop_core/yallashop_core.dart';

import '../../core/bloc/cart_bloc.dart';
import '../../core/bloc/cart_event.dart';
import '../../core/bloc/cart_state.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/unified_app_bar.dart';

const double _cartDeliveryFee = 0.0;
const double _cartTaxRate = 0.02;

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _couponController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<CartBloc>().add(const LoadCart());
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalization.of(context)!;
    return Scaffold(
      backgroundColor: CustomerAppColors.background,
      appBar: UnifiedAppBar.detail(
        title: loc.getText('yourCart'),
        subtitle: loc.getText('itemsFromStores'),
        showBackButton: true,
        showNotification: true,
        showUserAvatar: true,
        onAvatarTap: () => context.push('/account'),
      ),
      body: BlocBuilder<CartBloc, CartState>(
        builder: (context, state) {
          if (state.isLoading) {
            return _buildShimmer();
          }
          if (state.items.isEmpty) {
            return EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: loc.getText('cartEmpty'),
              subtitle: loc.getText('cartEmptySubtitle'),
              actionLabel: loc.getText('startShopping'),
              onAction: () => context.go('/'),
            );
          }

          final grouped = state.groupedByStore;
          final itemCount = state.items.length;
          final storeCount = grouped.length;
          final currencySymbol = state.items.first.product?.currencySymbol ?? '\$';

          return Column(
            children: [
              // Screen Title
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.getText('yourCart'),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: CustomerAppColors.onBackground,
                        letterSpacing: -0.02,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loc.getText(
                        'cartItemsSummary',
                        params: {'items': '$itemCount', 'stores': '$storeCount'},
                      ),
                      style: AppTypography.body14.copyWith(
                        color: CustomerAppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Cart Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    const SizedBox(height: 24),
                    // Store Groups
                    for (final entry in grouped.entries) ...[
                      _buildStoreHeader(entry.value.first),
                      const SizedBox(height: 16),
                      for (final item in entry.value)
                        _CartItemCard(item: item),
                      const SizedBox(height: 24),
                    ],
                    // Coupon Section
                    _CouponSection(controller: _couponController),
                    const SizedBox(height: 24),
                    // Order Summary
                    _OrderSummary(
                      subtotal: state.subtotal,
                      currencySymbol: currencySymbol,
                      onCheckout: () => context.push('/checkout'),
                    ),
                    const SizedBox(height: 100), // Space for floating checkout button
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 2),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: BlocBuilder<CartBloc, CartState>(
        builder: (context, state) {
          if (state.items.isEmpty) return const SizedBox.shrink();
          final total = state.subtotal + _cartDeliveryFee + state.subtotal * _cartTaxRate;
          final currencySymbol = state.items.first.product?.currencySymbol ?? '\$';
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: FloatingActionButton.extended(
              onPressed: () => context.push('/checkout'),
              backgroundColor: CustomerAppColors.primary,
              foregroundColor: Colors.white,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              extendedPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              label: Text(
                '${loc.getText('checkoutNow')} $currencySymbol${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.01,
                ),
              ),
              icon: const Icon(Icons.arrow_forward, size: 22),
            ),
          );
        },
      ),
    );
  }



  Widget _buildStoreHeader(CartItem item) {
    final store = item.variant.product?.store;
    final storeName = store?.name ?? 'Store';
    final storeLogo = store?.logo;

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 24,
            height: 24,
            child: storeLogo != null && storeLogo.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: storeLogo,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: CustomerAppColors.primary.withValues(alpha: 0.1),
                      child: const Icon(Icons.store_rounded, color: CustomerAppColors.primary, size: 16),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: CustomerAppColors.primary.withValues(alpha: 0.1),
                      child: const Icon(Icons.store_rounded, color: CustomerAppColors.primary, size: 16),
                    ),
                  )
                : Container(
                    color: CustomerAppColors.primary.withValues(alpha: 0.1),
                    child: const Icon(Icons.store_rounded, color: CustomerAppColors.primary, size: 16),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          storeName,
          style: AppTypography.title18.copyWith(
            color: CustomerAppColors.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title shimmer
            Container(height: 40, width: 180, color: Colors.white),
            const SizedBox(height: 8),
            Container(height: 20, width: 200, color: Colors.white),
            const SizedBox(height: 24),
            // Store header shimmer
            Row(
              children: [
                Container(width: 24, height: 24, color: Colors.white),
                const SizedBox(width: 8),
                Container(width: 150, height: 24, color: Colors.white),
              ],
            ),
            const SizedBox(height: 16),
            // Cart items shimmer
            for (int i = 0; i < 3; i++) ...[
              Container(
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 24),
            // Coupon shimmer
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 24),
            // Summary shimmer
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItem item;
  const _CartItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.variant.images?.isNotEmpty == true
        ? item.variant.images!.first.url
        : '';
    final currencySymbol = item.product?.currencySymbol ?? '\$';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CustomerAppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 96,
                height: 96,
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: CustomerAppColors.surfaceAlt,
                          child: const Center(
                            child: Icon(
                              Icons.shopping_bag_outlined,
                              color: CustomerAppColors.textSecondary,
                              size: 32,
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: CustomerAppColors.surfaceAlt,
                          child: const Center(
                            child: Icon(
                              Icons.shopping_bag_outlined,
                              color: CustomerAppColors.textSecondary,
                              size: 32,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        color: CustomerAppColors.surfaceAlt,
                        child: const Center(
                          child: Icon(
                            Icons.shopping_bag_outlined,
                            color: CustomerAppColors.textSecondary,
                            size: 32,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            // Product Info & Quantity
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Delete
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.product?.title ?? 'Product',
                              style: AppTypography.title18.copyWith(
                                color: CustomerAppColors.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            if (item.variant.attributes != null && item.variant.attributes!.isNotEmpty)
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: item.variant.attributes!.map((attr) {
                                  final display = attr.displayValue;
                                  if (display.isEmpty) return const SizedBox.shrink();
                                  final isColorAttr = attr.attribute?.name.toLowerCase() == 'color';
                                  if (isColorAttr) {
                                    return Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: _tryParseColor(display),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: CustomerAppColors.border,
                                          width: 1.5,
                                        ),
                                      ),
                                    );
                                  }
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: CustomerAppColors.surfaceAlt,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      display,
                                      style: AppTypography.body14.copyWith(
                                        color: CustomerAppColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: CustomerAppColors.textSecondary,
                          size: 20,
                        ),
                        onPressed: () => context.read<CartBloc>().add(RemoveItem(itemId: item.id)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Quantity and Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _QuantityControl(item: item),
                      Text(
                        '$currencySymbol${(item.variant.price ?? 0).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: CustomerAppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityControl extends StatelessWidget {
  final CartItem item;
  const _QuantityControl({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CustomerAppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(9999),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(
              Icons.remove,
              size: 18,
              color: CustomerAppColors.primary,
            ),
            onPressed: item.quantity > 1
                ? () => context.read<CartBloc>().add(UpdateQuantity(itemId: item.id, quantity: item.quantity - 1))
                : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const SizedBox(width: 8),
          Text(
            '${item.quantity}',
            style: AppTypography.body14.copyWith(
              fontWeight: FontWeight.w600,
              color: CustomerAppColors.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: CustomerAppColors.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.add,
                size: 16,
                color: Colors.white,
              ),
              onPressed: () => context.read<CartBloc>().add(UpdateQuantity(itemId: item.id, quantity: item.quantity + 1)),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

class _CouponSection extends StatelessWidget {
  final TextEditingController controller;
  const _CouponSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalization.of(context)!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CustomerAppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CustomerAppColors.border),
      ),
      child: Column(
        children: [
          Text(
            loc.getText('couponCode'),
            style: AppTypography.body12.copyWith(
              fontWeight: FontWeight.w600,
              color: CustomerAppColors.textSecondary,
              letterSpacing: 0.05,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: loc.getText('enterCouponCode'),
                    hintStyle: AppTypography.body14.copyWith(color: CustomerAppColors.textSecondary),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: CustomerAppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: CustomerAppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: CustomerAppColors.primary, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: CustomerAppColors.onSurface,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  textStyle: AppTypography.body12.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.05,
                  ),
                ),
                child: Text(loc.getText('apply')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderSummary extends StatelessWidget {
  final double subtotal;
  final String currencySymbol;
  final VoidCallback onCheckout;
  const _OrderSummary({required this.subtotal, required this.currencySymbol, required this.onCheckout});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalization.of(context)!;
    const delivery = _cartDeliveryFee;
    final tax = subtotal * _cartTaxRate;
    final total = subtotal + delivery + tax;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CustomerAppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          _SummaryRow(label: loc.getText('subtotal'), amount: subtotal, currencySymbol: currencySymbol),
          _SummaryRow(label: loc.getText('delivery'), amount: delivery, isFree: true, currencySymbol: currencySymbol),
          _SummaryRow(label: loc.getText('tax'), amount: tax, currencySymbol: currencySymbol),
          const Divider(height: 24, thickness: 1),
          _SummaryRow(
            label: loc.getText('total'),
            amount: total,
            isBold: true,
            isTotal: true,
            currencySymbol: currencySymbol,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double amount;
  final String currencySymbol;
  final bool isBold;
  final bool isFree;
  final bool isTotal;
  const _SummaryRow({
    required this.label,
    required this.amount,
    required this.currencySymbol,
    this.isBold = false,
    this.isFree = false,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalization.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: (isBold || isTotal ? AppTypography.h2_18 : AppTypography.body14).copyWith(
              fontWeight: isTotal ? FontWeight.w800 : (isBold ? FontWeight.w700 : FontWeight.w400),
              color: isTotal ? CustomerAppColors.onSurface : CustomerAppColors.textSecondary,
              fontSize: isTotal ? 24 : 14,
            ),
          ),
          isFree
              ? Text(
                  loc.getText('free'),
                  style: AppTypography.body14.copyWith(
                    fontWeight: FontWeight.w600,
                    color: CustomerAppColors.primary,
                  ),
                )
              : Text(
                  '$currencySymbol${amount.toStringAsFixed(2)}',
                  style: (isBold || isTotal ? AppTypography.h2_18 : AppTypography.body14).copyWith(
                    fontWeight: isTotal ? FontWeight.w800 : (isBold ? FontWeight.w700 : FontWeight.w400),
                    color: isTotal ? CustomerAppColors.primary : CustomerAppColors.textSecondary,
                    fontSize: isTotal ? 24 : 14,
                  ),
                ),
        ],
      ),
    );
  }
}

Color _tryParseColor(String value) {
  try {
    String hex = value.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  } catch (_) {
    return Colors.grey;
  }
}