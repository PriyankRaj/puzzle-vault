import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:topgames/app/theme.dart';
import 'package:topgames/core/game_definition.dart';
import 'package:topgames/core/progress_store.dart';
import 'package:topgames/core/widgets/game_host.dart';
import 'package:topgames/games/registry.dart';

/// Boots every registered game's gameplay screen for a few frames to catch
/// runtime build errors (overflows, null state, bad CustomPainter math)
/// that `flutter analyze` cannot see.
void main() {
  SharedPreferences.setMockInitialValues({});

  setUp(() async {
    await ProgressStore.instance.init();
  });

  for (final def in gameRegistry) {
    testWidgets('${def.id} builds without errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: GameHost(def: def, initialLevel: 1),
        ),
      );
      // A few pumps let initial animations/timers tick without letting any
      // physics-loop game run forever inside the test.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
    });
  }

  test('every game id is unique', () {
    final ids = gameRegistry.map((d) => d.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('every level-based game caps at 15 levels', () {
    for (final def in gameRegistry) {
      if (def.mode == GameMode.levels) {
        expect(def.levelCount, lessThanOrEqualTo(15), reason: def.id);
        expect(def.levelCount, greaterThan(0), reason: def.id);
      }
    }
  });
}
