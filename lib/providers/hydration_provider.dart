import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/water_log.dart';
import '../services/db_helper.dart';
import '../services/pref_service.dart';
import '../services/notification_service.dart';

class DayTrendData {
  final String label;
  final String dateString;
  final int totalMl;
  final double ratio;

  DayTrendData({
    required this.label,
    required this.dateString,
    required this.totalMl,
    required this.ratio,
  });
}

class HydrationProvider extends ChangeNotifier {
  int _todayIntakeMl = 0;
  int _dailyGoalMl = 2500;
  int _currentStreak = 0;
  int _bestStreak = 0;
  String _userName = 'HydroBuddy';
  List<WaterLog> _todayLogs = [];
  bool _isStreakBannerDismissed = false;

  // History State
  DateTime _selectedDate = DateTime.now();
  List<WaterLog> _selectedDateLogs = [];
  int _selectedDateIntakeMl = 0;
  int _lifetimeVolumeMl = 0;
  int _perfectDaysCount = 0;
  double _successRatePct = 0.0;
  bool _isShieldActive = false;
  Map<String, int> _dailyTotalsMap = {};

  // Insights State
  List<DayTrendData> _sevenDayTrend = [];
  double _weeklyAverageMl = 0.0;
  int _weeklyTotalMl = 0;
  String _bestDayLabel = '—';
  int _bestDayMl = 0;
  String _worstDayLabel = '—';
  int _worstDayMl = 0;
  String _hitRateFraction = '0/7';
  double _hitRatePct = 0.0;
  Map<String, String> _mealSchedule = {
    'bfast': '08:30 AM',
    'lunch': '01:00 PM',
    'dinner': '08:00 PM',
  };

  // Settings State
  bool _isNotifEnabled = true;
  bool _isPostMealNotifEnabled = true;
  List<String> _reminderTimes = ['08:00 AM', '12:00 PM', '04:00 PM', '08:00 PM'];
  List<String> _disabledReminderTimes = [];
  /// Times that should fire only ONCE (not repeat daily). Default = empty → all daily.
  List<String> _oneTimeReminderTimes = [];
  bool _isSoloOptIn = true;

  int get todayIntakeMl => _todayIntakeMl;
  int get dailyGoalMl => _dailyGoalMl;
  int get currentStreak => _currentStreak;
  int get bestStreak => _bestStreak;
  String get userName => _userName;
  List<WaterLog> get todayLogs => _todayLogs;
  bool get isStreakBannerDismissed => _isStreakBannerDismissed;

  DateTime get selectedDate => _selectedDate;
  List<WaterLog> get selectedDateLogs => _selectedDateLogs;
  int get selectedDateIntakeMl => _selectedDateIntakeMl;
  int get lifetimeVolumeMl => _lifetimeVolumeMl;
  int get perfectDaysCount => _perfectDaysCount;
  double get successRatePct => _successRatePct;
  bool get isShieldActive => _isShieldActive;
  Map<String, int> get dailyTotalsMap => _dailyTotalsMap;

  List<DayTrendData> get sevenDayTrend => _sevenDayTrend;
  double get weeklyAverageMl => _weeklyAverageMl;
  int get weeklyTotalMl => _weeklyTotalMl;
  String get bestDayLabel => _bestDayLabel;
  int get bestDayMl => _bestDayMl;
  String get worstDayLabel => _worstDayLabel;
  int get worstDayMl => _worstDayMl;
  String get hitRateFraction => _hitRateFraction;
  double get hitRatePct => _hitRatePct;
  Map<String, String> get mealSchedule => _mealSchedule;

  bool get isNotifEnabled => _isNotifEnabled;
  bool get isPostMealNotifEnabled => _isPostMealNotifEnabled;
  List<String> get reminderTimes => _reminderTimes;
  List<String> get disabledReminderTimes => _disabledReminderTimes;
  List<String> get oneTimeReminderTimes => _oneTimeReminderTimes;
  List<String> get activeReminderTimes => _reminderTimes.where((t) => !_disabledReminderTimes.contains(t)).toList();
  bool isReminderEnabled(String timeStr) => !_disabledReminderTimes.contains(timeStr);

