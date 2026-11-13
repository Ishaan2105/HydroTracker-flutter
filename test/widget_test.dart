import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:hydro_flutter/main.dart';
import 'package:hydro_flutter/providers/hydration_provider.dart';

void main() {
  testWidgets('HydroTracker App initial render test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => HydrationProvider(),
        child: const HydroTrackerApp(),
      ),
    );
    expect(find.text('HydroTracker Offline'), findsNothing);
  });
}
