import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/game_definition.dart';
import '../../core/game_level_context.dart';
import '../../core/motion.dart';
import '../../core/sound.dart';
import '../../core/widgets/game_actions.dart';

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
  helpText:
      'Tap any tile to flip it and its up/down/left/right neighbours. '
      'The goal is to turn every tile off. Every level is solvable — fewer '
      'taps earns more stars.',
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
    _setupLevel();
  }

  /// Builds this level's starting grid deterministically from its level
  /// number (same seed every time), so it can be reused both by
  /// [initState] and by [_restartLevel] to restore the exact same start —
  /// never a fresh/different scramble.
  void _setupLevel() {
    _size = _level <= 5
        ? 3
        : _level <= 10
        ? 4
        : 5;
    _grid = List.generate(_size, (_) => List.filled(_size, false));
    _moves = 0;
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

  /// Same-level restart: re-derives this level's starting grid in place,
  /// without leaving the screen or touching progress. Distinct from
  /// `gameActions()`'s own "Reset progress" action (wipes all levels).
  void _restartLevel() {
    Sfx.tap();
    setState(_setupLevel);
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

  /// Solves `A * x = b` over GF(2), where `A` is the standard Lights Out
  /// toggle matrix (pressing column-cell `j` flips row-cell `i` iff `i` is
  /// `j` itself or one of its up/down/left/right neighbours) and `b` is the
  /// vector of currently-lit cells. Any `x` with `x[j] == 1` is a cell whose
  /// press is *guaranteed* to be part of a solution from the current board
  /// state — unlike replaying the original scramble, this stays correct no
  /// matter what moves the player has already made. Returns the first such
  /// cell, or null if the (small, dense) system has no exact solution.
  Point<int>? _solveHint() {
    final n = _size * _size;
    final bBit = 1 << n;
    final mask = bBit - 1;
    final aug = List<int>.filled(n, 0);

    for (var j = 0; j < n; j++) {
      final r = j ~/ _size;
      final c = j % _size;
      final affected = <int>[j];
      if (r > 0) affected.add(j - _size);
      if (r < _size - 1) affected.add(j + _size);
      if (c > 0) affected.add(j - 1);
      if (c < _size - 1) affected.add(j + 1);
      for (final i in affected) {
        aug[i] |= 1 << j;
      }
    }
    for (var i = 0; i < n; i++) {
      final r = i ~/ _size;
      final c = i % _size;
      if (_grid[r][c]) aug[i] |= bBit;
    }

    var row = 0;
    final pivotRowOfCol = <int, int>{};
    for (var col = 0; col < n && row < n; col++) {
      var pivot = -1;
      for (var i = row; i < n; i++) {
        if ((aug[i] >> col) & 1 == 1) {
          pivot = i;
          break;
        }
      }
      if (pivot == -1) continue;
      final tmp = aug[row];
      aug[row] = aug[pivot];
      aug[pivot] = tmp;
      for (var i = 0; i < n; i++) {
        if (i != row && (aug[i] >> col) & 1 == 1) {
          aug[i] ^= aug[row];
        }
      }
      pivotRowOfCol[col] = row;
      row++;
    }

    for (var i = 0; i < n; i++) {
      if ((aug[i] & mask) == 0 && (aug[i] & bBit) != 0) {
        return null; // inconsistent system — shouldn't happen from a valid scramble.
      }
    }

    for (final entry in pivotRowOfCol.entries) {
      final solved = (aug[entry.value] & bBit) != 0;
      if (solved) {
        final j = entry.key;
        return Point(j ~/ _size, j % _size);
      }
    }
    return null; // already solved: no cell needs pressing.
  }

  void _showHint() {
    final hint = _solveHint();
    final message = hint == null
        ? lightsOutDefinition.helpText
        : 'Try toggling row ${hint.x + 1}, column ${hint.y + 1}.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tile Toggle · Level $_level'),
        actions: [
          ...gameActions(
            context: context,
            def: lightsOutDefinition,
            ctx: widget.ctx,
            onHint: _showHint,
            onRestart: _restartLevel,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Moves: $_moves',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Padding(
                  padding: const EdgeInsets.all(8),
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
                                      color: AppTheme.warning.withValues(
                                        alpha: 0.5,
                                      ),
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
