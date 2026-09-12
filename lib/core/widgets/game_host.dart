import 'package:flutter/material.dart';

import '../game_definition.dart';
import '../game_level_context.dart';
import '../progress_store.dart';
import '../settings_store.dart';
import 'info_tip_button.dart';
import 'level_select_screen.dart';
import 'result_dialog.dart';

/// Wraps a [GameDefinition]'s gameplay widget with the shared
/// complete/retry/next-level/exit plumbing, so individual games never need
/// to know about [ProgressStore] or navigation.
///
/// Each attempt gets a fresh widget subtree (via a changing [ValueKey]), so
/// a game's [State] can assume it starts clean every time it is built —
/// no manual reset method required.
class GameHost extends StatefulWidget {
  const GameHost({super.key, required this.def, required this.initialLevel});

  final GameDefinition def;
  final int initialLevel;

  @override
  State<GameHost> createState() => _GameHostState();
}

class _GameHostState extends State<GameHost> {
  late int _level;
  int _attempt = 0;
  _Celebration? _celebration;

  @override
  void initState() {
    super.initState();
    _level = widget.initialLevel;
    _maybeShowFirstVisitHelp();
  }

  /// Auto-shows the "how to play" dialog the very first time a player ever
  /// opens this game, so the help isn't purely opt-in via the ⓘ button —
  /// especially now that home jumps straight into gameplay rather than
  /// stopping at a level-select screen first. Shown at most once per game,
  /// ever, tracked via [ProgressStore.hasSeenHelp].
  void _maybeShowFirstVisitHelp() {
    final def = widget.def;
    if (ProgressStore.instance.hasSeenHelp(def.id)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ProgressStore.instance.markHelpSeen(def.id);
      showHowToPlayDialog(context, title: def.title, helpText: def.helpText);
    });
  }

  Future<void> _handleComplete({int stars = 0, int? score}) async {
    final def = widget.def;
    if (def.mode == GameMode.endless) {
      if (score != null) {
        await ProgressStore.instance.setBestScore(def.id, score);
      }
      if (!mounted) return;
      setState(() {
        _celebration = _Celebration(
          stars: 3,
          hasNextLevel: false,
          // Nothing to advance to in endless mode; Next is hidden.
          onNext: () {},
          onRetry: () => setState(() {
            _celebration = null;
            _attempt++;
          }),
          // This is the only callback that should ever leave the screen —
          // there's no dialog route to pop, just this GameHost's own route.
          onMenu: () => Navigator.of(context).pop(),
        );
      });
      return;
    }

    await ProgressStore.instance.setStars(def.id, _level, stars);
    final nextLevel = _level + 1;
    if (nextLevel <= def.levelCount) {
      await ProgressStore.instance.unlockUpTo(def.id, nextLevel);
    }
    if (!mounted) return;
    final hasNext = _level < def.levelCount;
    setState(() {
      _celebration = _Celebration(
        stars: stars,
        hasNextLevel: hasNext,
        onNext: () => setState(() {
          _celebration = null;
          _level = nextLevel;
          _attempt = 0;
        }),
        onRetry: () => setState(() {
          _celebration = null;
          _attempt++;
        }),
        onMenu: () => Navigator.of(context).pop(),
      );
    });
  }

  void _handleExit() {
    Navigator.of(context).maybePop();
  }

  Future<void> _openLevelSelect() async {
    final chosen = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => LevelSelectScreen(def: widget.def)),
    );
    if (chosen != null && mounted) {
      setState(() {
        _level = chosen;
        _attempt = 0;
        _celebration = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final def = widget.def;
    final celebration = _celebration;
    final ctx = GameLevelContext(
      gameId: def.id,
      level: _level,
      isEndless: def.mode == GameMode.endless,
      onComplete: _handleComplete,
      onExit: _handleExit,
      onOpenLevelSelect: def.mode == GameMode.levels ? _openLevelSelect : null,
    );
    // Every game's screen is built through this single choke point, so
    // listening for theme changes here — rather than in each of the 20
    // game files — is what makes the light/dark toggle reach every game
    // even while its screen is already on-screen.
    return ValueListenableBuilder<bool>(
      valueListenable: AppSettingsStore.instance.isDarkMode,
      builder: (context, _, _) {
        return Stack(
          children: [
            KeyedSubtree(
              key: ValueKey('${def.id}_${_level}_$_attempt'),
              child: def.builder(context, ctx),
            ),
            // Rendered as an overlay, not a dialog route, so the solved
            // board stays visible underneath — see result_dialog.dart.
            if (celebration != null)
              Positioned.fill(
                child: LevelCompleteOverlay(
                  key: ValueKey('celebration_${_level}_$_attempt'),
                  stars: celebration.stars,
                  hasNextLevel: celebration.hasNextLevel,
                  onNext: celebration.onNext,
                  onRetry: celebration.onRetry,
                  onMenu: celebration.onMenu,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Celebration {
  const _Celebration({
    required this.stars,
    required this.hasNextLevel,
    required this.onNext,
    required this.onRetry,
    required this.onMenu,
  });

  final int stars;
  final bool hasNextLevel;
  final VoidCallback onNext;
  final VoidCallback onRetry;
  final VoidCallback onMenu;
}
