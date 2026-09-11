import 'package:flutter/material.dart';

import '../game_definition.dart';
import '../game_level_context.dart';
import '../progress_store.dart';
import '../settings_store.dart';
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

  @override
  void initState() {
    super.initState();
    _level = widget.initialLevel;
  }

  Future<void> _handleComplete({int stars = 0, int? score}) async {
    final def = widget.def;
    if (def.mode == GameMode.endless) {
      if (score != null) {
        await ProgressStore.instance.setBestScore(def.id, score);
      }
      if (!mounted) return;
      await showLevelCompleteDialog(
        context,
        stars: 3,
        hasNextLevel: false,
        onNext: () {},
        onRetry: () {
          Navigator.of(context).pop();
          setState(() => _attempt++);
        },
        onMenu: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      );
      return;
    }

    await ProgressStore.instance.setStars(def.id, _level, stars);
    final nextLevel = _level + 1;
    if (nextLevel <= def.levelCount) {
      await ProgressStore.instance.unlockUpTo(def.id, nextLevel);
    }
    if (!mounted) return;
    final hasNext = _level < def.levelCount;
    await showLevelCompleteDialog(
      context,
      stars: stars,
      hasNextLevel: hasNext,
      onNext: () {
        Navigator.of(context).pop();
        setState(() {
          _level = nextLevel;
          _attempt = 0;
        });
      },
      onRetry: () {
        Navigator.of(context).pop();
        setState(() => _attempt++);
      },
      onMenu: () {
        Navigator.of(context).pop();
        Navigator.of(context).pop();
      },
    );
  }

  void _handleExit() {
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final def = widget.def;
    final ctx = GameLevelContext(
      gameId: def.id,
      level: _level,
      isEndless: def.mode == GameMode.endless,
      onComplete: _handleComplete,
      onExit: _handleExit,
    );
    // Every game's screen is built through this single choke point, so
    // listening for theme changes here — rather than in each of the 20
    // game files — is what makes the light/dark toggle reach every game
    // even while its screen is already on-screen.
    return ValueListenableBuilder<bool>(
      valueListenable: AppSettingsStore.instance.isDarkMode,
      builder: (context, _, _) {
        return KeyedSubtree(
          key: ValueKey('${def.id}_${_level}_$_attempt'),
          child: def.builder(context, ctx),
        );
      },
    );
  }
}
