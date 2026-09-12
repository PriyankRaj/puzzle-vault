import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:topgames/core/game_level_context.dart';
import 'package:topgames/games/gradient_sort/gradient_sort_game.dart';

/// Replicates the private `_buildLane` generation from `GradientSortScreen`
/// (same seed formula `5000 + level`, same rng-consumption order: hue/
/// saturation/lightness draws for color, THEN the order shuffle) closely
/// enough to compute the exact scrambled `order` permutation the widget
/// will display, so this test can compute a real minimal-swap solution and
/// drive it through the public widget instead of reaching into private
/// state. If the in-game generation algorithm changes, update this to
/// match.
List<int> _laneOrder(Random rng, int chipCount) {
  // Consume the same random calls as color generation, in the same order,
  // so the rng is in the same state before the order shuffle.
  rng.nextDouble(); // startHue
  rng.nextDouble(); // hueDelta
  rng.nextDouble(); // saturation
  rng.nextDouble(); // startLightness
  rng.nextDouble(); // endLightness

  List<int> order;
  do {
    order = List.generate(chipCount, (i) => i)..shuffle(rng);
  } while (chipCount > 1 && _isIdentity(order));
  return order;
}

bool _isIdentity(List<int> perm) {
  for (var i = 0; i < perm.length; i++) {
    if (perm[i] != i) return false;
  }
  return true;
}

/// Computes a minimal sequence of slot-index swaps that sorts [order] back
/// to the identity permutation, using the standard "fix cycles in place"
/// algorithm: this is the same number of swaps as `_minSwaps` counts in the
/// widget (`n - cycles`), and each swap here corresponds exactly to tapping
/// slot `a` then slot `b` in the widget's tap-to-select-then-swap UI.
List<(int, int)> _minimalSwapSequence(List<int> order) {
  final working = List<int>.from(order);
  final swaps = <(int, int)>[];
  for (var i = 0; i < working.length; i++) {
    while (working[i] != i) {
      final j = working[i];
      final tmp = working[i];
      working[i] = working[j];
      working[j] = tmp;
      swaps.add((i, j));
    }
  }
  return swaps;
}

Future<void> _tapSlot(WidgetTester tester, int slot) async {
  await tester.tap(find.byType(GestureDetector).at(slot));
  await tester.pump();
}

void main() {
  testWidgets(
    'gradient_sort: replaying the minimal swap sequence sorts the lane and reports completion',
    (tester) async {
      const level = 1;
      const chipCount = 5; // level 1: laneCount 1, chipCount 5 + 0
      final order = _laneOrder(Random(5000 + level), chipCount);
      final swaps = _minimalSwapSequence(order);

      var completed = false;
      int? completedStars;

      await tester.pumpWidget(
        MaterialApp(
          home: GradientSortScreen(
            ctx: GameLevelContext(
              gameId: 'gradient_sort',
              level: level,
              isEndless: false,
              onComplete: ({int stars = 0, int? score}) {
                completed = true;
                completedStars = stars;
              },
              onExit: () {},
            ),
          ),
        ),
      );

      for (final (a, b) in swaps) {
        await _tapSlot(tester, a);
        await _tapSlot(tester, b);
      }
      await tester.pump();

      expect(
        completed,
        isTrue,
        reason:
            'replaying the computed minimal swap sequence should fully sort the lane',
      );
      // Using exactly the minimal number of swaps should earn full stars.
      expect(completedStars, 3);
    },
  );

  testWidgets(
    'gradient_sort: a swap that leaves the lane unsorted does not report completion',
    (tester) async {
      const level = 1;
      const chipCount = 5;
      final order = _laneOrder(Random(5000 + level), chipCount);

      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: GradientSortScreen(
            ctx: GameLevelContext(
              gameId: 'gradient_sort',
              level: level,
              isEndless: false,
              onComplete: ({int stars = 0, int? score}) => completed = true,
              onExit: () {},
            ),
          ),
        ),
      );

      // Swap slots 0 and 1 and independently compute whether that single
      // swap happens to fully sort the lane. Either way, the widget's
      // reported completion state must match that computed truth — this
      // holds regardless of the specific scrambled permutation for this
      // seed.
      final simulated = List<int>.from(order);
      final tmp = simulated[0];
      simulated[0] = simulated[1];
      simulated[1] = tmp;
      final simulatedSolved = _isIdentity(simulated);

      await _tapSlot(tester, 0);
      await _tapSlot(tester, 1);
      await tester.pump();

      expect(completed, simulatedSolved);
      // For this seed the scramble is guaranteed non-trivial (never the
      // identity permutation), so a single arbitrary swap of two slots
      // should not coincidentally finish a 5-chip lane.
      expect(completed, isFalse);
    },
  );
}
