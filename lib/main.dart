import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/hydration_provider.dart';
import 'screens/main_navigation_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await NotificationService.init();
  } catch (_) {}

  final hydrationProvider = HydrationProvider();
  try {
    await hydrationProvider.init();
  } catch (_) {}

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
