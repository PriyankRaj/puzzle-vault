import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:topgames/core/game_level_context.dart';
import 'package:topgames/games/ragdoll_trials/ragdoll_trials_game.dart';

/// Drives the real physics simulation frame-by-frame through the public
/// push buttons (never reaching into private state). The push script below
/// was derived offline by replicating `_stepPhysics` in a standalone Dart
/// script (gravity 1500, push accel 950, damping 0.999, 6 substeps/frame,
/// 1/60s frames) for level 1's flat, obstacle-free floor: push right ~166ms
/// to build speed, coast to carry the blob from x=60 toward the goal
/// (x=300..370), then a short push-left to shed speed below the 45px/s
/// settle threshold, then coast until the 20-tick settle counter completes.
/// Because the game's ticker derives its own `dt` purely from the actual
/// elapsed pumped time (no RNG involved), replaying the exact same frame
/// durations against the real widget reproduces the same outcome.
const _frameDt = Duration(
  milliseconds: 16,
); // ~1/60s, well under the 1/30s clamp

/// Held-direction script: `1` = push right, `-1` = push left, `0` = none.
/// 10 frames right, 150 coast, 2 frames left, then coast to settle.
List<int> _pushScript() => [
  ...List.filled(10, 1),
  ...List.filled(150, 0),
  ...List.filled(2, -1),
  ...List.filled(60, 0),
];

Future<void> _runScript(WidgetTester tester, List<int> script) async {
  TestGesture? held;
  int? heldDirection;

  Future<void> setDirection(int dir) async {
    if (dir == heldDirection) return;
    if (held != null) {
      await held!.up();
      held = null;
    }
    if (dir != 0) {
      final icon = dir > 0
          ? Icons.chevron_right_rounded
          : Icons.chevron_left_rounded;
      held = await tester.startGesture(tester.getCenter(find.byIcon(icon)));
    }
    heldDirection = dir;
  }

  for (final dir in script) {
    await setDirection(dir);
    await tester.pump(_frameDt);
  }
  if (held != null) {
    await held!.up();
  }
}

void main() {
  testWidgets(
    'ragdoll_trials: replaying the derived push script on level 1 settles in the goal and completes',
    (tester) async {
      int? completedStars;
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: RagdollTrialsScreen(
            ctx: GameLevelContext(
              gameId: 'ragdoll_trials',
              level: 1,
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
      await tester.pump();

      await _runScript(tester, _pushScript());
      // onComplete fires via a microtask.
      await tester.pump();

      expect(
        completed,
        isTrue,
        reason:
            'the derived push/coast/counter-push script should carry the '
            'blob into the goal zone and let it settle below the speed '
            'threshold',
      );
      expect(completedStars, inInclusiveRange(1, 3));
    },
  );

  testWidgets(
    'ragdoll_trials: a brief push on level 1 does not falsely report completion',
    (tester) async {
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: RagdollTrialsScreen(
            ctx: GameLevelContext(
              gameId: 'ragdoll_trials',
              level: 1,
              isEndless: false,
              onComplete: ({int stars = 0, int? score}) => completed = true,
              onExit: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Only the same short right-push burst as the winning script's warm-up
      // (10 frames, ~166ms) with no coast/counter-push follow-through —
      // nowhere near enough horizontal travel from x=60 to the goal at
      // x=300..370.
      await _runScript(tester, List.filled(10, 1));
      for (var i = 0; i < 20; i++) {
        await tester.pump(_frameDt);
      }

      expect(completed, isFalse);
    },
  );
}
