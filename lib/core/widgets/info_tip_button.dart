import 'package:flutter/material.dart';

import '../sound.dart';

/// Shows the "How to play" dialog for a game. Shared by [InfoTipButton]
/// (the manual ⓘ trigger) and `GameHost`'s first-visit auto-show, so both
/// paths render the exact same dialog.
Future<void> showHowToPlayDialog(
  BuildContext context, {
  required String title,
  required String helpText,
}) {
  return showDialog<void>(
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
}

/// Info (ⓘ) icon-button for an AppBar that shows a "How to play" dialog.
/// One instance of this covers a game's instructions wherever it's placed —
/// see `gameActions()`, which every game spreads into its own AppBar.
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
        showHowToPlayDialog(context, title: title, helpText: helpText);
      },
    );
  }
}
