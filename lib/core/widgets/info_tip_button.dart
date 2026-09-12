import 'package:flutter/material.dart';

import '../sound.dart';

/// Info (ⓘ) icon-button for an AppBar that shows a "How to play" dialog.
/// One instance of this covers a game's instructions wherever it's placed —
/// see `LevelSelectScreen` for the level-based games and the two endless
/// games' own AppBars for the rest.
class InfoTipButton extends StatelessWidget {
  const InfoTipButton({super.key, required this.title, required this.helpText});

  final String title;
  final String helpText;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.info_outline_rounded),
      tooltip: 'How to play',
      onPressed: () {
        Sfx.tap();
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(helpText),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Got it'),
              ),
            ],
          ),
        );
      },
    );
  }
}
