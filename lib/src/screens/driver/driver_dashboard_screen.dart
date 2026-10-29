import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:yallashop_core/yallashop_core.dart';
import '../../config/api_config.dart';
import '../../widgets/bottom_nav_bar.dart';

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

String? _itemImage(Map<String, dynamic>? item) {
  if (item == null) return null;
  final variant = item['variant'] as Map<String, dynamic>?;
  final product = variant?['product'] as Map<String, dynamic>?;
  final variantImages = variant?['images'] as List<dynamic>? ?? [];
  final productImages = product?['images'] as List<dynamic>? ?? [];
  final allImages = variantImages.isNotEmpty ? variantImages : productImages;
  if (allImages.isEmpty) return null;
  final img = allImages.first;
  if (img is Map<String, dynamic>) return img['url']?.toString();
  return null;
}

String _driverStatusLabel(BuildContext context, String status) {
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
      return status.replaceAll('_', ' ');
  }
}

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen>
    with WidgetsBindingObserver {
  final _apiClient = ApiClient(baseUrl: CustomerApiConfig.baseUrl);
  bool _isLoading = true;
  bool _isOnline = false;
  Map<String, dynamic>? _earnings;
  List<dynamic> _availableTasks = [];
  List<dynamic> _activeTasks = [];
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
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
      _loadData(silent: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (mounted) _loadData(silent: true);
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) _loadData(silent: true);
    });
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!mounted) return;
    if (silent && _isLoading) return;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final statusResult = await _apiClient.get<dynamic>('/courier/status');
      final tasksResult = await _apiClient.get<dynamic>('/courier/tasks');
      final activeResult = await _apiClient.get<dynamic>('/courier/tasks/active');
      final earningsResult = await _apiClient.get<dynamic>('/courier/earnings');

      if (!mounted) return;

      if (statusResult is Success) {
        final data = (statusResult as Success).data;
        if (data is Map<String, dynamic>) {
          _isOnline = data['status'] == 'online';
        }
      } else if (statusResult is Failure) {
        _error ??= (statusResult as Failure).exception.message;
      }

      if (tasksResult is Success) {
        final data = (tasksResult as Success).data;
        _availableTasks = _extractList(data);
      } else if (tasksResult is Failure) {
        _error ??= (tasksResult as Failure).exception.message;
      }

      if (activeResult is Success) {
        final data = (activeResult as Success).data;
        _activeTasks = _extractList(data);
      } else if (activeResult is Failure) {
        _error ??= (activeResult as Failure).exception.message;
      }

      if (earningsResult is Success) {
        final data = (earningsResult as Success).data;
        _earnings = data is Map<String, dynamic> ? data : null;
      } else if (earningsResult is Failure) {
        _error ??= (earningsResult as Failure).exception.message;
      }
    } catch (e, stack) {
      developer.log('Error loading data: $e', name: 'Driver', error: e, stackTrace: stack);
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }

    if (mounted && !silent) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleOnline(bool value) async {
    final previous = _isOnline;
    setState(() => _isOnline = value);

    final result = await _apiClient.post<dynamic>(
      '/courier/status',
      data: {'status': value ? 'online' : 'offline'},
    );

    if (!mounted) return;

    if (result is Success) {
      final data = (result as Success).data;
      if (data is Map<String, dynamic>) {
        setState(() => _isOnline = data['status'] == 'online');
      }
      _loadData();
    } else if (result is Failure) {
      setState(() => _isOnline = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text((result as Failure).exception.message), backgroundColor: CustomerAppColors.error),
      );
    }
  }

  Future<void> _acceptTask(int subOrderId) async {
    final result = await _apiClient.post<dynamic>('/courier/tasks/$subOrderId/accept');

    if (result is Success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task accepted'), backgroundColor: CustomerAppColors.success),
        );
        _loadData();
      }
    } else if (result is Failure) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text((result as Failure).exception.message), backgroundColor: CustomerAppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalization.of(context)!;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(loc.getText('driverDashboard'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.getText('driverDashboard')),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 2),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _loadData, child: Text(loc.getText('retry'))),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(AppDimensions.md),
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.md),
                    decoration: BoxDecoration(
                      color: _isOnline ? CustomerAppColors.success.withOpacity(0.1) : CustomerAppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_isOnline ? loc.getText('youAreOnline') : loc.getText('youAreOffline'),
                              style: AppTypography.h2_18.copyWith(color: _isOnline ? CustomerAppColors.success : CustomerAppColors.textSecondary)),
                            Text(_isOnline ? loc.getText('receivingOrders') : loc.getText('goOnlineToReceive'),
                              style: AppTypography.caption12.copyWith(color: CustomerAppColors.textSecondary)),
                          ],
                        ),
                        Switch(value: _isOnline, onChanged: _toggleOnline, activeColor: CustomerAppColors.success),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.lg),
                  Row(children: [
                    Expanded(child: _StatCard(title: loc.getText('completedDeliveries'), value: '${_earnings?['completed_deliveries'] ?? 0}', icon: Icons.check_circle, color: CustomerAppColors.primary)),
                  ]),
                  const SizedBox(height: AppDimensions.lg),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(loc.getText('activeTasks'), style: AppTypography.h2_18),
                    Text('${_activeTasks.length}', style: AppTypography.body14.copyWith(color: CustomerAppColors.textSecondary)),
                  ]),
                  const SizedBox(height: AppDimensions.sm),
                  if (_activeTasks.isEmpty)
                    Container(padding: const EdgeInsets.all(AppDimensions.lg), decoration: BoxDecoration(color: CustomerAppColors.surfaceAlt, borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
                      child: Center(child: Text(loc.getText('noActiveTasks'), style: AppTypography.body14.copyWith(color: CustomerAppColors.textSecondary))))
                  else
                    ...List.generate(_activeTasks.length, (i) => _ActiveTaskCard(
                      task: _activeTasks[i] as Map<String, dynamic>,
                      onTap: () => context.go('/driver/task/${(_activeTasks[i] as Map)['id']}'),
                    )),
                  const SizedBox(height: AppDimensions.lg),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(loc.getText('availableTasks'), style: AppTypography.h2_18),
                    Text('${_availableTasks.length}', style: AppTypography.body14.copyWith(color: CustomerAppColors.textSecondary)),
                  ]),
                  const SizedBox(height: AppDimensions.sm),
                  if (_availableTasks.isEmpty)
                    Container(padding: const EdgeInsets.all(AppDimensions.lg), decoration: BoxDecoration(color: CustomerAppColors.surfaceAlt, borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
                      child: Center(child: Text(loc.getText('noTasksAvailable'), style: AppTypography.body14.copyWith(color: CustomerAppColors.textSecondary))))
                  else
                    ...List.generate(_availableTasks.length, (i) => _AvailableTaskCard(
                      task: _availableTasks[i] as Map<String, dynamic>,
                      onAccept: () => _acceptTask((_availableTasks[i] as Map)['id'] as int),
                    )),
                ],
              ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppDimensions.radiusMd), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: AppDimensions.sm),
        Text(value, style: AppTypography.h1_22.copyWith(fontWeight: FontWeight.w700, color: CustomerAppColors.secondary)),
        const SizedBox(height: AppDimensions.xs),
        Text(title, style: AppTypography.caption12.copyWith(color: CustomerAppColors.textSecondary)),
      ]),
    );
  }
}

