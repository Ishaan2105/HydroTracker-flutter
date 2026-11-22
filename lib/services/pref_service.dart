import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrefService {
  static const String keyGoal = 'daily_goal_ml';
  static const String keyUserName = 'user_name';
  static const String keyCurrentStreak = 'current_streak';
  static const String keyBestStreak = 'best_streak';
  static const String keyLastActiveDate = 'last_active_date';
  static const String keyBfastTime = 'bfast_time';
  static const String keyLunchTime = 'lunch_time';
  static const String keyDinnerTime = 'dinner_time';

  static const String keyNotifEnabled = 'notif_enabled';
  static const String keyPostMealNotif = 'post_meal_notif';
  static const String keyReminderTimes = 'reminder_times';
  static const String keySoloOptIn = 'solo_opt_in';
  static const String keyLeaderboardOptIn = 'leaderboard_opt_in';
  static const String keyCustomGlassMl = 'custom_glass_ml';
  static const String keyHasConfiguredGlass = 'has_configured_glass';
  static const String keyHasPromptedUsername = 'has_prompted_username_setup';
  static const String keyLastSyncedUid = 'last_synced_user_uid';

  static String formatTo12H(String timeStr) {
    try {
      final clean = timeStr.trim();
      final isPm = clean.toUpperCase().contains('PM');
      final isAm = clean.toUpperCase().contains('AM');
      if (isPm || isAm) return clean;

      final parts = clean.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);
        final dt = DateTime(2026, 1, 1, hour, minute);
        return DateFormat('hh:mm a').format(dt);
      }
    } catch (_) {}
    return timeStr;
  }

  static Future<int> getGoal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(keyGoal) ?? 2500;
  }

  static Future<void> setGoal(int goalMl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyGoal, goalMl);
  }

  static Future<String> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyUserName) ?? 'HydroBuddy';
  }

  static Future<void> setUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyUserName, name);
  }

  static Future<int> getCurrentStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(keyCurrentStreak) ?? 0;
  }

  static Future<void> setCurrentStreak(int streak) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyCurrentStreak, streak);
  }

  static Future<int> getBestStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(keyBestStreak) ?? 0;
  }

  static Future<void> setBestStreak(int streak) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyBestStreak, streak);
  }

  static Future<String?> getLastActiveDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyLastActiveDate);
  }

  static Future<void> setLastActiveDate(String dateString) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyLastActiveDate, dateString);
  }

  static Future<Map<String, String>> getMealSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'bfast': formatTo12H(prefs.getString(keyBfastTime) ?? '08:30 AM'),
      'lunch': formatTo12H(prefs.getString(keyLunchTime) ?? '01:00 PM'),
      'dinner': formatTo12H(prefs.getString(keyDinnerTime) ?? '08:00 PM'),
    };
  }

  static Future<void> setMealSchedule(String bfast, String lunch, String dinner) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyBfastTime, bfast);
    await prefs.setString(keyLunchTime, lunch);
    await prefs.setString(keyDinnerTime, dinner);
  }

  static Future<bool> getNotifEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyNotifEnabled) ?? true;
  }

  static Future<void> setNotifEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyNotifEnabled, enabled);
  }

  static Future<bool> getPostMealNotif() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyPostMealNotif) ?? true;
  }

  static Future<void> setPostMealNotif(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyPostMealNotif, enabled);
  }

  static DateTime? parseToTime(String timeStr) {
    try {
      final clean = timeStr.trim();
      if (clean.toUpperCase().contains('AM') || clean.toUpperCase().contains('PM')) {
        return DateFormat('hh:mm a').parse(clean);
      } else {
        return DateFormat('HH:mm').parse(clean);
      }
    } catch (_) {
      return null;
    }
  }

  static List<String> sortTimesChronologically(List<String> times) {
    final list = List<String>.from(times);
    list.sort((a, b) {
      final dtA = parseToTime(a);
      final dtB = parseToTime(b);
      if (dtA == null || dtB == null) return 0;
      final minsA = dtA.hour * 60 + dtA.minute;
      final minsB = dtB.hour * 60 + dtB.minute;
      return minsA.compareTo(minsB);
    });
    return list;
  }

  static Future<List<String>> getReminderTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(keyReminderTimes) ?? ['08:00 AM', '12:00 PM', '04:00 PM', '08:00 PM'];
    final formatted = raw.map(formatTo12H).toList();
    return sortTimesChronologically(formatted);
  }

  static Future<void> setReminderTimes(List<String> times) async {
    final prefs = await SharedPreferences.getInstance();
    final formatted = times.map(formatTo12H).toList();
    final sorted = sortTimesChronologically(formatted);
    await prefs.setStringList(keyReminderTimes, sorted);
  }

  static Future<bool> getSoloOptIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keySoloOptIn) ?? true;
  }

  static Future<void> setSoloOptIn(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keySoloOptIn, val);
  }

  static Future<bool> getLeaderboardOptIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyLeaderboardOptIn) ?? true;
  }

  static Future<void> setLeaderboardOptIn(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyLeaderboardOptIn, val);
  }

  static Future<int> getCustomGlassMl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(keyCustomGlassMl) ?? 200;
  }

  static Future<void> setCustomGlassMl(int ml) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyCustomGlassMl, ml);
  }

  static Future<bool> hasConfiguredGlass() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyHasConfiguredGlass) ?? false;
  }

  static Future<void> setHasConfiguredGlass(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyHasConfiguredGlass, val);
  }

  static const String keyDisabledReminderTimes = 'disabled_reminder_times';

  static Future<List<String>> getDisabledReminderTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(keyDisabledReminderTimes) ?? [];
    return raw.map(formatTo12H).toList();
  }

  static Future<void> setDisabledReminderTimes(List<String> times) async {
    final prefs = await SharedPreferences.getInstance();
    final formatted = times.map(formatTo12H).toList();
    await prefs.setStringList(keyDisabledReminderTimes, formatted);
  }

  /// Wipe all keys in SharedPreferences
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // --- Daily toggle: tracks alarms that should fire only ONCE (not daily) ---
  // Default is empty → all alarms repeat daily.
  static const String keyOneTimeReminderTimes = 'one_time_reminder_times';

  static Future<List<String>> getOneTimeReminderTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(keyOneTimeReminderTimes) ?? [];
    return raw.map(formatTo12H).toList();
  }

  static Future<void> setOneTimeReminderTimes(List<String> times) async {
    final prefs = await SharedPreferences.getInstance();
    final formatted = times.map(formatTo12H).toList();
    await prefs.setStringList(keyOneTimeReminderTimes, formatted);
  }

  // --- One-time battery guidance dialog flag ---
  static const String keyBatteryPromptShown = 'battery_prompt_shown';

  static Future<bool> getBatteryPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyBatteryPromptShown) ?? false;
  }

  static Future<void> setBatteryPromptShown(bool shown) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyBatteryPromptShown, shown);
  }

  // --- Theme Mode: 'auto' (Schedule: 6:30 AM Light / 6:30 PM Dark), 'light', 'dark' ---
  static const String keyThemeMode = 'theme_mode';
  static const String keyIsDarkMode = 'is_dark_mode';

  static Future<String> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(keyThemeMode);
    if (mode != null && (mode == 'auto' || mode == 'light' || mode == 'dark')) {
      return mode;
    }
    // Backward compatibility for existing users who already toggled
    if (prefs.containsKey(keyIsDarkMode)) {
      final isDark = prefs.getBool(keyIsDarkMode) ?? true;
      return isDark ? 'dark' : 'light';
    }
    return 'auto';
  }

  static Future<void> setThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyThemeMode, mode);
    if (mode == 'dark') {
      await prefs.setBool(keyIsDarkMode, true);
    } else if (mode == 'light') {
      await prefs.setBool(keyIsDarkMode, false);
    }
  }

  static Future<bool> getIsDarkMode() async {
    final mode = await getThemeMode();
    if (mode == 'dark') return true;
    if (mode == 'light') return false;
    final now = DateTime.now();
    final minutes = now.hour * 60 + now.minute;
    return minutes < 390 || minutes >= 1110;
  }

  static Future<void> setIsDarkMode(bool isDark) async {
    await setThemeMode(isDark ? 'dark' : 'light');
  }

  // --- Today's intake cache for Android AppWidget ---
  static const String keyTodayIntake = 'today_intake_ml';
  static const String keyPendingWidgetLogs = 'pending_widget_logs';
  static const String keyWidgetLastActiveDate = 'widget_last_active_date';

  static Future<int> getTodayIntake() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.reload();
    } catch (_) {}
    return prefs.getInt(keyTodayIntake) ?? 0;
  }

  static Future<void> setTodayIntake(int ml) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyTodayIntake, ml);
  }

  /// Retrieve and clear any pending water logs recorded directly from the Android AppWidget
  static Future<bool> hasPromptedUsernameSetup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyHasPromptedUsername) ?? false;
  }

  static Future<void> setHasPromptedUsernameSetup(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyHasPromptedUsername, val);
  }

  static Future<List<Map<String, dynamic>>> getAndClearPendingWidgetLogs() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.reload();
    } catch (_) {}
    final raw = prefs.getString(keyPendingWidgetLogs);
    if (raw == null || raw.trim().isEmpty) return [];

    await prefs.remove(keyPendingWidgetLogs);
    final list = <Map<String, dynamic>>[];
    final items = raw.split(';');
    for (final item in items) {
      final parts = item.trim().split('|');
      if (parts.isNotEmpty) {
        final amount = int.tryParse(parts[0]) ?? 0;
        final ts = parts.length > 1 ? int.tryParse(parts[1]) : null;
        if (amount > 0) {
          list.add({
            'amount': amount,
            'timestamp': ts != null
                ? DateTime.fromMillisecondsSinceEpoch(ts)
                : DateTime.now(),
          });
        }
      }
    }
    return list;
  }

  static Future<String?> getLastSyncedUid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyLastSyncedUid);
  }

  static Future<void> setLastSyncedUid(String? uid) async {
    final prefs = await SharedPreferences.getInstance();
    if (uid == null) {
      await prefs.remove(keyLastSyncedUid);
    } else {
      await prefs.setString(keyLastSyncedUid, uid);
    }
  }
}
