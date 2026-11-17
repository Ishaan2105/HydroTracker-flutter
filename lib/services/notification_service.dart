import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';
import '../models/water_log.dart';
import 'app_logger.dart';
import 'db_helper.dart';
import 'pref_service.dart';
import 'widget_service.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  final actionId = response.actionId;
  if (actionId == 'ACTION_LOG_GLASS') {
    final hasGlass = await PrefService.hasConfiguredGlass();
    if (hasGlass) {
      final customGlassMl = await PrefService.getCustomGlassMl();
      await NotificationService.logWaterDirectly(customGlassMl);
    }
  } else if (actionId == 'ACTION_LOG_250') {
    await NotificationService.logWaterDirectly(250);
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static String _activeIcon = '@mipmap/ic_launcher';
  static const String channelId = 'hydro_tracker_reminders';
  static const String channelName = 'Hydration Reminders';
  static final StreamController<int> notificationIntakeStream = StreamController<int>.broadcast();

  static const List<AndroidNotificationAction> _notificationActions = [
    AndroidNotificationAction(
      'ACTION_LOG_GLASS',
      'Glass',
      showsUserInterface: false,
      cancelNotification: true,
    ),
    AndroidNotificationAction(
      'ACTION_LOG_250',
      '+250 ml',
      showsUserInterface: false,
      cancelNotification: true,
    ),
  ];

  static Future<void> _handleNotificationResponse(NotificationResponse response) async {
    AppLogger.info('NotificationService', 'Notification response received: ${response.id}, action: ${response.actionId}');
    final actionId = response.actionId;
    if (actionId == 'ACTION_LOG_GLASS') {
      final hasGlass = await PrefService.hasConfiguredGlass();
      if (hasGlass) {
        final customGlassMl = await PrefService.getCustomGlassMl();
        await logWaterDirectly(customGlassMl);
      } else {
        WidgetService.onWidgetActionReceived?.call('create_glass');
      }
    } else if (actionId == 'ACTION_LOG_250') {
      await logWaterDirectly(250);
    }
  }

  static Future<void> logWaterDirectly(int amountMl) async {
    try {
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      final log = WaterLog(
        amountMl: amountMl,
        timestamp: now,
        dateString: dateStr,
      );
      await DBHelper.instance.insertLog(log);
      final logs = await DBHelper.instance.getLogsForDate(dateStr);
      final total = logs.fold<int>(0, (sum, l) => sum + l.amountMl);
      await PrefService.setTodayIntake(total);
      final goal = await PrefService.getGoal();
      await WidgetService.updateWidgetData(total, goal);
      notificationIntakeStream.add(amountMl);
      AppLogger.info('NotificationService', 'Directly logged $amountMl ml via notification action');
    } catch (e, st) {
      AppLogger.error('NotificationService', 'logWaterDirectly failed', e, st);
    }
  }

  /// Initialize notifications plugin, channels & timezone data
  static Future<void> init() async {
    if (_initialized) return;

    try {
      await _initTimeZone();

      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      // Attempt initialization with ic_stat_hydro_logo, gracefully fallback to @mipmap/ic_launcher
      bool initialized = false;
      for (final iconCandidate in ['ic_stat_hydro_logo', '@mipmap/ic_launcher']) {
        try {
          final AndroidInitializationSettings androidSettings =
              AndroidInitializationSettings(iconCandidate);
          final InitializationSettings initSettings = InitializationSettings(
            android: androidSettings,
            iOS: iosSettings,
          );

          await _notificationsPlugin.initialize(
            initSettings,
            onDidReceiveNotificationResponse: _handleNotificationResponse,
            onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
          );
          _activeIcon = iconCandidate;
          initialized = true;
          AppLogger.info('NotificationService', 'Initialized notifications with icon: $iconCandidate');
          break;
        } catch (iconErr) {
          AppLogger.warn('NotificationService', 'Failed to initialize with icon $iconCandidate: $iconErr');
        }
      }

      if (!initialized) {
        const AndroidInitializationSettings androidSettings =
            AndroidInitializationSettings('@mipmap/ic_launcher');
        await _notificationsPlugin.initialize(
          const InitializationSettings(android: androidSettings, iOS: iosSettings),
          onDidReceiveNotificationResponse: _handleNotificationResponse,
          onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
        );
        _activeIcon = '@mipmap/ic_launcher';
      }

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
      }

      _initialized = true;
    } catch (e, st) {
      AppLogger.error('NotificationService', 'NotificationService init error: $e', e, st);
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

  /// Check if the app can schedule exact alarms on Android 12+ (API 31+)
  static Future<bool> canScheduleExactAlarms() async {
    try {
      await init();
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        return await androidImplementation.canScheduleExactNotifications() ?? false;
      }
      return true;
    } catch (_) {
      return true;
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

  /// Check if notifications are enabled by the user in Android OS
  static Future<bool> areNotificationsEnabled() async {
    try {
      await init();
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        return await androidImplementation.areNotificationsEnabled() ?? false;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  /// Opens the device App Notification Settings page
  static Future<bool> openNotificationSettings() async {
    try {
      final res = await _batteryChannel.invokeMethod<bool>('openNotificationSettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Request permissions on demand or on app startup
  static Future<bool> requestPermissions() async {
    try {
      await init();
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final areEnabled = await androidImplementation.areNotificationsEnabled();
        if (areEnabled != true) {
          await androidImplementation.requestNotificationsPermission();
        }
        final canExact = await androidImplementation.canScheduleExactNotifications();
        if (canExact == false) {
          try {
            await androidImplementation.requestExactAlarmsPermission();
          } catch (_) {}
        }
        return (await androidImplementation.areNotificationsEnabled()) ?? true;
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
      return 'Alarm set for $timeFormatted (in ${secs}s)';
    } else if (diff.inMinutes < 60) {
      final mins = diff.inMinutes;
      final secs = diff.inSeconds % 60;
      return 'Alarm set for $timeFormatted (in ${mins}m ${secs}s)';
    } else {
      final hours = diff.inHours;
      final mins = diff.inMinutes % 60;
      return 'Alarm set for $timeFormatted (in ${hours}h ${mins}m)';
    }
  }

  /// Cancel ALL scheduled system alarms.
  /// Use this when notifications are globally disabled or on a full reset.
  static Future<void> cancelAllAlarms() async {
    try {
      await init();
      await _notificationsPlugin.cancelAll();
      AppLogger.info('NotificationService', 'Cancelled all alarms.');
    } catch (e, st) {
      AppLogger.error('NotificationService', 'Error canceling all alarms', e, st);
    }
  }

  /// Cancel a single alarm by its notification [id] without touching other alarms.
  /// Also cancels any legacy backup ID (id + 500) if it was previously scheduled.
  static Future<void> cancelAlarm(int id) async {
    try {
      await init();
      // Cancel OS-level AlarmManager entries (including legacy backup ID if present)
      await _notificationsPlugin.cancel(id);
      await _notificationsPlugin.cancel(id + 500);
      AppLogger.info('NotificationService', 'Cancelled alarm ID $id.');
    } catch (e, st) {
      AppLogger.error('NotificationService', 'Error canceling alarm $id', e, st);
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
      await init();
      // Cancel existing reminder alarms (100..199 and backups 600..699)
      for (int i = 0; i < 100; i++) {
        await cancelAlarm(100 + i);
      }

      if (!enabled || reminderTimes.isEmpty) {
        AppLogger.info('NotificationService', 'Notifications disabled or reminder list empty.');
        return;
      }

      // Log battery optimization status — UI banner reads this via isBatteryOptimizationExempt()
      final exempt = await isBatteryOptimizationExempt();
      if (!exempt) {
        AppLogger.warn(
          'NotificationService',
          'Battery optimization is NOT disabled for this app. Android OEM power-management may suppress AlarmManager. Open Settings to fix.',
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
          title: 'Time to Hydrate!',
          body: 'Stay on top of your goal with a fresh glass of water.',
          isDaily: isDaily,
        );
      }
      AppLogger.info('NotificationService', 'Successfully scheduled ${reminderTimes.length} reminder alarms.');
    } catch (e, st) {
      AppLogger.error('NotificationService', 'Error scheduling reminders', e, st);
    }
  }

  /// Schedule post-meal reminders (30 minutes after each meal).
  static Future<void> schedulePostMealReminders(
    Map<String, String> mealSchedule,
    bool enabled,
  ) async {
    try {
      await init();
      // Cancel previous post-meal alarms (IDs 300, 301, 302)
      for (int i = 0; i < 3; i++) {
        await cancelAlarm(300 + i);
      }

      if (!enabled || mealSchedule.isEmpty) {
        AppLogger.info('NotificationService', 'Post-meal reminders disabled or schedule empty.');
        return;
      }

      final meals = [
        {'key': 'bfast', 'name': 'Breakfast', 'id': 300},
        {'key': 'lunch', 'name': 'Lunch', 'id': 301},
        {'key': 'dinner', 'name': 'Dinner', 'id': 302},
      ];

      for (var meal in meals) {
        final timeStr = mealSchedule[meal['key'] as String];
        if (timeStr == null || timeStr.trim().isEmpty) continue;

        final mealTime = _parseTimeString(timeStr);
        if (mealTime == null) continue;

        // Add 30 minutes to meal time
        final postMealTime = mealTime.add(const Duration(minutes: 30));
        final postMealTimeStr = DateFormat('hh:mm a').format(postMealTime);
        final target = calculateNextTzOccurrence(postMealTimeStr);

        await _schedulePointInTimeAlarm(
          id: meal['id'] as int,
          target: target,
          timeStr: postMealTimeStr,
          title: 'Post-${meal['name']} Hydration',
          body: 'It’s been 30 minutes since ${meal['name']}. Drink a glass of water for optimal digestion!',
          isDaily: true,
        );
        AppLogger.info('NotificationService', 'Scheduled Post-${meal['name']} alarm for $postMealTimeStr (Target: $target)');
      }
      AppLogger.info('NotificationService', 'Successfully scheduled post-meal reminders (30m after meals).');
    } catch (e, st) {
      AppLogger.error('NotificationService', 'Error scheduling post-meal reminders', e, st);
    }
  }


  /// Helper to build Android notification details with fallback icon support
  static AndroidNotificationDetails _buildAndroidNotificationDetails({
    String? customIcon,
    List<AndroidNotificationAction>? actions,
  }) {
    return AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Scheduled alarms and daily water intake reminders',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: customIcon ?? _activeIcon,
      color: const Color(0xFF00E5FF),
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      showWhen: true,
      actions: actions ?? _notificationActions,
    );
  }

  /// Point-in-time alarm scheduling.
  /// For [isDaily] = true: registers a native daily-repeating alarm (wallClockTime +
  /// matchDateTimeComponents).
  /// For [isDaily] = false: one-shot absoluteTime alarm.
  static Future<void> _schedulePointInTimeAlarm({
    required int id,
    required tz.TZDateTime target,
    required String title,
    required String body,
    String timeStr = '',
    bool isDaily = true,
  }) async {
    final notificationDetails = NotificationDetails(
      android: _buildAndroidNotificationDetails(),
      iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
    );

    if (isDaily) {
      // --- Clean schedule for DAILY alarms ---
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
        AppLogger.info('NotificationService', 'Daily alarm $id scheduled at $target (exactAllowWhileIdle)');
      } catch (e1) {
        AppLogger.warn('NotificationService', 'Daily alarm exactAllowWhileIdle failed: $e1. Trying alarmClock...');
        try {
          await _notificationsPlugin.zonedSchedule(
            id,
            title,
            body,
            target,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.alarmClock,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.wallClockTime,
            matchDateTimeComponents: DateTimeComponents.time,
          );
          AppLogger.info('NotificationService', 'Daily alarm $id scheduled at $target (alarmClock)');
        } catch (e2) {
          AppLogger.warn('NotificationService', 'Daily alarm alarmClock failed: $e2. Trying inexact fallback...');
          try {
            final fallbackDetails = NotificationDetails(
              android: _buildAndroidNotificationDetails(customIcon: '@mipmap/ic_launcher'),
              iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
            );
            await _notificationsPlugin.zonedSchedule(
              id,
              title,
              body,
              target,
              fallbackDetails,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.wallClockTime,
              matchDateTimeComponents: DateTimeComponents.time,
            );
            AppLogger.info('NotificationService', 'Daily alarm $id scheduled at $target (inexact fallback)');
          } catch (e3, st) {
            AppLogger.error('NotificationService', 'All daily alarm scheduling attempts failed for ID $id', e3, st);
          }
        }
      }
    } else {
      // --- Clean schedule for ONE-TIME alarms ---
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
        AppLogger.info('NotificationService', 'One-time alarm $id scheduled at $target (exactAllowWhileIdle)');
      } catch (e1) {
        AppLogger.warn('NotificationService', 'One-time alarm exactAllowWhileIdle failed: $e1. Trying alarmClock...');
        try {
          await _notificationsPlugin.zonedSchedule(
            id,
            title,
            body,
            target,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.alarmClock,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
          AppLogger.info('NotificationService', 'One-time alarm $id scheduled at $target (alarmClock)');
        } catch (e2) {
          AppLogger.warn('NotificationService', 'One-time alarm alarmClock failed: $e2. Trying inexact fallback...');
          try {
            final fallbackDetails = NotificationDetails(
              android: _buildAndroidNotificationDetails(customIcon: '@mipmap/ic_launcher'),
              iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
            );
            await _notificationsPlugin.zonedSchedule(
              id,
              title,
              body,
              target,
              fallbackDetails,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
            );
            AppLogger.info('NotificationService', 'One-time alarm $id scheduled at $target (inexact fallback)');
          } catch (e3, st) {
            AppLogger.error('NotificationService', 'All one-time alarm scheduling attempts failed for ID $id', e3, st);
          }
        }
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

    final notificationDetails = NotificationDetails(
      android: _buildAndroidNotificationDetails(),
      iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
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
      AppLogger.info('NotificationService', '1-min test alarm scheduled via exactAllowWhileIdle');
    } catch (e1) {
      AppLogger.warn('NotificationService', '1-min test exactAllowWhileIdle failed: $e1. Trying alarmClock...');
      try {
        await _notificationsPlugin.zonedSchedule(
          999,
          '⏰ Hydro Tracker 1-Min Test Alarm!',
          'Scheduled alarm test succeeded! Background notification working.',
          target,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.alarmClock,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        AppLogger.info('NotificationService', '1-min test alarm scheduled via alarmClock');
      } catch (e2) {
        AppLogger.warn('NotificationService', '1-min test alarmClock failed: $e2. Trying inexact fallback...');
        final fallbackDetails = NotificationDetails(
          android: _buildAndroidNotificationDetails(customIcon: '@mipmap/ic_launcher'),
          iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
        );
        await _notificationsPlugin.zonedSchedule(
          999,
          '⏰ Hydro Tracker 1-Min Test Alarm!',
          'Scheduled alarm test succeeded! Background notification working.',
          target,
          fallbackDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        AppLogger.info('NotificationService', '1-min test alarm scheduled via inexact fallback');
      }
    }

    return DateTime.now().add(const Duration(seconds: 60));
  }

  /// Helper to parse 12h "08:00 AM" or 24h "08:00" strings into DateTime
  static DateTime? _parseTimeString(String timeStr) {
    try {
      String clean = timeStr.trim();
      if (clean.toUpperCase().contains('AM') || clean.toUpperCase().contains('PM')) {
        try {
          return DateFormat('hh:mm a').parse(clean);
        } catch (_) {
          try {
            return DateFormat('h:mm a').parse(clean);
          } catch (_) {
            return DateFormat('hh:mma').parse(clean);
          }
        }
      } else {
        try {
          return DateFormat('HH:mm').parse(clean);
        } catch (_) {
          return DateFormat('H:mm').parse(clean);
        }
      }
    } catch (_) {
      return null;
    }
  }

  /// Trigger an instant test notification
  static Future<bool> showTestNotification() async {
    try {
      await init();
      final hasPerm = await requestPermissions();
      if (!hasPerm) {
        AppLogger.warn('NotificationService', 'showTestNotification: permission denied');
        return false;
      }

      final notificationDetails = NotificationDetails(
        android: _buildAndroidNotificationDetails(),
        iOS: const DarwinNotificationDetails(),
      );

      try {
        await _notificationsPlugin.show(
          0,
          'Hydro Tracker Alarm Active! 💧',
          'Your scheduled hydration reminders are configured and working smoothly.',
          notificationDetails,
        );
        return true;
      } catch (iconErr) {
        // Fallback to mipmap/ic_launcher if custom drawable lookup encounters an issue
        final fallbackDetails = NotificationDetails(
          android: _buildAndroidNotificationDetails(customIcon: '@mipmap/ic_launcher'),
          iOS: const DarwinNotificationDetails(),
        );
        await _notificationsPlugin.show(
          0,
          'Hydro Tracker Alarm Active! 💧',
          'Your scheduled hydration reminders are configured and working smoothly.',
          fallbackDetails,
        );
        return true;
      }
    } catch (e, st) {
      AppLogger.error('NotificationService', 'showTestNotification error: $e', e, st);
      return false;
    }
  }

  /// Trigger an instant test notification for a post-meal reminder
  static Future<bool> showPostMealTestNotification(String mealName) async {
    try {
      await init();
      final hasPerm = await requestPermissions();
      if (!hasPerm) {
        AppLogger.warn('NotificationService', 'showPostMealTestNotification: permission denied');
        return false;
      }

      final notificationDetails = NotificationDetails(
        android: _buildAndroidNotificationDetails(),
        iOS: const DarwinNotificationDetails(),
      );

      try {
        await _notificationsPlugin.show(
          399,
          'Post-$mealName Hydration 🍽️💧',
          'It’s been 30 minutes since $mealName. Drink a fresh glass of water for optimal digestion!',
          notificationDetails,
        );
        return true;
      } catch (_) {
        final fallbackDetails = NotificationDetails(
          android: _buildAndroidNotificationDetails(customIcon: '@mipmap/ic_launcher'),
          iOS: const DarwinNotificationDetails(),
        );
        await _notificationsPlugin.show(
          399,
          'Post-$mealName Hydration 🍽️💧',
          'It’s been 30 minutes since $mealName. Drink a fresh glass of water for optimal digestion!',
          fallbackDetails,
        );
        return true;
      }
    } catch (e, st) {
      AppLogger.error('NotificationService', 'showPostMealTestNotification error: $e', e, st);
      return false;
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
