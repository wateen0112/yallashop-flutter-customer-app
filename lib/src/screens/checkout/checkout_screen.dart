import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:yallashop_core/yallashop_core.dart';

import '../../config/api_config.dart';
import '../../core/bloc/cart_bloc.dart';
import '../../core/bloc/cart_event.dart';
import '../../core/bloc/cart_state.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _apiClient = ApiClient(baseUrl: CustomerApiConfig.baseUrl);
  final _couponController = TextEditingController();
  final _instructionsController = TextEditingController();
  List<Address> _addresses = [];
  int? _selectedAddressId;
  bool _isPlacing = false;
  bool _isLoadingAddresses = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _couponController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingAddresses = true);
    try {
      final result = await _apiClient.get<Map<String, dynamic>>('/auth/me');
      if (result is Success<Map<String, dynamic>>) {
        final userData = result.data;
        if (userData.containsKey('addresses') && userData['addresses'] != null) {
          final addrsList = userData['addresses'] as List<dynamic>;
          final addrs = addrsList
              .map((e) => Address.fromJson(e as Map<String, dynamic>))
              .toList();
          if (mounted) {
            setState(() {
              _addresses = addrs;
              if (addrs.isNotEmpty && _selectedAddressId == null) {
                // Auto-select the default address, or the first one
                final defaultAddr = addrs.firstWhere(
                  (a) => a.isDefault,
                  orElse: () => addrs.first,
                );
                _selectedAddressId = defaultAddr.id;
              }
            });
          }
        }
      }
    } catch (e) {
      // Silently handle - addresses will just be empty
    }
    if (mounted) {
      setState(() => _isLoadingAddresses = false);
    }
  }

  Future<void> _placeOrder() async {
    final loc = AppLocalization.of(context)!;
    if (_selectedAddressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.getText('pleaseSelectAddress'))),
      );
      return;
    }
    setState(() => _isPlacing = true);
    try {
      final result = await _apiClient.post<Map<String, dynamic>>(
        '/checkout',
        data: {
          'address_id': _selectedAddressId,
          'payment_method': 'cod',
          if (_couponController.text.isNotEmpty) 'coupon_code': _couponController.text,
        },
      );
      if (result is Success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.getText('orderPlacedSuccessfully'))),
          );
          context.read<CartBloc>().add(const ClearCart());
          context.go('/orders');
        }
      } else {
        setState(() {
          _error = (result as Failure).exception.message;
          _isPlacing = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isPlacing = false;
      });
    }
  }

  String _itemsCurrencySymbol(List<CartItem> items, AppLocalization loc) {
    if (items.isEmpty) return loc.getText('currency');
    return items.first.product?.currencySymbol ?? loc.getText('currency');
  }

  bool _hasMixedCurrencies(List<CartItem> items) {
    final ids = <int?>{};
    for (final item in items) {
      final id = item.product?.currencyId;
      if (id != null) ids.add(id);
    }
    return ids.length > 1;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalization.of(context)!;
    final cartState = context.watch<CartBloc>().state;
    final currencySymbol = _itemsCurrencySymbol(cartState.items, loc);
    final mixedCurrency = _hasMixedCurrencies(cartState.items);
    return Scaffold(
      appBar: AppBar(title: Text(loc.getText('checkout'))),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.md),
        children: [
          Text(loc.getText('orderItems'), style: AppTypography.h2_18),
          const SizedBox(height: AppDimensions.sm),
          if (cartState.items.isEmpty)
            Text(loc.getText('cartEmpty'), style: AppTypography.caption12),
          ...cartState.items.map((item) => _CartItemTile(item: item)),
          const SizedBox(height: AppDimensions.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(loc.getText('deliveryAddress'), style: AppTypography.h2_18),
              if (!_isLoadingAddresses && _addresses.isEmpty)
                TextButton.icon(
                  onPressed: () async {
                    final added = await context.push<bool>('/account/add-address');
                    if (added == true && mounted) _loadData();
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(loc.getText('addNewAddress')),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          if (_isLoadingAddresses)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppDimensions.md),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_addresses.isEmpty)
            Container(
              padding: const EdgeInsets.all(AppDimensions.md),
              decoration: BoxDecoration(
                color: CustomerAppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              child: Column(
                children: [
                  const Icon(Icons.location_off, size: 48, color: CustomerAppColors.textSecondary),
                  const SizedBox(height: AppDimensions.sm),
                  Text(
                    loc.getText('noSavedAddresses'),
                    style: AppTypography.body14.copyWith(color: CustomerAppColors.textSecondary),
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final added = await context.push<bool>('/account/add-address');
                      if (added == true && mounted) _loadData();
                    },
                    icon: const Icon(Icons.add),
                    label: Text(loc.getText('addNewAddress')),
                  ),
                ],
              ),
            )
          else
            ...List.generate(_addresses.length, (i) {
              final addr = _addresses[i];
              final selected = addr.id == _selectedAddressId;
              return GestureDetector(
                onTap: () => setState(() => _selectedAddressId = addr.id),
                child: Container(
                  margin: const EdgeInsets.only(bottom: AppDimensions.sm),
                  padding: const EdgeInsets.all(AppDimensions.sm),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selected ? CustomerAppColors.primary : CustomerAppColors.border,
                      width: selected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  child: Row(
                    children: [
                      Radio<int>(
                        value: addr.id,
                        groupValue: _selectedAddressId,
                        onChanged: (v) => setState(() => _selectedAddressId = v),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(addr.label ?? loc.getText('address'),
                                  style: AppTypography.body14.copyWith(fontWeight: FontWeight.w600),
                                ),
                                if (addr.isDefault) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: CustomerAppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(loc.getText('default'),
                                      style: AppTypography.caption12.copyWith(
                                        color: CustomerAppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(addr.fullAddress,
                              style: AppTypography.caption12.copyWith(color: CustomerAppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          TextField(
            controller: _instructionsController,
            decoration: InputDecoration(
              hintText: loc.getText('deliveryInstructions'),
              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: AppDimensions.lg),
          Container(
            padding: const EdgeInsets.all(AppDimensions.sm),
            decoration: BoxDecoration(
              color: CustomerAppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Row(
              children: [
                const Icon(Icons.money, color: CustomerAppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(loc.getText('cashOnDelivery'), style: AppTypography.body14.copyWith(
                  color: CustomerAppColors.primary,
                  fontWeight: FontWeight.w600,
                )),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.lg),
          TextField(
            controller: _couponController,
            decoration: InputDecoration(
              hintText: loc.getText('couponCodeOptional'),
              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          Container(
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: BoxDecoration(
              color: CustomerAppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Column(
              children: [
                _Row(label: loc.getText('subtotal'), value: '$currencySymbol${cartState.subtotal.toStringAsFixed(2)}'),
                const SizedBox(height: 4),
                _Row(label: loc.getText('deliveryFee'), value: '$currencySymbol${5.99.toStringAsFixed(2)}'),
                const Divider(),
                _Row(label: loc.getText('total'), value: '$currencySymbol${(cartState.subtotal + 5.99).toStringAsFixed(2)}', isBold: true),
              ],
            ),
          ),
          if (mixedCurrency) ...[
            const SizedBox(height: AppDimensions.md),
            Container(
              padding: const EdgeInsets.all(AppDimensions.md),
              decoration: BoxDecoration(
                color: CustomerAppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: CustomerAppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      loc.getText('mixedCurrencyWarning'),
                      style: AppTypography.body14.copyWith(color: CustomerAppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppDimensions.sm),
            Text(_error!, style: const TextStyle(color: CustomerAppColors.error)),
          ],
          const SizedBox(height: AppDimensions.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (mixedCurrency || _isPlacing || _isLoadingAddresses || _selectedAddressId == null) ? null : _placeOrder,
              child: _isPlacing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(loc.getText('placeOrder')),
            ),
          ),
          const SizedBox(height: AppDimensions.xl),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  const _Row({required this.label, required this.value, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: (isBold ? AppTypography.body14 : AppTypography.caption12).copyWith(
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
        )),
        Text(value, style: (isBold ? AppTypography.body14 : AppTypography.caption12).copyWith(
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
          color: CustomerAppColors.secondary,
        )),
      ],
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  const _CartItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.product?.images?.isNotEmpty == true
        ? item.product!.images!.first.url
        : '';
    final currencySymbol = item.product?.currencySymbol ?? '\$';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CustomerAppColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56,
              height: 56,
              child: imageUrl.isNotEmpty
                  ? Image.network(imageUrl, fit: BoxFit.cover)
                  : Container(
                      color: CustomerAppColors.surfaceAlt,
                      child: const Icon(Icons.shopping_bag_outlined, size: 24),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product?.title ?? 'Product',
                  style: AppTypography.body14.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
                          width: 16,
                          height: 16,
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: CustomerAppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          display,
                          style: AppTypography.caption12.copyWith(
                            color: CustomerAppColors.textSecondary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          Text(
            '${item.quantity}x $currencySymbol${(item.variant.price ?? 0).toStringAsFixed(2)}',
            style: AppTypography.body14.copyWith(
              fontWeight: FontWeight.w600,
              color: CustomerAppColors.primary,
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