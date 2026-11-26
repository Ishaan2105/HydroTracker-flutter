import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/water_log.dart';
import '../services/db_helper.dart';
import '../services/pref_service.dart';
import '../services/notification_service.dart';
import '../services/app_logger.dart';
import '../services/cloud_sync_service.dart';
import '../services/widget_service.dart';
import '../services/weather_service.dart';
import '../services/app_update_service.dart';

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
  int _baseRegularGoalMl = 2500;
  bool _isWeatherBoostActive = false;
  int _appliedWeatherBoostMl = 0;
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
  List<DayTrendData> _sevenDayTrend = generateDefaultSevenDayTrend();
  double _weeklyAverageMl = 0.0;
  int _weeklyTotalMl = 0;
  String _bestDayLabel = '—';
  int _bestDayMl = 0;
  String _worstDayLabel = '—';
  int _worstDayMl = 0;
  String _hitRateFraction = '0/7';
  double _hitRatePct = 0.0;
  int _morningIntakeMl = 0;
  int _afternoonIntakeMl = 0;
  int _eveningIntakeMl = 0;
  Map<String, String> _mealSchedule = {
    'bfast': '08:30 AM',
    'lunch': '01:00 PM',
    'dinner': '08:00 PM',
  };

  // Settings State
  bool _isNotifEnabled = true;
  bool _isPostMealNotifEnabled = true;
  List<String> _reminderTimes = List.from(PrefService.kDefaultReminderTimes);
  List<String> _disabledReminderTimes = [];
  /// Times that should fire only ONCE (not repeat daily). Default = empty → all daily.
  List<String> _oneTimeReminderTimes = [];
  bool _isSoloOptIn = true;
  bool _isLeaderboardOptIn = true;
  int _customGlassMl = 200;
  bool _hasConfiguredGlass = false;
  String _themeMode = 'auto'; // 'auto' (schedule: 6:30 AM Light / 6:30 PM Dark), 'light', 'dark'
  bool _isDarkMode = true;
  UpdateGateResult? _updateGateResult;
  bool _isUpdateBannerDismissed = false;

  UpdateGateResult? get updateGateResult => _updateGateResult;
  bool get isUpdateBannerDismissed => _isUpdateBannerDismissed;

  void setUpdateGateResult(UpdateGateResult? result) {
    _updateGateResult = result;
    notifyListeners();
  }

  void dismissUpdateBanner() {
    _isUpdateBannerDismissed = true;
    notifyListeners();
  }

  int get todayIntakeMl => _todayIntakeMl;
  int get dailyGoalMl => _dailyGoalMl;
  int get baseRegularGoalMl => _baseRegularGoalMl;
  bool get isWeatherBoostActive => _isWeatherBoostActive;
  int get appliedWeatherBoostMl => _appliedWeatherBoostMl;
  int get currentStreak => _currentStreak;
  int get bestStreak => _bestStreak;
  String get userName => _userName;
  List<WaterLog> get todayLogs => _todayLogs;
  bool get isStreakBannerDismissed => _isStreakBannerDismissed;
  bool get isLeaderboardOptIn => _isLeaderboardOptIn;
  int get customGlassMl => _customGlassMl;
  bool get hasConfiguredGlass => _hasConfiguredGlass;
  String get themeMode => _themeMode;

  /// Returns true if [dt] (or DateTime.now()) falls within the daytime window:
  /// from 6:30 AM (390 min) up to 6:30 PM / 18:30 (1110 min).
  static bool isDaytime([DateTime? dt]) {
    final now = dt ?? DateTime.now();
    final minutes = now.hour * 60 + now.minute;
    return minutes >= 390 && minutes < 1110;
  }

  /// Evaluates whether the app should render in Dark Mode:
  /// - If user selected 'dark' -> true
  /// - If user selected 'light' -> false
  /// - If user selected 'auto' -> Daytime (6:30 AM to 6:30 PM) is Light Mode (false);
  ///                               Nighttime (6:30 PM to 6:30 AM) is Dark Mode (true).
  bool get isDarkMode {
    if (_themeMode == 'dark') return true;
    if (_themeMode == 'light') return false;
    return !isDaytime();
  }

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
  int get morningIntakeMl => _morningIntakeMl;
  int get afternoonIntakeMl => _afternoonIntakeMl;
  int get eveningIntakeMl => _eveningIntakeMl;
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
    if (progressRatio >= 0.90) return 'Max Rank Achieved!';
    if (progressRatio >= 0.80) return 'Ocean Master';
    if (progressRatio >= 0.70) return 'Shield Guardian';
    if (progressRatio >= 0.60) return 'Wave Rider';
    if (progressRatio >= 0.50) return 'Current Commander';
    if (progressRatio >= 0.40) return 'River Guide';
    if (progressRatio >= 0.30) return 'Stream Sailor';
    if (progressRatio >= 0.20) return 'Puddle Jumper';
    if (progressRatio >= 0.10) return 'Dew Dropper';
    return 'Mist Seeker';
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
      final savedGoal = await PrefService.getGoal();
      _baseRegularGoalMl = savedGoal > 0 ? savedGoal : 2500;
      _dailyGoalMl = _baseRegularGoalMl;
      _userName = await PrefService.getUserName();
      _currentStreak = await PrefService.getCurrentStreak();
      _bestStreak = await PrefService.getBestStreak();
      _mealSchedule = await PrefService.getMealSchedule();

      _isNotifEnabled = true; // Hydration alerts are permanently enabled
      await PrefService.setNotifEnabled(true);
      _isPostMealNotifEnabled = await PrefService.getPostMealNotif();
      _reminderTimes = await PrefService.getReminderTimes();
      _disabledReminderTimes = await PrefService.getDisabledReminderTimes();
      _oneTimeReminderTimes = await PrefService.getOneTimeReminderTimes();
      _isSoloOptIn = await PrefService.getSoloOptIn();
      _isLeaderboardOptIn = await PrefService.getLeaderboardOptIn();
      _customGlassMl = await PrefService.getCustomGlassMl();
      _hasConfiguredGlass = await PrefService.hasConfiguredGlass();
      _themeMode = await PrefService.getThemeMode();
      _isDarkMode = isDarkMode;

      await checkMidnightReset();
      await loadTodayData();
      await loadHistoryStats();
      await loadInsightsData();
      await WidgetService.updateWidgetData(
        _todayIntakeMl,
        _dailyGoalMl,
        customGlassMl: _customGlassMl,
        hasConfiguredGlass: _hasConfiguredGlass,
      );

      NotificationService.notificationIntakeStream.stream.listen((amount) async {
        await loadTodayData();
        await loadHistoryStats();
        await loadInsightsData();
        if (_isLeaderboardOptIn) {
          CloudSyncService.instance.syncLeaderboardEntry(this);
        }
        notifyListeners();
      });
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
      await NotificationService.schedulePostMealReminders(
        _mealSchedule,
        _isPostMealNotifEnabled && _isNotifEnabled,
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

    // Automatic Reset: If a weather goal boost was applied on an earlier day, revert to default goal
    final restoredGoal = await WeatherService.clearWeatherBoostIfExpired();
    if (restoredGoal != null && restoredGoal > 0) {
      _dailyGoalMl = restoredGoal;
      _baseRegularGoalMl = restoredGoal;
      _isWeatherBoostActive = false;
      _appliedWeatherBoostMl = 0;
      await PrefService.setGoal(restoredGoal);
      WidgetService.updateWidgetData(_todayIntakeMl, _dailyGoalMl);
      AppLogger.info('HydrationProvider', 'Day ended: Reverted weather boost to default goal: ${restoredGoal}ml');
      notifyListeners();
    }

    await PrefService.setLastActiveDate(todayStr);
  }

  Future<void> loadTodayData() async {
    // Check if weather goal boost expired (new day rollover)
    final expiredBaseGoal = await WeatherService.clearWeatherBoostIfExpired();
    if (expiredBaseGoal != null && expiredBaseGoal > 0) {
      _dailyGoalMl = expiredBaseGoal;
      _baseRegularGoalMl = expiredBaseGoal;
      _isWeatherBoostActive = false;
      _appliedWeatherBoostMl = 0;
      await PrefService.setGoal(expiredBaseGoal);
      WidgetService.updateWidgetData(_todayIntakeMl, _dailyGoalMl);
      notifyListeners();
    } else {
      final boostApplied = await WeatherService.isBoostAppliedToday();
      if (boostApplied) {
        final base = await WeatherService.getBaseRegularGoal();
        if (base != null && base > 0) {
          _baseRegularGoalMl = base;
        }
        _appliedWeatherBoostMl = await WeatherService.getAppliedBoostMl();
        _isWeatherBoostActive = true;
        _dailyGoalMl = _baseRegularGoalMl + _appliedWeatherBoostMl;
      } else {
        _isWeatherBoostActive = false;
        _appliedWeatherBoostMl = 0;
        _dailyGoalMl = _baseRegularGoalMl;
      }
    }

    // 1. Drain pending logs recorded directly from the Android AppWidget
    final pendingLogs = await PrefService.getAndClearPendingWidgetLogs();
    if (pendingLogs.isNotEmpty) {
      for (final item in pendingLogs) {
        final amount = item['amount'] as int;
        final timestamp = item['timestamp'] as DateTime;
        final dateStr = formatDateString(timestamp);
        final newLog = WaterLog(
          amountMl: amount,
          timestamp: timestamp,
          dateString: dateStr,
        );
        await DBHelper.instance.insertLog(newLog);
        CloudSyncService.instance.syncSingleLog(newLog);
      }
      await loadHistoryStats();
      await loadInsightsData();
    }

    // 2. Fetch all logs for today directly from SQLite (Single Source of Truth)
    _todayLogs = await DBHelper.instance.getLogsForDate(todayDateString);
    _todayIntakeMl = 0;
    for (var log in _todayLogs) {
      _todayIntakeMl += log.amountMl;
    }

    // 3. Keep SharedPreferences and AppWidget synchronized with SQLite
    await PrefService.setTodayIntake(_todayIntakeMl);
    await loadSelectedDateData();
    WidgetService.updateWidgetData(_todayIntakeMl, _dailyGoalMl);
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

    // 1. Perfect days count (all time)
    int perfect = 0;
    _dailyTotalsMap.forEach((date, total) {
      if (total >= _dailyGoalMl) {
        perfect++;
      }
    });
    _perfectDaysCount = perfect;

    // 2. 30-day Success Rate
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

    // 3. Strict Date-Continuity Current Streak Calculation
    final todayStr = todayDateString;
    final todayTotal = _dailyTotalsMap[todayStr] ?? _todayIntakeMl;
    final bool todayCompleted = _dailyGoalMl > 0 && todayTotal >= _dailyGoalMl;

    // Count consecutive completed days strictly backwards starting from yesterday
    int consecutivePastDays = 0;
    int dayOffset = 1;
    while (true) {
      final pastDate = now.subtract(Duration(days: dayOffset));
      final pastDateStr = formatDateString(pastDate);
      final pastTotal = _dailyTotalsMap[pastDateStr] ?? 0;
      if (_dailyGoalMl > 0 && pastTotal >= _dailyGoalMl) {
        consecutivePastDays++;
        dayOffset++;
      } else {
        // Break on the first missing/incomplete day — strict continuity!
        break;
      }
    }

    if (todayCompleted) {
      _currentStreak = consecutivePastDays + 1;
    } else {
      // Today is in progress; streak from yesterday remains active
      _currentStreak = consecutivePastDays;
    }
    await PrefService.setCurrentStreak(_currentStreak);

    // 4. Best Streak Calculation across all history
    int maxStreakFound = 0;
    if (_dailyTotalsMap.isNotEmpty && _dailyGoalMl > 0) {
      final validDates = <DateTime>{};
      _dailyTotalsMap.forEach((dateStr, total) {
        if (total >= _dailyGoalMl) {
          try {
            final parsed = DateTime.parse(dateStr);
            validDates.add(DateTime(parsed.year, parsed.month, parsed.day));
          } catch (_) {}
        }
      });
      if (todayCompleted) {
        validDates.add(DateTime(now.year, now.month, now.day));
      }

      if (validDates.isNotEmpty) {
        final sortedDates = validDates.toList()..sort();
        int currentRun = 1;
        maxStreakFound = 1;

        for (int i = 1; i < sortedDates.length; i++) {
          final prev = sortedDates[i - 1];
          final curr = sortedDates[i];
          final diffDays = curr.difference(prev).inDays;
          if (diffDays == 1) {
            currentRun++;
            if (currentRun > maxStreakFound) {
              maxStreakFound = currentRun;
            }
          } else if (diffDays > 1) {
            currentRun = 1;
          }
        }
      }
    }

    final storedBest = await PrefService.getBestStreak();
    _bestStreak = [storedBest, maxStreakFound, _currentStreak].reduce((a, b) => a > b ? a : b);
    await PrefService.setBestStreak(_bestStreak);

    _isShieldActive = _currentStreak >= 3;

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

    try {
      final startDateStr = formatDateString(now.subtract(const Duration(days: 6)));
      final endDateStr = formatDateString(now);
      final weekLogs = await DBHelper.instance.getLogsForDateRange(startDateStr, endDateStr);
      int morning = 0;
      int afternoon = 0;
      int evening = 0;
      for (var log in weekLogs) {
        final hour = log.timestamp.hour;
        if (hour >= 6 && hour < 12) {
          morning += log.amountMl;
        } else if (hour >= 12 && hour < 18) {
          afternoon += log.amountMl;
        } else {
          evening += log.amountMl;
        }
      }
      _morningIntakeMl = morning;
      _afternoonIntakeMl = afternoon;
      _eveningIntakeMl = evening;
    } catch (_) {}

    notifyListeners();
  }

  /// Calculates the ideal daily drinking water goal in mL based on the
  /// landmark human water turnover model published in Science:
  /// Yamada et al., Science 378, 909–915 (2022).
  ///
  /// Step 1: Estimate water turnover (mL/day)
  /// WT = 1076 * PAL
  ///    + 14.34 * weight_kg
  ///    + 374.9 * sex (female = 0, male = 1)
  ///    + 5.823 * humidity_%
  ///    + 1070 * athlete (no = 0, yes = 1)
  ///    + 104.6 * HDI (0 = High, 1 = Medium e.g. India, 2 = Low)
  ///    + 0.4726 * altitude_m
  ///    - 0.3529 * age^2 + 24.78 * age
  ///    + 1.865 * temp^2 - 19.66 * temp
  ///    - 713.1
  ///
  /// Step 2: Convert to a drinks-only goal
  /// daily_goal_mL = WT * 0.85 * 0.8  (approx WT * 0.68)
  /// (0.85 turnover -> total intake; 0.8 removes ~20% moisture from food)
  ///
  /// Step 3: Apply safety limits & round to nearest 50 mL
  /// Clamped between 1500 mL and 4000 mL, rounded to nearest 50 mL.
  int calculateSuggestedGoal({
    required double weightKg,
    required int age,
    required String gender,
    double pal = 1.75,
    bool isAthlete = false,
    double tempC = 28.0,
    double humidityPct = 50.0,
    double altitudeM = 0.0,
    int hdi = 1,
    double? heightCm,
  }) {
    // sex: female = 0, male = 1, other/unspecified = 0.5
    final double sex;
    final gLower = gender.toLowerCase();
    if (gLower == 'female') {
      sex = 0.0;
    } else if (gLower == 'male') {
      sex = 1.0;
    } else {
      sex = 0.5;
    }

    final double athlete = isAthlete ? 1.0 : 0.0;
    // Model calibrated for adult physiology (18+)
    final double safeAge = (age < 18 ? 18 : age).toDouble();
    final double safeWeight = weightKg > 0 ? weightKg : 60.0;

    // Step 1: Estimate water turnover (mL/day)
    final double wt = 1076.0 * pal
        + 14.34 * safeWeight
        + 374.9 * sex
        + 5.823 * humidityPct
        + 1070.0 * athlete
        + 104.6 * hdi.toDouble()
        + 0.4726 * altitudeM
        - 0.3529 * (safeAge * safeAge) + 24.78 * safeAge
        + 1.865 * (tempC * tempC) - 19.66 * tempC
        - 713.1;

    // Step 2: Convert to drinks-only goal
    final double drinksGoal = wt * 0.85 * 0.8;

    // Step 3: Apply safety limits & round to nearest 50 mL
    final double clamped = drinksGoal.clamp(1500.0, 4000.0);
    final int rounded = (clamped / 50.0).round() * 50;

    return rounded;
  }

  Future<void> toggleNotif([bool enabled = true]) async {
    _isNotifEnabled = true; // Alerts are permanently enabled
    notifyListeners();
    await PrefService.setNotifEnabled(true);
    await NotificationService.requestPermissions();
    try {
      await NotificationService.scheduleReminders(
        activeReminderTimes,
        _isNotifEnabled,
        dailyTimes: _buildDailySet(),
      );
      await NotificationService.schedulePostMealReminders(
        _mealSchedule,
        _isPostMealNotifEnabled && _isNotifEnabled,
      );
    } catch (_) {}
  }

  Future<void> togglePostMealNotif(bool enabled) async {
    _isPostMealNotifEnabled = enabled;
    notifyListeners();
    await PrefService.setPostMealNotif(enabled);
    if (enabled) {
      await NotificationService.requestPermissions();
    }
    try {
      await NotificationService.schedulePostMealReminders(
        _mealSchedule,
        enabled && _isNotifEnabled,
      );
    } catch (e, st) {
      AppLogger.error('HydrationProvider', 'togglePostMealNotif error: $e', e, st);
    }
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

  Future<void> toggleLeaderboardOptIn(bool val) async {
    _isLeaderboardOptIn = val;
    notifyListeners();
    await PrefService.setLeaderboardOptIn(val);
    await CloudSyncService.instance.updateLeaderboardParticipation(this, val);
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

    _sevenDayTrend = generateDefaultSevenDayTrend();
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
    _reminderTimes = List.from(PrefService.kDefaultReminderTimes);
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

  /// Cleanly resets local provider state upon account sign out
  Future<void> resetForSignOut() async {
    _todayIntakeMl = 0;
    _todayLogs = [];
    _selectedDateLogs = [];
    _selectedDateIntakeMl = 0;
    _lifetimeVolumeMl = 0;
    _perfectDaysCount = 0;
    _successRatePct = 0.0;
    _currentStreak = 0;
    _bestStreak = 0;
    _dailyTotalsMap = {};
    _sevenDayTrend = generateDefaultSevenDayTrend();
    _weeklyAverageMl = 0.0;
    _weeklyTotalMl = 0;
    _bestDayLabel = '—';
    _bestDayMl = 0;
    _worstDayLabel = '—';
    _worstDayMl = 0;
    _hitRateFraction = '0/7';
    _hitRatePct = 0.0;
    _morningIntakeMl = 0;
    _afternoonIntakeMl = 0;
    _eveningIntakeMl = 0;
    _userName = 'HydroBuddy';
    _dailyGoalMl = 2500;
    _baseRegularGoalMl = 2500;
    await PrefService.setUserName('HydroBuddy');
    await PrefService.setGoal(2500);
    await PrefService.setCurrentStreak(0);
    await PrefService.setBestStreak(0);
    await WidgetService.updateWidgetData(0, 2500);
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
    try {
      await NotificationService.schedulePostMealReminders(
        _mealSchedule,
        _isPostMealNotifEnabled && _isNotifEnabled,
      );
    } catch (e, st) {
      AppLogger.error('HydrationProvider', 'saveMealSchedule error: $e', e, st);
    }
  }

  Future<void> logWater(int amountMl) async {
    try {
      final log = WaterLog(
        amountMl: amountMl,
        timestamp: DateTime.now(),
        dateString: todayDateString,
      );

      await DBHelper.instance.insertLog(log);
      CloudSyncService.instance.syncSingleLog(log);
      await loadTodayData();
      await loadHistoryStats();
      await loadInsightsData();
      if (_isLeaderboardOptIn) {
        CloudSyncService.instance.syncLeaderboardEntry(this);
      }
    } catch (e, st) {
      AppLogger.error('HydrationProvider', 'logWater failed: $e', e, st);
    }
  }

  Future<bool> undoLastLog() async {
    try {
      final lastLog = await DBHelper.instance.getLastLogForDate(todayDateString);
      if (lastLog != null && lastLog.id != null) {
        await DBHelper.instance.deleteLog(lastLog.id!);
        CloudSyncService.instance.deleteSingleLog(lastLog.timestamp);
        _todayLogs = await DBHelper.instance.getLogsForDate(todayDateString);
        _todayIntakeMl = 0;
        for (var log in _todayLogs) {
          _todayIntakeMl += log.amountMl;
        }
        await PrefService.setTodayIntake(_todayIntakeMl);
        await WidgetService.updateWidgetData(_todayIntakeMl, _dailyGoalMl);
        await loadHistoryStats();
        await loadInsightsData();
        await loadSelectedDateData();
        if (_isLeaderboardOptIn) {
          CloudSyncService.instance.syncLeaderboardEntry(this);
        }
        notifyListeners();
        return true;
      }
      return false;
    } catch (e, st) {
      AppLogger.error('HydrationProvider', 'undoLastLog failed: $e', e, st);
      return false;
    }
  }

  Future<void> setCustomGlassMl(int ml) async {
    _customGlassMl = ml.clamp(50, 1000);
    _hasConfiguredGlass = true;
    await PrefService.setCustomGlassMl(_customGlassMl);
    await PrefService.setHasConfiguredGlass(true);
    await WidgetService.updateWidgetData(
      todayIntakeMl,
      dailyGoalMl,
      customGlassMl: _customGlassMl,
      hasConfiguredGlass: true,
    );
    notifyListeners();
    try {
      await NotificationService.scheduleReminders(
        activeReminderTimes,
        _isNotifEnabled,
        dailyTimes: _buildDailySet(),
      );
      await NotificationService.schedulePostMealReminders(
        _mealSchedule,
        _isPostMealNotifEnabled && _isNotifEnabled,
      );
    } catch (_) {}
    try {
      if (CloudSyncService.instance.isSignedIn) {
        await CloudSyncService.instance.syncProfileSettings(
          dailyGoalMl: dailyGoalMl,
          userName: userName,
          themeMode: themeMode,
          customGlassMl: _customGlassMl,
          hasConfiguredGlass: true,
        );
      }
    } catch (_) {}
  }

  Future<void> logGlasses(int glassCount) async {
    final count = glassCount.clamp(1, 20);
    final totalMl = count * _customGlassMl;
    await logWater(totalMl);
  }

  Future<void> deleteLogById(int id) async {
    try {
      final allLogs = await DBHelper.instance.getAllLogs();
      final target = allLogs.where((l) => l.id == id).firstOrNull;
      await DBHelper.instance.deleteLog(id);
      if (target != null) {
        CloudSyncService.instance.deleteSingleLog(target.timestamp);
      }
      _todayLogs = await DBHelper.instance.getLogsForDate(todayDateString);
      _todayIntakeMl = 0;
      for (var log in _todayLogs) {
        _todayIntakeMl += log.amountMl;
      }
      await PrefService.setTodayIntake(_todayIntakeMl);
      await WidgetService.updateWidgetData(_todayIntakeMl, _dailyGoalMl);
      await loadHistoryStats();
      await loadInsightsData();
      await loadSelectedDateData();
      if (_isLeaderboardOptIn) {
        CloudSyncService.instance.syncLeaderboardEntry(this);
      }
      notifyListeners();
    } catch (e, st) {
      AppLogger.error('HydrationProvider', 'deleteLogById failed: $e', e, st);
    }
  }

  static List<DayTrendData> generateDefaultSevenDayTrend() {
    final now = DateTime.now();
    final List<DayTrendData> list = [];
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      String label;
      if (i == 0) {
        label = 'Today';
      } else if (i == 1) {
        label = 'Yesterday';
      } else {
        label = DateFormat('E').format(date);
      }
      list.add(DayTrendData(
        label: label,
        dateString: dateStr,
        totalMl: 0,
        ratio: 0.0,
      ));
    }
    return list;
  }

  Future<void> updateGoal(int newGoalMl, {bool fromWeatherBoost = false}) async {
    _dailyGoalMl = newGoalMl;
    if (!fromWeatherBoost) {
      _baseRegularGoalMl = newGoalMl;
      _isWeatherBoostActive = false;
      _appliedWeatherBoostMl = 0;
      await WeatherService.setBaseRegularGoal(newGoalMl);
      await PrefService.setGoal(newGoalMl);
      CloudSyncService.instance.syncProfileSettings(
        dailyGoalMl: newGoalMl,
        userName: _userName,
        themeMode: _themeMode,
      );
    }
    WidgetService.updateWidgetData(_todayIntakeMl, _dailyGoalMl);
    if (_isLeaderboardOptIn) {
      CloudSyncService.instance.syncLeaderboardEntry(this);
    }
    notifyListeners(); // Notify instantly so UI updates in 0ms!
    await loadHistoryStats();
    await loadInsightsData();
  }

  /// Sets the user's base regular goal from settings
  Future<void> updateBaseRegularGoal(int newBaseGoalMl) async {
    _baseRegularGoalMl = newBaseGoalMl;
    await PrefService.setGoal(newBaseGoalMl);
    await WeatherService.setBaseRegularGoal(newBaseGoalMl);
    if (_isWeatherBoostActive) {
      _dailyGoalMl = newBaseGoalMl + _appliedWeatherBoostMl;
    } else {
      _dailyGoalMl = newBaseGoalMl;
    }
    WidgetService.updateWidgetData(_todayIntakeMl, _dailyGoalMl);
    CloudSyncService.instance.syncProfileSettings(
      dailyGoalMl: newBaseGoalMl,
      userName: _userName,
      themeMode: _themeMode,
    );
    if (_isLeaderboardOptIn) {
      CloudSyncService.instance.syncLeaderboardEntry(this);
    }
    notifyListeners();
    await loadHistoryStats();
    await loadInsightsData();
  }

  Future<void> applyWeatherGoalBoost({required int boostMl}) async {
    _isWeatherBoostActive = true;
    _appliedWeatherBoostMl = boostMl;
    _dailyGoalMl = _baseRegularGoalMl + boostMl;
    await WeatherService.applyWeatherBoost(
      currentGoalMl: _baseRegularGoalMl,
      boostMl: boostMl,
    );
    WidgetService.updateWidgetData(_todayIntakeMl, _dailyGoalMl);
    notifyListeners();
    await loadHistoryStats();
    await loadInsightsData();
  }

  Future<void> undoWeatherGoalBoost() async {
    final baseGoal = await WeatherService.undoWeatherBoost() ?? _baseRegularGoalMl;
    _isWeatherBoostActive = false;
    _baseRegularGoalMl = baseGoal;
    _appliedWeatherBoostMl = 0;
    _dailyGoalMl = baseGoal;
    WidgetService.updateWidgetData(_todayIntakeMl, _dailyGoalMl);
    notifyListeners();
    await loadHistoryStats();
    await loadInsightsData();
  }

  Future<void> setThemeMode(String mode) async {
    _themeMode = mode;
    _isDarkMode = isDarkMode;
    await PrefService.setThemeMode(mode);
    CloudSyncService.instance.syncProfileSettings(
      dailyGoalMl: _dailyGoalMl,
      userName: _userName,
      themeMode: mode,
    );
    notifyListeners();
  }

  Future<void> toggleTheme(bool isDark) async {
    await setThemeMode(isDark ? 'dark' : 'light');
  }

  void checkThemeSchedule() {
    if (_themeMode == 'auto') {
      final currentIsDark = isDarkMode;
      if (_isDarkMode != currentIsDark) {
        _isDarkMode = currentIsDark;
        notifyListeners();
      }
    }
  }

  Future<void> updateUserName(String name) async {
    _userName = name;
    await PrefService.setUserName(name);
    CloudSyncService.instance.syncProfileSettings(
      dailyGoalMl: _dailyGoalMl,
      userName: name,
      themeMode: _themeMode,
    );
    await CloudSyncService.instance.syncLeaderboardEntry(this);
    notifyListeners();
  }

  String getRankForRatio(double ratio) {
    if (ratio >= 0.90) return 'Ocean Master';
    if (ratio >= 0.80) return 'Shield Guardian';
    if (ratio >= 0.70) return 'Wave Rider';
    if (ratio >= 0.60) return 'Current Commander';
    if (ratio >= 0.50) return 'River Guide';
    if (ratio >= 0.40) return 'Stream Sailor';
    if (ratio >= 0.30) return 'Puddle Jumper';
    if (ratio >= 0.20) return 'Dew Dropper';
    if (ratio >= 0.10) return 'Mist Seeker';
    return 'Desert Dweller';
  }

  String get currentSelectedRank => getRankForRatio(selectedDateProgressRatio);

  String getCoachResponse(String userPrompt) {
    final prompt = userPrompt.toLowerCase();

    if (prompt.contains('how am i doing') || prompt.contains('progress') || prompt.contains('status')) {
      if (progressRatio >= 1.0) {
        return "Fantastic job, $_userName! You've achieved 100% of your daily goal (${_todayIntakeMl}ml). Stay refreshed!";
      } else if (progressRatio >= 0.5) {
        return "Doing great! You are at $progressPercentage% of your daily goal with ${_todayIntakeMl}ml logged. Keep sipping!";
      } else {
        return "You've consumed ${_todayIntakeMl}ml so far ($progressPercentage%). You still need ${remainingMl}ml to hit your goal. Time for a glass of water!";
      }
    }

    if (prompt.contains('when should i drink') || prompt.contains('next')) {
      if (remainingMl == 0) {
        return "You've met your daily intake! Have a small glass of water before bedtime or after physical activity.";
      }
      if (isStreakAtRisk) {
        return "Right now! You're behind on your target for today. Drink at least 500ml now to keep your streak alive!";
      }
      return "Based on your remaining ${remainingMl}ml goal, I recommend drinking 250ml every 1.5 to 2 hours.";
    }

    if (prompt.contains('remaining goal') || prompt.contains('remaining') || prompt.contains('left')) {
      if (remainingMl == 0) {
        return "Daily goal achieved! You've hit ${dailyGoalMl}ml today!";
      }
      final remainingL = (remainingMl / 1000).toStringAsFixed(2);
      return "You need ${remainingMl}ml ($remainingL L) more to reach your target of ${dailyGoalMl}ml today.";
    }

    if (prompt.contains('streak')) {
      if (_currentStreak > 0) {
        return "You're on a $_currentStreak-day hydration streak! Your all-time best is $_bestStreak days. Keep it up!";
      } else {
        return "No active streak today. Hit your ${dailyGoalMl}ml target today to ignite a new streak!";
      }
    }

    if (prompt.contains('tip') || prompt.contains('advice')) {
      final tips = [
        "Tip: Drink a glass of water first thing in the morning to kickstart your metabolism!",
        "Tip: Drink water 30 minutes before meals to aid digestion.",
        "Tip: Keep a water bottle on your desk or nearby as a visual reminder.",
        "Tip: If you feel tired during the day, try drinking water—dehydration causes fatigue!",
        "Tip: Electrolytes & natural water help absorb hydration faster."
      ];
      tips.shuffle();
      return tips.first;
    }

    return "Offline Coach: You've drunk ${_todayIntakeMl}ml / ${_dailyGoalMl}ml ($progressPercentage%) today. Remaining: ${remainingMl}ml. Stay hydrated!";
  }
}
