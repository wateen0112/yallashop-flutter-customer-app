import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:yallashop_core/yallashop_core.dart';

import '../../config/api_config.dart';
import '../../core/cubit/notifications_cubit.dart';
import '../../widgets/unified_app_bar.dart';

List<dynamic> _extractNotificationList(dynamic payload) {
  if (payload is List) return payload;
  if (payload is Map<String, dynamic> && payload.containsKey('data')) {
    final inner = payload['data'];
    if (inner is List) return inner;
    if (inner is Map<String, dynamic> && inner['data'] is List) {
      return inner['data'] as List<dynamic>;
    }
  }
  return [];
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _apiClient = ApiClient(baseUrl: CustomerApiConfig.baseUrl);
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (mounted) setState(() => _isLoading = true);
    final result = await _apiClient.get<dynamic>('/notifications');
    if (result is Success<dynamic>) {
      if (mounted) {
        setState(() {
          _notifications = _extractNotificationList(result.data)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _error = null;
          _isLoading = false;
        });
      }
    } else if (result is Failure) {
      if (mounted) {
        setState(() {
          _error = (result).exception.message;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markRead(int id) async {
    final cubit = context.read<NotificationsCubit>();
    final index = _notifications.indexWhere((n) => n['id'] == id);
    if (index < 0) return;
    if (_notifications[index]['read'] == true) return;
    await _apiClient.post('/notifications/$id/read');
    if (mounted) {
      setState(() {
        _notifications[index]['read'] = true;
      });
    }
    cubit.refresh();
  }

  Future<void> _markAllRead() async {
    final cubit = context.read<NotificationsCubit>();
    await _apiClient.post('/notifications/read-all');
    if (mounted) {
      setState(() {
        for (final n in _notifications) {
          n['read'] = true;
        }
      });
    }
    cubit.refresh();
  }

  void _openNotification(Map<String, dynamic> notification) {
    final data = (notification['data'] as Map<String, dynamic>?) ?? {};
    final role = data['role'] as String?;
    final orderId = data['order_id'];
    final subOrderId = data['sub_order_id'];
    _markRead(notification['id'] as int);

    if (role == 'vendor' && subOrderId != null) {
      context.push('/vendor-order/$subOrderId');
    } else if (orderId != null) {
      context.push('/order/$orderId');
    }
  }

  String _relativeTime(String? value) {
    final dt = DateTime.tryParse(value ?? '');
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '$day/$month/${dt.year}';
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'new_order':
        return Icons.shopping_bag_outlined;
      case 'order_status':
        return Icons.local_shipping_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalization.of(context)!;
    return Scaffold(
      backgroundColor: CustomerAppColors.background,
      appBar: UnifiedAppBar.detail(
        title: loc.getText('notifications'),
        showBackButton: true,
        showUserAvatar: false,
        showNotification: false,
        actions: _notifications.isEmpty
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.done_all, color: CustomerAppColors.primary),
                  tooltip: loc.getText('markAllAsRead'),
                  onPressed: _markAllRead,
                ),
              ],
      ),
      body: _buildBody(loc),
    );
  }

  Widget _buildBody(AppLocalization loc) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: CustomerAppColors.primary));
    }

    if (_error != null && _notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_off_outlined, size: 48, color: CustomerAppColors.textSecondary),
            const SizedBox(height: 12),
            Text(loc.getText('noNotificationsYet'), style: AppTypography.body14.copyWith(color: CustomerAppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadNotifications, child: Text(loc.getText('retry'))),
          ],
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_none, size: 48, color: CustomerAppColors.textSecondary),
            const SizedBox(height: 12),
            Text(loc.getText('noNotificationsYet'), style: AppTypography.body14.copyWith(color: CustomerAppColors.textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: CustomerAppColors.primary,
      onRefresh: _loadNotifications,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final n = _notifications[index];
          final title = n['title'] as String? ?? loc.getText('notifications');
          final body = n['body'] as String? ?? '';
          final isRead = n['read'] == true;
          return Material(
            color: isRead ? CustomerAppColors.surfaceContainerLowest : const Color(0xFFFFDAD9).withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openNotification(n),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: CustomerAppColors.surfaceContainerHigh,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_iconFor(n['type'] as String? ?? ''), size: 20, color: CustomerAppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: AppTypography.body14.copyWith(fontWeight: FontWeight.w700),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(left: 6),
                                  decoration: const BoxDecoration(color: CustomerAppColors.primary, shape: BoxShape.circle),
                                ),
                            ],
                          ),
                          if (body.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              body,
                              style: AppTypography.body14.copyWith(color: CustomerAppColors.textSecondary, height: 1.4),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            _relativeTime(n['created_at'] as String?),
                            style: AppTypography.caption12.copyWith(color: CustomerAppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}