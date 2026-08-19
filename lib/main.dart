import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/hydration_provider.dart';
import 'screens/main_navigation_screen.dart';
import 'services/app_logger.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Capture Flutter framework & rendering errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    AppLogger.crash(
      'FlutterFramework',
      details.exceptionAsString(),
      details.stack,
    );
  };

  // 2. Capture unhandled asynchronous / isolate / platform errors
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppLogger.crash('PlatformDispatcher', error, stack);
    return true; // prevent app hard-crash when possible
  };

  AppLogger.info('AppLifecycle', '🚀 Hydro Tracker starting up...');

  try {
    await NotificationService.init();
    AppLogger.info('NotificationService', 'NotificationService initialized.');
  } catch (e, st) {
    AppLogger.error('NotificationService', 'Failed to initialize notifications', e, st);
  }

  final hydrationProvider = HydrationProvider();
  try {
    await hydrationProvider.init();
    AppLogger.info('HydrationProvider', 'HydrationProvider state loaded.');
  } catch (e, st) {
    AppLogger.error('HydrationProvider', 'Failed to initialize hydration provider', e, st);
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: hydrationProvider),
      ],
      child: const HydroTrackerApp(),
    ),
  );
}

class HydroTrackerApp extends StatelessWidget {
  const HydroTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hydro Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B1329),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1565C0),
          secondary: Color(0xFF00E5FF),
          surface: Color(0xFF1E293B),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}
