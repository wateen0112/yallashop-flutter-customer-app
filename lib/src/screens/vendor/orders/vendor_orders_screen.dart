import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:yallashop_core/yallashop_core.dart';
import '../../../config/api_config.dart';
import '../../../widgets/bottom_nav_bar.dart';
import '../../../widgets/unified_app_bar.dart';

class VendorOrdersScreen extends StatefulWidget {
  const VendorOrdersScreen({super.key});

  @override
  State<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends State<VendorOrdersScreen>
    with WidgetsBindingObserver {
  final _apiClient = ApiClient(baseUrl: CustomerApiConfig.baseUrl);
  List<dynamic> _orders = [];
  bool _isLoading = true;
  String? _error;
  String _selectedTab = 'all';
  Timer? _pollTimer;

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
        final data = (result as Success).data;
        List<dynamic> orders = [];
        if (data is List) {
          orders = data;
        } else if (data is Map<String, dynamic>) {
          orders = data['data'] as List<dynamic>? ?? [];
        }
        setState(() => _orders = orders);
      } else if (result is Failure && !silent) {
        setState(() => _error = (result as Failure).exception.message);
      }
    } catch (e) {
      if (mounted && !silent) setState(() => _error = e.toString());
    }

    if (mounted && !silent) setState(() => _isLoading = false);
  }

  Future<void> _updateStatus(int subOrderId, String status) async {
    final result = await _apiClient.put(
      '/vendor/orders/$subOrderId/status',
      data: {'status': status},
    );

    if (result is Success) {
      _loadOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalization.of(context)!.getText('statusUpdatedTo', params: {'status': _statusLabel(context, status)})),
            backgroundColor: CustomerAppColors.success,
          ),
        );
      }
    } else if (result is Failure) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text((result as Failure).exception.message), backgroundColor: CustomerAppColors.error),
        );
      }
    }
  }

  List<dynamic> get _filteredOrders {
    if (_selectedTab == 'all') return _orders;
    return _orders.where((o) => o['status'] == _selectedTab).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: UnifiedAppBar.main(
        title: AppLocalization.of(context)!.getText('vendorOrders'),
        backgroundColor: Colors.transparent,
        opaqueOnScroll: true,
        showNotification: true,
        showUserAvatar: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 80),
          _buildTabBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError()
                    : _filteredOrders.isEmpty
                        ? _buildEmpty()
                        : _buildOrdersList(),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 3),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 100,
      padding: const EdgeInsets.only(left: 16,top: 14,right: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _tab('all', AppLocalization.of(context)!.getText('all')),
          _tab('pending', AppLocalization.of(context)!.getText('orderStatusPending')),
          _tab('confirmed', AppLocalization.of(context)!.getText('orderStatusConfirmed')),
          _tab('preparing', AppLocalization.of(context)!.getText('orderStatusPreparing')),
          _tab('ready_for_pickup', AppLocalization.of(context)!.getText('ready')),
          _tab('cancelled', AppLocalization.of(context)!.getText('orderStatusCancelled')),
        ],
      ),
    );
  }

  Widget _tab(String value, String label) {
    final isSelected = _selectedTab == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedTab = value),
        selectedColor: CustomerAppColors.primary,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : CustomerAppColors.onSurface,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: CustomerAppColors.error),
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: CustomerAppColors.error)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadOrders, child: Text(AppLocalization.of(context)!.getText('retry'))),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 64, color: CustomerAppColors.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(AppLocalization.of(context)!.getText('noOrders'), style: TextStyle(color: CustomerAppColors.textSecondary, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredOrders.length,
        itemBuilder: (context, index) {
          final order = _filteredOrders[index] as Map<String, dynamic>;
          return _OrderCard(
            order: order,
            onViewDetail: () => context.push('/vendor-order/${order['id']}'),
            onAccept: () => _updateStatus(order['id'], 'confirmed'),
            onReject: () => _updateStatus(order['id'], 'cancelled'),
            onPrepare: () => _updateStatus(order['id'], 'preparing'),
            onReady: () => _updateStatus(order['id'], 'ready_for_pickup'),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onViewDetail;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onPrepare;
  final VoidCallback onReady;

  const _OrderCard({
    required this.order,
    required this.onViewDetail,
    required this.onAccept,
    required this.onReject,
    required this.onPrepare,
    required this.onReady,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalization.of(context)!;
    final status = order['status'] as String? ?? 'pending';
    final orderId = order['order_id'] ?? '#${order['id']}';
    final customerName = order['customer_name'] ?? loc.getText('customer');
    final totalAmount = _toDouble(order['total_amount'] ?? 0);
    final itemsCount = order['items_count'] ?? 0;
    final createdAt = order['created_at'] as String?;
    final currency = ((order['currency_snapshot'] ?? order['currency']) as Map<String, dynamic>?)?['symbol'] ?? 'SAR';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onViewDetail,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$orderId', style: AppTypography.body14.copyWith(fontWeight: FontWeight.w700)),
                  _StatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: CustomerAppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(customerName, style: AppTypography.body14),
                  const Spacer(),
                  Text(loc.getText('xItems', params: {'count': '$itemsCount'}), style: AppTypography.caption12.copyWith(color: CustomerAppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$currency ${totalAmount.toStringAsFixed(2)}', style: AppTypography.h2_18.copyWith(color: CustomerAppColors.primary, fontWeight: FontWeight.w700)),
                  if (createdAt != null) Text(_formatDate(createdAt), style: AppTypography.caption12.copyWith(color: CustomerAppColors.textSecondary)),
                ],
              ),
              if (status == 'pending') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: ElevatedButton(onPressed: onAccept, style: ElevatedButton.styleFrom(backgroundColor: CustomerAppColors.success), child: Text(loc.getText('accept')))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton(onPressed: onReject, style: OutlinedButton.styleFrom(foregroundColor: CustomerAppColors.error, side: const BorderSide(color: CustomerAppColors.error)), child: Text(loc.getText('reject')))),
                  ],
                ),
              ],
              if (status == 'confirmed') ...[
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: onPrepare, child: Text(loc.getText('startPreparing')))),
              ],
              if (status == 'preparing') ...[
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: onReady, style: ElevatedButton.styleFrom(backgroundColor: CustomerAppColors.success), child: Text(loc.getText('orderStatusReadyForPickup')))),
              ],
            ],
          ),
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
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _getColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getColor().withOpacity(0.3)),
      ),
      child: Text(
        _statusLabel(context, status).toUpperCase(),
        style: TextStyle(color: _getColor(), fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Color _getColor() {
    switch (status) {
      case 'pending': return CustomerAppColors.warning;
      case 'confirmed': return CustomerAppColors.primary;
      case 'preparing': return CustomerAppColors.primary;
      case 'ready_for_pickup': return CustomerAppColors.success;
      case 'cancelled': return CustomerAppColors.error;
      default: return CustomerAppColors.textSecondary;
    }
  }
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

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}