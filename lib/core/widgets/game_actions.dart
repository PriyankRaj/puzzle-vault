import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../game_definition.dart';
import '../game_level_context.dart';
import '../progress_store.dart';
import '../sound.dart';
import 'info_tip_button.dart';

/// Shared AppBar actions every game screen includes, spread directly into
/// each game's own `AppBar.actions` — see ARCHITECTURE.md for why this is a
/// helper rather than a shared `Scaffold` imposed by `GameHost` (it would
/// change the widget tree above every game and break index-based test
/// finders like `tactics_grid_logic_test.dart`'s
/// `_cellGestureDetectorOffset`).
///
/// Order: Restart level (only if the game supplies one), Hint (only if the
/// game supplies one), How to play, Levels (only for [GameMode.levels]
/// games — opens the picker without leaving the screen), Reset progress.
List<Widget> gameActions({
  required BuildContext context,
  required GameDefinition def,
  required GameLevelContext ctx,
  VoidCallback? onHint,
  VoidCallback? onRestart,
}) {
  return [
    if (onRestart != null)
      IconButton(
        icon: const Icon(Icons.replay_rounded),
        tooltip: 'Restart level',
        onPressed: onRestart,
      ),
    if (onHint != null)
      IconButton(
        icon: const Icon(Icons.lightbulb_outline_rounded),
        tooltip: 'Hint',
        onPressed: () {
          Sfx.tap();
          onHint();
        },
      ),
    InfoTipButton(title: def.title, helpText: def.helpText),
    if (ctx.onOpenLevelSelect != null)
      IconButton(
        icon: const Icon(Icons.grid_view_rounded),
        tooltip: 'Levels',
        onPressed: ctx.onOpenLevelSelect,
      ),
    IconButton(
      icon: const Icon(Icons.restart_alt_rounded),
      tooltip: 'Reset progress',
      onPressed: () => confirmAndResetGame(context, def),
    ),
  ];
}

/// Shared "reset this game's progress" confirmation + action, used by
/// [gameActions] and by [LevelSelectScreen] (which still offers its own
/// copy for players who reach it directly).
Future<void> confirmAndResetGame(
  BuildContext context,
  GameDefinition def,
) async {
  Sfx.tap();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Reset ${def.title}?'),
        content: const Text(
          'This clears unlocked levels and stars for this game only. '
          'This cannot be undone.',
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('Reset'),
          ),
        ],
      );
    },
  );
  if (confirmed != true) return;

  await ProgressStore.instance.resetGame(def.id);
  Sfx.success();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('${def.title} progress has been reset')),
  );
}
