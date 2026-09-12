import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../game_definition.dart';
import '../progress_store.dart';
import '../settings_store.dart';
import '../sound.dart';
import 'game_host.dart';
import 'info_tip_button.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key, required this.def});

  final GameDefinition def;

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  Future<void> _confirmReset(BuildContext context) async {
    final def = widget.def;
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
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${def.title} progress has been reset')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final def = widget.def;
    final unlocked = ProgressStore.instance.unlockedLevel(def.id);
    final stars = ProgressStore.instance.starsByLevel(def.id);

    return ValueListenableBuilder<bool>(
      valueListenable: AppSettingsStore.instance.isDarkMode,
      builder: (context, _, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(def.title),
            actions: [
              InfoTipButton(title: def.title, helpText: def.helpText),
              IconButton(
                icon: const Icon(Icons.restart_alt_rounded),
                tooltip: 'Reset progress',
                onPressed: () => _confirmReset(context),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: GridView.builder(
              itemCount: def.levelCount,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final level = index + 1;
                final isLocked = level > unlocked;
                final earned = stars[level] ?? 0;
                return _LevelTile(
                  level: level,
                  locked: isLocked,
                  stars: earned,
                  tint: def.tint,
                  onTap: isLocked
                      ? null
                      : () async {
                          Sfx.tap();
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  GameHost(def: def, initialLevel: level),
                            ),
                          );
                          if (mounted) setState(() {});
                        },
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.level,
    required this.locked,
    required this.stars,
    required this.tint,
    required this.onTap,
  });

  final int level;
  final bool locked;
  final int stars;
  final GameTint tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: locked ? AppTheme.surface : AppTheme.surfaceHigh,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (locked)
                Icon(
                  Icons.lock_rounded,
                  color: AppTheme.textSecondary,
                  size: 22,
                )
              else
                Text(
                  '$level',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: tint.primary,
                  ),
                ),
              const SizedBox(height: 6),
              if (!locked)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    final filled = i < stars;
                    return Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 12,
                      color: filled ? AppTheme.warning : AppTheme.textSecondary,
                    );
                  }),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
