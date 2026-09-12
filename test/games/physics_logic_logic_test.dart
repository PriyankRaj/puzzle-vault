import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:topgames/core/game_level_context.dart';
import 'package:topgames/core/settings_store.dart';
import 'package:topgames/games/physics_logic/physics_logic_game.dart';

/// Physics Logic runs a real-time physics ticker once "Launch" is pressed,
/// so per the task brief this test avoids driving that simulation and
/// instead exercises the deterministic, non-physics drawing/ink-budget
/// validation logic that gates what the player is even allowed to launch.
void main() {
  setUp(() {
    // Avoid a repeating AnimationController ticker (the goal-zone pulse)
    // outliving the test.
    AppSettingsStore.instance.animationsEnabled.value = false;
  });

  Rect canvasRect(WidgetTester tester) {
    final finder = find.byWidgetPredicate(
      (w) =>
          w is CustomPaint &&
          w.painter.runtimeType.toString() == '_PhysicsLogicPainter',
    );
    return tester.getRect(finder);
  }

  testWidgets('physics_logic: drawing a stroke within the ink budget consumes '
      'exactly its logical length from the budget', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PhysicsLogicScreen(
          ctx: GameLevelContext(
            gameId: 'physics_logic',
            level: 1, // level 1's ink budget is 60 logical px.
            isEndless: false,
            onComplete: ({int stars = 0, int? score}) {},
            onExit: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Ink left: 60 / 60'), findsOneWidget);

    final rect = canvasRect(tester);
    final scale = rect.width / 400;
    Offset toGlobal(double x, double y) =>
        rect.topLeft + Offset(x * scale, y * scale);

    // A single straight 30-logical-pixel stroke, well under the level's
    // 60px budget.
    final gesture = await tester.startGesture(toGlobal(50, 300));
    await tester.pump();
    await gesture.moveTo(toGlobal(80, 300));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(find.text('Ink left: 30 / 60'), findsOneWidget);
  });

  testWidgets(
    'physics_logic: drawing far beyond the remaining ink budget clips the '
    'stroke instead of letting ink usage overrun the budget',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PhysicsLogicScreen(
            ctx: GameLevelContext(
              gameId: 'physics_logic',
              level: 1,
              isEndless: false,
              onComplete: ({int stars = 0, int? score}) {},
              onExit: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final rect = canvasRect(tester);
      final scale = rect.width / 400;
      Offset toGlobal(double x, double y) =>
          rect.topLeft + Offset(x * scale, y * scale);

      // A stroke far longer (340 logical px) than the level's 60px budget.
      final gesture = await tester.startGesture(toGlobal(50, 350));
      await tester.pump();
      await gesture.moveTo(toGlobal(390, 350));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      // Ink used is clamped to exactly the budget, never negative/over.
      expect(find.text('Ink left: 0 / 60'), findsOneWidget);

      // Further drawing is a no-op once the budget is exhausted.
      final gesture2 = await tester.startGesture(toGlobal(50, 450));
      await tester.pump();
      await gesture2.moveTo(toGlobal(100, 450));
      await tester.pump();
      await gesture2.up();
      await tester.pump();

      expect(find.text('Ink left: 0 / 60'), findsOneWidget);
    },
  );
}
