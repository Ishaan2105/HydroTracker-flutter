import 'package:flutter_test/flutter_test.dart';
import 'package:hydro_flutter/providers/hydration_provider.dart';

void main() {
  group('Yamada et al. (Science 2022) Water Turnover Goal Calculator Tests', () {
    late HydrationProvider provider;

    setUp(() {
      provider = HydrationProvider();
    });

    test('Benchmark User Example: 30yo Female, 60kg, PAL 1.75, 50% humidity, 28°C = 2550 mL', () {
      final goal = provider.calculateSuggestedGoal(
        weightKg: 60.0,
        age: 30,
        gender: 'Female',
        pal: 1.75,
        humidityPct: 50.0,
        tempC: 28.0,
        isAthlete: false,
        hdi: 1,
        altitudeM: 0.0,
      );

      // Expected calculation:
      // WT = 1076 * 1.75 + 14.34 * 60 + 374.9 * 0 + 5.823 * 50 + 1070 * 0
      //    + 104.6 * 1 + 0.4726 * 0 - 0.3529 * (30^2) + 24.78 * 30
      //    + 1.865 * (28^2) - 19.66 * 28 - 713.1
      // WT = 3763.52 mL/day
      // drinks_goal = 3763.52 * 0.85 * 0.8 = 2559.1936 mL
      // Clamped to [1500, 4000], rounded to nearest 50 mL = 2550 mL
      expect(goal, equals(2550));
    });

    test('25yo Male, 75kg, PAL 1.75, 50% humidity, 28°C = 2950 mL', () {
      final goal = provider.calculateSuggestedGoal(
        weightKg: 75.0,
        age: 25,
        gender: 'Male',
        pal: 1.75,
        humidityPct: 50.0,
        tempC: 28.0,
        isAthlete: false,
        hdi: 1,
        altitudeM: 0.0,
      );

      expect(goal, equals(2950));
    });

    test('Athlete status increases intake recommendation', () {
      final nonAthlete = provider.calculateSuggestedGoal(
        weightKg: 70.0,
        age: 28,
        gender: 'Male',
        pal: 1.75,
        isAthlete: false,
      );

      final athlete = provider.calculateSuggestedGoal(
        weightKg: 70.0,
        age: 28,
        gender: 'Male',
        pal: 1.75,
        isAthlete: true,
      );

      expect(athlete, greaterThan(nonAthlete));
      // 1070 * 0.85 * 0.8 = 727.6 mL difference before rounding
      expect(athlete - nonAthlete, inInclusiveRange(700, 750));
    });

    test('Safety limit clamps extreme inputs to [1500, 4000] mL', () {
      final highGoal = provider.calculateSuggestedGoal(
        weightKg: 180.0,
        age: 25,
        gender: 'Male',
        pal: 2.2,
        isAthlete: true,
        tempC: 45.0,
        humidityPct: 90.0,
      );

      final lowGoal = provider.calculateSuggestedGoal(
        weightKg: 35.0,
        age: 80,
        gender: 'Female',
        pal: 1.4,
        isAthlete: false,
        tempC: 5.0,
        humidityPct: 20.0,
      );

      expect(highGoal, equals(4000));
      expect(lowGoal, equals(1500));
    });

    test('Result is always cleanly divisible by 50 mL', () {
      for (double w = 45; w <= 110; w += 10) {
        final g = provider.calculateSuggestedGoal(
          weightKg: w,
          age: 25,
          gender: 'Female',
          pal: 1.6,
        );
        expect(g % 50, equals(0));
      }
    });
  });
}

