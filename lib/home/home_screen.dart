import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/game_definition.dart';
import '../core/settings_store.dart';
import '../core/sound.dart';
import '../core/widgets/game_host.dart';
import '../core/widgets/level_select_screen.dart';
import '../games/registry.dart';
import '../settings/settings_screen.dart';

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
            title: const Text('Puzzle Vault'),
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
            child: GridView.builder(
              itemCount: gameRegistry.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.92,
              ),
              itemBuilder: (context, index) =>
                  _GameCard(def: gameRegistry[index]),
            ),
          ),
        );
      },
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.def});

  final GameDefinition def;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Sfx.tap();
          if (def.mode == GameMode.levels) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => LevelSelectScreen(def: def)),
            );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => GameHost(def: def, initialLevel: 1),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: def.tint.gradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(def.icon, color: Colors.white, size: 24),
              ),
              const Spacer(),
              Text(
                def.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                def.tagline,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
