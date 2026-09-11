import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/game_definition.dart';
import '../../core/game_level_context.dart';
import '../../core/motion.dart';

/// Reference implementation: classic grid-toggle logic puzzle (public
/// domain mechanic). 15 levels, grid size and scramble depth scale up.
final GameDefinition lightsOutDefinition = GameDefinition(
  id: 'lights_out',
  title: 'Tile Toggle',
  tagline: 'Toggle tiles until the whole grid goes dark',
  icon: Icons.lightbulb_rounded,
  tint: const GameTint(Color(0xFFFBBF24), Color(0xFFB45309)),
  mode: GameMode.levels,
  levelCount: 15,
  builder: (context, ctx) => LightsOutScreen(ctx: ctx),
);

class LightsOutScreen extends StatefulWidget {
  const LightsOutScreen({super.key, required this.ctx});

  final GameLevelContext ctx;

  @override
  State<LightsOutScreen> createState() => _LightsOutScreenState();
}

class _LightsOutScreenState extends State<LightsOutScreen> {
  late int _size;
  late List<List<bool>> _grid;
  int _moves = 0;

  int get _level => widget.ctx.level;

  @override
  void initState() {
    super.initState();
    _size = _level <= 5
        ? 3
        : _level <= 10
            ? 4
            : 5;
    _grid = List.generate(_size, (_) => List.filled(_size, false));
    final scramble = 4 + _level; // deeper scramble at higher levels
    final rng = Random(1000 + _level); // deterministic per level
    for (var i = 0; i < scramble; i++) {
      _toggle(rng.nextInt(_size), rng.nextInt(_size), countMove: false);
    }
    // Guarantee a non-trivial (already solved) start.
    if (_isSolved()) {
      _toggle(0, 0, countMove: false);
    }
  }

  void _toggle(int r, int c, {bool countMove = true}) {
    _flip(r, c);
    _flip(r - 1, c);
    _flip(r + 1, c);
    _flip(r, c - 1);
    _flip(r, c + 1);
    if (countMove) _moves++;
  }

  void _flip(int r, int c) {
    if (r < 0 || r >= _size || c < 0 || c >= _size) return;
    _grid[r][c] = !_grid[r][c];
  }

  bool _isSolved() => _grid.every((row) => row.every((v) => !v));

  void _onTap(int r, int c) {
    setState(() => _toggle(r, c));
    if (_isSolved()) {
      final optimalGuess = 4 + _level;
      final stars = _moves <= optimalGuess
          ? 3
          : _moves <= optimalGuess + 3
              ? 2
              : 1;
      Future.microtask(() => widget.ctx.onComplete(stars: stars));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tile Toggle · Level $_level')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Moves: $_moves', style: Theme.of(context).textTheme.titleLarge),
          ),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _size * _size,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _size,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemBuilder: (context, index) {
                      final r = index ~/ _size;
                      final c = index % _size;
                      final on = _grid[r][c];
                      return GestureDetector(
                        onTap: () => _onTap(r, c),
                        child: AnimatedContainer(
                          duration: Motion.ms(150),
                          decoration: BoxDecoration(
                            color: on ? AppTheme.warning : AppTheme.surfaceHigh,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: on
                                ? [
                                    BoxShadow(
                                      color: AppTheme.warning.withValues(alpha: 0.5),
                                      blurRadius: 12,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Tap a tile to flip it and its neighbours',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
