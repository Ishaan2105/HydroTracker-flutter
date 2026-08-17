import 'package:flutter_test/flutter_test.dart';
import 'package:hydro_flutter/main.dart';

void main() {
  testWidgets('HydroTracker App initial render test', (WidgetTester tester) async {
    await tester.pumpWidget(const HydroTrackerApp());
    expect(find.text('HydroTracker Offline'), findsNothing);
  });
}
