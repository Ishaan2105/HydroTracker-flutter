import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_logger.dart';

class WeatherHydrationData {
  final String cityName;
  final double temperature;
  final int relativeHumidity;
  final int weatherCode;
  final String condition;
  final String emoji;
  final int suggestedExtraMl;
  final String message;
  final DateTime fetchedAt;

  const WeatherHydrationData({
    required this.cityName,
    required this.temperature,
    required this.relativeHumidity,
    required this.weatherCode,
    required this.condition,
    required this.emoji,
    required this.suggestedExtraMl,
    required this.message,
    required this.fetchedAt,
  });

  Map<String, dynamic> toJson() => {
        'cityName': cityName,
        'temperature': temperature,
        'relativeHumidity': relativeHumidity,
        'weatherCode': weatherCode,
        'condition': condition,
        'emoji': emoji,
        'suggestedExtraMl': suggestedExtraMl,
        'message': message,
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  factory WeatherHydrationData.fromJson(Map<String, dynamic> json) {
    return WeatherHydrationData(
      cityName: json['cityName'] as String? ?? 'Your Location',
      temperature: (json['temperature'] as num?)?.toDouble() ?? 28.0,
      relativeHumidity: (json['relativeHumidity'] as num?)?.toInt() ?? 50,
      weatherCode: (json['weatherCode'] as num?)?.toInt() ?? 0,
      condition: json['condition'] as String? ?? 'Clear & Sunny',
      emoji: json['emoji'] as String? ?? '☀️',
      suggestedExtraMl: (json['suggestedExtraMl'] as num?)?.toInt() ?? 500,
      message: json['message'] as String? ??
          'Stay hydrated with extra water for today!',
      fetchedAt: json['fetchedAt'] != null
          ? DateTime.tryParse(json['fetchedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class WeatherService {
  static const String _prefKeyCachedWeather = 'cached_weather_hydration_data';
  static const String _prefKeyLastAppliedDate = 'weather_goal_applied_date';
  static const String _prefKeyDismissedDate = 'weather_goal_dismissed_date';
  static const String _prefKeyBaseRegularGoal = 'weather_base_regular_goal';
  static const String _prefKeyAppliedBoostMl = 'weather_goal_applied_boost_ml';

  static WeatherHydrationData? _cachedData;

  /// Returns whether there is fresh, unapplied weather data that should show the orange badge
  static Future<bool> shouldShowBadge() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final lastApplied = prefs.getString(_prefKeyLastAppliedDate);
    final lastDismissed = prefs.getString(_prefKeyDismissedDate);

    // If already applied or dismissed today, don't show the orange alert badge
    if (lastApplied == today || lastDismissed == today) {
      return false;
    }
    return true;
  }

  /// Returns true if a weather goal adjustment has already been applied today
  static Future<bool> isBoostAppliedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final lastApplied = prefs.getString(_prefKeyLastAppliedDate);
    return lastApplied == today;
  }

  /// Gets the date on which a weather goal adjustment was applied
  static Future<String?> getAppliedDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyLastAppliedDate);
  }

  /// Gets the base regular goal before any weather adjustment
  static Future<int?> getBaseRegularGoal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefKeyBaseRegularGoal);
  }

  /// Gets the amount of ml added in today's weather adjustment
  static Future<int> getAppliedBoostMl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefKeyAppliedBoostMl) ?? 500;
  }

  /// Applies a weather boost: stores the original base goal, boost amount, and today's date
  static Future<void> applyWeatherBoost({
    required int currentGoalMl,
    required int boostMl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Only set base goal if not already stored
    final existingBase = prefs.getInt(_prefKeyBaseRegularGoal);
    if (existingBase == null || existingBase <= 0) {
      await prefs.setInt(_prefKeyBaseRegularGoal, currentGoalMl);
    }

    await prefs.setInt(_prefKeyAppliedBoostMl, boostMl);
    await prefs.setString(_prefKeyLastAppliedDate, today);
  }

  /// Undoes today's weather boost and returns the base regular goal
  static Future<int?> undoWeatherBoost() async {
    final prefs = await SharedPreferences.getInstance();
    final baseGoal = prefs.getInt(_prefKeyBaseRegularGoal);
    await prefs.remove(_prefKeyLastAppliedDate);
    await prefs.remove(_prefKeyAppliedBoostMl);
    await prefs.remove(_prefKeyBaseRegularGoal);
    return baseGoal;
  }

  /// Clears weather boost when the day has ended and returns base regular goal to restore
  static Future<int?> clearWeatherBoostIfExpired() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final lastApplied = prefs.getString(_prefKeyLastAppliedDate);

    if (lastApplied != null && lastApplied != today) {
      final baseGoal = prefs.getInt(_prefKeyBaseRegularGoal);
      await prefs.remove(_prefKeyLastAppliedDate);
      await prefs.remove(_prefKeyAppliedBoostMl);
      await prefs.remove(_prefKeyBaseRegularGoal);
      return baseGoal;
    }
    return null;
  }

  /// Saves or updates the user's base regular goal when they change it normally
  static Future<void> setBaseRegularGoal(int goalMl) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final lastApplied = prefs.getString(_prefKeyLastAppliedDate);
    // Only update base regular goal if a weather boost is not actively applied today
    if (lastApplied != today) {
      await prefs.setInt(_prefKeyBaseRegularGoal, goalMl);
    }
  }

  /// Marks today's weather suggestion as dismissed
  static Future<void> markDismissedForToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await prefs.setString(_prefKeyDismissedDate, today);
  }

  /// Fetches weather data either from memory/cache (if fresh < 30 mins) or from Open-Meteo & IP location
  static Future<WeatherHydrationData> getWeatherData({bool forceRefresh = false}) async {
    final now = DateTime.now();

    // 1. Check in-memory cache
    if (!forceRefresh &&
        _cachedData != null &&
        now.difference(_cachedData!.fetchedAt).inMinutes < 30) {
      return _cachedData!;
    }

    // 2. Check SharedPreferences cache
    if (!forceRefresh) {
      final prefs = await SharedPreferences.getInstance();
      final cachedJsonStr = prefs.getString(_prefKeyCachedWeather);
      if (cachedJsonStr != null) {
        try {
          final decoded = jsonDecode(cachedJsonStr) as Map<String, dynamic>;
          final cached = WeatherHydrationData.fromJson(decoded);
          if (now.difference(cached.fetchedAt).inMinutes < 30) {
            _cachedData = cached;
            return cached;
          }
        } catch (_) {}
      }
    }

    // 3. Perform network fetch
    try {
      final freshData = await _fetchFromNetwork();
      _cachedData = freshData;

      // Save to SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _prefKeyCachedWeather,
          jsonEncode(freshData.toJson()),
        );
      } catch (_) {}

      return freshData;
    } catch (e) {
      AppLogger.warn('WeatherService', 'Error fetching weather: $e');
      if (_cachedData != null) return _cachedData!;

      // Fallback default
      return WeatherHydrationData(
        cityName: 'Mumbai',
        temperature: 29.0,
        relativeHumidity: 55,
        weatherCode: 0,
        condition: 'Clear & Sunny',
        emoji: '☀️',
        suggestedExtraMl: 500,
        message:
            "It's sunny and hot today (29°C). High perspiration increases fluid needs. Add +500ml to your goal for today to stay fully hydrated!",
        fetchedAt: DateTime.now(),
      );
    }
  }

  static Future<WeatherHydrationData> _fetchFromNetwork() async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);

    String city = 'Mumbai';
    double lat = 19.076;
    double lon = 72.8777;

    // Step 1: Detect approximate location from IP
    try {
      final ipUri = Uri.parse('http://ip-api.com/json');
      final ipReq = await client.getUrl(ipUri).timeout(const Duration(seconds: 4));
      final ipRes = await ipReq.close().timeout(const Duration(seconds: 4));
      if (ipRes.statusCode == 200) {
        final body = await ipRes.transform(utf8.decoder).join();
        final ipData = jsonDecode(body) as Map<String, dynamic>;
        if (ipData['status'] == 'success') {
          city = ipData['city'] as String? ?? city;
          lat = (ipData['lat'] as num?)?.toDouble() ?? lat;
          lon = (ipData['lon'] as num?)?.toDouble() ?? lon;
        }
      }
    } catch (e) {
      AppLogger.warn('WeatherService', 'IP location fallback used: $e');
    }

    // Step 2: Fetch current weather from Open-Meteo
    final weatherUri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m,weather_code,is_day&timezone=auto',
    );
    final weatherReq = await client.getUrl(weatherUri).timeout(const Duration(seconds: 4));
    final weatherRes = await weatherReq.close().timeout(const Duration(seconds: 4));

    if (weatherRes.statusCode == 200) {
      final body = await weatherRes.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final current = data['current'] as Map<String, dynamic>? ?? {};

      final temp = (current['temperature_2m'] as num?)?.toDouble() ?? 29.0;
      final humidity = (current['relative_humidity_2m'] as num?)?.toInt() ?? 50;
      final code = (current['weather_code'] as num?)?.toInt() ?? 0;

      final condition = _getWeatherCondition(code);
      final emoji = _getWeatherEmoji(code);
      final extraMl = _calcSuggestedExtraMl(temp, humidity);
      final message = _buildRecommendationMessage(temp, condition, extraMl);

      return WeatherHydrationData(
        cityName: city,
        temperature: temp,
        relativeHumidity: humidity,
        weatherCode: code,
        condition: condition,
        emoji: emoji,
        suggestedExtraMl: extraMl,
        message: message,
        fetchedAt: DateTime.now(),
      );
    } else {
      throw Exception('Open-Meteo returned status ${weatherRes.statusCode}');
    }
  }

  static String _getWeatherCondition(int code) {
    if (code == 0) return 'Clear & Sunny';
    if (code == 1) return 'Mainly Clear';
    if (code == 2) return 'Partly Cloudy';
    if (code == 3) return 'Overcast';
    if (code == 45 || code == 48) return 'Foggy';
    if (code >= 51 && code <= 55) return 'Drizzle';
    if (code >= 61 && code <= 65) return 'Rainy';
    if (code >= 71 && code <= 77) return 'Snowy';
    if (code >= 80 && code <= 82) return 'Rain Showers';
    if (code >= 95 && code <= 99) return 'Thunderstorm';
    return 'Clear & Sunny';
  }

  static String _getWeatherEmoji(int code) {
    if (code == 0 || code == 1) return '☀️';
    if (code == 2 || code == 3) return '🌤️';
    if (code == 45 || code == 48) return '🌫️';
    if ((code >= 51 && code <= 65) || (code >= 80 && code <= 82)) return '🌧️';
    if (code >= 71 && code <= 77) return '❄️';
    if (code >= 95) return '⛈️';
    return '☀️';
  }

  static int _calcSuggestedExtraMl(double temp, int humidity) {
    if (temp >= 33) return 750;
    if (temp >= 27) return 500;
    if (temp >= 22) return 300;
    return 250;
  }

  static String _buildRecommendationMessage(
      double temp, String condition, int extraMl) {
    if (temp >= 27) {
      return "It's sunny and hot today (${temp.round()}°C). High perspiration increases fluid needs. Add +${extraMl}ml to your goal for today to stay fully hydrated!";
    } else if (temp >= 22) {
      return "Warm weather outside (${temp.round()}°C). Extra activity and perspiration require fluid balance. Add +${extraMl}ml to your goal today!";
    } else {
      return "Current temperature is ${temp.round()}°C ($condition). Staying well-hydrated helps maintain your energy levels and skin moisture!";
    }
  }
}
