import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:topgames/core/game_level_context.dart';
import 'package:topgames/games/defuse_protocol/defuse_protocol_game.dart';

// The following constants and functions replicate the private module
// generation in `DefuseProtocolScreen` (`_generateModules`,
// `_generateWireModule`, `_generateKeypadModule`, `_wireRuleIndex`) closely
// enough — same seed formula `4242 + level`, same rng-consumption order —
// to deduce, for a given level, exactly which module type the widget will
// generate and what its correct action is, so the test can drive a real
// correct/incorrect action through the public widget instead of hardcoding
// or reaching into private state. If the in-game generation algorithm
// changes, update this to match.

const List<Color> _wirePalette = [
  Color(0xFFEF4444), // red
  Color(0xFF3B82F6), // blue
  Color(0xFFFACC15), // yellow
  Color(0xFF22C55E), // green
  Color(0xFFF8FAFC), // white
];

const List<IconData> _keypadIconPool = [
  Icons.star_rounded,
  Icons.circle,
  Icons.change_history_rounded,
  Icons.square_rounded,
  Icons.favorite,
];

const List<List<int>> _patternsAppearsTwice = [
  [2, 3, 4],
  [2, 1, 3, 3],
  [2, 1, 1, 1, 4],
  [2, 7],
];
const List<List<int>> _patternsAppearsOnce = [
  [1, 2, 6],
  [1, 2, 3, 3],
  [1, 4, 4],
  [1, 2, 2, 2, 2],
];

sealed class _ModuleOutcome {}

class _WireOutcome extends _ModuleOutcome {
  _WireOutcome(this.colors, this.correctIndex);
  final List<Color> colors;
  final int correctIndex;
}

class _KeypadOutcome extends _ModuleOutcome {
  _KeypadOutcome(this.correctIcon);
  final IconData correctIcon;
}

class _ToggleOutcome extends _ModuleOutcome {
  _ToggleOutcome(this.ruleId, this.initialStates);
  final int ruleId;
  final List<bool> initialStates;
}

int _wireRuleIndex(int ruleId, List<Color> colors) {
  switch (ruleId) {
    case 0:
      bool repeats(int i) => colors.where((c) => c == colors[i]).length > 1;
      for (var i = colors.length - 1; i >= 0; i--) {
        if (repeats(i)) return i;
      }
      final blueIndex = colors.indexOf(_wirePalette[1]);
      if (blueIndex != -1) return blueIndex;
      return colors.length - 1;
    case 1:
      final whiteIdx = <int>[];
      for (var i = 0; i < colors.length; i++) {
        if (colors[i] == _wirePalette[4]) whiteIdx.add(i);
      }
      if (whiteIdx.length == 1) return whiteIdx[0];
      final lastRed = colors.lastIndexOf(_wirePalette[0]);
      if (lastRed != -1) return (lastRed + 1) % colors.length;
      return 0;
    default:
      if (colors.length % 2 == 0) {
        final lastColor = colors.last;
        for (var i = 0; i < colors.length - 1; i++) {
          if (colors[i] == lastColor) return i;
        }
      }
      return colors.length ~/ 2;
  }
}

_WireOutcome _determineWire(Random rng, int level) {
  final wireCount = (3 + (level - 1) ~/ 3).clamp(3, 6);
  final colors = List.generate(
    wireCount,
    (_) => _wirePalette[rng.nextInt(_wirePalette.length)],
  );
  final ruleId = rng.nextInt(3);
  final correctIndex = _wireRuleIndex(ruleId, colors);
  return _WireOutcome(colors, correctIndex);
}

_KeypadOutcome _determineKeypad(Random rng) {
  final ruleId = rng.nextInt(2);
  final patterns = ruleId == 0 ? _patternsAppearsTwice : _patternsAppearsOnce;
  final pattern = List<int>.from(patterns[rng.nextInt(patterns.length)])
    ..shuffle(rng);
  final iconPool = List<IconData>.from(_keypadIconPool)..shuffle(rng);

  final flat = <IconData>[];
  for (var i = 0; i < pattern.length; i++) {
    final icon = iconPool[i % iconPool.length];
    for (var n = 0; n < pattern[i]; n++) {
      flat.add(icon);
    }
  }
  flat.shuffle(rng);

  final counts = <IconData, int>{};
  for (final icon in flat) {
    counts[icon] = (counts[icon] ?? 0) + 1;
  }
  final target = ruleId == 0 ? 2 : 1;
  final correctIcon = counts.entries.firstWhere((e) => e.value == target).key;
  return _KeypadOutcome(correctIcon);
}

_ToggleOutcome _determineToggle(Random rng, int level) {
  final switchCount = (3 + (level - 1) ~/ 5).clamp(3, 5);
  final ruleId = rng.nextInt(2);
  List<bool> states;
  do {
    states = List.generate(switchCount, (_) => rng.nextBool());
  } while ((ruleId == 0 && states.where((s) => s).length.isEven) ||
      (ruleId == 1 && states.every((s) => s)));
  return _ToggleOutcome(ruleId, states);
}

