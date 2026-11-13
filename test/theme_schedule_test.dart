import 'package:flutter_test/flutter_test.dart';
import 'package:hydro_flutter/providers/hydration_provider.dart';

void main() {
  group('Theme Schedule Boundary Tests (6:30 AM – 6:30 PM)', () {
    test('06:29 AM is Nighttime (Dark Mode by default)', () {
      final dt = DateTime(2026, 11, 13, 6, 29);
      expect(HydrationProvider.isDaytime(dt), isFalse);
    });

    test('06:30 AM is Daytime (Light Mode by default)', () {
      final dt = DateTime(2026, 11, 13, 6, 30);
      expect(HydrationProvider.isDaytime(dt), isTrue);
    });

    test('12:00 PM (Noon) is Daytime (Light Mode by default)', () {
      final dt = DateTime(2026, 11, 13, 12, 0);
      expect(HydrationProvider.isDaytime(dt), isTrue);
    });

    test('06:29 PM (18:29) is Daytime (Light Mode by default)', () {
      final dt = DateTime(2026, 11, 13, 18, 29);
      expect(HydrationProvider.isDaytime(dt), isTrue);
    });

    test('06:30 PM (18:30) is Nighttime (Dark Mode by default)', () {
      final dt = DateTime(2026, 11, 13, 18, 30);
      expect(HydrationProvider.isDaytime(dt), isFalse);
    });

    test('11:59 PM (23:59) is Nighttime (Dark Mode by default)', () {
      final dt = DateTime(2026, 11, 13, 23, 59);
      expect(HydrationProvider.isDaytime(dt), isFalse);
    });

    test('12:00 AM (00:00) Midnight is Nighttime (Dark Mode by default)', () {
      final dt = DateTime(2026, 11, 13, 0, 0);
      expect(HydrationProvider.isDaytime(dt), isFalse);
    });
  });
}

