import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:topgames/app/theme.dart';
import 'package:topgames/core/progress_store.dart';
import 'package:topgames/core/settings_store.dart';
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
      expect(ProgressStore.instance.starsByLevel(def.id), isEmpty, reason: def.id);
      expect(ProgressStore.instance.bestScore(def.id), 0, reason: def.id);
    }
  });

  testWidgets('tapping Reset then confirming wipes progress via the Settings UI',
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
  });
}