  /// Returns the notification ID that scheduleReminders assigns to [timeStr].
  /// IDs are assigned positionally: alarm at index i → ID 100 + i.
  /// Returns -1 if the time is not found.
  int _alarmIdForTime(String timeStr) {
    final idx = _reminderTimes.indexOf(timeStr);
    return idx >= 0 ? 100 + idx : -1;
  }
  /// Returns true if the alarm for [timeStr] repeats daily (not one-time).
  bool isReminderDaily(String timeStr) => !_oneTimeReminderTimes.contains(timeStr);
  bool get isSoloOptIn => _isSoloOptIn;

  String formatDateString(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);
  String get todayDateString => formatDateString(DateTime.now());
  String get selectedDateString => formatDateString(_selectedDate);

  double get progressRatio {
    if (_dailyGoalMl <= 0) return 0.0;
    return (_todayIntakeMl / _dailyGoalMl).clamp(0.0, 1.0);
  }

  int get progressPercentage => (progressRatio * 100).round();

  double get selectedDateProgressRatio {
    if (_dailyGoalMl <= 0) return 0.0;
    return (_selectedDateIntakeMl / _dailyGoalMl).clamp(0.0, 1.0);
  }

  int get selectedDateProgressPercentage => (selectedDateProgressRatio * 100).round();

  int get remainingMl {
    final remaining = _dailyGoalMl - _todayIntakeMl;
    return remaining > 0 ? remaining : 0;
  }

  bool get isStreakAtRisk {
    if (_isStreakBannerDismissed) return false;
    final now = DateTime.now();
    return now.hour >= 16 && progressRatio < 0.40;
  }

  void dismissStreakBanner() {
    _isStreakBannerDismissed = true;
    notifyListeners();
  }

  String get currentRankName => getRankForRatio(progressRatio);

  String get nextRankName {
    if (progressRatio >= 0.90) return '🔱 Max Rank Achieved!';
    if (progressRatio >= 0.80) return '🔱 Ocean Master';
    if (progressRatio >= 0.70) return '🛡️ Shield Guardian';
    if (progressRatio >= 0.60) return '🏄 Wave Rider';
    if (progressRatio >= 0.50) return '🌊 Current Commander';
    if (progressRatio >= 0.40) return '🚣 River Guide';
    if (progressRatio >= 0.30) return '🛶 Stream Sailor';
    if (progressRatio >= 0.20) return '💧 Puddle Jumper';
    if (progressRatio >= 0.10) return '🧊 Dew Dropper';
    return '🌫️ Mist Seeker';
  }

  int get nextRankTargetMl {
    if (progressRatio >= 0.90) return (_dailyGoalMl * 1.0).round();
    if (progressRatio >= 0.80) return (_dailyGoalMl * 0.90).round();
    if (progressRatio >= 0.70) return (_dailyGoalMl * 0.80).round();
    if (progressRatio >= 0.60) return (_dailyGoalMl * 0.70).round();
    if (progressRatio >= 0.50) return (_dailyGoalMl * 0.60).round();
    if (progressRatio >= 0.40) return (_dailyGoalMl * 0.50).round();
    if (progressRatio >= 0.30) return (_dailyGoalMl * 0.40).round();
    if (progressRatio >= 0.20) return (_dailyGoalMl * 0.30).round();
    if (progressRatio >= 0.10) return (_dailyGoalMl * 0.20).round();
    return (_dailyGoalMl * 0.10).round();
  }

  int get nextRankNeededMl {
    final target = nextRankTargetMl;
    final needed = target - _todayIntakeMl;
    return needed > 0 ? needed : 0;
  }

