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
}
