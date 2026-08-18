import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/hydration_provider.dart';
import '../services/notification_service.dart';
import 'main_navigation_screen.dart';

/// AppShell shows an instant splash, then initializes everything in the background.
/// This guarantees the first frame is never blocked by async work.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // All async work runs AFTER the splash is on screen
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    final provider = context.read<HydrationProvider>();

    // Step 1: initialize notification plugin (no permission dialogs)
    await NotificationService.init();

    // Step 2: load all app data from SQLite + SharedPrefs
    await provider.init();

    // Step 3: request runtime permissions (shows dialog after UI is visible)
    await NotificationService.requestPermissions();

    // Step 4: schedule reminders now that permissions are granted
    await NotificationService.scheduleReminders(
      provider.activeReminderTimes,
      provider.isNotifEnabled,
    );

    // Transition to the main app
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const MainNavigationScreen();
    return const _SplashScreen();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1329),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1565C0), Color(0xFF00E5FF)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                    blurRadius: 28,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.water_drop_rounded,
                color: Colors.white,
                size: 46,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Hydro Tracker',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Loading your hydration data...',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 36),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFF00E5FF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
