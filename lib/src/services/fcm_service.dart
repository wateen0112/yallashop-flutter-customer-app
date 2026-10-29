import 'dart:developer' as developer;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:yallashop_core/yallashop_core.dart';
import '../config/api_config.dart';

/// Handles Firebase Cloud Messaging setup and device-token lifecycle.
class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static String? _deviceToken;

  /// Called when a foreground (in-app) push arrives so the app can refresh
  /// the unread count / notifications feed in near real-time.
  static void Function()? onForegroundMessage;

  static Future<void> init() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        developer.log('FCM permission granted', name: 'FCM');
        _deviceToken = await _messaging.getToken();
        if (_deviceToken != null) {
          developer.log('FCM token acquired', name: 'FCM');
        }
        _messaging.onTokenRefresh.listen((token) {
          _deviceToken = token;
          // Re-register; harmless if the user isn't authenticated (401 ignored).
          _sendTokenToBackend(token);
        });
      }

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
    } catch (e) {
      developer.log('FCM init failed: $e', name: 'FCM');
    }
  }

  /// Registers the stored device token with the backend for the currently
  /// authenticated user. Call after a successful login / on app start.
  static Future<void> registerCurrentToken() async {
    final token = _deviceToken;
    if (token == null) {
      // Token not acquired yet; try to fetch it.
      try {
        _deviceToken = await _messaging.getToken();
      } catch (_) {}
      if (_deviceToken == null) return;
      _sendTokenToBackend(_deviceToken!);
      return;
    }
    await _sendTokenToBackend(token);
  }

  /// Removes the stored device token from the backend on logout.
  static Future<void> unregisterCurrentToken() async {
    final token = _deviceToken;
    if (token == null) return;
    try {
      final apiClient = ApiClient(baseUrl: CustomerApiConfig.baseUrl);
      await apiClient.delete('/fcm-token', queryParams: {'token': token});
    } catch (e) {
      developer.log('Failed to unregister FCM token: $e', name: 'FCM');
    }
  }

  static Future<void> _sendTokenToBackend(String token) async {
    try {
      final apiClient = ApiClient(baseUrl: CustomerApiConfig.baseUrl);
      await apiClient.post('/fcm-token', data: {
        'token': token,
        'platform': 'android',
      });
      developer.log('FCM token sent to backend', name: 'FCM');
    } catch (e) {
      developer.log('Failed to send FCM token (may be logged out): $e', name: 'FCM');
    }
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    developer.log('Foreground message: ${message.notification?.title}', name: 'FCM');
    // Refresh the in-app feed / unread badge immediately.
    try {
      onForegroundMessage?.call();
    } catch (_) {}
  }

  @pragma('vm:entry-point')
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    developer.log('Background message: ${message.notification?.title}', name: 'FCM');
  }
}