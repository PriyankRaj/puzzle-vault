import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/game_definition.dart';
import '../../core/game_level_context.dart';
import '../../core/motion.dart';
import '../../core/progress_store.dart';
import '../../core/sound.dart';
import '../../core/widgets/info_tip_button.dart';

/// Reference implementation: endless tile-merging strategy game, in the
/// spirit of the classic "2048" mechanic (swipe to merge equal tiles).
/// Original grid, code and assets — no third-party branding.
const String _merge2048HelpText =
    'Swipe up, down, left, or right to slide every tile in that direction. '
    'Two tiles with the same number merge into one with double the value. '
    'A new tile appears after each move. The board fills up over time — '
    'plan merges ahead so you always have somewhere to slide. Reach 2048 '
    'for the highest honors, or just chase a new best score.';

final GameDefinition merge2048Definition = GameDefinition(
  id: 'merge_2048',
  title: 'Number Merge',
  tagline: 'Slide and merge tiles to reach 2048',
  icon: Icons.grid_4x4_rounded,
  tint: const GameTint(Color(0xFFF5A623), Color(0xFFE8590C)),
  mode: GameMode.endless,
  helpText: _merge2048HelpText,
  builder: (context, ctx) => Merge2048Screen(ctx: ctx),
);

const int _gridSize = 4;

class Merge2048Screen extends StatefulWidget {
  const Merge2048Screen({super.key, required this.ctx});

  final GameLevelContext ctx;

  @override
  State<Merge2048Screen> createState() => _Merge2048ScreenState();
}

class _Merge2048ScreenState extends State<Merge2048Screen> {
  late List<List<int>> _board;
  final _rng = Random();
  int _score = 0;
  bool _gameOver = false;

  @override
  void initState() {
    super.initState();
    _board = List.generate(_gridSize, (_) => List.filled(_gridSize, 0));
    _spawnTile();
    _spawnTile();
  }

  void _spawnTile() {
    final empty = <Point<int>>[];
    for (var r = 0; r < _gridSize; r++) {
      for (var c = 0; c < _gridSize; c++) {
        if (_board[r][c] == 0) empty.add(Point(r, c));
      }
    }
    if (empty.isEmpty) return;
    final p = empty[_rng.nextInt(empty.length)];
    _board[p.x][p.y] = _rng.nextDouble() < 0.9 ? 2 : 4;
  }

  bool _movesAvailable() {
    for (var r = 0; r < _gridSize; r++) {
      for (var c = 0; c < _gridSize; c++) {
        if (_board[r][c] == 0) return true;
        if (c + 1 < _gridSize && _board[r][c] == _board[r][c + 1]) return true;
        if (r + 1 < _gridSize && _board[r][c] == _board[r + 1][c]) return true;
      }
    }
    return false;
  }

  /// Compacts and merges a single line towards its start, returns whether
  /// anything moved/merged.
  List<int> _mergeLine(List<int> line) {
    final compact = line.where((v) => v != 0).toList();
    final result = <int>[];
    var i = 0;
    while (i < compact.length) {
      if (i + 1 < compact.length && compact[i] == compact[i + 1]) {
        final merged = compact[i] * 2;
        result.add(merged);
        _score += merged;
        i += 2;
      } else {
        result.add(compact[i]);
        i += 1;
      }
    }
    while (result.length < _gridSize) {
      result.add(0);
    }
    return result;
  }

  void _move(int dx, int dy) {
    if (_gameOver) return;
    final before = _board.map((r) => List<int>.from(r)).toList();

    if (dx == -1 || dx == 1) {
      // horizontal
      for (var r = 0; r < _gridSize; r++) {
        var line = _board[r];
        if (dx == 1) line = line.reversed.toList();
        final merged = _mergeLine(line);
        _board[r] = dx == 1 ? merged.reversed.toList() : merged;
      }
    } else {
      // vertical
      for (var c = 0; c < _gridSize; c++) {
        var line = [for (var r = 0; r < _gridSize; r++) _board[r][c]];
        if (dy == 1) line = line.reversed.toList();
        final merged = _mergeLine(line);
        final ordered = dy == 1 ? merged.reversed.toList() : merged;
        for (var r = 0; r < _gridSize; r++) {
          _board[r][c] = ordered[r];
        }
      }
    }

    final changed = _boardsDiffer(before, _board);
    if (changed) {
      _spawnTile();
      if (!_movesAvailable()) {
        _gameOver = true;
        ProgressStore.instance.setBestScore(widget.ctx.gameId, _score);
        widget.ctx.onComplete(score: _score);
      }
    }
    setState(() {});
  }

  bool _boardsDiffer(List<List<int>> a, List<List<int>> b) {
    for (var r = 0; r < _gridSize; r++) {
      for (var c = 0; c < _gridSize; c++) {
        if (a[r][c] != b[r][c]) return true;
      }
    }
    return false;
  }

  Future<void> _confirmReset(BuildContext context) async {
    Sfx.tap();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset Number Merge?'),
          content: const Text(
            'This clears the best score for this game only. This cannot '
            'be undone.',
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

    await ProgressStore.instance.resetGame(widget.ctx.gameId);
    Sfx.success();
    if (!context.mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Number Merge progress has been reset')),
    );
  }

  Color _tileColor(int value) {
    final colors = {
      0: AppTheme.surface,
      2: Color(0xFF3A4166),
      4: Color(0xFF4A5285),
      8: Color(0xFFF5A623),
      16: Color(0xFFF08A24),
      32: Color(0xFFEB6F28),
      64: Color(0xFFE8590C),
      128: Color(0xFFE0C341),
      256: Color(0xFFE0B92E),
      512: Color(0xFFE0AC1B),
      1024: Color(0xFFE09F00),
      2048: Color(0xFF4ADE80),
    };
    return colors[value] ?? const Color(0xFF6C2BD9);
  }

  @override
  Widget build(BuildContext context) {
    final best = ProgressStore.instance.bestScore(widget.ctx.gameId);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Number Merge'),
        actions: [
          const InfoTipButton(
            title: 'Number Merge',
            helpText: _merge2048HelpText,
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded),
            tooltip: 'Reset progress',
            onPressed: () => _confirmReset(context),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('Best $best', style: const TextStyle(fontSize: 14)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Score: $_score',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: Center(
              child: GestureDetector(
                onHorizontalDragEnd: (details) {
                  final v = details.primaryVelocity ?? 0;
                  if (v.abs() < 100) return;
                  _move(v > 0 ? 1 : -1, 0);
                },
                onVerticalDragEnd: (details) {
                  final v = details.primaryVelocity ?? 0;
                  if (v.abs() < 100) return;
                  _move(0, v > 0 ? 1 : -1);
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceHigh,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  width: 340,
                  height: 340,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _gridSize * _gridSize,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _gridSize,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemBuilder: (context, index) {
                      final r = index ~/ _gridSize;
                      final c = index % _gridSize;
                      final value = _board[r][c];
                      return AnimatedContainer(
                        duration: Motion.ms(120),
                        decoration: BoxDecoration(
                          color: _tileColor(value),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: value == 0
                            ? null
                            : Text(
                                '$value',
                                style: TextStyle(
                                  fontSize: value > 512 ? 20 : 24,
                                  fontWeight: FontWeight.w800,
                                  color: value >= 8
                                      ? Colors.white
                                      : AppTheme.textPrimary,
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
              'Swipe to slide the board',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
