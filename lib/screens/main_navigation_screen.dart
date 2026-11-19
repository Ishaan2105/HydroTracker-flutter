import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/hydration_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/waves_background.dart';
import 'home_screen.dart';
import 'trends_insights_screen.dart';
import 'leaderboard_screen.dart';
import 'advanced_options_screen.dart';
import 'settings_screen.dart';
import '../services/notification_service.dart';
import '../widgets/username_setup_dialog.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  Timer? _themeScheduleTimer;
  StreamSubscription<int>? _intakeSub;

  final List<Widget> _screens = const [
    HomeScreen(),
    TrendsInsightsScreen(),
    LeaderboardScreen(),
    AdvancedOptionsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Register tab switcher callback for notification redirection (e.g. switch to Home for custom glass creation)
    NotificationService.onTabSwitchRequested = (tabIndex) {
      if (mounted) {
        setState(() => _currentIndex = tabIndex);
      }
    };

    // Listen to real-time notification action logging events so in-app state stays 100% synchronized
    _intakeSub = NotificationService.notificationIntakeStream.stream.listen((_) {
      if (mounted) {
        final provider = context.read<HydrationProvider>();
        provider.loadTodayData();
        provider.loadHistoryStats();
      }
    });

    // Periodically evaluate daytime / nighttime schedule and midnight day rollover every minute
    _themeScheduleTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        final provider = context.read<HydrationProvider>();
        provider.checkThemeSchedule();
        provider.checkMidnightReset();
      }
    });

    // After the first frame renders, request notification permissions if needed,
    // check if app was launched via notification action, and check battery optimization guidance.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        await NotificationService.requestPermissions();
        await NotificationService.checkLaunchIntent();
        if (mounted) {
          await UsernameSetupDialog.showIfNeeded(context);
        }
        if (mounted) {
          BatteryGuidanceBottomSheet.showIfNeeded(context);
        }
      }
    });
  }

  @override
  void dispose() {
    _themeScheduleTimer?.cancel();
    _intakeSub?.cancel();
    NotificationService.onTabSwitchRequested = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      final provider = context.read<HydrationProvider>();
      provider.checkThemeSchedule();
      provider.checkMidnightReset();
      provider.loadTodayData();
      provider.loadHistoryStats();
      provider.loadInsightsData();
      NotificationService.checkLaunchIntent();
    }
  }

  /// Called every time the user taps a bottom-nav tab.
  void _onTabTapped(int index) {
    final provider = context.read<HydrationProvider>();

    if (index == 1) {
      // Trends & Insights tab: reload today's data, history stats, and insights data
      provider.loadTodayData();
      provider.loadHistoryStats().then((_) => provider.loadInsightsData());
    } else if (index == 3) {
      // Advanced Options tab: make sure today's intake is fresh for the widget preview
      provider.loadTodayData();
    }

    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HydrationProvider>();
    final isDark = provider.isDarkMode;
    final colors = AppColors(isDark: isDark);

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: colors.scaffoldBg,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      body: WavesBackground(
        backgroundColor: colors.wavesBg,
        lineColor: colors.wavesLine,
        child: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: colors.surfaceBorderSubtle, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          backgroundColor: colors.bottomNavBg,
          selectedItemColor: colors.cyanAccent,
          unselectedItemColor: colors.bottomNavUnselected,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
          selectedFontSize: 11,
          unselectedFontSize: 10,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.water_drop_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_graph_rounded),
              label: 'Insights',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events_rounded),
              label: 'Leaderboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.widgets_rounded),
              label: 'Advanced',
            ),
          ],
        ),
      ),
    );
  }
}
