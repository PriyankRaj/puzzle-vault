import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:topgames/core/game_level_context.dart';
import 'package:topgames/core/settings_store.dart';
import 'package:topgames/games/snip_logic/snip_logic_game.dart';

/// Snip Logic starts its physics ticker immediately in `initState` (there
/// is no separate "launch" step), so these tests drive it with small,
/// bounded `tester.pump` steps and cap the total simulated time — never
/// `pumpAndSettle`, which would hang on the always-running ticker.
void main() {
  setUp(() {
    // Avoid a repeating AnimationController ticker (the target-zone pulse)
    // outliving the test.
    AppSettingsStore.instance.animationsEnabled.value = false;
  });

  Rect canvasRect(WidgetTester tester) {
    final finder = find.byWidgetPredicate(
      (w) =>
          w is CustomPaint &&
          w.painter.runtimeType.toString() == '_SnipLogicPainter',
    );
    return tester.getRect(finder);
  }

  /// Pumps physics in small steps until [predicate] is true or [maxTicks]
  /// (a hard cap, so this can never hang) is reached.
  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() predicate, {
    int maxTicks = 400,
  }) async {
    for (var i = 0; i < maxTicks && !predicate(); i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('snip_logic: level 1 hangs the parcel straight below its single '
      'anchor — cutting the rope drops it straight down into the target '
      'and reports completion', (tester) async {
    var completed = false;
    int? completedStars;

    await tester.pumpWidget(
      MaterialApp(
        home: SnipLogicScreen(
          ctx: GameLevelContext(
            gameId: 'snip_logic',
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

    final rect = canvasRect(tester);
    final scale = rect.width / 400;
    Offset toGlobal(double x, double y) =>
        rect.topLeft + Offset(x * scale, y * scale);

    // Tap along the rope (anchor (200,70) to parcel (200,170)) to cut it.
    await tester.tapAt(toGlobal(200, 120));
    await tester.pump();

    await pumpUntil(tester, () => completed);

    expect(completed, isTrue);
    expect(completedStars, inInclusiveRange(1, 3));
    expect(find.text('Delivered!'), findsOneWidget);
  });

  testWidgets(
    'snip_logic: cutting the rope immediately on level 6 sends the parcel '
    'straight into the oscillating hazard — a loss distinct from a '
    'successful delivery, and onComplete is never called',
    (tester) async {
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SnipLogicScreen(
            ctx: GameLevelContext(
              gameId: 'snip_logic',
              level: 6,
              isEndless: false,
              onComplete: ({int stars = 0, int? score}) => completed = true,
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

      // Cut the single rope (anchor (150,70) to parcel (300,200)) right
      // away, before the pendulum swing has carried it clear of the
      // hazard's horizontal travel range.
      await tester.tapAt(toGlobal(225, 135));
      await tester.pump();

      await pumpUntil(
        tester,
        () => completed || find.text('Lost…').evaluate().isNotEmpty,
      );

      expect(completed, isFalse);
      expect(find.text('Lost…'), findsOneWidget);
      expect(find.text('Delivered!'), findsNothing);

      // The distinct failure dialog (rather than any success UI) appears.
      await tester.pump();
      expect(find.text('Parcel lost'), findsOneWidget);
    },
  );

  testWidgets(
    'snip_logic: restart level resets ropes and bumps the retry count '
    'without opening the failed dialog',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SnipLogicScreen(
            ctx: GameLevelContext(
              gameId: 'snip_logic',
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

      await tester.tapAt(toGlobal(200, 120));
      await tester.pump();
      expect(find.text('Falling…'), findsOneWidget);

      await tester.tap(find.byTooltip('Restart level'));
      await tester.pump();

      expect(find.text('Tap a rope to cut it (1 left)'), findsOneWidget);
      expect(find.text('Retries: 1'), findsOneWidget);
      expect(find.text('Parcel lost'), findsNothing);
    },
  );
}
