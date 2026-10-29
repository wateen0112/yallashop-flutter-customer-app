import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:yallashop_core/yallashop_core.dart';

import '../../config/api_config.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/unified_action_button.dart';
import '../../widgets/unified_app_bar.dart';

List<dynamic> _extractList(dynamic payload) {
  if (payload is List) return payload;
  if (payload is Map<String, dynamic> && payload.containsKey('data')) {
    final inner = payload['data'];
    if (inner is List) return inner;
    if (inner is Map<String, dynamic> && inner.containsKey('data') && inner['data'] is List) {
      return inner['data'] as List<dynamic>;
    }
  }
  return [];
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with WidgetsBindingObserver {
  final _apiClient = ApiClient(baseUrl: CustomerApiConfig.baseUrl);
  List<Order> _orders = [];
  bool _isLoading = true;
  String _selectedTab = 'ongoing';
  Timer? _pollTimer;

  // ── HTML color palette ──
  static const _primary = Color(0xFFBA002C);
  static const _trackBtn = Color(0xFFFF4155);
  static const _onSurface = Color(0xFF151C27);
  static const _onSurfaceVariant = Color(0xFF5C403F);
  static const _surfaceContainerLowest = Color(0xFFFFFFFF);
  static const _surfaceContainer = Color(0xFFE7EEFE);
  static const _surfaceContainerHigh = Color(0xFFE2E8F8);
  static const _primaryFixed = Color(0xFFFFDAD9);
  static const _outlineVariant = Color(0xFFE5BDBC);
  static const _background = Color(0xFFF9F9FF);

  static const _bgImage =
      'https://lh3.googleusercontent.com/aida/AP1WRLuFHvA6DuJAhqv57RGAplxC5T_6PWZYMT6Oab6Lw814WiacRP1SjRb8iRwIHEvtoUyCmzE-un2s8hf7ZmQWOq4pxzk2KJVrzRqhFMj6HU1NLEn8BIrKF9i9lZVNrchZzSRzeaimrwbg8CAVnyQzwneCNip9TShTTk5wXx_rGlTBA9mmAGSCGku_CI1Qwe_ppWNefIePHNrhR2p4RuarhLuowex9KyEqT16Xpkj25vLRijZzPLLcF8VUk7xn';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadOrders();
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
      _loadOrders(silent: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (mounted) _loadOrders(silent: true);
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) _loadOrders(silent: true);
    });
  }

  Future<void> _loadOrders({bool silent = false}) async {
    if (!mounted) return;
    if (silent && _isLoading) return;
    if (!silent) setState(() => _isLoading = true);
    try {
      final result = await _apiClient.get<dynamic>('/orders');
      if (!mounted) return;
      if (result is Success) {
        final rawList = _extractList(result.data);
        final orders = rawList
            .map((e) => Order.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() {
          _orders = orders;
          _isLoading = false;
        });
      } else if (!silent) {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (!silent) setState(() => _isLoading = false);
    }
  }

  String _getEffectiveStatus(Order order) {
    if (order.subOrders != null && order.subOrders!.isNotEmpty) {
      return order.subOrders!.first.status;
    }
    return order.status;
  }

  List<Order> _filteredOrders() {
    switch (_selectedTab) {
      case 'ongoing':
        return _orders
            .where((o) => !['delivered', 'cancelled']
                .contains(_getEffectiveStatus(o)))
            .toList();
      case 'delivered':
        return _orders
            .where((o) => _getEffectiveStatus(o) == 'delivered')
            .toList();
      case 'cancelled':
        return _orders
            .where((o) => _getEffectiveStatus(o) == 'cancelled')
            .toList();
      default:
        return _orders;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final loc = AppLocalization.of(context)!;

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      backgroundColor: _background,
      appBar: UnifiedAppBar.main(
        title: loc.getText('myOrders'),
        subtitle: loc.getText('ordersSubtitle'),
        showNotification: true,
        showUserAvatar: true,
        backgroundColor: Colors.transparent,
        opaqueOnScroll: true,
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
          _isLoading
              ? _buildShimmer()
              : RefreshIndicator(
                  onRefresh: _loadOrders,
                  color: _primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20, topPadding + 72 + 16, 20, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTabNavigation(),
                        const SizedBox(height: 24),
                        _buildOngoingContent(),
                      ],
                    ),
                  ),
                ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 3),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB NAVIGATION (pill style)
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildTabNavigation() {
    final loc = AppLocalization.of(context)!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _surfaceContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              _buildTab('ongoing', loc.getText('ongoing')),
              _buildTab('delivered', loc.getText('delivered')),
              _buildTab('cancelled', loc.getText('cancelled')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(String key, String label) {
    final sel = _selectedTab == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: sel
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: sel ? _primary : _onSurfaceVariant,
              height: 20 / 14,
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ONGOING TAB CONTENT
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildOngoingContent() {
    final orders = _filteredOrders();
    return Column(
      children: [
        if (orders.isNotEmpty)
          ...orders.map((o) => _buildOrderCard(o)),
        if (orders.isNotEmpty) const SizedBox(height: 16),
        _buildBentoHints(),
        const SizedBox(height: 16),
        _buildEmptyState(),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // GLASS CARD
  // ═══════════════════════════════════════════════════════════════════
  Widget _glassCard({required Widget child, bool dashed = false}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surfaceContainerLowest.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
            border: dashed
                ? Border.all(
                    color: _outlineVariant.withValues(alpha: 0.3),
                    width: 2,
                  )
                : Border.all(color: Colors.white.withValues(alpha: 0.3)),
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

  // ═══════════════════════════════════════════════════════════════════
  // ORDER CARD
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildOrderCard(Order order) {
    final loc = AppLocalization.of(context)!;
    final firstSub = order.subOrders?.isNotEmpty == true
        ? order.subOrders!.first
        : null;
    final effStatus = _getEffectiveStatus(order);
    final storeName =
        firstSub?.deliveryAddressSnapshot?['label'] ?? 'Burger Prime Express';
    final firstItem =
        firstSub?.items.isNotEmpty == true ? firstSub?.items.first : null;
    final productImage = firstItem?.productImage;
    final itemCount = firstSub?.items.length ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _glassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: image + name + status ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: _surfaceContainerHigh,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: productImage != null && productImage.isNotEmpty
                      ? Image.network(productImage,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildPlaceholderImage())
                      : _buildPlaceholderImage(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(storeName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: _onSurface,
                            height: 28 / 20,
                          )),
                      const SizedBox(height: 2),
                      Text('#${order.orderNumber}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: _onSurfaceVariant,
                            height: 20 / 14,
                          )),
                    ],
                  ),
                ),
                _buildStatusBadge(effStatus),
              ],
            ),

            const SizedBox(height: 16),

            // ── Date & item count ──
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                      color: _outlineVariant.withValues(alpha: 0.2)),
                  bottom: BorderSide(
                      color: _outlineVariant.withValues(alpha: 0.2)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(loc.getText('orderDateLabel').toUpperCase(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _onSurfaceVariant,
                              height: 16 / 12,
                              letterSpacing: 0.5,
                            )),
                        const SizedBox(height: 4),
                        Text(
                          order.placedAt != null
                              ? _formatDate(order.placedAt!)
                              : '-',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _onSurface,
                            height: 24 / 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(loc.getText('itemCountLabel').toUpperCase(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _onSurfaceVariant,
                              height: 16 / 12,
                              letterSpacing: 0.5,
                            )),
                        const SizedBox(height: 4),
                        Text(
                          itemCount == 1
                              ? '1 ${loc.getText('item')}'
                              : loc.getText('xItems', params: {'count': '$itemCount'}),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _onSurface,
                            height: 24 / 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Buttons ──
            UnifiedActionButton(
              label: loc.getText('trackOrder'),
              onPressed: () => context.push('/order/${order.id}'),
              color: _primary,
              outlined: true,
              fullWidth: true,
            ),
            const SizedBox(height: 8),
            UnifiedActionButton(
              label: loc.getText('orderDetails'),
              onPressed: () => context.push('/order/${order.id}'),
              color: _primary,
              outlined: true,
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // STATUS BADGE
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildStatusBadge(String status) {
    final isActive = !['delivered', 'cancelled'].contains(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _primaryFixed.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive) ...[
            const _PulsingDot(color: _primary),
            const SizedBox(width: 6),
          ],
          Text(
            _getStatusLabel(status),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _primary,
              height: 16 / 12,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(String status) {
    final loc = AppLocalization.of(context)!;
    switch (status) {
      case 'pending':
        return loc.getText('orderStatusPending');
      case 'confirmed':
        return loc.getText('orderStatusConfirmed');
      case 'preparing':
        return loc.getText('orderStatusPreparing');
      case 'ready_for_pickup':
        return loc.getText('orderStatusReadyForPickup');
      case 'waiting_for_driver':
        return loc.getText('orderStatusWaitingForDriver');
      case 'with_driver':
        return loc.getText('orderStatusWithDriver');
      case 'picked_up':
        return loc.getText('orderStatusPickedUp');
      case 'out_for_delivery':
        return loc.getText('orderStatusOutForDelivery');
      case 'delivered':
        return loc.getText('orderStatusDelivered');
      case 'cancelled':
        return loc.getText('orderStatusCancelled');
      default:
        return status;
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: _surfaceContainer,
      child: const Center(
        child: Icon(Icons.shopping_bag_outlined, size: 28, color: _primary),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // BENTO HINT CARDS
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildBentoHints() {
    final loc = AppLocalization.of(context)!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _glassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.help_center, size: 24, color: _primary),
                const SizedBox(height: 8),
                Text(loc.getText('needHelp'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _onSurface,
                      height: 20 / 14,
                    )),
                const SizedBox(height: 2),
                Text(loc.getText('chatWithSupport'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _onSurfaceVariant,
                      height: 16 / 12,
                    )),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _glassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.receipt_long, size: 24, color: _trackBtn),
                const SizedBox(height: 8),
                Text(loc.getText('downloadReceipt'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _onSurface,
                      height: 20 / 14,
                    )),
                const SizedBox(height: 2),
                Text(loc.getText('pdfVersion'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _onSurfaceVariant,
                      height: 16 / 12,
                    )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // EMPTY STATE (dashed card)
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildEmptyState() {
    final loc = AppLocalization.of(context)!;
    return _glassCard(
      dashed: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.history,
                  size: 36, color: _outlineVariant.withValues(alpha: 0.6)),
              const SizedBox(height: 8),
              Text(loc.getText('noOtherOngoingOrders'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _onSurfaceVariant,
                    height: 20 / 14,
                  )),
              const SizedBox(height: 4),
              Text(
                loc.getText('checkDeliveredForHistory'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _onSurfaceVariant.withValues(alpha: 0.7),
                  height: 16 / 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // SHIMMER LOADING
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 72 + 16, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 28, width: 150, color: Colors.white),
            const SizedBox(height: 8),
            Container(height: 16, width: 220, color: Colors.white),
            const SizedBox(height: 24),
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: List.generate(
                2,
                (i) => Expanded(
                  child: Container(
                    height: 80,
                    margin: EdgeInsets.only(right: i == 0 ? 12 : 0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// PULSING DOT
// ═══════════════════════════════════════════════════════════════════════
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: _animation.value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
