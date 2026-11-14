import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/hydration_provider.dart';
import 'screens/auth_gate_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'services/app_logger.dart';
import 'services/cloud_sync_service.dart';
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

  // 3. Initialize Firebase & Cloud Sync
  try {
    await CloudSyncService.init();
    AppLogger.info('CloudSyncService', 'CloudSyncService initialized.');
  } catch (e, st) {
    AppLogger.error('CloudSyncService', 'Failed to initialize cloud sync', e, st);
  }

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

  // 4. If already authenticated, trigger background cloud sync
  if (CloudSyncService.instance.isSignedIn) {
    CloudSyncService.instance.performFullTwoWaySync(hydrationProvider);
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
    return Consumer<HydrationProvider>(
      builder: (context, provider, child) {
        final isDark = provider.isDarkMode;
        return MaterialApp(
          title: 'Hydro Tracker',
          debugShowCheckedModeBanner: false,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          darkTheme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: Colors.black,
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF1565C0),
              secondary: Color(0xFF00E5FF),
              surface: Color(0xFF1E293B),
            ),
            textTheme: GoogleFonts.poppinsTextTheme(
              ThemeData.dark().textTheme,
            ),
          ),
          theme: ThemeData.light().copyWith(
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1565C0),
              secondary: Color(0xFF0284C7),
              surface: Colors.white,
            ),
            textTheme: GoogleFonts.poppinsTextTheme(
              ThemeData.light().textTheme,
            ),
          ),
          home: CloudSyncService.instance.isSignedIn
              ? const MainNavigationScreen()
              : const AuthGateScreen(),
        );
      },
    );
  }
}