class _ActiveTaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback onTap;
  const _ActiveTaskCard({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalization.of(context)!;
    final storeName = task['store']?['name'] ?? 'Store';
    final status = task['status'] ?? 'pending';
    final items = task['items'] as List<dynamic>? ?? [];
    final firstItem = items.isNotEmpty ? (items.first as Map<String, dynamic>?) : null;
    final imageUrl = _itemImage(firstItem);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDimensions.sm),
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppDimensions.radiusMd), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))]),
        child: Row(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: CustomerAppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(AppDimensions.radiusSm)),
            clipBehavior: Clip.antiAlias,
            child: imageUrl != null
                ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.store, color: CustomerAppColors.primary))
                : const Icon(Icons.store, color: CustomerAppColors.primary)),
          const SizedBox(width: AppDimensions.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(storeName, style: AppTypography.body14.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(loc.getText('xItems', params: {'count': '${items.length}'}), style: AppTypography.caption12.copyWith(color: CustomerAppColors.textSecondary)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: _getStatusColor(status).withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
            child: Text(_driverStatusLabel(context, status), style: AppTypography.caption12.copyWith(color: _getStatusColor(status), fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: AppDimensions.sm),
          const Icon(Icons.chevron_right, color: CustomerAppColors.textSecondary),
        ]),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'waiting_for_driver': return CustomerAppColors.warning;
      case 'with_driver': return CustomerAppColors.primary;
      case 'delivered': return CustomerAppColors.success;
      default: return CustomerAppColors.textSecondary;
    }
  }
}

class _AvailableTaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback onAccept;
  const _AvailableTaskCard({required this.task, required this.onAccept});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalization.of(context)!;
    final storeName = task['store']?['name'] ?? 'Store';
    final items = task['items'] as List<dynamic>? ?? [];
    final deliveryFee = task['delivery_fee'] ?? 0;
    final currency = (task['currency'] as Map<String, dynamic>?)?['symbol'] ?? 'SAR';
    final firstItem = items.isNotEmpty ? (items.first as Map<String, dynamic>?) : null;
    final imageUrl = _itemImage(firstItem);

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: CustomerAppColors.primary.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(color: CustomerAppColors.primary.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: CustomerAppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(AppDimensions.radiusSm)),
              clipBehavior: Clip.antiAlias,
              child: imageUrl != null
                  ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.store, color: CustomerAppColors.success))
                  : const Icon(Icons.store, color: CustomerAppColors.success)),
            const SizedBox(width: AppDimensions.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(storeName, style: AppTypography.body14.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('${loc.getText('xItems', params: {'count': '${items.length}'})}  •  $currency $deliveryFee ${loc.getText('delivery')}', style: AppTypography.caption12.copyWith(color: CustomerAppColors.textSecondary)),
            ])),
          ]),
          const SizedBox(height: AppDimensions.sm),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onAccept,
              style: ElevatedButton.styleFrom(backgroundColor: CustomerAppColors.success),
              child: Text(loc.getText('acceptDelivery'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
