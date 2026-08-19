import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

  /// Calculate next tz.TZDateTime occurrence directly in device timezone
  static tz.TZDateTime calculateNextTzOccurrence(String timeStr) {
    DateTime? parsed = _parseTimeString(timeStr);
    final now = tz.TZDateTime.now(tz.local);
    if (parsed == null) return now.add(const Duration(minutes: 1));

    var target = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      parsed.hour,
      parsed.minute,
      0,
    );

    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }
    return target;
  }

  /// Format user-friendly confirmation message
  static String formatAlarmConfirmation(DateTime targetTime) {
    final now = DateTime.now();
    final diff = targetTime.difference(now);
    final timeFormatted = DateFormat('hh:mm:ss a').format(targetTime);

    if (diff.inSeconds <= 60) {
      final secs = diff.inSeconds > 0 ? diff.inSeconds : 60;
      return '⏳ Alarm active for $timeFormatted! Lock phone & wait ${secs}s.';
    } else if (diff.inMinutes < 60) {
      final mins = diff.inMinutes;
      final secs = diff.inSeconds % 60;
      return '⏳ Alarm active for $timeFormatted (in ${mins}m ${secs}s)! Lock phone & wait.';
    } else {
      final hours = diff.inHours;
      final mins = diff.inMinutes % 60;
      return '⏳ Alarm active for $timeFormatted (in ${hours}h ${mins}m)!';
    }
  }

  static final List<Timer> _activeTimers = [];

  /// Cancel all scheduled system alarms and in-memory timers
  static Future<void> cancelAllAlarms() async {
    try {
      await init();
      for (var timer in _activeTimers) {
        timer.cancel();
      }
      _activeTimers.clear();
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('Error canceling all alarms: $e');
    }
  }

  /// Schedule notifications for a list of reminder times.
  /// [dailyTimes] = set of times that should fire every day.
  /// Times NOT in dailyTimes fire only once (one-shot).
  static Future<void> scheduleReminders(
    List<String> reminderTimes,
    bool enabled, {
    Set<String> dailyTimes = const {},
  }) async {
    try {
      await cancelAllAlarms();

      if (!enabled || reminderTimes.isEmpty) return;

      // Log battery optimization status — UI banner reads this via isBatteryOptimizationExempt()
      final exempt = await isBatteryOptimizationExempt();
      if (!exempt) {
        debugPrint(
          '[HydroTracker] WARNING: Battery optimization is NOT disabled for this app. '
          'Samsung One UI may suppress AlarmManager. Open Settings to fix.',
        );
      }

      int id = 100;
      for (String timeStr in reminderTimes) {
        final target = calculateNextTzOccurrence(timeStr);
        final isDaily = dailyTimes.contains(timeStr);
        await _schedulePointInTimeAlarm(
          id: id++,
          target: target,
          timeStr: timeStr,
          title: '💧 Time to Hydrate!',
          body: 'Stay on top of your goal with a fresh glass of water.',
          isDaily: isDaily,
        );
      }
    } catch (e) {
      debugPrint('Error scheduling reminders: $e');
    }
  }


  /// Point-in-time alarm scheduling.
  /// For [isDaily] = true: registers a native daily-repeating alarm (wallClockTime +
  /// matchDateTimeComponents) PLUS an absoluteTime one-shot backup for today.
  /// For [isDaily] = false: one-shot absoluteTime only.
  static Future<void> _schedulePointInTimeAlarm({
    required int id,
    required tz.TZDateTime target,
    required String title,
    required String body,
    String timeStr = '',
    bool isDaily = true,
  }) async {
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

    if (isDaily) {
      // --- Strategy for DAILY alarms ---
      // 1. Try native daily-repeating alarm (wallClockTime + matchDateTimeComponents.time)
      //    This handles recurrence at the OS level.
      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          target,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.wallClockTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (e1) {
        debugPrint('Daily recurring alarm fallback: $e1');
        try {
          await _notificationsPlugin.zonedSchedule(
            id,
            title,
            body,
            target,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.wallClockTime,
            matchDateTimeComponents: DateTimeComponents.time,
          );
        } catch (_) {}
      }

      // 2. One-shot absoluteTime backup for today (same engine as 1-min test alarm)
      //    Uses a different notification ID (+500) to avoid conflicts with recurring alarm.
      final backupId = id + 500;
      try {
        await _notificationsPlugin.zonedSchedule(
          backupId,
          title,
          body,
          target,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (_) {}

      // 3. In-memory timer fallback while process is alive
      final diff = target.difference(tz.TZDateTime.now(tz.local));
      if (diff.inSeconds > 0 && diff.inHours < 24) {
        final timer = Timer(diff, () async {
          try {
            await _notificationsPlugin.show(id, title, body, notificationDetails);
          } catch (_) {}
        });
        _activeTimers.add(timer);
      }
    } else {
      // --- Strategy for ONE-TIME alarms ---
      // absoluteTime exact alarm only (same as 1-min test alarm).
      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          target,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e1) {
        try {
          await _notificationsPlugin.zonedSchedule(
            id,
            title,
            body,
            target,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        } catch (_) {}
      }

      // In-memory timer fallback
      final diff = target.difference(tz.TZDateTime.now(tz.local));
      if (diff.inSeconds > 0 && diff.inHours < 24) {
        final timer = Timer(diff, () async {
          try {
            await _notificationsPlugin.show(id, title, body, notificationDetails);
          } catch (_) {}
        });
        _activeTimers.add(timer);
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

  // ---------------------------------------------------------------------------
  // Battery Optimization (Android) — via MethodChannel to MainActivity.kt
  // ---------------------------------------------------------------------------

  static const _batteryChannel = MethodChannel('hydro_flutter/battery');

  /// Returns true if this app is already exempt from battery optimizations.
  /// Always returns true on iOS or Android < M (no restriction on those platforms).
  static Future<bool> isBatteryOptimizationExempt() async {
    try {
      final result = await _batteryChannel.invokeMethod<bool>('checkBatteryOptimization');
      return result ?? true;
    } catch (_) {
      return true; // Assume OK if channel fails (e.g. iOS)
    }
  }

  /// Opens the system dialog asking the user to exempt this app from battery
  /// optimizations. On Samsung One UI, this sets the app to "Unrestricted"
  /// battery mode which prevents the OS from killing its AlarmManager entries.
  ///
  /// Returns true if the direct exemption dialog was shown,
  /// false if a fallback settings page was opened instead.
  static Future<bool> requestBatteryOptimizationExemption() async {
    try {
      final result = await _batteryChannel.invokeMethod<bool>('requestBatteryOptimization');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens Samsung Device Care battery page directly.
  /// Guides the user to: Battery → Background usage limits → Never sleeping apps.
  /// Falls back to the app's system detail page on non-Samsung devices.
  static Future<bool> openSamsungDeviceCare() async {
    try {
      final result = await _batteryChannel.invokeMethod<bool>('openSamsungDeviceCare');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
