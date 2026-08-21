import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/hydration_provider.dart';
import '../widgets/waves_background.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'insights_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    HistoryScreen(),
    InsightsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // After the first frame renders, check if we need to show the battery guidance
    // bottom sheet. It only shows once (tracked by a SharedPreferences flag) and
    // only when the device's battery optimization is not yet exempted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        BatteryGuidanceBottomSheet.showIfNeeded(context);
      }
    });
  }

  /// Called every time the user taps a bottom-nav tab.
  ///
  /// History (1) and Insights (2) re-fetch their data from the DB on every
  /// visit so they always reflect the latest state — even if water was logged
  /// on another tab without triggering a full rebuild.
  void _onTabTapped(int index) {
    final provider = context.read<HydrationProvider>();

    if (index == 1) {
      // History tab: reload today's data + all history stats
      provider.loadTodayData();
      provider.loadHistoryStats();
    } else if (index == 2) {
      // Insights tab: history stats are a dependency for trend computation
      provider.loadHistoryStats().then((_) => provider.loadInsightsData());
    }

    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WavesBackground(
        child: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        backgroundColor: const Color(0xFF0F172A),
        selectedItemColor: const Color(0xFF00E5FF),
        unselectedItemColor: const Color(0xFF64748B),
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_rounded),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.lightbulb_outline_rounded),
            label: 'Insights',
          ),
        ],
      ),
    );
  }
}
