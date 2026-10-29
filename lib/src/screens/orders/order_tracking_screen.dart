import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:yallashop_core/yallashop_core.dart';

import '../../config/api_config.dart';
import '../../core/bloc/auth_bloc.dart';
import '../../core/bloc/auth_state.dart';
import '../../widgets/unified_action_button.dart';
import '../../widgets/unified_app_bar.dart';
import '../../widgets/rating_dialog.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen>
    with WidgetsBindingObserver {
  final _apiClient = ApiClient(baseUrl: CustomerApiConfig.baseUrl);
  Order? _order;
  Map<String, dynamic>? _vendorOrder;
  bool _isLoading = true;
  bool _isCancelling = false;
  bool _statusLoading = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadOrder();
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _loadOrder(silent: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (mounted) _loadOrder(silent: true);
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) _loadOrder(silent: true);
    });
  }

  bool get _isVendor {
    final authState = context.read<AuthBloc>().state;
    return authState is Authenticated && authState.user.role == 'vendor';
  }

  // HTML color palette
  static const Color primary = Color(0xFFba002c);
  static const Color background = Color(0xFFF9F9FF);
  static const Color onSurface = Color(0xFF151c27);
  static const Color onSecondaryContainer = Color(0xFF636467);
  static const Color surfaceContainerHigh = Color(0xFFE2E8F8);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color primaryFixed = Color(0xFFFFDAD9);
  static const Color secondaryContainer = Color(0xFFE2E2E5);
  static const Color outlineVariant = Color(0xFFE5BDBC);

  static const _bgImage =
      'https://lh3.googleusercontent.com/aida/AP1WRLuFHvA6DuJAhqv57RGAplxC5T_6PWZYMT6Oab6Lw814WiacRP1SjRb8iRwIHEvtoUyCmzE-un2s8hf7ZmQWOq4pxzk2KJVrzRqhFMj6HU1NLEn8BIrKF9i9lZVNrchZzSRzeaimrwbg8CAVnyQzwneCNip9TShTTk5wXx_rGlTBA9mmAGSCGku_CI1Qwe_ppWNefIePHNrhR2p4RuarhLuowex9KyEqT16Xpkj25vLRijZzPLLcF8VUk7xn';
  static const _mapImage =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuC5J7axCZE59VxuK_XBIDBJZt8NCoya_-VOHCItwJII9Q9AdmgJv-szriP4AC9VPyHS31BbQZWRGheDB22-texNZLphMS7-Y6IiQ3vIs6hc8FT9LnMAaOTaf-9YCAejGkn2YRBeL0mR2DJaXo0iI8UsOR3Du86_QgheSn9Ge99SUrzAGAyZj4_JtqQ7Bi9clXekLS5BkxehuWu4L7RHO0c-Iqng8cNB-21YNtQbgXPYp1OXQbzQ9FaU857qRceXvjtyovPOc3NUIx5H';

  Future<void> _loadOrder({bool silent = false}) async {
    if (!mounted) return;
    if (silent && _isLoading) return;
    if (!silent) setState(() => _isLoading = true);
    if (_isVendor) {
      await _loadVendorOrder(silent: silent);
      return;
    }
    final result = await _apiClient.get<dynamic>('/orders/${widget.orderId}');
    if (result is Success) {
      setState(() {
        _order = Order.fromJson(result.data);
        _isLoading = false;
      });
    } else if (!silent) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadVendorOrder({bool silent = false}) async {
    try {
      final result = await _apiClient.get<dynamic>('/vendor/orders');
      if (result is Success) {
        final data = result.data;
        List<dynamic> orders = [];
        if (data is List) {
          orders = data;
        } else if (data is Map<String, dynamic>) {
          orders = data['data'] as List<dynamic>? ?? [];
        }
        final found = orders.cast<Map<String, dynamic>?>().firstWhere(
              (o) => '${o?['id']}' == widget.orderId || '${o?['order_id']}' == widget.orderId ||
                  '${o?['order_number']}' == widget.orderId,
              orElse: () => null,
            );
        setState(() {
          _vendorOrder = found;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String status) async {
    if (_vendorOrder == null) return;
    final loc = AppLocalization.of(context)!;
    setState(() => _statusLoading = true);
    final result = await _apiClient.put(
      '/vendor/orders/${widget.orderId}/status',
      data: {'status': status},
    );
    if (result is Success) {
      _loadVendorOrder();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.getText('orderStatusUpdated')),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
      }
    } else if (result is Failure) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.exception.message),
            backgroundColor: const Color(0xFFD32F2F),
          ),
        );
      }
    }
    if (mounted) setState(() => _statusLoading = false);
  }

  Future<void> _cancelOrder() async {
    setState(() => _isCancelling = true);
    await _apiClient.post('/orders/${widget.orderId}/cancel');
    _loadOrder();
    setState(() => _isCancelling = false);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalization.of(context)!;
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: background,
        body: Center(child: CircularProgressIndicator(color: primary)),
      );
    }

    if (_isVendor) {
      return _buildVendorView();
    }

    final order = _order;
    if (order == null) {
      return Scaffold(
        backgroundColor: background,
        body: Center(child: Text(loc.getText('orderNotFound'))),
      );
    }

    final subOrders = order.subOrders ?? [];
    final effectiveStatus = subOrders.isNotEmpty ? subOrders.first.status : order.status;
    final canCancel = !['delivered', 'cancelled'].contains(effectiveStatus);

    // Find delivery code from sub-orders
    String? deliveryCode;
    for (final sub in subOrders) {
      if (sub.status == 'with_driver' && sub.deliveryCode != null) {
        deliveryCode = sub.deliveryCode;
        break;
      }
    }

    // Calculate totals (use backend authoritative values when present)
    final currency = order.currencySymbol;
    final subtotal = order.subtotal;
    final deliveryFee = order.deliveryFeeTotal;

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      backgroundColor: background,
      appBar: UnifiedAppBar.detail(
        title: '#${order.orderNumber}',
        backgroundColor: Colors.transparent,
        opaqueOnScroll: true,
        showBackButton: true,
        showUserAvatar: true,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image — full screen
          Image.network(
            _bgImage,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),

          // Main scrollable content
          SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 64 + 16, 20, 40),
            child: Column(
              children: [
                // Delivery code card (shown when status is with_driver)
                if (deliveryCode != null) ...[
                  _buildDeliveryCodeCard(deliveryCode),
                  const SizedBox(height: 16),
                ],

                // Order status timeline
                _buildOrderStatusTimeline(effectiveStatus, subOrders),
                const SizedBox(height: 16),

                // Order items section
                _buildOrderItemsSection(subOrders, currency),
                const SizedBox(height: 16),

                // Price summary
                _buildPriceSummary(subtotal, deliveryFee, order.grandTotal, currency),
                const SizedBox(height: 16),

                // Action buttons
                if (canCancel) _buildCancelButton(),
                if (effectiveStatus == 'delivered') ...[
                  const SizedBox(height: 12),
                  _buildRateOrderButton(subOrders),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // VENDOR TRACKING VIEW (mirrors admin dashboard order-detail-modal.tsx)
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildVendorView() {
    final loc = AppLocalization.of(context)!;
    final order = _vendorOrder;
    if (order == null) {
      return Scaffold(
        backgroundColor: background,
        body: Center(child: Text(loc.getText('orderNotFound'))),
      );
    }

    final status = order['status'] as String? ?? 'pending';
    final orderId = order['order_number'] ?? order['order_id'] ?? '#${order['id']}';
    final createdAt = order['created_at'] as String?;
    final customerName = order['customer_name'] as String?;
    final customerEmail = order['customer_email'] as String?;
    final vendorName = order['vendor_name'] as String?;
    final items = order['items'] as List<dynamic>? ?? [];
    final courier = order['courier'] as Map<String, dynamic>?;
    final pickupCode = order['pickup_code'] as String?;
    final deliveryAddress = order['delivery_address_snapshot'] as Map<String, dynamic>?;
    final deliveryFee = _toDouble(order['delivery_fee'] ?? order['delivery_fee_total'] ?? 0);
    final totalAmount = _toDouble(order['grand_total'] ?? order['total_amount'] ?? 0);
    final subtotal = totalAmount - deliveryFee;
    final currencyMap = (order['currency_snapshot'] ?? order['currency']) as Map<String, dynamic>?;
    final currency = (currencyMap?['symbol'] ?? 'SAR').toString();

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      backgroundColor: background,
      appBar: UnifiedAppBar.detail(
        title: '$orderId',
        backgroundColor: Colors.transparent,
        opaqueOnScroll: true,
        showBackButton: true,
        showUserAvatar: true,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            _bgImage,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 64 + 16, 20, 40),
            child: Column(
              children: [
                _buildVendorOrderInfoHeader(orderId, status, customerName, customerEmail, vendorName, createdAt),
                const SizedBox(height: 16),
                _buildVendorTimeline(status),
                if (deliveryAddress != null) ...[
                  const SizedBox(height: 16),
                  _buildVendorDeliveryAddress(deliveryAddress),
                ],
                if (pickupCode != null) ...[
                  const SizedBox(height: 16),
                  _buildVendorCodeCard(loc.getText('pickupCode'), pickupCode),
                ],
                if (courier != null) ...[
                  const SizedBox(height: 16),
                  _buildVendorCourierCard(courier),
                ],
                const SizedBox(height: 16),
                _buildVendorOrderItems(items, currency),
                const SizedBox(height: 16),
                _buildVendorPriceSummary(subtotal, deliveryFee, totalAmount, currency),
                const SizedBox(height: 16),
                _buildVendorStatusActions(status),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _vendorTimelineSteps = [
    'pending',
    'confirmed',
    'preparing',
    'ready_for_pickup',
    'waiting_for_driver',
    'with_driver',
    'delivered',
  ];

  Widget _buildVendorOrderInfoHeader(
    String orderId,
    String status,
    String? customerName,
    String? customerEmail,
    String? vendorName,
    String? createdAt,
  ) {
    final loc = AppLocalization.of(context)!;
    return _glassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildVendorInfoField(loc.getText('orderIdLabel'), '$orderId')),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    loc.getText('status').toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: primary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildVendorStatusPill(status),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildVendorInfoField(loc.getText('customer'), customerName ?? '-')),
              if (vendorName != null) ...[
                const SizedBox(width: 16),
                Expanded(child: _buildVendorInfoField(loc.getText('vendor'), vendorName)),
              ],
            ],
          ),
          if (customerEmail != null) ...[
            const SizedBox(height: 8),
            Text(
              customerEmail,
              style: const TextStyle(fontSize: 13, color: onSecondaryContainer),
            ),
          ],
          if (createdAt != null) ...[
            const SizedBox(height: 12),
            _buildVendorInfoField(loc.getText('date'), _formatDate(createdAt)),
          ],
        ],
      ),
    );
  }

  Widget _buildVendorInfoField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: primary,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildVendorStatusPill(String status) {
    final color = _vendorStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        _vendorStatusLabel(status).toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  String _vendorStatusLabel(String status) {
    final loc = AppLocalization.of(context)!;
    switch (status) {
      case 'pending': return loc.getText('orderStatusPending');
      case 'confirmed': return loc.getText('orderStatusConfirmed');
      case 'preparing': return loc.getText('orderStatusPreparing');
      case 'ready_for_pickup': return loc.getText('orderStatusReadyForPickup');
      case 'waiting_for_driver': return loc.getText('orderStatusWaitingForDriver');
      case 'with_driver': return loc.getText('orderStatusWithDriver');
      case 'picked_up': return loc.getText('orderStatusPickedUp');
      case 'out_for_delivery': return loc.getText('orderStatusOutForDelivery');
      case 'delivered': return loc.getText('orderStatusDelivered');
      case 'cancelled': return loc.getText('orderStatusCancelled');
      default: return status.replaceAll('_', ' ');
    }
  }

  Color _vendorStatusColor(String status) {
    switch (status) {
      case 'pending': return const Color(0xFFF59E0B);
      case 'confirmed': return primary;
      case 'preparing': return const Color(0xFF3B82F6);
      case 'ready_for_pickup': return const Color(0xFF10B981);
      case 'waiting_for_driver': return const Color(0xFF8B5CF6);
      case 'with_driver': return const Color(0xFF06B6D4);
      case 'delivered': return const Color(0xFF059669);
      case 'cancelled': return const Color(0xFFDC2626);
      default: return onSecondaryContainer;
    }
  }

  Widget _buildVendorTimeline(String status) {
    final loc = AppLocalization.of(context)!;
    if (status == 'cancelled') {
      return _glassCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 16, height: 16,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFDC2626)),
              child: const Icon(Icons.close, size: 10, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(
              loc.getText('orderCancelled'),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: onSurface),
            ),
          ],
        ),
      );
    }

    final currentIdx = _vendorTimelineSteps.indexOf(status);
    final isTerminal = status == 'delivered';

    return _glassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.getText('orderTimeline').toUpperCase(),
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: primary, letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(_vendorTimelineSteps.length, (i) {
            final step = _vendorTimelineSteps[i];
            final completed = isTerminal || i < currentIdx;
            final active = !isTerminal && i == currentIdx;
            final isLast = i == _vendorTimelineSteps.length - 1;
            return _buildVendorTimelineStep(
              label: _vendorStepLabel(step),
              completed: completed,
              active: active,
              isLast: isLast,
              showMap: active && step == 'with_driver',
            );
          }),
        ],
      ),
    );
  }

  String _vendorStepLabel(String step) {
    final loc = AppLocalization.of(context)!;
    switch (step) {
      case 'pending': return loc.getText('orderPlacedStep');
      case 'confirmed': return loc.getText('orderStatusConfirmed');
      case 'preparing': return loc.getText('orderStatusPreparing');
      case 'ready_for_pickup': return loc.getText('orderStatusReadyForPickup');
      case 'waiting_for_driver': return loc.getText('orderStatusWaitingForDriver');
      case 'with_driver': return loc.getText('orderStatusWithDriver');
      case 'delivered': return loc.getText('orderStatusDelivered');
      default: return step;
    }
  }

  Widget _buildVendorTimelineStep({
    required String label,
    required bool completed,
    required bool active,
    required bool isLast,
    required bool showMap,
  }) {
    final loc = AppLocalization.of(context)!;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 16,
            child: Column(
              children: [
                Container(
                  width: 16, height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: completed ? primary : secondaryContainer,
                    boxShadow: active
                        ? [BoxShadow(color: primaryFixed.withValues(alpha: 0.8), blurRadius: 0, spreadRadius: 4)]
                        : null,
                  ),
                  child: active
                      ? const Center(
                          child: SizedBox(
                            width: 8, height: 8,
                            child: DecoratedBox(
                              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                            ),
                          ),
                        )
                      : completed
                          ? const Icon(Icons.check, size: 10, color: Colors.white)
                          : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: completed ? primary : secondaryContainer,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: completed ? primary : onSecondaryContainer,
                    ),
                  ),
                  if (active && showMap) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 128,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: outlineVariant.withValues(alpha: 0.3)),
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Image.network(
                                _mapImage,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: surfaceContainerHigh,
                                  child: const Center(
                                    child: Icon(Icons.map_outlined, size: 48, color: Color(0x4DBA002C)),
                                  ),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [Colors.black.withValues(alpha: 0.2), Colors.transparent],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 8, left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(9999),
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.speed, size: 14, color: primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      loc.getText('liveTracking'),
                                      style: const TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.w700, color: onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorDeliveryAddress(Map<String, dynamic> address) {
    final loc = AppLocalization.of(context)!;
    final fullAddress = (address['full_address'] as String? ?? address['address'] ?? address['label'] as String?).toString().trim();
    final city = (address['city'] as String? ?? '').toString();
    final area = (address['area'] as String? ?? '').toString();
    final phone = address['phone'] as String?;
    final lines = <String>[
      if (fullAddress.isNotEmpty) fullAddress,
      if (city.isNotEmpty || area.isNotEmpty)
        [city, area].where((e) => e.isNotEmpty).join(', '),
    ];

    return _glassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.getText('deliveryAddressLabel').toUpperCase(),
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: primary, letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, size: 20, color: primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in lines) ...[
                      if (line.isNotEmpty) ...[
                        Text(line, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: onSurface)),
                        const SizedBox(height: 4),
                      ],
                    ],
                    if (phone != null && phone.isNotEmpty) ...[
                      Text(loc.getText('phoneLabel', params: {'phone': phone}), style: TextStyle(fontSize: 13, color: onSecondaryContainer)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVendorCodeCard(String label, String code) {
    return _glassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: primary, letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            code,
            style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 6, color: onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorCourierCard(Map<String, dynamic> courier) {
    final loc = AppLocalization.of(context)!;
    return _glassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.getText('courier').toUpperCase(),
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: primary, letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(shape: BoxShape.circle, color: surfaceContainerHigh),
                child: const Icon(Icons.person, color: primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      courier['name'] ?? loc.getText('courier'),
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: onSurface),
                    ),
                    if (courier['phone'] != null) ...[
                      const SizedBox(height: 2),
                      Text(courier['phone'], style: TextStyle(fontSize: 13, color: onSecondaryContainer)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVendorOrderItems(List<dynamic> items, String currency) {
    final loc = AppLocalization.of(context)!;
    return _glassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.getText('orderItems').toUpperCase(),
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: primary, letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Text(loc.getText('noItems'), style: TextStyle(fontSize: 14, color: onSecondaryContainer))
          else
            ...items.map((item) => _buildVendorOrderItem(item, currency)),
        ],
      ),
    );
  }

  Widget _buildVendorOrderItem(dynamic item, String currency) {
    final loc = AppLocalization.of(context)!;
    final itemMap = item as Map<String, dynamic>;
    final name = itemMap['name'] ?? itemMap['product_name'] ?? loc.getText('item');
    final qty = itemMap['qty'] ?? itemMap['quantity'] ?? 1;
    final price = _toDouble(itemMap['total_price'] ?? itemMap['price'] ?? 0);
    final unitPrice = _toDouble(itemMap['unit_price'] ?? price);
    final imageUrl = itemMap['image_url'] as String? ?? itemMap['product_image'] as String?;

    final variant = itemMap['variant'] as Map<String, dynamic>?;
    final product = variant?['product'] as Map<String, dynamic>?;
    final displayName = product?['title'] ?? name;
    final sku = variant?['sku'] as String?;
    final images = variant?['images'] as List<dynamic>?;
    final productImages = product?['images'] as List<dynamic>?;
    final allImages = (images != null && images.isNotEmpty) ? images : productImages;
    final displayImage = imageUrl ?? (allImages != null && allImages.isNotEmpty ? allImages[0]['url'] as String? : null);
    final attributes = variant?['attributes'] as List<dynamic>? ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: surfaceContainerHigh,
              border: Border.all(color: outlineVariant.withValues(alpha: 0.1)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: displayImage != null
                  ? Image.network(displayImage, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.fastfood, color: Color(0x4DBA002C)))
                  : const Icon(Icons.fastfood, color: Color(0x4DBA002C)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (sku != null) ...[
                  const SizedBox(height: 2),
                  Text(loc.getText('skuLabel', params: {'sku': sku}), style: TextStyle(fontSize: 12, color: onSecondaryContainer)),
                ],
                if (attributes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: attributes.map((attr) {
                      final a = attr as Map<String, dynamic>;
                      final attrName = (a['attribute'] as Map<String, dynamic>?)?['name'] ?? '';
                      final attrValue = (a['option'] as Map<String, dynamic>?)?['value'] ?? a['value'] ?? '';
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          attrName.isNotEmpty ? '$attrName: $attrValue' : attrValue.toString(),
                          style: TextStyle(fontSize: 11, color: primary),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '${loc.getText('qtyLabel', params: {'qty': '$qty'})} x $currency ${unitPrice.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 12, color: onSecondaryContainer),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$currency ${price.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorPriceSummary(double subtotal, double deliveryFee, double total, String currency) {
    final loc = AppLocalization.of(context)!;
    return _glassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildVendorSummaryRow(loc.getText('subtotal'), subtotal, currency),
          const SizedBox(height: 8),
          _buildVendorSummaryRow(loc.getText('deliveryFee'), deliveryFee, currency),
          const SizedBox(height: 12),
          Container(height: 1, color: primary.withValues(alpha: 0.1)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc.getText('total'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: onSurface),
              ),
              Text(
                '$currency ${total.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVendorSummaryRow(String label, double amount, String currency) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: onSecondaryContainer)),
        Text('$currency ${amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 14, color: onSecondaryContainer)),
      ],
    );
  }

  Widget _buildVendorStatusActions(String status) {
    final loc = AppLocalization.of(context)!;
    return Column(
      children: [
        if (status == 'pending') ...[
          Row(
            children: [
              Expanded(
                child: _buildVendorActionButton(
                  loc.getText('accept'),
                  const Color(0xFF2E7D32),
                  () => _updateStatus('confirmed'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildVendorActionButton(
                  loc.getText('reject'),
                  const Color(0xFFC62828),
                  () => _updateStatus('cancelled'),
                  outlined: true,
                ),
              ),
            ],
          ),
        ],
        if (status == 'confirmed')
          _buildVendorActionButton(loc.getText('startPreparing'), primary, () => _updateStatus('preparing'), fullWidth: true),
        if (status == 'preparing')
          _buildVendorActionButton(loc.getText('orderStatusReadyForPickup'), const Color(0xFF2E7D32), () => _updateStatus('ready_for_pickup'), fullWidth: true),
      ],
    );
  }

  Widget _buildVendorActionButton(String label, Color color, VoidCallback onPressed, {bool outlined = false, bool fullWidth = false}) {
    return UnifiedActionButton(
      label: label,
      onPressed: _statusLoading ? null : onPressed,
      color: color,
      outlined: outlined,
      fullWidth: fullWidth,
      loading: _statusLoading,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // DELIVERY CODE CARD
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildDeliveryCodeCard(String deliveryCode) {
    final loc = AppLocalization.of(context)!;
    return _glassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.vpn_key, size: 40, color: primary),
          const SizedBox(height: 12),
          Text(
            loc.getText('showCodeToCourier'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: onSecondaryContainer,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            deliveryCode,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: 8,
              color: primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            loc.getText('courierAsksForCode'),
            style: TextStyle(
              fontSize: 12,
              color: onSecondaryContainer.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ORDER STATUS TIMELINE
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildOrderStatusTimeline(String currentStatus, List<SubOrder> subOrders) {
    final loc = AppLocalization.of(context)!;
    final steps = _getStatusSteps(currentStatus);

    return _glassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.getText('orderStatus'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: onSurface,
              height: 28 / 20,
            ),
          ),
          const SizedBox(height: 24),
          ...steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final isLast = index == steps.length - 1;
            final isCompleted = step['completed'] == true;
            final isCurrent = step['current'] == true;

            return _buildTimelineStep(
              title: step['title'],
              time: step['time'],
              description: step['description'],
              isCompleted: isCompleted,
              isCurrent: isCurrent,
              isLast: isLast,
              showMap: isCurrent && currentStatus == 'with_driver',
            );
          }),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getStatusSteps(String status) {
    final loc = AppLocalization.of(context)!;
    final steps = [
      {
        'title': loc.getText('orderPlacedStep'),
        'time': '10:15 AM',
        'description': loc.getText('orderPendingDesc'),
        'status': 'pending',
      },
      {
        'title': loc.getText('orderStatusConfirmed'),
        'time': '10:22 AM',
        'description': loc.getText('orderConfirmedDesc'),
        'status': 'confirmed',
      },
      {
        'title': loc.getText('orderStatusPreparing'),
        'time': '10:30 AM',
        'description': loc.getText('orderPreparingDesc'),
        'status': 'preparing',
      },
      {
        'title': loc.getText('orderStatusReadyForPickup'),
        'time': '10:40 AM',
        'description': loc.getText('orderReadyForPickupDesc'),
        'status': 'ready_for_pickup',
      },
      {
        'title': loc.getText('orderStatusWithDriver'),
        'time': '10:45 AM',
        'description': loc.getText('withDriverDesc'),
        'status': 'with_driver',
      },
      {
        'title': loc.getText('orderStatusDelivered'),
        'time': '--:--',
        'description': loc.getText('deliveredDesc'),
        'status': 'delivered',
      },
    ];

    final statusOrder = ['pending', 'confirmed', 'preparing', 'ready_for_pickup', 'waiting_for_driver', 'with_driver', 'delivered'];
    final currentIndex = statusOrder.indexOf(status);

    return steps.asMap().entries.map((entry) {
      final step = entry.value;
      final stepStatus = step['status'] as String;
      final stepIndex = statusOrder.indexOf(stepStatus);

      return {
        ...step,
        'completed': stepIndex <= currentIndex,
        'current': stepStatus == status,
      };
    }).toList();
  }

  Widget _buildTimelineStep({
    required String title,
    required String time,
    required String description,
    required bool isCompleted,
    required bool isCurrent,
    required bool isLast,
    required bool showMap,
  }) {
    final loc = AppLocalization.of(context)!;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          SizedBox(
            width: 16,
            child: Column(
              children: [
                // Circle
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted ? primary : secondaryContainer,
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: primaryFixed.withValues(alpha: 0.8),
                              blurRadius: 0,
                              spreadRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                  child: isCurrent
                      ? const Center(
                          child: SizedBox(
                            width: 8,
                            height: 8,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
                // Line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: isCompleted ? primary : secondaryContainer,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and time
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isCompleted ? primary : onSecondaryContainer,
                        ),
                      ),
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Description
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                      color: isCurrent ? onSurface : onSecondaryContainer,
                    ),
                  ),
                  // Map for current step
                  if (showMap) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 128,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Map image
                            Positioned.fill(
                              child: Image.network(
                                _mapImage,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: surfaceContainerHigh,
                                  child: const Center(
                                    child: Icon(Icons.map_outlined, size: 48, color: Color(0x4DBA002C)),
                                  ),
                                ),
                              ),
                            ),
                            // Gradient overlay
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.2),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Live tracking badge
                            Positioned(
                              bottom: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(9999),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.speed, size: 14, color: primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      loc.getText('liveTracking'),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ORDER ITEMS SECTION
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildOrderItemsSection(List<SubOrder> subOrders, String currency) {
    final loc = AppLocalization.of(context)!;
    return _glassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.getText('orderItems'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: onSurface,
              height: 28 / 20,
            ),
          ),
          const SizedBox(height: 16),
          ...subOrders.expand((sub) => sub.items.map((item) {
            final itemMap = item.toJson();
            final variant = itemMap['variant'] as Map<String, dynamic>? ?? {};
            final product = variant['product'] as Map<String, dynamic>? ?? {};
            final name = product['title'] ?? loc.getText('product');
            final variantImages = variant['images'] as List<dynamic>? ?? [];
            final productImages = product['images'] as List<dynamic>? ?? [];
            final allImages = variantImages.isNotEmpty ? variantImages : productImages;
            final imageUrl = allImages.isNotEmpty ? allImages[0]['url'] : null;
            final attributes = variant['attributes'] as List<dynamic>? ?? [];
            final qty = itemMap['qty'] ?? 1;
            final price = (itemMap['unit_price'] ?? '0').toString();
            final totalPrice = (itemMap['total_price'] ?? '0').toString();
            final productId = product['id'];
            return GestureDetector(
              onTap: productId != null ? () => context.push('/product/$productId') : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    // Item image
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: surfaceContainerHigh,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(
                          color: outlineVariant.withValues(alpha: 0.1),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: imageUrl != null
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.fastfood, color: Color(0x4DBA002C)),
                                ),
                              )
                            : const Center(
                                child: Icon(Icons.fastfood, color: Color(0x4DBA002C)),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Item details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: onSurface,
                            ),
                          ),
                          if (attributes.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: attributes.map((attr) {
                                final attrMap = attr as Map<String, dynamic>;
                                final attrName = (attrMap['attribute'] as Map<String, dynamic>?)?['name'] ?? '';
                                final attrValue = (attrMap['option'] as Map<String, dynamic>?)?['value'] ?? attrMap['value'] ?? '';
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    attrName.isNotEmpty ? '$attrName: $attrValue' : attrValue.toString(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: primary,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            '${loc.getText('qtyLabel', params: {'qty': '$qty'})}  •  $currency ${double.tryParse(price)?.toStringAsFixed(2) ?? price}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Price
                    Text(
                      '$currency ${double.tryParse(totalPrice)?.toStringAsFixed(2) ?? totalPrice}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            );
          })),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // PRICE SUMMARY
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildPriceSummary(double subtotal, double deliveryFee, double grandTotal, String currency) {
    final loc = AppLocalization.of(context)!;
    return _glassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildSummaryRow(loc.getText('subtotal'), subtotal, currency),
          const SizedBox(height: 8),
          _buildSummaryRow(loc.getText('deliveryFee'), deliveryFee, currency),
          const SizedBox(height: 12),
          Container(
            height: 1,
            color: primary.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc.getText('total'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                  height: 28 / 20,
                ),
              ),
              Text(
                '$currency ${grandTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: primary,
                  height: 28 / 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, String currency) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: onSecondaryContainer,
          ),
        ),
        Text(
          '$currency ${amount.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 14,
            color: onSecondaryContainer,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ACTION BUTTONS
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildCancelButton() {
    final loc = AppLocalization.of(context)!;
    return UnifiedActionButton(
      label: loc.getText('cancelOrder'),
      onPressed: _isCancelling ? null : _cancelOrder,
      color: CustomerAppColors.error,
      icon: Icons.cancel_outlined,
      outlined: true,
      loading: _isCancelling,
      fullWidth: true,
    );
  }

  Widget _buildRateOrderButton(List<SubOrder> subOrders) {
    final loc = AppLocalization.of(context)!;
    return UnifiedActionButton(
      label: loc.getText('rateOrder'),
      onPressed: () => _showRatingDialog(subOrders),
      color: CustomerAppColors.accentGold,
      icon: Icons.star,
      outlined: true,
      fullWidth: true,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // RATING DIALOG
  // ═══════════════════════════════════════════════════════════════════
  void _showRatingDialog(List<SubOrder> subOrders) {
    final Map<String, Map<String, dynamic>> productsToReview = {};
    Map<String, dynamic>? storeToReview;

    for (final sub in subOrders) {
      if (storeToReview == null) {
        storeToReview = {'type': 'store', 'id': sub.storeId, 'name': 'Store'};
      }

      for (final item in sub.items) {
        final itemMap = item.toJson();
        final variant = itemMap['variant'] as Map<String, dynamic>? ?? {};
        final product = variant['product'] as Map<String, dynamic>? ?? {};
        final productId = product['id'];
        if (productId != null && !productsToReview.containsKey(productId.toString())) {
          productsToReview[productId.toString()] = {
            'type': 'product',
            'id': productId,
            'name': product['title'] ?? 'Product',
            'image': (variant['images'] as List<dynamic>?)?.isNotEmpty == true
                ? (variant['images'] as List<dynamic>)[0]['url']
                : null,
          };
        }
      }
    }

    _showNextRating(0, productsToReview.values.toList(), storeToReview, subOrders.first.id);
  }

  void _showNextRating(int index, List<Map<String, dynamic>> items, Map<String, dynamic>? store, int orderId) {
    if (index >= items.length) {
      if (store != null) {
        showDialog(
          context: context,
          builder: (context) => RatingDialog(
            type: store['type'],
            id: store['id'],
            name: store['name'],
            orderId: orderId,
            onSubmitted: () => _loadOrder(),
          ),
        );
      }
      return;
    }

    final item = items[index];
    showDialog(
      context: context,
      builder: (context) => RatingDialog(
        type: item['type'],
        id: item['id'],
        name: item['name'],
        imageUrl: item['image'],
        orderId: orderId,
        onSubmitted: () => _showNextRating(index + 1, items, store, orderId),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // GLASS CARD
  // ═══════════════════════════════════════════════════════════════════
  Widget _glassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceContainerLowest.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
