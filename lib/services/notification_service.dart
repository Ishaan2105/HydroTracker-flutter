import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Initialize notifications plugin & timezone data
  static Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(initSettings);

    // Request permissions on Android 13+
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
    }

    _initialized = true;
  }

  /// Schedule daily recurring notifications for a list of 12h or 24h time strings (e.g., ["08:00 AM", "02:30 PM"])
  static Future<void> scheduleReminders(List<String> reminderTimes, bool enabled) async {
    await init();
    await _notificationsPlugin.cancelAll();

    if (!enabled || reminderTimes.isEmpty) return;

    int id = 100;
    for (String timeStr in reminderTimes) {
      DateTime? time = _parseTimeString(timeStr);
      if (time != null) {
        await _scheduleDailyNotification(
          id: id++,
          hour: time.hour,
          minute: time.minute,
          title: '💧 Time to Hydrate!',
          body: 'Stay on top of your goal with a fresh glass of water.',
        );
      }
    }
  }

  /// Schedule a specific daily notification at hour & minute
  static Future<void> _scheduleDailyNotification({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'hydro_tracker_reminders',
      'Hydration Reminders',
      channelDescription: 'Scheduled alarms and daily water intake reminders',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('notification'),
      playSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    );

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Helper to parse 12h "08:00 AM" or 24h "08:00" strings into DateTime
  static DateTime? _parseTimeString(String timeStr) {
    try {
      String clean = timeStr.trim();
      if (clean.contains('AM') || clean.contains('PM') || clean.contains('am') || clean.contains('pm')) {
        return DateFormat('hh:mm a').parse(clean);
      } else {
        return DateFormat('HH:mm').parse(clean);
      }
    } catch (_) {
      return null;
    }
  }

  /// Trigger an instant test notification
  static Future<void> showTestNotification() async {
    await init();
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'hydro_tracker_reminders',
      'Hydration Reminders',
      channelDescription: 'Scheduled alarms and daily water intake reminders',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      0,
      '💧 Hydro Tracker Alarm Active!',
      'Your scheduled hydration reminders are configured and working smoothly.',
      notificationDetails,
    );
  }
}
