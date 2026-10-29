import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yallashop_core/yallashop_core.dart';

import '../../config/api_config.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_state.dart';

/// Holds the live unread-notifications count for the authenticated user.
class NotificationsState {
  final int unreadCount;

  const NotificationsState({this.unreadCount = 0});
}

/// Polls `/notifications/unread-count` so the app bell badge stays in sync
/// with the backend. Starts polling only while the user is authenticated.
class NotificationsCubit extends Cubit<NotificationsState> {
  final ApiClient _apiClient;
  Timer? _timer;
  bool _polling = false;

  NotificationsCubit({ApiClient? apiClient, AuthBloc? authBloc})
      : _apiClient = apiClient ?? ApiClient(baseUrl: CustomerApiConfig.baseUrl),
        super(const NotificationsState()) {
    if (authBloc != null) {
      authBloc.stream.listen(_onAuthChanged);
    } else {
      // No auth bloc provided (tests): poll unconditionally.
      start();
    }
  }

  void _onAuthChanged(AuthState state) {
    if (state is Authenticated) {
      start();
    } else {
      stop();
    }
  }

  void start() {
    if (_polling) return;
    _polling = true;
    refresh();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => refresh());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _polling = false;
    emit(const NotificationsState());
  }

  Future<void> refresh() async {
    if (!_polling) return;
    try {
      final result = await _apiClient.get<Map<String, dynamic>>(
        '/notifications/unread-count',
      );
      if (result is Success<Map<String, dynamic>>) {
        final data = result.data['data'];
        final count = (data is Map && data['count'] is num)
            ? (data['count'] as num).toInt()
            : 0;
        emit(NotificationsState(unreadCount: count));
      }
    } catch (_) {
      // Ignore transient failures; next poll retries.
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _timer = null;
    _polling = false;
    return super.close();
  }
}