  double get nextRankProgressRatio {
    final target = nextRankTargetMl;
    if (target <= 0) return 1.0;
    return (_todayIntakeMl / target).clamp(0.0, 1.0);
  }

  Future<void> init() async {
    try {
      _dailyGoalMl = await PrefService.getGoal();
      _userName = await PrefService.getUserName();
      _currentStreak = await PrefService.getCurrentStreak();
      _bestStreak = await PrefService.getBestStreak();
      _mealSchedule = await PrefService.getMealSchedule();

      _isNotifEnabled = await PrefService.getNotifEnabled();
      _isPostMealNotifEnabled = await PrefService.getPostMealNotif();
      _reminderTimes = await PrefService.getReminderTimes();
      _disabledReminderTimes = await PrefService.getDisabledReminderTimes();
      _oneTimeReminderTimes = await PrefService.getOneTimeReminderTimes();
      _isSoloOptIn = await PrefService.getSoloOptIn();

      await checkMidnightReset();
      await loadTodayData();
      await loadHistoryStats();
      await loadInsightsData();
    } catch (e) {
      debugPrint('HydrationProvider init data load error: $e');
    }

    try {
      final dailySet = activeReminderTimes
          .where((t) => !_oneTimeReminderTimes.contains(t))
          .toSet();
      await NotificationService.scheduleReminders(
        activeReminderTimes,
        _isNotifEnabled,
        dailyTimes: dailySet,
      );
    } catch (e) {
      debugPrint('HydrationProvider notification scheduling error: $e');
    }

    notifyListeners();
  }

  Future<void> checkMidnightReset() async {
    final lastActive = await PrefService.getLastActiveDate();
    final todayStr = todayDateString;

    if (lastActive != null && lastActive != todayStr) {
      final yesterdayStr = DateFormat('yyyy-MM-dd').format(
        DateTime.now().subtract(const Duration(days: 1)),
      );

      if (lastActive == yesterdayStr) {
        final yesterdayIntake = await DBHelper.instance.getTotalIntakeForDate(yesterdayStr);
        if (yesterdayIntake < _dailyGoalMl) {
          _currentStreak = 0;
          await PrefService.setCurrentStreak(0);
        }
      } else {
        _currentStreak = 0;
        await PrefService.setCurrentStreak(0);
      }
    }

    await PrefService.setLastActiveDate(todayStr);
  }

  Future<void> loadTodayData() async {
    _todayLogs = await DBHelper.instance.getLogsForDate(todayDateString);
    _todayIntakeMl = 0;
    for (var log in _todayLogs) {
      _todayIntakeMl += log.amountMl;
    }
    await loadSelectedDateData();
    notifyListeners();
  }

  Future<void> selectDate(DateTime date) async {
    _selectedDate = date;
    await loadSelectedDateData();
    notifyListeners();
  }

  Future<void> loadSelectedDateData() async {
    final dateStr = selectedDateString;
    _selectedDateLogs = await DBHelper.instance.getLogsForDate(dateStr);
    _selectedDateIntakeMl = 0;
    for (var log in _selectedDateLogs) {
      _selectedDateIntakeMl += log.amountMl;
    }
  }

  Future<void> loadHistoryStats() async {
    _lifetimeVolumeMl = await DBHelper.instance.getLifetimeVolume();
    _dailyTotalsMap = await DBHelper.instance.getDailyTotalsMap();

    int perfect = 0;
    _dailyTotalsMap.forEach((date, total) {
      if (total >= _dailyGoalMl) {
        perfect++;
      }
    });
    _perfectDaysCount = perfect;

    int hitCount30 = 0;
    final now = DateTime.now();
    for (int i = 0; i < 30; i++) {
      final d = now.subtract(Duration(days: i));
      final dStr = formatDateString(d);
      final total = _dailyTotalsMap[dStr] ?? 0;
      if (total >= _dailyGoalMl) {
        hitCount30++;
      }
    }
    _successRatePct = (hitCount30 / 30.0) * 100;

    int streakCount = 0;
    for (int i = 0; i < 30; i++) {
      final d = now.subtract(Duration(days: i));
      final dStr = formatDateString(d);
      final total = _dailyTotalsMap[dStr] ?? 0;
      if (total >= _dailyGoalMl) {
        streakCount++;
      } else if (i > 0) {
        break;
      }
    }
    _isShieldActive = streakCount >= 3;

    notifyListeners();
  }

