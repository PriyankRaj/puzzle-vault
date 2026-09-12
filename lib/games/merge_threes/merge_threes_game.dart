import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/game_definition.dart';
import '../../core/game_level_context.dart';
import '../../core/motion.dart';
import '../../core/progress_store.dart';
import '../../core/sound.dart';
import '../../core/widgets/info_tip_button.dart';

/// Original endless tile game: "Triple Merge". Loosely inspired by the
/// generic "swipe to slide numbered tiles" mechanic family, but with a
/// deliberately different merge rule from the 2048 module in this app:
/// a lone `1` and a lone `2` sliding together merge into `3` (the only
/// base merge), and from `3` onward two equal tiles double as usual.
/// Bare `1`+`1` or `2`+`2` pairs never merge — they just sit adjacent,
/// blocking each other, the "Threes"-style twist that sets this apart
/// from a plain equal-pair merger. Original grid, code and assets — no
/// third-party branding.
const String _mergeThreesHelpText =
    'Swipe to slide every tile in that direction. A lone 1 sliding into a '
    'lone 2 merges into a 3 — that is the only way to make a 3. From 3 '
    'onward, two equal tiles merge by doubling, just like a classic merge '
    'game. Two bare 1s or two bare 2s do NOT merge — they just block each '
    'other, so save your 1s and 2s for pairing with the other value.';

final GameDefinition mergeThreesDefinition = GameDefinition(
  id: 'merge_threes',
  title: 'Sequence Merge',
  tagline: 'Slide 1s and 2s together to build up to big numbers',
  icon: Icons.filter_3_rounded,
  tint: const GameTint(Color(0xFF34D399), Color(0xFF065F46)),
  mode: GameMode.endless,
  levelCount: 1,
  helpText: _mergeThreesHelpText,
  builder: (context, ctx) => MergeThreesScreen(ctx: ctx),
);

const int _gridSize = 4;

class MergeThreesScreen extends StatefulWidget {
  const MergeThreesScreen({super.key, required this.ctx});

  final GameLevelContext ctx;

  @override
  State<MergeThreesScreen> createState() => _MergeThreesScreenState();
}

class _MergeThreesScreenState extends State<MergeThreesScreen> {
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

  int _randomSpawnValue() {
    final roll = _rng.nextDouble();
    if (roll < 0.45) return 1;
    if (roll < 0.90) return 2;
    return 3;
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
    _board[p.x][p.y] = _randomSpawnValue();
  }

  /// The one and only merge predicate for this game: a `1` next to a `2`
  /// becomes a `3` (the "make up the difference to 3" rule); any other
  /// equal pair with value `>= 3` doubles, exactly like the back half of
  /// a classic doubling game; bare `1`+`1` or `2`+`2` never merge.
  bool _canMerge(int a, int b) {
    if ((a == 1 && b == 2) || (a == 2 && b == 1)) return true;
    if (a == b && a >= 3) return true;
    return false;
  }

  int _mergedValue(int a, int b) {
    if ((a == 1 && b == 2) || (a == 2 && b == 1)) return 3;
    return a * 2;
  }

  bool _movesAvailable() {
    for (var r = 0; r < _gridSize; r++) {
      for (var c = 0; c < _gridSize; c++) {
        if (_board[r][c] == 0) return true;
        final v = _board[r][c];
        if (c + 1 < _gridSize && _canMerge(v, _board[r][c + 1])) return true;
        if (r + 1 < _gridSize && _canMerge(v, _board[r + 1][c])) return true;
      }
    }
    return false;
  }

  /// Compacts a single line towards its start, merging the first eligible
  /// adjacent pair found (per [_canMerge]) and leaving non-mergeable equal
  /// pairs (bare 1+1 or 2+2) sitting side by side, unmerged.
  List<int> _mergeLine(List<int> line) {
    final compact = line.where((v) => v != 0).toList();
    final result = <int>[];
    var i = 0;
    while (i < compact.length) {
      if (i + 1 < compact.length && _canMerge(compact[i], compact[i + 1])) {
        final merged = _mergedValue(compact[i], compact[i + 1]);
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
          title: const Text('Reset Sequence Merge?'),
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
      const SnackBar(content: Text('Sequence Merge progress has been reset')),
    );
  }

  Color _tileColor(int value) {
    final colors = {
      0: AppTheme.surface,
      1: const Color(0xFF3A4166),
      2: Color(0xFF4A5285),
      3: Color(0xFF34D399),
      6: Color(0xFF22C99B),
      12: Color(0xFF10B4A0),
      24: Color(0xFF0E9F9A),
      48: Color(0xFF0C8A94),
      96: Color(0xFF0A6F82),
      192: Color(0xFF0B5E86),
      384: Color(0xFF0B4E8A),
      768: Color(0xFF12397D),
      1536: Color(0xFF1F2B6E),
      3072: Color(0xFFF5A623),
    };
    return colors[value] ?? const Color(0xFF6C2BD9);
  }

  @override
  Widget build(BuildContext context) {
    final best = ProgressStore.instance.bestScore(widget.ctx.gameId);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sequence Merge'),
        actions: [
          const InfoTipButton(
            title: 'Sequence Merge',
            helpText: _mergeThreesHelpText,
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
                                  color: value >= 6
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
