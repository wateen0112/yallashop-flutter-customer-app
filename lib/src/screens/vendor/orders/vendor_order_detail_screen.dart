import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:yallashop_core/yallashop_core.dart';
import '../../../config/api_config.dart';
import '../../../widgets/unified_app_bar.dart';

class VendorOrderDetailScreen extends StatefulWidget {
  final String orderId;
  const VendorOrderDetailScreen({super.key, required this.orderId});

  @override
  State<VendorOrderDetailScreen> createState() => _VendorOrderDetailScreenState();
}

class _VendorOrderDetailScreenState extends State<VendorOrderDetailScreen>
    with WidgetsBindingObserver {
  final _apiClient = ApiClient(baseUrl: CustomerApiConfig.baseUrl);
  Map<String, dynamic>? _order;
  bool _isLoading = true;
  String? _error;
  Timer? _pollTimer;

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
  static const _courierAvatar =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuAMHJs0WGQd50OOja-l9d71PBV41X_BoMQxSlmTtOyfUNVeX6n_oiiljjZTD66aRsGqUQyF0XiWpVSKn3kCAGjhnY3Sj_BDDfKrgPTDzrUW5DW-RHggeIDtLT_Jsut5iTh8qG0EWrL8j-CjzS3xKWDKMQn-my-oRo4y8UPKLQpY9pKd_J7-eapVU1TE-vi4SfekHCI2O0l4iY5sauACv4wKGsXQGAcqIaB8y-Q8MF2EolRAh35h6wBx9tiENx7v13mXPzj3McdkIWSD';
  static const _mapImage =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuC5J7axCZE59VxuK_XBIDBJZt8NCoya_-VOHCItwJII9Q9AdmgJv-szriP4AC9VPyHS31BbQZWRGheDB22-texNZLphMS7-Y6IiQ3vIs6hc8FT9LnMAaOTaf-9YCAejGkn2YRBeL0mR2DJaXo0iI8UsOR3Du86_QgheSn9Ge99SUrzAGAyZj4_JtqQ7Bi9clXekLS5BkxehuWu4L7RHO0c-Iqng8cNB-21YNtQbgXPYp1OXQbzQ9FaU857qRceXvjtyovPOc3NUIx5H';

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
    final result = await _apiClient.put(
      '/vendor/orders/${widget.orderId}/status',
      data: {'status': status},
    );

    if (result is Success) {
      _loadOrder();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalization.of(context)!.getText('statusUpdatedTo', params: {'status': _getStatusBadgeLabel(context, status)})),
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

    final status = order['status'] as String? ?? 'pending';
    final orderId = '${order['order_number'] ?? order['order_id'] ?? '#${order['id']}'}';
    final totalAmount = _toDouble(order['grand_total'] ?? order['total_amount'] ?? 0);
    final deliveryFee = _toDouble(order['delivery_fee'] ?? order['delivery_fee_total'] ?? 0);
    final items = order['items'] as List<dynamic>? ?? [];
    final courier = order['courier'] as Map<String, dynamic>?;
    final createdAt = order['created_at'] as String?;
    final currency = ((order['currency_snapshot'] ?? order['currency']) as Map<String, dynamic>?)?['symbol'] ?? 'SAR';

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      backgroundColor: background,
      appBar: UnifiedAppBar.detail(
        title: '#$orderId',
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
                _buildCourierAssignedCard(courier, status),
                const SizedBox(height: 16),
                _buildOrderStatusTimeline(status, createdAt),
                const SizedBox(height: 16),
                _buildOrderItemsSection(items, totalAmount, deliveryFee, currency),
                const SizedBox(height: 16),
                _buildContactSupportButton(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // COURIER ASSIGNED CARD
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildCourierAssignedCard(Map<String, dynamic>? courier, String status) {
    final loc = AppLocalization.of(context)!;
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc.getText('courierAssigned').toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: primary,
                  letterSpacing: 1,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  _getStatusBadgeLabel(context, status),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Courier info
          Row(
            children: [
              // Avatar with ring
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: primaryFixed, width: 4),
                ),
                child: ClipOval(
                  child: Image.network(
                    _courierAvatar,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: surfaceContainerHigh,
                      child: const Icon(Icons.person, color: primary),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Courier details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      courier?['name'] ?? loc.getText('courier'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: onSurface,
                        height: 28 / 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.stars, size: 16, color: onSecondaryContainer),
                        const SizedBox(width: 4),
                        Text(
                          '${courier?['rating'] ?? '4.9'} (${loc.getText('deliveries', params: {'count': '${courier?['deliveries'] ?? '2,400+'}'})})',
                          style: const TextStyle(
                            fontSize: 14,
                            color: onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Action buttons
              Row(
                children: [
                  _buildActionButton(
                    icon: Icons.call,
                    bgColor: primary,
                    iconColor: Colors.white,
                    onTap: () {},
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    icon: Icons.chat,
                    bgColor: surfaceContainerHigh,
                    iconColor: primary,
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
    );
  }

  String _getStatusBadgeLabel(BuildContext context, String status) {
    final loc = AppLocalization.of(context)!;
    switch (status) {
      case 'pending':
        return loc.getText('orderStatusPending');
      case 'confirmed':
        return loc.getText('orderStatusConfirmed');
      case 'preparing':
        return loc.getText('orderStatusPreparing');
      case 'ready_for_pickup':
        return loc.getText('ready');
      case 'waiting_for_driver':
        return loc.getText('orderStatusWaitingForDriver');
      case 'with_driver':
      case 'picked_up':
      case 'out_for_delivery':
        return loc.getText('inTransit');
      case 'delivered':
        return loc.getText('orderStatusDelivered');
      case 'cancelled':
        return loc.getText('orderStatusCancelled');
      default:
        return status;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // ORDER STATUS TIMELINE
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildOrderStatusTimeline(String currentStatus, String? createdAt) {
    final loc = AppLocalization.of(context)!;
    final steps = _getStatusSteps(context, currentStatus);

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
              showMap: isCurrent,
            );
          }),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getStatusSteps(BuildContext context, String status) {
    final loc = AppLocalization.of(context)!;
    final steps = [
      {
        'title': loc.getText('orderPending'),
        'time': '10:15 AM',
        'description': loc.getText('orderPendingDesc'),
        'status': 'pending',
      },
      {
        'title': loc.getText('courierAssigned'),
        'time': '10:22 AM',
        'description': loc.getText('courierAssignedDesc'),
        'status': 'confirmed',
      },
      {
        'title': loc.getText('withDriver'),
        'time': '10:45 AM',
        'description': loc.getText('withDriverDesc'),
        'status': 'preparing',
      },
      {
        'title': loc.getText('orderStatusDelivered'),
        'time': '--:--',
        'description': loc.getText('deliveredDesc'),
        'status': 'delivered',
      },
    ];

    final statusOrder = ['pending', 'confirmed', 'preparing', 'ready_for_pickup', 'delivered'];
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
  Widget _buildOrderItemsSection(List<dynamic> items, double totalAmount, double deliveryFee, String currency) {
    final loc = AppLocalization.of(context)!;
    final subtotal = totalAmount - deliveryFee;

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
          // Items list
          if (items.isEmpty)
            Text(
              loc.getText('noItems'),
              style: const TextStyle(
                fontSize: 14,
                color: onSecondaryContainer,
              ),
            )
          else
            ...items.map((item) => _buildOrderItem(item, currency)),
          // Summary
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: primary.withValues(alpha: 0.1)),
              ),
            ),
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
                      '$currency ${totalAmount.toStringAsFixed(2)}',
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
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(dynamic item, String currency) {
    final loc = AppLocalization.of(context)!;
    final name = item['name'] ?? item['product_name'] ?? loc.getText('item');
    final qty = item['qty'] ?? item['quantity'] ?? 1;
    final options = item['options'] ?? '';
    final price = _toDouble(item['total_price'] ?? item['price'] ?? 0);
    final imageUrl = item['image_url'] ?? item['product_image'] as String?;

    return Padding(
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
                const SizedBox(height: 4),
                Text(
                  '${loc.getText('qtyLabel', params: {'qty': '$qty'})}${options.toString().isNotEmpty ? ' • $options' : ''}',
                  style: const TextStyle(
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
            '$currency ${price.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: onSurface,
            ),
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
  // CONTACT SUPPORT BUTTON
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildContactSupportButton() {
    final loc = AppLocalization.of(context)!;
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: primary.withValues(alpha: 0.2),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.support_agent, color: primary, size: 24),
            const SizedBox(width: 8),
            Text(
              loc.getText('contactSupport'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: primary,
              ),
            ),
          ],
        ),
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

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
