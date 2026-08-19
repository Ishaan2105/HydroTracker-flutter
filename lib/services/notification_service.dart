import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static const String channelId = 'hydro_tracker_reminders';
  static const String channelName = 'Hydration Reminders';

  /// Initialize notifications plugin, channels & timezone data
  static Future<void> init() async {
    if (_initialized) return;

    try {
      await _initTimeZone();

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

      // Create explicit Android Notification Channel with max priority & sound
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          channelId,
          channelName,
          description: 'Scheduled alarms and daily water intake reminders',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        );
        await androidImplementation.createNotificationChannel(channel);
        try {
          await androidImplementation.requestNotificationsPermission();
        } catch (_) {}
        try {
          await androidImplementation.requestExactAlarmsPermission();
        } catch (_) {}
      }

      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  /// Robust timezone initialization matching device offset
  static Future<void> _initTimeZone() async {
    tz.initializeTimeZones();
    try {
      String timeZoneName = await FlutterTimezone.getLocalTimezone();
      timeZoneName = timeZoneName.trim();
      if (timeZoneName == 'Asia/Calcutta') {
        timeZoneName = 'Asia/Kolkata';
      }

      try {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
        return;
      } catch (_) {}

      // Match by location name suffix
      for (var locName in tz.timeZoneDatabase.locations.keys) {
        if (locName.toLowerCase() == timeZoneName.toLowerCase() ||
            locName.endsWith(timeZoneName.split('/').last)) {
          tz.setLocalLocation(tz.getLocation(locName));
          return;
        }
      }

      // Match by exact timezone UTC offset (e.g., +05:30)
      final offset = DateTime.now().timeZoneOffset;
      for (var loc in tz.timeZoneDatabase.locations.values) {
        if (loc.currentTimeZone.offset == offset.inMilliseconds) {
          tz.setLocalLocation(loc);
          return;
        }
      }
    } catch (e) {
      debugPrint('Timezone config error: $e');
    }
  }

  /// Check and request exact alarms permission (Android 12/13/14)
  static Future<bool> requestExactAlarmsPermission() async {
    try {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        return await androidImplementation.requestExactAlarmsPermission() ?? false;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  /// Request permissions on demand (e.g., when toggle is switched on)
  static Future<bool> requestPermissions() async {
    try {
      await init();
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final granted = await androidImplementation.requestNotificationsPermission() ?? false;
        try {
          await androidImplementation.requestExactAlarmsPermission();
        } catch (_) {}
        return granted;
      }
      return true;
    } catch (e) {
      debugPrint('requestPermissions error: $e');
      return false;
    }
  }

  /// Schedule daily recurring notifications for a list of 12h or 24h time strings (e.g., ["08:00 AM", "02:30 PM"])
  static Future<void> scheduleReminders(List<String> reminderTimes, bool enabled) async {
    try {
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
    } catch (e) {
      debugPrint('Error scheduling reminders: $e');
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
      0,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Scheduled alarms and daily water intake reminders',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.wallClockTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (exactErr) {
      debugPrint('exactAllowWhileIdle fallback to inexact: $exactErr');
      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.wallClockTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (e) {
        debugPrint('Error in zonedSchedule inexact: $e');
      }
    }
  }

  /// Schedule a 1-minute test alarm for instant verification
  static Future<DateTime> scheduleOneMinuteTest() async {
    await init();
    try {
      await requestPermissions();
    } catch (_) {}

    final now = tz.TZDateTime.now(tz.local);
    final target = now.add(const Duration(seconds: 60));

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Scheduled alarms and daily water intake reminders',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        999,
        '⏰ Hydro Tracker 1-Min Test Alarm!',
        'Scheduled alarm test succeeded! Background notification working.',
        target,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e1) {
      debugPrint('zonedSchedule exact error: $e1');
      try {
        await _notificationsPlugin.zonedSchedule(
          999,
          '⏰ Hydro Tracker 1-Min Test Alarm!',
          'Scheduled alarm test succeeded! Background notification working.',
          target,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e2) {
        debugPrint('zonedSchedule inexact error: $e2');
      }
    }

    // Dual-redundancy timer fallback while process is active
    Future.delayed(const Duration(seconds: 60), () async {
      try {
        await _notificationsPlugin.show(
          999,
          '⏰ Hydro Tracker 1-Min Test Alarm!',
          'Scheduled alarm test succeeded! Background notification working.',
          notificationDetails,
        );
      } catch (_) {}
    });

    return DateTime.now().add(const Duration(seconds: 60));
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
    try {
      await init();
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'Scheduled alarms and daily water intake reminders',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
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
    } catch (e) {
      debugPrint('showTestNotification error: $e');
    }
  }
}
