import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../game_definition.dart';
import '../progress_store.dart';
import '../settings_store.dart';
import '../sound.dart';
import 'game_actions.dart';
import 'info_tip_button.dart';

/// The level picker for a [GameMode.levels] game. Reached from an in-game
/// "Levels" action (see `game_actions.dart`), not as a mandatory step before
/// every game — `HomeScreen` jumps straight into `GameHost` at the next
/// unlocked level. Tapping an unlocked tile pops this screen with the
/// chosen level number for `GameHost` to apply; it never pushes a nested
/// `GameHost` itself.
class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key, required this.def});

  final GameDefinition def;

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  Future<void> _confirmReset(BuildContext context) async {
    await confirmAndResetGame(context, widget.def);
    if (mounted) setState(() {});
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Keep tiles a sensible size on wide/tablet screens instead
                // of a fixed 3-up grid stretching them arbitrarily wide.
                final crossAxisCount = (constraints.maxWidth / 130)
                    .floor()
                    .clamp(3, 6);
                return GridView.builder(
                  itemCount: def.levelCount,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: textScaleAdjustedAspectRatio(context, 1),
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
                          : () {
                              Sfx.tap();
                              Navigator.of(context).pop(level);
                            },
                    );
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
    final label = locked
        ? 'Level $level, locked'
        : 'Level $level, $stars of 3 stars';
    return Material(
      color: locked ? AppTheme.surface : AppTheme.surfaceHigh,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Semantics(
          button: true,
          label: label,
          child: ExcludeSemantics(
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
                          filled
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 16,
                          color: filled
                              ? AppTheme.warning
                              : AppTheme.textSecondary,
                        );
                      }),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
