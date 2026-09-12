import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:topgames/app/theme.dart';
import 'package:topgames/core/game_definition.dart';
import 'package:topgames/core/game_level_context.dart';
import 'package:topgames/core/progress_store.dart';
import 'package:topgames/core/settings_store.dart';
import 'package:topgames/core/widgets/level_select_screen.dart';
import 'package:topgames/games/merge2048/merge2048_game.dart';
import 'package:topgames/games/registry.dart';
import 'package:topgames/settings/settings_screen.dart';

void main() {
  SharedPreferences.setMockInitialValues({});

  setUp(() async {
    await ProgressStore.instance.init();
    await AppSettingsStore.instance.init();
  });

  test('ProgressStore.resetAll clears unlocked levels, stars and best scores '
      'for every game', () async {
    for (final def in gameRegistry) {
      await ProgressStore.instance.unlockUpTo(def.id, 5);
      await ProgressStore.instance.setStars(def.id, 1, 3);
      await ProgressStore.instance.setBestScore(def.id, 999);
    }

    await ProgressStore.instance.resetAll(gameRegistry.map((d) => d.id));

    for (final def in gameRegistry) {
      expect(ProgressStore.instance.unlockedLevel(def.id), 1, reason: def.id);
      expect(
        ProgressStore.instance.starsByLevel(def.id),
        isEmpty,
        reason: def.id,
      );
      expect(ProgressStore.instance.bestScore(def.id), 0, reason: def.id);
    }
  });

  testWidgets(
    'tapping Reset then confirming wipes progress via the Settings UI',
    (tester) async {
      final probeId = gameRegistry.first.id;
      await ProgressStore.instance.unlockUpTo(probeId, 4);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.dark(), home: const SettingsScreen()),
      );
      await tester.pump();

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear rather than resetting immediately.
      expect(find.text('Reset all progress?'), findsOneWidget);
      expect(ProgressStore.instance.unlockedLevel(probeId), 4);

      // The dialog itself has its own "Reset" action, distinct from the tile's.
      await tester.tap(find.text('Reset').last);
      await tester.pumpAndSettle();

      expect(ProgressStore.instance.unlockedLevel(probeId), 1);
      expect(find.text('All progress has been reset'), findsOneWidget);
    },
  );

  testWidgets(
    "resetting one game's progress from its level-select screen doesn't "
    "touch other games",
    (tester) async {
      final target = gameRegistry.firstWhere((d) => d.mode == GameMode.levels);
      final other = gameRegistry.firstWhere(
        (d) => d.mode == GameMode.levels && d.id != target.id,
      );
      await ProgressStore.instance.unlockUpTo(target.id, 5);
      await ProgressStore.instance.setStars(target.id, 1, 3);
      await ProgressStore.instance.unlockUpTo(other.id, 3);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: LevelSelectScreen(def: target),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Reset progress'));
      await tester.pumpAndSettle();

      expect(find.text('Reset ${target.title}?'), findsOneWidget);
      // Confirmation gate: nothing cleared until the dialog's own button.
      expect(ProgressStore.instance.unlockedLevel(target.id), 5);

      await tester.tap(find.text('Reset').last);
      await tester.pumpAndSettle();

      expect(ProgressStore.instance.unlockedLevel(target.id), 1);
      expect(ProgressStore.instance.starsByLevel(target.id), isEmpty);
      expect(
        find.text('${target.title} progress has been reset'),
        findsOneWidget,
      );
      // The other game's progress is untouched.
      expect(ProgressStore.instance.unlockedLevel(other.id), 3);
    },
  );

  testWidgets(
    'resetting Number Merge from its own AppBar clears only its best score',
    (tester) async {
      const target = 'merge_2048';
      // Any other registered game id works here — this just proves
      // resetting merge_2048 doesn't leak into unrelated games' scores.
      const other = 'sudoku';
      await ProgressStore.instance.setBestScore(target, 4096);
      await ProgressStore.instance.setBestScore(other, 512);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Merge2048Screen(
            ctx: GameLevelContext(
              gameId: target,
              level: 1,
              isEndless: true,
              onComplete: ({int stars = 0, int? score}) {},
              onExit: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Reset progress'));
      await tester.pumpAndSettle();

      expect(find.text('Reset Number Merge?'), findsOneWidget);
      expect(ProgressStore.instance.bestScore(target), 4096);

      await tester.tap(find.text('Reset').last);
      await tester.pumpAndSettle();

      expect(ProgressStore.instance.bestScore(target), 0);
      expect(ProgressStore.instance.bestScore(other), 512);
      expect(find.text('Number Merge progress has been reset'), findsOneWidget);
    },
  );
}