  Future<void> loadInsightsData() async {
    final now = DateTime.now();
    final List<DayTrendData> trendList = [];
    int weeklyTotal = 0;
    int hitCount7 = 0;

    int maxMl = -1;
    String maxDayLabel = '—';
    int minMl = 999999;
    String minDayLabel = '—';

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = formatDateString(date);
      final total = _dailyTotalsMap[dateStr] ?? 0;
      final ratio = _dailyGoalMl > 0 ? (total / _dailyGoalMl) : 0.0;

      String label;
      if (i == 0) {
        label = 'Today';
      } else if (i == 1) {
        label = 'Yesterday';
      } else {
        label = DateFormat('E').format(date);
      }

      trendList.add(DayTrendData(
        label: label,
        dateString: dateStr,
        totalMl: total,
        ratio: ratio,
      ));

      weeklyTotal += total;
      if (total >= _dailyGoalMl) {
        hitCount7++;
      }

      if (total > maxMl) {
        maxMl = total;
        maxDayLabel = DateFormat('EEEE').format(date);
      }
      if (total < minMl) {
        minMl = total;
        minDayLabel = DateFormat('EEEE').format(date);
      }
    }

    _sevenDayTrend = trendList;
    _weeklyTotalMl = weeklyTotal;
    _weeklyAverageMl = (weeklyTotal / 7.0);
    _bestDayLabel = maxMl > 0 ? '$maxDayLabel (${(maxMl / 1000).toStringAsFixed(1)}L)' : 'None';
    _bestDayMl = maxMl > 0 ? maxMl : 0;
    _worstDayLabel = minMl < 999999 ? '$minDayLabel (${(minMl / 1000).toStringAsFixed(1)}L)' : 'None';
    _worstDayMl = minMl < 999999 ? minMl : 0;
    _hitRateFraction = '$hitCount7/7';
    _hitRatePct = (hitCount7 / 7.0) * 100;

