import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

/// Sprint 0: Yalnızca anlık, test amaçlı yerel bildirim.
/// Planlı hatırlatma ve FCM bu sürümde yoktur.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> _prepare() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    _initialized = true;
  }

  /// İzin verilmişse (veya platformda gerekmiyorsa) bildirimi gösterir ve `true` döner.
  /// Kullanıcı izni reddettiyse bildirim göstermeden `false` döner — çağıran taraf
  /// bunu kullanıcıya açıkça bildirmelidir, "gönderildi" gibi yanıltıcı mesaj vermemelidir.
  Future<bool> showTestNotification() async {
    await _prepare();

    final androidGranted = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    if (androidGranted == false) return false;

    final iosGranted = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    if (iosGranted == false) return false;

    await _plugin.show(
      id: 101,
      title: 'İlaç Hatırlatıcısı — DEMO',
      body:
          'Bu, test amaçlı bir yerel bildirimdir. Gerçek ilaç planı değildir.',
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
    return true;
  }

  Future<bool> scheduleDailyMedication({
    required int id,
    required String medicationName,
    required int hour,
    required int minute,
  }) async {
    await _prepare();

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android == null) return false;

    var granted = await android.areNotificationsEnabled() ?? false;

    if (!granted) {
      granted = await android.requestNotificationsPermission() ?? false;
    }

    if (!granted) return false;

    var exact = await android.canScheduleExactNotifications() ?? false;

    if (!exact) {
      exact = await android.requestExactAlarmsPermission() ?? false;
    }

    final now = tz.TZDateTime.now(tz.local);

    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (!scheduledDate.isAfter(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: id,
      title: 'DEMO - İlaç hatırlatıcı',
      body: 'DEMO hatırlatma: $medicationName için belirlediğiniz saat geldi.',
      scheduledDate: scheduledDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'ilac_kanali',
          'İlaç Hatırlatmaları',
          channelDescription: 'Günlük ilaç bildirimleri',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    return true;
  }

  Future<void> cancelMedication(int id) async {
    await _prepare();
    await _plugin.cancel(id: id);
  }
}
