import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../sound.dart';

/// Shared "you won / next level" dialog used by every level-based game.
Future<void> showLevelCompleteDialog(
  BuildContext context, {
  required int stars,
  required bool hasNextLevel,
  required VoidCallback onNext,
  required VoidCallback onRetry,
  required VoidCallback onMenu,
}) {
  Sfx.success();
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: const Text('Level complete'),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final filled = i < stars;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                filled ? Icons.star_rounded : Icons.star_outline_rounded,
                color: filled ? AppTheme.warning : AppTheme.textSecondary,
                size: 40,
              ),
            );
          }),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: onMenu,
            child: const Text('Menu'),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
          if (hasNextLevel)
            ElevatedButton(
              onPressed: onNext,
              child: const Text('Next'),
            ),
        ],
      );
    },
  );
}

/// Shared "try again" dialog for a failed attempt.
Future<void> showLevelFailedDialog(
  BuildContext context, {
  String message = "That didn't quite work out.",
  required VoidCallback onRetry,
  required VoidCallback onMenu,
}) {
  Sfx.error();
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: const Text('Try again'),
        content: Text(message),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(onPressed: onMenu, child: const Text('Menu')),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      );
    },
  );
}