    notifyListeners();
  }

  int calculateSuggestedGoal({
    double? heightCm,
    required double weightKg,
    required int age,
    required String gender,
  }) {
    double base = weightKg * 35.0;
    double hAdj = (heightCm ?? 170.0) * 2.0;
    double aAdj = age < 30 ? 200.0 : (age > 55 ? -150.0 : 0.0);
    double gAdj = gender.toLowerCase() == 'male' ? 250.0 : 0.0;

    int total = (base + hAdj + aAdj + gAdj).round();
    return total.clamp(1500, 5000);
  }

  Future<void> toggleNotif(bool enabled) async {
    _isNotifEnabled = enabled;
    notifyListeners();
    await PrefService.setNotifEnabled(enabled);
    if (enabled) {
      await NotificationService.requestPermissions();
    }
    try {
      await NotificationService.scheduleReminders(
        activeReminderTimes,
        _isNotifEnabled,
        dailyTimes: _buildDailySet(),
      );
    } catch (_) {}
  }

  Future<void> togglePostMealNotif(bool enabled) async {
    _isPostMealNotifEnabled = enabled;
    notifyListeners();
    await PrefService.setPostMealNotif(enabled);
  }

  Future<void> addReminderTime(String timeStr) async {
    final formatted = PrefService.formatTo12H(timeStr);
    if (!_reminderTimes.contains(formatted)) {
      _reminderTimes.add(formatted);
      _reminderTimes = PrefService.sortTimesChronologically(_reminderTimes);
      notifyListeners();
      await PrefService.setReminderTimes(_reminderTimes);
      try {
        await NotificationService.scheduleReminders(
          activeReminderTimes,
          _isNotifEnabled,
          dailyTimes: _buildDailySet(),
        );
      } catch (_) {}
    }
  }

  Future<void> removeReminderTime(String timeStr) async {
    // Resolve alarm ID BEFORE removing from the list (removal shifts indices)
    final alarmId = _alarmIdForTime(timeStr);

    _reminderTimes.remove(timeStr);
    _disabledReminderTimes.remove(timeStr);
    _oneTimeReminderTimes.remove(timeStr); // clean up daily-toggle state
    notifyListeners();
    await PrefService.setReminderTimes(_reminderTimes);
    await PrefService.setDisabledReminderTimes(_disabledReminderTimes);
    await PrefService.setOneTimeReminderTimes(_oneTimeReminderTimes);
    try {
      // Cancel just the deleted alarm immediately — no full wipe needed
      if (alarmId >= 0) await NotificationService.cancelAlarm(alarmId);
      // Reschedule remaining alarms so IDs stay consistent (positional)
      await NotificationService.scheduleReminders(
        activeReminderTimes,
        _isNotifEnabled,
        dailyTimes: _buildDailySet(),
      );
    } catch (_) {}
  }

  Future<void> toggleReminderActive(String timeStr, bool active) async {
    if (active) {
      _disabledReminderTimes.remove(timeStr);
    } else {
      if (!_disabledReminderTimes.contains(timeStr)) {
        _disabledReminderTimes.add(timeStr);
      }
    }
    notifyListeners();
    await PrefService.setDisabledReminderTimes(_disabledReminderTimes);
    try {
      if (!active) {
        // Cancel ONLY this alarm's OS entry and in-memory timer
        final alarmId = _alarmIdForTime(timeStr);
        if (alarmId >= 0) await NotificationService.cancelAlarm(alarmId);
      } else {
        // Re-enabling: reschedule all so this alarm gets its ID back
        await NotificationService.scheduleReminders(
          activeReminderTimes,
          _isNotifEnabled,
          dailyTimes: _buildDailySet(),
        );
      }
    } catch (_) {}
  }

  /// Toggle whether a reminder fires daily or only once.
  Future<void> toggleReminderDaily(String timeStr, bool isDaily) async {
    if (isDaily) {
      _oneTimeReminderTimes.remove(timeStr);
    } else {
      if (!_oneTimeReminderTimes.contains(timeStr)) {
        _oneTimeReminderTimes.add(timeStr);
      }
    }
    notifyListeners();
    await PrefService.setOneTimeReminderTimes(_oneTimeReminderTimes);
    try {
      await NotificationService.scheduleReminders(
        activeReminderTimes,
        _isNotifEnabled,
        dailyTimes: _buildDailySet(),
      );
    } catch (_) {}
  }

  /// Returns the set of active reminder times that should repeat daily.
  Set<String> _buildDailySet() {
    return activeReminderTimes
        .where((t) => !_oneTimeReminderTimes.contains(t))
        .toSet();
  }

  Future<void> toggleSoloOptIn(bool val) async {
    _isSoloOptIn = val;
    await PrefService.setSoloOptIn(val);
    notifyListeners();
  }

  Future<void> clearAllData() async {
    // 1. Wipe all local SQLite database logs
    await DBHelper.instance.clearAllLogs();

    // 2. Clear all SharedPreferences storage
    await PrefService.clearAll();

    // 3. Cancel all system background notifications and active in-memory timers
    await NotificationService.cancelAllAlarms();

    // 4. Reset all in-memory provider state to factory defaults
    _todayIntakeMl = 0;
    _dailyGoalMl = 2500;
    _currentStreak = 0;
    _bestStreak = 0;
    _userName = 'HydroBuddy';
    _todayLogs = [];
    _isStreakBannerDismissed = false;

    _selectedDate = DateTime.now();
    _selectedDateLogs = [];
    _selectedDateIntakeMl = 0;
    _lifetimeVolumeMl = 0;
    _perfectDaysCount = 0;
    _successRatePct = 0.0;
    _isShieldActive = false;
    _dailyTotalsMap = {};

    _sevenDayTrend = [];
    _weeklyAverageMl = 0.0;
    _weeklyTotalMl = 0;
    _bestDayLabel = '—';
    _bestDayMl = 0;
    _worstDayLabel = '—';
    _worstDayMl = 0;
    _hitRateFraction = '0/7';
    _hitRatePct = 0.0;
    _mealSchedule = {
      'bfast': '08:30 AM',
      'lunch': '01:00 PM',
      'dinner': '08:00 PM',
    };

    _isNotifEnabled = true;
    _isPostMealNotifEnabled = true;
    _reminderTimes = ['08:00 AM', '12:00 PM', '04:00 PM', '08:00 PM'];
    _disabledReminderTimes = [];
    _oneTimeReminderTimes = []; // reset: all reminders back to daily by default
    _isSoloOptIn = true;

    // 5. Re-seed default settings
    await PrefService.setGoal(_dailyGoalMl);
    await PrefService.setUserName(_userName);
    await PrefService.setReminderTimes(_reminderTimes);
    await PrefService.setDisabledReminderTimes(_disabledReminderTimes);
    await PrefService.setOneTimeReminderTimes(_oneTimeReminderTimes);
    await PrefService.setNotifEnabled(_isNotifEnabled);
    await PrefService.setPostMealNotif(_isPostMealNotifEnabled);
    await PrefService.setMealSchedule('08:30 AM', '01:00 PM', '08:00 PM');
    await PrefService.setSoloOptIn(_isSoloOptIn);

    // 6. Schedule fresh reminders (all daily by default after reset)
    try {
      await NotificationService.scheduleReminders(
        _reminderTimes,
        _isNotifEnabled,
        dailyTimes: _reminderTimes.toSet(),
      );
    } catch (_) {}

    // 7. Reload and notify all UI listeners
    await loadTodayData();
    await loadHistoryStats();
    await loadInsightsData();
    notifyListeners();
  }

  Future<void> saveMealSchedule(String bfast, String lunch, String dinner) async {
    _mealSchedule = {
      'bfast': bfast,
      'lunch': lunch,
      'dinner': dinner,
    };
    await PrefService.setMealSchedule(bfast, lunch, dinner);
    notifyListeners();
  }

  Future<void> logWater(int amountMl) async {
    final log = WaterLog(
      amountMl: amountMl,
      timestamp: DateTime.now(),
      dateString: todayDateString,
    );

    await DBHelper.instance.insertLog(log);
    _todayIntakeMl += amountMl;

    if (_todayIntakeMl >= _dailyGoalMl) {
      final todayIntakeBefore = _todayIntakeMl - amountMl;
      if (todayIntakeBefore < _dailyGoalMl) {
        _currentStreak++;
        await PrefService.setCurrentStreak(_currentStreak);

        if (_currentStreak > _bestStreak) {
          _bestStreak = _currentStreak;
          await PrefService.setBestStreak(_bestStreak);
        }
      }
    }

    await loadTodayData();
    await loadHistoryStats();
    await loadInsightsData();
  }

  Future<bool> undoLastLog() async {
    final lastLog = await DBHelper.instance.getLastLogForDate(todayDateString);
    if (lastLog != null && lastLog.id != null) {
      await DBHelper.instance.deleteLog(lastLog.id!);
      await loadTodayData();
      await loadHistoryStats();
      await loadInsightsData();
      return true;
    }
    return false;
  }

  Future<void> deleteLogById(int id) async {
    await DBHelper.instance.deleteLog(id);
    await loadTodayData();
    await loadHistoryStats();
    await loadInsightsData();
  }

  Future<void> updateGoal(int newGoalMl) async {
    _dailyGoalMl = newGoalMl;
    await PrefService.setGoal(newGoalMl);
    await loadHistoryStats();
    await loadInsightsData();
    notifyListeners();
  }

  Future<void> updateUserName(String name) async {
    _userName = name;
    await PrefService.setUserName(name);
    notifyListeners();
  }

  String getRankForRatio(double ratio) {
    if (ratio >= 0.90) return '🔱 Ocean Master';
    if (ratio >= 0.80) return '🛡️ Shield Guardian';
    if (ratio >= 0.70) return '🏄 Wave Rider';
    if (ratio >= 0.60) return '🌊 Current Commander';
    if (ratio >= 0.50) return '🚣 River Guide';
    if (ratio >= 0.40) return '🛶 Stream Sailor';
    if (ratio >= 0.30) return '💧 Puddle Jumper';
    if (ratio >= 0.20) return '🧊 Dew Dropper';
    if (ratio >= 0.10) return '🌫️ Mist Seeker';
    return '🌵 Desert Dweller';
  }

  String get currentSelectedRank => getRankForRatio(selectedDateProgressRatio);

  String getCoachResponse(String userPrompt) {
    final prompt = userPrompt.toLowerCase();

    if (prompt.contains('how am i doing') || prompt.contains('progress') || prompt.contains('status')) {
      if (progressRatio >= 1.0) {
        return "🎉 Fantastic job, $_userName! You've achieved 100% of your daily goal (${_todayIntakeMl}ml). Stay refreshed!";
      } else if (progressRatio >= 0.5) {
        return "👍 Doing great! You are at $progressPercentage% of your daily goal with ${_todayIntakeMl}ml logged. Keep sipping!";
      } else {
        return "⏰ You've consumed ${_todayIntakeMl}ml so far ($progressPercentage%). You still need ${remainingMl}ml to hit your goal. Time for a glass of water!";
      }
    }

    if (prompt.contains('when should i drink') || prompt.contains('next')) {
      if (remainingMl == 0) {
        return "✨ You've met your daily intake! Have a small glass of water before bedtime or after physical activity.";
      }
      if (isStreakAtRisk) {
        return "🚨 Right now! You're behind on your target for today. Drink at least 500ml now to keep your streak alive!";
      }
      return "🥤 Based on your remaining ${remainingMl}ml goal, I recommend drinking 250ml every 1.5 to 2 hours.";
    }

    if (prompt.contains('remaining goal') || prompt.contains('remaining') || prompt.contains('left')) {
      if (remainingMl == 0) {
        return "🎯 Daily goal achieved! You've hit ${dailyGoalMl}ml today!";
      }
      final remainingL = (remainingMl / 1000).toStringAsFixed(2);
      return "🎯 You need ${remainingMl}ml ($remainingL L) more to reach your target of ${dailyGoalMl}ml today.";
    }

    if (prompt.contains('streak')) {
      if (_currentStreak > 0) {
        return "🔥 You're on a $_currentStreak-day hydration streak! Your all-time best is $_bestStreak days. Keep it up!";
      } else {
        return "🔥 No active streak today. Hit your ${dailyGoalMl}ml target today to ignite a new streak!";
      }
    }

    if (prompt.contains('tip') || prompt.contains('advice')) {
      final tips = [
        "💡 Tip: Drink a glass of water first thing in the morning to kickstart your metabolism!",
        "💡 Tip: Drink water 30 minutes before meals to aid digestion.",
        "💡 Tip: Keep a water bottle on your desk or nearby as a visual reminder.",
        "💡 Tip: If you feel tired during the day, try drinking water—dehydration causes fatigue!",
        "💡 Tip: Electrolytes & natural water help absorb hydration faster."
      ];
      tips.shuffle();
      return tips.first;
    }

    return "💧 Offline Coach: You've drunk ${_todayIntakeMl}ml / ${_dailyGoalMl}ml ($progressPercentage%) today. Remaining: ${remainingMl}ml. Stay hydrated!";
  }
}
