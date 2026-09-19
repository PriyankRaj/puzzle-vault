import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/character_store.dart';
import '../core/game_definition.dart';
import '../core/progress_store.dart';
import '../core/settings_store.dart';
import '../core/sound.dart';
import '../core/widgets/character_avatar.dart';
import '../core/widgets/game_host.dart';
import '../games/registry.dart';
import '../settings/settings_screen.dart';
import 'character_customize_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Listening here means this always-mounted screen (bottom of the nav
    // stack) picks up a theme change immediately, not just on next visit.
    return ValueListenableBuilder<bool>(
      valueListenable: AppSettingsStore.instance.isDarkMode,
      builder: (context, _, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Brainers Time!'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_rounded),
                tooltip: 'Settings',
                onPressed: () {
                  Sfx.tap();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                const _CharacterBanner(),
                const SizedBox(height: 12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // 2-up on a phone; more columns (not just bigger
                      // cards) on wider/tablet screens.
                      final crossAxisCount = (constraints.maxWidth / 190)
                          .floor()
                          .clamp(2, 5);
                      return GridView.builder(
                        itemCount: gameRegistry.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          // 0.78, not the pre-progress-badge 0.92: the icon +
                          // progress badge + title + 2-line tagline need real
                          // device testing to fit, not just a synthetic-viewport
                          // widget test — this ratio was verified on an actual
                          // Android emulator at normal text scale, not just in a
                          // widget test's default 800x600 viewport (which never
                          // exercises this device's real 3-up column width).
                          // Also grows taller under larger system text sizes.
                          childAspectRatio: textScaleAdjustedAspectRatio(
                            context,
                            0.74,
                          ),
                        ),
                        itemBuilder: (context, index) =>
                            _GameCard(def: gameRegistry[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Stateful only so it can refresh its own [_ProgressBadge] after returning
/// from a game — [HomeScreen] itself only rebuilds on a theme change, so
/// without this a card's progress would look stale until some unrelated
/// rebuild happened to occur.
class _GameCard extends StatefulWidget {
  const _GameCard({required this.def});

  final GameDefinition def;

  @override
  State<_GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<_GameCard> {
  Future<void> _open() async {
    Sfx.tap();
    final def = widget.def;
    // Jump straight into gameplay at the next unlocked level instead of
    // forcing a level-select stop first; the picker is still reachable
    // in-game via the "Levels" action (see game_actions.dart).
    final level = def.mode == GameMode.levels
        ? ProgressStore.instance.unlockedLevel(def.id)
        : 1;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameHost(def: def, initialLevel: level),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final def = widget.def;
    final progress = _progressSummary(def);
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _open,
        child: Semantics(
          button: true,
          label: [
            def.title,
            def.tagline,
            if (progress != null) progress.semantic,
          ].join('. '),
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: def.tint.gradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(def.icon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 8),
                  _ProgressBadge(progress: progress),
                  const Spacer(),
                  Text(
                    def.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    def.tagline,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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

/// A "where you left off" summary — level reached + total stars for
/// level-based games, best score for the endless game — or null for a game
/// with no recorded progress yet. [display] is the compact on-card text;
/// [semantic] is the fuller phrase folded into the card's aggregate
/// accessibility label, so the visible badge and the announced label are
/// always derived from the same underlying numbers.
typedef _ProgressSummary = ({String display, String semantic, IconData icon});

_ProgressSummary? _progressSummary(GameDefinition def) {
  if (def.mode == GameMode.endless) {
    final best = ProgressStore.instance.bestScore(def.id);
    if (best <= 0) return null;
    return (
      display: 'Best $best',
      semantic: 'Best score $best',
      icon: Icons.emoji_events_rounded,
    );
  }
  final unlocked = ProgressStore.instance.unlockedLevel(def.id);
  final totalStars = ProgressStore.instance
      .starsByLevel(def.id)
      .values
      .fold<int>(0, (sum, s) => sum + s);
  if (unlocked <= 1 && totalStars <= 0) return null;
  return (
    display: 'Lv $unlocked/${def.levelCount} $totalStars',
    semantic: 'Level $unlocked of ${def.levelCount}, $totalStars stars earned',
    icon: Icons.star_rounded,
  );
}

/// Renders [_progressSummary]'s `display` text as a compact icon+text line,
/// or an empty same-height placeholder when there's nothing to show yet —
/// so every card in a row keeps its title/tagline vertically aligned
/// regardless of progress. Purely visual; the parent's `ExcludeSemantics`
/// already covers this, and `semantic` is folded into the card's single
/// aggregate `Semantics` label instead of being announced separately.
class _ProgressBadge extends StatelessWidget {
  const _ProgressBadge({required this.progress});

  final _ProgressSummary? progress;

  @override
  Widget build(BuildContext context) {
    const height = 18.0;
    final progress = this.progress;
    if (progress == null) return const SizedBox(height: height);

    final textStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppTheme.textSecondary,
    );
    return SizedBox(
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(progress.icon, size: 14, color: AppTheme.warning),
          const SizedBox(width: 4),
          Text(progress.display, style: textStyle),
        ],
      ),
    );
  }
}

/// A friendly greeting card above the game grid: the user's customizable
/// mascot (see [CharacterStore]) plus their chosen name, tapping through to
/// [CharacterCustomizeScreen]. Purely cosmetic — no gameplay tie-in.
class _CharacterBanner extends StatelessWidget {
  const _CharacterBanner();

  void _open(BuildContext context) {
    Sfx.tap();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CharacterCustomizeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _open(context),
        child: Semantics(
          button: true,
          label: 'Customize your buddy',
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: Row(
                children: [
                  const CharacterBadge(size: 56),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ValueListenableBuilder<String>(
                          valueListenable: CharacterStore.instance.name,
                          builder: (context, name, _) {
                            return Text(
                              'Hey, $name!',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tap to customize your buddy',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textSecondary,
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
