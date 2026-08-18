import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/hydration_provider.dart';
import 'screens/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // runApp IMMEDIATELY — zero async work before this line
  runApp(
    ChangeNotifierProvider(
      create: (_) => HydrationProvider(),
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
      ),
      home: const AppShell(),
    );
  }
}
