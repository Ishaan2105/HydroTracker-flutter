import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'pref_service.dart';

class WidgetService {
  static const MethodChannel _channel = MethodChannel('hydro_flutter/widget');

  /// Check if the device / launcher supports pinning widgets directly
  static Future<bool> isPinWidgetSupported() async {
    try {
      final bool? supported = await _channel.invokeMethod<bool>('isPinSupported');
      return supported ?? false;
    } catch (e) {
      debugPrint('WidgetService.isPinWidgetSupported error: $e');
      return false;
    }
  }

  /// Request Android OS to pin the Hydro Tracker widget to the Home Screen
  static Future<bool> requestPinWidget() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('requestPinWidget');
      return result ?? false;
    } catch (e) {
      debugPrint('WidgetService.requestPinWidget error: $e');
      return false;
    }
  }

  /// Synchronize today's intake and goal with the Android AppWidget
  static Future<void> updateWidgetData(int intakeMl, int goalMl) async {
    try {
      await PrefService.setTodayIntake(intakeMl);
      await _channel.invokeMethod('updateWidgetData', {
        'todayIntake': intakeMl,
        'todayIntakeMl': intakeMl,
        'dailyGoal': goalMl,
        'dailyGoalMl': goalMl,
      });
    } catch (e) {
      debugPrint('WidgetService.updateWidgetData error: $e');
    }
  }
}

