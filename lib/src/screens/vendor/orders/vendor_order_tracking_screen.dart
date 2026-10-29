import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:yallashop_core/yallashop_core.dart';
import '../../../config/api_config.dart';
import '../../../widgets/unified_app_bar.dart';

class VendorOrderTrackingScreen extends StatefulWidget {
  final String orderId;
  const VendorOrderTrackingScreen({super.key, required this.orderId});

  @override
  State<VendorOrderTrackingScreen> createState() => _VendorOrderTrackingScreenState();
}

class _VendorOrderTrackingScreenState extends State<VendorOrderTrackingScreen>
    with WidgetsBindingObserver {
  final _apiClient = ApiClient(baseUrl: CustomerApiConfig.baseUrl);
  Map<String, dynamic>? _order;
  bool _isLoading = true;
  bool _statusLoading = false;
  String? _error;
  Timer? _pollTimer;

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

  static const _timelineSteps = [
    'pending',
    'confirmed',
    'preparing',
    'ready_for_pickup',
    'waiting_for_driver',
    'with_driver',
    'delivered',
  ];

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

  Future<void> _loadOrder({bool silent = false}) async {
    if (!mounted) return;
    if (silent && _isLoading) return;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final result = await _apiClient.get<dynamic>('/vendor/orders');
      if (!mounted) return;

      if (result is Success) {
        final data = result.data;
        List<dynamic> orders = [];
        if (data is List) {
          orders = data;
        } else if (data is Map<String, dynamic>) {
          orders = data['data'] as List<dynamic>? ?? [];
        }

        final found = orders.firstWhere(
          (o) => '${(o as Map)['id']}' == widget.orderId,
          orElse: () => null,
        );

        if (found != null && mounted) {
          setState(() => _order = found as Map<String, dynamic>);
        } else if (mounted) {
          setState(() => _error = AppLocalization.of(context)!.getText('orderNotFound'));
        }
      } else if (result is Failure && !silent) {
        if (mounted) setState(() => _error = result.exception.message);
      }
    } catch (e) {
      if (mounted && !silent) setState(() => _error = e.toString());
    }

    if (mounted && !silent) setState(() => _isLoading = false);
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _statusLoading = true);
    final result = await _apiClient.put(
      '/vendor/orders/${widget.orderId}/status',
      data: {'status': status},
    );

    if (result is Success) {
      _loadOrder();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalization.of(context)!.getText('statusUpdatedTo', params: {'status': _stepLabel(context, status)})),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: background,
        body: Center(child: CircularProgressIndicator(color: primary)),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(0xFFD32F2F)),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Color(0xFFD32F2F))),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadOrder,
                style: ElevatedButton.styleFrom(backgroundColor: primary),
                child: Text(AppLocalization.of(context)!.getText('retry'), style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final order = _order;
    if (order == null) {
      return Scaffold(
        backgroundColor: background,
        body: Center(child: Text(AppLocalization.of(context)!.getText('orderNotFound'))),
      );
    }

    final loc = AppLocalization.of(context)!;
    final status = order['status'] as String? ?? 'pending';
    final orderId = '${order['order_number'] ?? order['order_id'] ?? '#${order['id']}'}';
    final totalAmount = _toDouble(order['grand_total'] ?? order['total_amount'] ?? 0);
    final deliveryFee = _toDouble(order['delivery_fee'] ?? order['delivery_fee_total'] ?? 0);
    final items = order['items'] as List<dynamic>? ?? [];
    final courier = order['courier'] as Map<String, dynamic>?;
    final createdAt = order['created_at'] as String?;
    final customerName = order['customer_name'] as String?;
    final customerEmail = order['customer_email'] as String?;
    final pickupCode = order['pickup_code'] as String?;
    final deliveryAddress = order['delivery_address_snapshot'] as Map<String, dynamic>?;
    final subtotal = totalAmount - deliveryFee;
    final currency = ((order['currency_snapshot'] ?? order['currency']) as Map<String, dynamic>?)?['symbol'] ?? 'SAR';

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
                _buildOrderInfoHeader(orderId, status, customerName, customerEmail, createdAt),
                const SizedBox(height: 16),
                _buildTimelineSection(status),
                if (deliveryAddress != null) ...[
                  const SizedBox(height: 16),
                  _buildDeliveryAddress(deliveryAddress),
                ],
                if (pickupCode != null) ...[
                  const SizedBox(height: 16),
                  _buildCodeCard(loc.getText('pickupCode'), pickupCode),
                ],
                if (courier != null) ...[
                  const SizedBox(height: 16),
                  _buildCourierCard(courier),
                ],
                const SizedBox(height: 16),
                _buildOrderItems(items, currency),
                const SizedBox(height: 16),
                _buildPriceSummary(subtotal, deliveryFee, totalAmount, currency),
                const SizedBox(height: 16),
                _buildStatusActions(status),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfoHeader(
    String orderId,
    String status,
    String? customerName,
    String? customerEmail,
    String? createdAt,
  ) {
    final loc = AppLocalization.of(context)!;
    return _glassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInfoField(loc.getText('orderIdLabel'), orderId),
              ),
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
                  _buildStatusPill(context, status),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (customerName != null) ...[
            _buildInfoField(loc.getText('customer'), customerName),
            if (customerEmail != null) ...[
              const SizedBox(height: 8),
              Text(
                customerEmail,
                style: TextStyle(
                  fontSize: 13,
                  color: onSecondaryContainer,
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
          if (createdAt != null) _buildInfoField(loc.getText('date'), _formatDate(createdAt)),
        ],
      ),
    );
  }

  Widget _buildInfoField(String label, String value) {
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

  Widget _buildStatusPill(BuildContext context, String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        _statusLabel(context, status).toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  String _statusLabel(BuildContext context, String status) {
    final loc = AppLocalization.of(context)!;
    switch (status) {
      case 'pending': return loc.getText('orderStatusPending');
      case 'confirmed': return loc.getText('orderStatusConfirmed');
      case 'preparing': return loc.getText('orderStatusPreparing');
      case 'ready_for_pickup': return loc.getText('ready');
      case 'waiting_for_driver': return loc.getText('orderStatusWaitingForDriver');
      case 'with_driver': return loc.getText('orderStatusWithDriver');
      case 'delivered': return loc.getText('orderStatusDelivered');
      case 'cancelled': return loc.getText('orderStatusCancelled');
      default: return status.replaceAll('_', ' ').toUpperCase();
    }
  }

  Color _statusColor(String status) {
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

  // Timeline
  Widget _buildTimelineSection(String status) {
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
              AppLocalization.of(context)!.getText('orderCancelled'),
              style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: onSurface,
              ),
            ),
          ],
        ),
      );
    }

    final currentIdx = _timelineSteps.indexOf(status);
    final isTerminal = status == 'delivered';

    return _glassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalization.of(context)!.getText('orderTimeline').toUpperCase(),
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: primary, letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(_timelineSteps.length, (i) {
            final step = _timelineSteps[i];
            final completed = isTerminal || i < currentIdx;
            final active = !isTerminal && i == currentIdx;
            final isLast = i == _timelineSteps.length - 1;

            return _buildTimelineStep(
              label: _stepLabel(context, step),
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

  String _stepLabel(BuildContext context, String step) {
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

  Widget _buildTimelineStep({
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

  // Delivery Address
  Widget _buildDeliveryAddress(Map<String, dynamic> address) {
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
            loc.getText('deliveryAddress').toUpperCase(),
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
                        Text(
                          line,
                          style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500, color: onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ],
                    if (phone != null && phone.isNotEmpty) ...[
                      Text(
                        loc.getText('phoneLabel', params: {'phone': phone}),
                        style: TextStyle(fontSize: 13, color: onSecondaryContainer),
                      ),
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

  // Code Card
  Widget _buildCodeCard(String label, String code) {
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

  // Courier Card
  Widget _buildCourierCard(Map<String, dynamic> courier) {
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
                      style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600, color: onSurface,
                      ),
                    ),
                    if (courier['phone'] != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        courier['phone'],
                        style: TextStyle(fontSize: 13, color: onSecondaryContainer),
                      ),
                    ],
                  ],
                ),
              ),
              Row(
                children: [
                  _buildCircleIcon(Icons.call, primary, Colors.white),
                  const SizedBox(width: 8),
                  _buildCircleIcon(Icons.chat, surfaceContainerHigh, primary),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircleIcon(IconData icon, Color bg, Color iconColor) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, color: iconColor, size: 20),
    );
  }

  // Order Items
  Widget _buildOrderItems(List<dynamic> items, String currency) {
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
            Text(
              loc.getText('noItems'),
              style: TextStyle(fontSize: 14, color: onSecondaryContainer),
            )
          else
            ...items.map((item) => _buildOrderItem(item, currency)),
        ],
      ),
    );
  }

  Widget _buildOrderItem(dynamic item, String currency) {
    final loc = AppLocalization.of(context)!;
    final itemMap = item as Map<String, dynamic>;
    final name = itemMap['name'] ?? itemMap['product_name'] ?? loc.getText('item');
    final qty = itemMap['qty'] ?? itemMap['quantity'] ?? 1;
    final price = _toDouble(itemMap['total_price'] ?? itemMap['price'] ?? 0);
    final unitPrice = _toDouble(itemMap['unit_price'] ?? price);
    final imageUrl = itemMap['image_url'] as String? ?? itemMap['product_image'] as String?;
    final options = itemMap['options'] as String? ?? '';

    final variant = itemMap['variant'] as Map<String, dynamic>?;
    final product = variant?['product'] as Map<String, dynamic>?;
    final displayName = product?['title'] ?? name;
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

  // Price Summary
  Widget _buildPriceSummary(double subtotal, double deliveryFee, double total, String currency) {
    final loc = AppLocalization.of(context)!;
    return _glassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildSummaryRow(loc.getText('subtotal'), subtotal, currency),
          const SizedBox(height: 8),
          _buildSummaryRow(loc.getText('deliveryFee'), deliveryFee, currency),
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

  Widget _buildSummaryRow(String label, double amount, String currency) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: onSecondaryContainer)),
        Text('$currency ${amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 14, color: onSecondaryContainer)),
      ],
    );
  }

  // Status Actions
  Widget _buildStatusActions(String status) {
    final loc = AppLocalization.of(context)!;
    return Column(
      children: [
        if (status == 'pending') ...[
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  loc.getText('accept'),
                  const Color(0xFF2E7D32),
                  () => _updateStatus('confirmed'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
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
          _buildActionButton(loc.getText('startPreparing'), primary, () => _updateStatus('preparing'), fullWidth: true),
        if (status == 'preparing')
          _buildActionButton(loc.getText('orderStatusReadyForPickup'), const Color(0xFF2E7D32), () => _updateStatus('ready_for_pickup'), fullWidth: true),
        const SizedBox(height: 12),
        _buildContactSupport(),
      ],
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onPressed, {bool outlined = false, bool fullWidth = false}) {
    final widget = SizedBox(
      height: 48,
      child: TextButton(
        onPressed: _statusLoading ? null : onPressed,
        style: TextButton.styleFrom(
          backgroundColor: outlined ? Colors.transparent : color,
          foregroundColor: outlined ? color : Colors.white,
          side: outlined ? BorderSide(color: color, width: 2) : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _statusLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    );

    if (fullWidth) return SizedBox(width: double.infinity, child: widget);
    return widget;
  }

  Widget _buildContactSupport() {
    final loc = AppLocalization.of(context)!;
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primary.withValues(alpha: 0.2), width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.support_agent, color: primary, size: 20),
            const SizedBox(width: 8),
            Text(
              loc.getText('contactSupport'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: primary),
            ),
          ],
        ),
      ),
    );
  }

  // Glass Card
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
