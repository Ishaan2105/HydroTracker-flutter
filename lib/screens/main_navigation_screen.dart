import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/hydration_provider.dart';
import '../widgets/waves_background.dart';
import 'home_screen.dart';
import 'trends_insights_screen.dart';
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
    TrendsInsightsScreen(),
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
  void _onTabTapped(int index) {
    final provider = context.read<HydrationProvider>();

    if (index == 1) {
      // Trends & Insights tab: reload today's data, history stats, and insights data
      provider.loadTodayData();
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
            icon: Icon(Icons.auto_graph_rounded),
            label: 'Trends & Insights',
          ),
        ],
      ),
    );
  }
}
