import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationService {
  NotificationService();

  static const String channelId = 'rentflow_live_updates';
  static const String channelName = 'RentFlow Live Updates';

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _tokenSyncStarted = false;
  AndroidNotificationChannel? _channel;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(settings: settings);

    try {
      _channel = const AndroidNotificationChannel(
        channelId,
        channelName,
        description: 'Payment, tenant, and due alerts',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel!);

      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
      FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    } catch (_) {
      // Firebase setup depends on platform files and can be absent in local dev.
    }

    _initialized = true;
  }

  Future<String?> getFcmToken() async {
    try {
      return FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  Future<void> startTokenSync(Future<void> Function(String?) onToken) async {
    if (_tokenSyncStarted) {
      return;
    }

    _tokenSyncStarted = true;

    try {
      final currentToken = await FirebaseMessaging.instance.getToken();
      await onToken(currentToken);

      FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
        await onToken(token);
      });
    } catch (_) {
      // Ignore token sync failures until Firebase is configured in the runtime.
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (kIsWeb) return;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Payment, tenant, and due alerts',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _localNotifications.show(
      id: message.notification.hashCode,
      title: message.notification?.title ?? 'RentFlow',
      body: message.notification?.body ?? 'New update available',
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: message.data.toString(),
    );
  }
}
