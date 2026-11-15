import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'pref_service.dart';

class WidgetService {
  static const MethodChannel _channel = MethodChannel('hydro_flutter/widget');
  static void Function(String action)? onWidgetActionReceived;
  static bool _handlerInitialized = false;

  /// Initialize native callback listeners for widget actions
  static void init() {
    if (_handlerInitialized) return;
    _handlerInitialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onWidgetAction') {
        final action = call.arguments as String?;
        if (action != null && onWidgetActionReceived != null) {
          onWidgetActionReceived!(action);
        }
      }
    });
  }

  /// Consume the pending launch action (if app was opened via widget button)
  static Future<String?> getInitialAction() async {
    try {
      final String? action = await _channel.invokeMethod<String>('getInitialAction');
      return action;
    } catch (e) {
      debugPrint('WidgetService.getInitialAction error: $e');
      return null;
    }
  }

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

