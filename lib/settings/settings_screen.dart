import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/progress_store.dart';
import '../core/settings_store.dart';
import '../core/sound.dart';
import '../games/registry.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppSettingsStore.instance;
    // Wrapping the whole screen (not just the Dark theme tile) means the
    // Sound/Animations tiles below also repaint in the new palette the
    // instant the theme switch is flipped, not just on next visit.
    return ValueListenableBuilder<bool>(
      valueListenable: store.isDarkMode,
      builder: (context, _, _) => _buildBody(context, store),
    );
  }

  Widget _buildBody(BuildContext context, AppSettingsStore store) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _SectionLabel('Appearance'),
          ValueListenableBuilder<bool>(
            valueListenable: store.isDarkMode,
            builder: (context, isDark, _) {
              return _SettingsTile(
                icon: isDark
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
                title: 'Dark theme',
                subtitle: isDark ? 'On' : 'Off — using light theme',
                trailing: Switch(
                  value: isDark,
                  onChanged: (value) {
                    Sfx.tap();
                    store.setDarkMode(value);
                  },
                ),
              );
            },
          ),
          const _SectionLabel('Gameplay'),
          ValueListenableBuilder<bool>(
            valueListenable: store.soundEnabled,
            builder: (context, enabled, _) {
              return _SettingsTile(
                icon: enabled
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                title: 'Sound effects',
                subtitle: 'Taps, wins and mistakes make a sound',
                trailing: Switch(
                  value: enabled,
                  onChanged: (value) {
                    store.setSoundEnabled(value);
                    if (value) Sfx.tap();
                  },
                ),
              );
            },
          ),
          ValueListenableBuilder<bool>(
            valueListenable: store.animationsEnabled,
            builder: (context, enabled, _) {
              return _SettingsTile(
                icon: Icons.animation_rounded,
                title: 'Animations',
                subtitle: 'Tile, dialog and transition motion effects',
                trailing: Switch(
                  value: enabled,
                  onChanged: (value) {
                    Sfx.tap();
                    store.setAnimationsEnabled(value);
                  },
                ),
              );
            },
          ),
          const _SectionLabel('Data'),
          _SettingsTile(
            icon: Icons.restart_alt_rounded,
            title: 'Reset all progress',
            subtitle:
                'Clears unlocked levels, stars and best scores for every game',
            trailing: TextButton(
              onPressed: () => _confirmResetAll(context),
              style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
              child: const Text('Reset'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmResetAll(BuildContext context) async {
    Sfx.tap();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset all progress?'),
          content: const Text(
            'This clears unlocked levels, stars and best scores for every '
            'game. This cannot be undone.',
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

    await ProgressStore.instance.resetAll(gameRegistry.map((d) => d.id));
    Sfx.success();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All progress has been reset')),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          // Merges the title/subtitle text and the trailing control's own
          // semantics (e.g. a Switch's on/off state) into one announced
          // node, instead of a screen reader hitting a bare "Switch, off"
          // with no idea which setting it belongs to.
          child: MergeSemantics(
            child: Row(
              children: [
                Icon(icon, color: AppTheme.accent),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