/// Determines which module type `DefuseProtocolScreen` will generate first
/// for [level] (the only module, since level 1 has module count 1) and its
/// correct action.
_ModuleOutcome _determineModule(int level) {
  final rng = Random(4242 + level);
  switch (rng.nextInt(3)) {
    case 0:
      return _determineWire(rng, level);
    case 1:
      return _determineKeypad(rng);
    default:
      return _determineToggle(rng, level);
  }
}

void main() {
  testWidgets(
    'defuse_protocol: performing the manual-correct action on module 1 advances toward completion',
    (tester) async {
      const level = 1;
      final outcome = _determineModule(level);

      var completed = false;
      int? completedStars;

      await tester.pumpWidget(
        MaterialApp(
          home: DefuseProtocolScreen(
            ctx: GameLevelContext(
              gameId: 'defuse_protocol',
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

      // The completing action bumps the module index to `_modules.length`
      // and fires `onComplete` via `Future.microtask`, while the screen
      // itself stays mounted (the host's result dialog opens as an
      // overlay on top of it, not in place of it) — so an extra pump here
      // rebuilds this screen with an out-of-range module index. This is a
      // real scenario (a dialog's entrance animation schedules exactly
      // this kind of frame in production), so keep this pump rather than
      // avoiding it: it is a regression guard for that RangeError.
      switch (outcome) {
        case _WireOutcome(
          colors: final colors,
          correctIndex: final correctIndex,
        ):
          expect(find.byType(GestureDetector), findsNWidgets(colors.length));
          await tester.tap(find.byType(GestureDetector).at(correctIndex));
        case _KeypadOutcome(correctIcon: final correctIcon):
          await tester.tap(find.byIcon(correctIcon).first);
        case _ToggleOutcome(
          ruleId: final ruleId,
          initialStates: final initialStates,
        ):
          final switches = find.byType(Switch);
          if (ruleId == 0) {
            // "Flip switches until the number of ON switches is EVEN."
            // Generation guarantees the initial ON-count is odd (states
            // that already satisfy "even" are excluded), so flipping any
            // single switch changes the parity to even.
            await tester.tap(switches.first);
            await tester.pump();
          } else {
            // "Flip exactly the switches that are currently OFF" -> final
            // state should be every switch ON.
            for (var i = 0; i < initialStates.length; i++) {
              if (!initialStates[i]) {
                await tester.tap(switches.at(i));
                await tester.pump();
              }
            }
          }
          await tester.tap(find.text('Confirm'));
      }
      await tester.pump();
      await tester.pump();

      // Only module 1 of a single-module level, so a correct action must
      // finish the level.
      expect(
        completed,
        isTrue,
        reason:
            'the manual-correct action on the only module should defuse the device',
      );
      expect(completedStars, isNotNull);
    },
  );

  testWidgets(
    'defuse_protocol: a wrong action triggers the device-triggered failure path instead of completion',
    (tester) async {
      const level = 1;
      final outcome = _determineModule(level);

      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: DefuseProtocolScreen(
            ctx: GameLevelContext(
              gameId: 'defuse_protocol',
              level: level,
              isEndless: false,
              onComplete: ({int stars = 0, int? score}) => completed = true,
              onExit: () {},
            ),
          ),
        ),
      );

      switch (outcome) {
        case _WireOutcome(correctIndex: final correctIndex):
          final wrongIndex = correctIndex == 0 ? 1 : 0;
          await tester.tap(find.byType(GestureDetector).at(wrongIndex));
          await tester.pump();
        case _KeypadOutcome(correctIcon: final correctIcon):
          final wrongIconFinder = find
              .byWidgetPredicate(
                (w) =>
                    w is Icon &&
                    w.icon != correctIcon &&
                    w.icon != Icons.timer_outlined &&
                    // Exclude the shared hint action's icon: it's the first
                    // Icon in the tree (AppBar comes before the module
                    // body), and tapping it would open a hint SnackBar
                    // instead of exercising the intended wrong-answer tap.
                    w.icon != Icons.lightbulb_outline_rounded,
              )
              .first;
          await tester.tap(wrongIconFinder);
          await tester.pump();
        case _ToggleOutcome():
          // Confirm immediately: generation guarantees the initial switch
          // state never already satisfies the rule, so this is always a
          // wrong action without needing to know the specific rule.
          await tester.tap(find.text('Confirm'));
          await tester.pump();
      }

      expect(
        find.text('Device triggered'),
        findsOneWidget,
        reason:
            'a wrong action should show the failure dialog, not silently succeed',
      );
      expect(completed, isFalse);

      // Dismiss the dialog (there are two "Menu" labels on screen — the
      // AppBar action and this dialog's button — so scope the tap to the
      // dialog) and let the widget's periodic timer be cancelled via
      // disposal before the test ends.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Menu'),
        ),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
    },
  );
}
