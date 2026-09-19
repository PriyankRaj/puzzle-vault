import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:topgames/app/theme.dart';
import 'package:topgames/core/game_definition.dart';
import 'package:topgames/core/progress_store.dart';
import 'package:topgames/core/settings_store.dart';
import 'package:topgames/core/widgets/game_host.dart';
import 'package:topgames/core/widgets/level_select_screen.dart';
import 'package:topgames/games/registry.dart';
import 'package:topgames/home/home_screen.dart';
import 'package:topgames/settings/settings_screen.dart';

/// Baseline accessibility checks for the shared chrome (home, level select,
/// settings) that every player passes through regardless of which game
/// they're playing:
///
/// 1. Enlarging system text (accessibility text scaling) must not overflow
///    these screens — a `RenderFlex overflowed` exception would surface as
///    a `FlutterError` caught by [WidgetTester.takeException].
/// 2. Interactive elements expose a real [Semantics] label/button flag for
///    screen readers, not just bare icons/numbers with no announced
///    meaning — checked via [SemanticsTester] queries below.
///
/// This intentionally does not attempt a full per-game audit (grid cells,
/// canvas taps, etc.) — see ARCHITECTURE.md for why that's a much larger,
/// separately-scoped effort.
void main() {
  SharedPreferences.setMockInitialValues({});

  setUp(() async {
    await ProgressStore.instance.init();
    await AppSettingsStore.instance.init();
  });

  Widget wrap(Widget child, {double textScale = 1}) {
    return MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(theme: AppTheme.light(), home: child),
    );
  }

  group('text scaling does not overflow shared screens', () {
    testWidgets('home screen at 2x text scale', (tester) async {
      await tester.pumpWidget(wrap(const HomeScreen(), textScale: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('settings screen at 2x text scale', (tester) async {
      await tester.pumpWidget(wrap(const SettingsScreen(), textScale: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('level select screen at 2x text scale', (tester) async {
      final def = gameRegistry.firstWhere((d) => d.mode == GameMode.levels);
      await tester.pumpWidget(wrap(LevelSelectScreen(def: def), textScale: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('home cards do not overflow at real device widths', () {
    // The default widget-test viewport (~800x600 logical) always lands on
    // exactly 2 columns, so a card-content overflow that only shows up at
    // 3+ columns (a real, narrower phone width, per HomeScreen's own
    // width-derived crossAxisCount) went uncaught by the tests above and
    // only surfaced on a real Android emulator, at normal (1x) text scale
    // — see the childAspectRatio comment in home_screen.dart. This
    // exercises the actual widths that tip HomeScreen into 2/3/4/5 columns,
    // at 1x text scale, so that class of regression fails a test instead
    // of only showing up on-device.
    for (final width in [320.0, 360.0, 400.0, 600.0, 800.0, 1100.0]) {
      testWidgets('at width ${width.toInt()} logical px', (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(wrap(const HomeScreen()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('game screens do not overflow at a narrow phone width', () {
    // A physically-narrow real device (320 logical px, the same width
    // used above for the home grid) is much tighter than the ~800x600
    // default widget-test viewport every per-game logic test uses, so a
    // status-row/AppBar overflow that only shows up this narrow went
    // uncaught until it surfaced on a real emulator. Boots every
    // registered game's actual gameplay screen (not just the home grid)
    // at that width for a few frames, same as game_smoke_test.dart but at
    // a real device width instead of the default wide viewport.
    for (final def in gameRegistry) {
      testWidgets('${def.id} at width 320 logical px', (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 720));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: GameHost(def: def, initialLevel: 1),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
      });
    }
  });

  group('key controls expose real semantics', () {
    testWidgets('a home game card is announced as a labeled button', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap(const HomeScreen()));
      await tester.pumpAndSettle();

      final sudoku = gameRegistry.firstWhere((d) => d.id == 'sudoku');
      final node = tester.getSemantics(find.text(sudoku.title).first);
      // The card's own Semantics(button: true, label: ...) merges into an
      // ancestor node once ExcludeSemantics hides the raw title Text node
      // from the tree, so what we actually find here is that ancestor.
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.label, contains(sudoku.title));
      expect(node.label, contains(sudoku.tagline));

      handle.dispose();
    });

    testWidgets('a settings switch tile announces title + state together', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap(const SettingsScreen()));
      await tester.pumpAndSettle();

      final node = tester.getSemantics(find.text('Dark theme').first);
      expect(node.label, contains('Dark theme'));
      // MergeSemantics folds the Switch's own toggled-state flag into the
      // same node — Tristate.none means "not applicable", so anything else
      // means the Switch's semantics really did merge in here.
      expect(
        node.flagsCollection.isToggled,
        isNot(Tristate.none),
        reason: "expected the Switch's own semantics to be merged in",
      );

      handle.dispose();
    });

    testWidgets('a locked level tile announces its locked state', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final def = gameRegistry.firstWhere(
        (d) => d.mode == GameMode.levels && d.levelCount > 1,
      );
      await tester.pumpWidget(wrap(LevelSelectScreen(def: def)));
      await tester.pumpAndSettle();

      // A locked tile shows a lock icon, not its level number as text.
      final node = tester.getSemantics(find.byIcon(Icons.lock_rounded).first);
      expect(node.label, contains('locked'));

      handle.dispose();
    });
  });
}
