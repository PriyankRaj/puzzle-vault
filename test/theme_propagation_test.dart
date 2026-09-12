import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:topgames/app/theme.dart';
import 'package:topgames/core/motion.dart';
import 'package:topgames/core/progress_store.dart';
import 'package:topgames/core/settings_store.dart';
import 'package:topgames/core/widgets/game_host.dart';
import 'package:topgames/games/registry.dart';
import 'package:topgames/settings/settings_screen.dart';

/// Regression test for a real bug found via manual testing: `AppTheme`
/// colors are plain static getters (so every game file can keep using
/// `AppTheme.surface` etc. without needing a BuildContext), which means a
/// widget only repaints them when *something* tells Flutter to rebuild it.
/// Toggling dark mode must therefore reach every already-mounted screen
/// through an explicit listener — this test proves it does for both the
/// Settings screen itself and for a live game screen via [GameHost].
void main() {
  SharedPreferences.setMockInitialValues({});

  setUp(() async {
    await ProgressStore.instance.init();
    await AppSettingsStore.instance.init();
    await AppSettingsStore.instance.setDarkMode(true);
    AppTheme.setBrightness(Brightness.dark);
  });

  testWidgets('toggling dark mode updates SettingsScreen tiles that do not '
      'directly listen for the theme change', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark(), home: const SettingsScreen()),
    );
    await tester.pump();

    // The "Sound effects" tile only listens to `soundEnabled`, not
    // `isDarkMode` — it must be reached via the screen-level listener.
    final soundSubtitle = find.text('Taps, wins and mistakes make a sound');
    expect(soundSubtitle, findsOneWidget);
    final beforeColor = tester.widget<Text>(soundSubtitle).style!.color;

    AppTheme.setBrightness(Brightness.light);
    await AppSettingsStore.instance.setDarkMode(false);
    await tester.pump();
    await tester.pump();

    final afterColor = tester.widget<Text>(soundSubtitle).style!.color;
    expect(
      afterColor,
      isNot(equals(beforeColor)),
      reason:
          'Sound effects tile did not repaint after the theme toggle — '
          'the light/dark setting is not propagating to already-mounted '
          'widgets that only listen to a different notifier.',
    );
  });

  testWidgets(
    'toggling dark mode updates an already-open game screen via GameHost',
    (tester) async {
      // "Tile Toggle" paints an off-tile's color directly from
      // `AppTheme.surfaceHigh` inside its GridView.builder itemBuilder (i.e.
      // re-evaluated on every build, not cached at initState) — a solid,
      // concrete probe for whether GameHost's rebuild-on-toggle actually
      // reaches a live game screen's rendering.
      final def = gameRegistry.firstWhere((d) => d.id == 'lights_out');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: GameHost(def: def, initialLevel: 1),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      Color offTileColor() {
        final decoratedBoxes = tester.widgetList<Container>(
          find.byType(Container),
        );
        for (final c in decoratedBoxes) {
          final decoration = c.decoration;
          if (decoration is BoxDecoration && decoration.borderRadius != null) {
            return decoration.color!;
          }
        }
        throw StateError('no tile container found');
      }

      final colorBefore = offTileColor();

      // This mirrors production: the app root sets the brightness flag, and
      // GameHost's own listener (on the same notifier) is what forces the
      // already-open game screen to rebuild and pick it up.
      AppTheme.setBrightness(Brightness.light);
      await AppSettingsStore.instance.setDarkMode(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final colorAfter = offTileColor();

      expect(
        colorAfter,
        isNot(equals(colorBefore)),
        reason:
            'The already-open game screen did not repaint in the new '
            'palette after the theme toggle.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  test('Motion.ms zeroes durations when Animations is off', () {
    AppSettingsStore.instance.animationsEnabled.value = true;
    expect(Motion.ms(150), const Duration(milliseconds: 150));

    AppSettingsStore.instance.animationsEnabled.value = false;
    expect(Motion.ms(150), Duration.zero);
  });

  testWidgets("Tile Toggle's own AnimatedContainer duration reflects the "
      'Animations setting', (tester) async {
    final def = gameRegistry.firstWhere((d) => d.id == 'lights_out');
    await AppSettingsStore.instance.setAnimationsEnabled(false);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: GameHost(def: def, initialLevel: 1),
      ),
    );
    await tester.pump();

    final tile = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .first;
    expect(
      tile.duration,
      Duration.zero,
      reason:
          "Tile Toggle's tiles should stop animating once Animations is off.",
    );

    await AppSettingsStore.instance.setAnimationsEnabled(true);
  });

  test('Settings > Animations off swaps in an instant page transition', () {
    final animated = AppTheme.dark(animate: true).pageTransitionsTheme;
    final instant = AppTheme.dark(animate: false).pageTransitionsTheme;
    expect(
      instant.builders[TargetPlatform.android].runtimeType,
      isNot(equals(animated.builders[TargetPlatform.android].runtimeType)),
      reason:
          'Disabling Animations should swap the route transition '
          'builder to a no-op one, not leave the default slide/fade.',
    );
  });
}
