import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Sprint 0: Yalnızca anlık, test amaçlı yerel bildirim.
/// Planlı hatırlatma ve FCM bu sürümde yoktur.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> _prepare() async {
    if (_initialized) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    _initialized = true;
  }

  Future<void> showTestNotification() async {
    await _prepare();
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _plugin.show(
      id: 101,
      title: 'İlaç Hatırlatıcısı — DEMO',
      body: 'Bu, test amaçlı bir yerel bildirimdir. Gerçek ilaç planı değildir.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'demo_reminders',
          'Demo ilaç hatırlatmaları',
          channelDescription: 'Sprint 0 yerel bildirim denemesi',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
