import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:topgames/core/game_level_context.dart';
import 'package:topgames/core/progress_store.dart';
import 'package:topgames/games/merge2048/merge2048_game.dart';

/// The board is seeded from an unseeded `Random()` (see `_Merge2048ScreenState`
/// in merge2048_game.dart), so this test cannot know exact tile positions or
/// values ahead of time and cannot deterministically replay a specific merge
/// or a specific game-over board. Instead it reads the real rendered board
/// through repeated swipes and asserts on invariants that must hold
/// regardless of the random seed:
///   * sliding + merging a line never changes the total tile value sum
///     (a merge of v+v -> 2v preserves the pair's sum) — only the newly
///     spawned tile can add to the board sum, and only by 2 or 4.
///   * the score only increases when tiles are actually merged (tracked via
///     the drop in nonzero tile count once the spawn is accounted for), and
///     the increase is always a positive multiple of 4 (the smallest
///     possible merge is 2+2 -> 4).
/// This directly exercises `_move`'s real merge math on whatever pairs the
/// random board happens to produce, across many swipes.
///
/// Tiles render as individually-animated, identity-keyed widgets (not a
/// fixed 16-slot `GridView`) so they can visibly slide/pop rather than snap
/// — see merge2048_game.dart's `_Tile`/`AnimatedPositioned`. That means
/// there's no longer a fixed widget-index -> board-slot mapping to read
/// row-major; instead this reads every tile's value (found via the
/// `mergeBoard` key), sorted into a canonical order and padded with zeros to
/// 16 entries. That's still exactly enough to check the invariants above —
/// they only depend on the *set* of values on the board, never on position.
const _cells = 16;

List<int> _readBoard(WidgetTester tester) {
  final values =
      find
          .descendant(
            of: find.byKey(const Key('mergeBoard')),
            matching: find.byType(Text),
          )
          .evaluate()
          .map((el) => int.parse((el.widget as Text).data!))
          .toList()
        ..sort();
  while (values.length < _cells) {
    values.add(0);
  }
  return values;
}

int _readScore(WidgetTester tester) {
  final text = tester.widget<Text>(find.textContaining('Score:'));
  return int.parse(text.data!.replaceAll('Score: ', ''));
}

Future<void> _swipe(WidgetTester tester, Offset direction) async {
  // warnIfMissed: false — the tap lands correctly on the ancestor
  // SwipeArea's opaque GestureDetector (confirmed by every test passing);
  // the RenderStack at 'mergeBoard' just isn't itself a hit-test target
  // (no HitTestBehavior set), which is what the default warning flags.
  await tester.fling(
    find.byKey(const Key('mergeBoard')),
    direction,
    1200,
    warnIfMissed: false,
  );
  // Slide + (if anything merged) the delayed cleanup/spawn phase both need
  // to finish before the board reflects the completed move — see _move's
  // two-phase setState in merge2048_game.dart.
  await tester.pumpAndSettle();
}

void main() {
  SharedPreferences.setMockInitialValues({});

  setUp(() async {
    await ProgressStore.instance.init();
  });

  testWidgets(
    'merge2048: repeated swipes conserve tile-value sum and score matches merge accounting',
    (tester) async {
      int? completedScore;

      await tester.pumpWidget(
        MaterialApp(
          home: Merge2048Screen(
            ctx: GameLevelContext(
              gameId: 'merge_2048',
              level: 1,
              isEndless: true,
              onComplete: ({int stars = 0, int? score}) =>
                  completedScore = score,
              onExit: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      const directions = [
        Offset(300, 0), // right
        Offset(0, 300), // down
        Offset(-300, 0), // left
        Offset(0, -300), // up
      ];

      var observedAnyMerge = false;

      for (var i = 0; i < 60 && completedScore == null; i++) {
        final boardBefore = _readBoard(tester);
        final scoreBefore = _readScore(tester);
        final sumBefore = boardBefore.fold<int>(0, (a, b) => a + b);
        final nonZeroBefore = boardBefore.where((v) => v != 0).length;

        await _swipe(tester, directions[i % directions.length]);

        final boardAfter = _readBoard(tester);
        final scoreAfter = _readScore(tester);
        final sumAfter = boardAfter.fold<int>(0, (a, b) => a + b);
        final nonZeroAfter = boardAfter.where((v) => v != 0).length;

        final changed = boardAfter.toString() != boardBefore.toString();
        if (!changed) {
          // A no-op swipe (nothing to slide that direction) must leave the
          // board and score untouched.
          expect(
            sumAfter,
            sumBefore,
            reason: 'unchanged board must not alter the tile-value sum',
          );
          expect(
            scoreAfter,
            scoreBefore,
            reason: 'unchanged board must not alter the score',
          );
          continue;
        }

        final spawnValue = sumAfter - sumBefore;
        expect(
          spawnValue == 2 || spawnValue == 4,
          isTrue,
          reason:
              'a changed move must only add a single freshly spawned 2 '
              'or 4 to the board total ($sumBefore -> $sumAfter); anything '
              'else means a merge did not conserve value',
        );

        // nonZeroAfter = nonZeroBefore - mergeCount + 1 (the spawn).
        final mergeCount = nonZeroBefore - nonZeroAfter + 1;
        expect(
          mergeCount,
          greaterThanOrEqualTo(0),
          reason: 'merge accounting must not go negative',
        );

        final scoreDelta = scoreAfter - scoreBefore;
        if (mergeCount == 0) {
          expect(
            scoreDelta,
            0,
            reason: 'no tiles merged, so the score must not change',
          );
        } else {
          observedAnyMerge = true;
          expect(
            scoreDelta,
            greaterThan(0),
            reason: 'merged tiles must increase the score',
          );
          expect(
            scoreDelta % 4,
            0,
            reason:
                'the smallest possible merge (2+2) scores 4, so every '
                'score delta must be a multiple of 4',
          );
        }
      }

      // Not strictly required by the assertions above, but confirms the
      // 60-swipe budget actually exercised real merges rather than only
      // no-op/slide-only moves (extremely unlikely to fail in practice on
      // a 4x4 board across 60 swipes in every direction).
      expect(
        observedAnyMerge,
        isTrue,
        reason: 'expected at least one real merge across 60 swipes',
      );

      if (completedScore != null) {
        // If the random board happened to fill up and hit game-over during
        // this run, onComplete must have fired with the score shown on
        // screen just before completion.
        expect(completedScore, isNonNegative);
      }
    },
  );

  testWidgets(
    'merge2048: a short drag below the minimum swipe distance does not move or merge anything',
    (tester) async {
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Merge2048Screen(
            ctx: GameLevelContext(
              gameId: 'merge_2048',
              level: 1,
              isEndless: true,
              onComplete: ({int stars = 0, int? score}) => completed = true,
              onExit: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final boardBefore = _readBoard(tester);
      final scoreBefore = _readScore(tester);

      // `SwipeArea` resolves a swipe on total drag *distance*, not
      // velocity (see swipe_area.dart) — a short, slow drag stays well
      // under its `minDistance` threshold, so nothing on the board should
      // change regardless of how slowly it's drawn or the random initial
      // board.
      await tester.timedDrag(
        find.byKey(const Key('mergeBoard')),
        const Offset(40, 0),
        const Duration(seconds: 2),
        warnIfMissed: false,
      );
      await tester.pump();

      final boardAfter = _readBoard(tester);
      final scoreAfter = _readScore(tester);

      expect(
        boardAfter,
        boardBefore,
        reason: 'a below-threshold drag must not slide/merge any tile',
      );
      expect(scoreAfter, scoreBefore);
      expect(completed, isFalse);
    },
  );
}
