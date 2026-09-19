import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/game_definition.dart';
import '../../core/game_level_context.dart';
import '../../core/motion.dart';
import '../../core/progress_store.dart';
import '../../core/sound.dart';
import '../../core/widgets/game_actions.dart';
import '../../core/widgets/swipe_area.dart';

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
const List<SwipeDirection> _directions = [
  SwipeDirection.left,
  SwipeDirection.right,
  SwipeDirection.up,
  SwipeDirection.down,
];

/// A live tile on the board. Kept as its own identity-bearing object (not
/// just a value in a grid) so [AnimatedPositioned] can actually animate a
/// tile sliding from its old cell to its new one, keyed by [id] — Flutter's
/// implicit animations only interpolate a widget's position across
/// rebuilds when the *same* widget identity persists; keying by row/col
/// instead of a stable id would make every move look like tiles
/// teleporting in and out rather than sliding.
class _Tile {
  _Tile({
    required this.id,
    required this.row,
    required this.col,
    required this.value,
  });

  final int id;
  int row;
  int col;
  int value;

  /// True once this tile has been absorbed into another tile's merge this
  /// move. It's kept in the list (still rendered, slid to the survivor's
  /// destination cell) until the slide animation finishes, then removed —
  /// see [_Merge2048ScreenState._move]'s delayed cleanup.
  bool merged = false;
}

class Merge2048Screen extends StatefulWidget {
  const Merge2048Screen({super.key, required this.ctx});

  final GameLevelContext ctx;

  @override
  State<Merge2048Screen> createState() => _Merge2048ScreenState();
}

class _Merge2048ScreenState extends State<Merge2048Screen> {
  final List<_Tile> _tiles = [];
  final _rng = Random();
  int _nextId = 0;
  int _score = 0;
  bool _gameOver = false;

  /// True while a move's slide animation is still playing — blocks new
  /// moves and hints from reading/mutating a half-settled board.
  bool _animating = false;

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  /// Clears the board back to its just-started state (two freshly spawned
  /// tiles, score reset). Shared by [initState] and the "Restart level"
  /// action so there's one place that defines "a fresh game" — this game
  /// is endless, so restarting never touches the persisted best score.
  void _startNewGame() {
    _tiles.clear();
    _score = 0;
    _gameOver = false;
    _animating = false;
    _spawnTile();
    _spawnTile();
  }

  void _restart() {
    Sfx.tap();
    setState(_startNewGame);
  }

  List<Point<int>> _emptyCells() {
    final occupied = {
      for (final t in _tiles.where((t) => !t.merged)) Point(t.row, t.col),
    };
    return [
      for (var r = 0; r < _gridSize; r++)
        for (var c = 0; c < _gridSize; c++)
          if (!occupied.contains(Point(r, c))) Point(r, c),
    ];
  }

  void _spawnTile() {
    final empty = _emptyCells();
    if (empty.isEmpty) return;
    final p = empty[_rng.nextInt(empty.length)];
    _tiles.add(
      _Tile(
        id: _nextId++,
        row: p.x,
        col: p.y,
        value: _rng.nextDouble() < 0.9 ? 2 : 4,
      ),
    );
  }

  /// A plain value grid derived from the live tiles — used only by the
  /// pure simulation helpers below ([_movesAvailable], [_bestDirection]),
  /// which predate the tile-identity model and have no reason to know
  /// about it.
  List<List<int>> _boardSnapshot() {
    final grid = List.generate(_gridSize, (_) => List.filled(_gridSize, 0));
    for (final t in _tiles.where((t) => !t.merged)) {
      grid[t.row][t.col] = t.value;
    }
    return grid;
  }

  bool _movesAvailable() {
    final grid = _boardSnapshot();
    for (var r = 0; r < _gridSize; r++) {
      for (var c = 0; c < _gridSize; c++) {
        if (grid[r][c] == 0) return true;
        if (c + 1 < _gridSize && grid[r][c] == grid[r][c + 1]) return true;
        if (r + 1 < _gridSize && grid[r][c] == grid[r + 1][c]) return true;
      }
    }
    return false;
  }

  /// Compacts and merges a single line towards its start. Returns the
  /// merged line and the score gained, without touching any instance state
  /// — used only by the hint's what-if simulation ([_bestDirection]); the
  /// real move ([_move]) does its own tile-aware version of this so it can
  /// track identity/position for animation.
  (List<int>, int) _mergeLinePure(List<int> line) {
    final compact = line.where((v) => v != 0).toList();
    final result = <int>[];
    var gained = 0;
    var i = 0;
    while (i < compact.length) {
      if (i + 1 < compact.length && compact[i] == compact[i + 1]) {
        final merged = compact[i] * 2;
        result.add(merged);
        gained += merged;
        i += 2;
      } else {
        result.add(compact[i]);
        i += 1;
      }
    }
    while (result.length < _gridSize) {
      result.add(0);
    }
    return (result, gained);
  }

  /// Applies a direction to a scratch value grid. Used only by the hint to
  /// evaluate all four directions without touching real board state.
  (List<List<int>>, int) _simulateMove(List<List<int>> board, int dx, int dy) {
    final next = board.map((r) => List<int>.from(r)).toList();
    var gained = 0;
    if (dx == -1 || dx == 1) {
      for (var r = 0; r < _gridSize; r++) {
        var line = next[r];
        if (dx == 1) line = line.reversed.toList();
        final (merged, g) = _mergeLinePure(line);
        gained += g;
        next[r] = dx == 1 ? merged.reversed.toList() : merged;
      }
    } else {
      for (var c = 0; c < _gridSize; c++) {
        var line = [for (var r = 0; r < _gridSize; r++) next[r][c]];
        if (dy == 1) line = line.reversed.toList();
        final (merged, g) = _mergeLinePure(line);
        gained += g;
        final ordered = dy == 1 ? merged.reversed.toList() : merged;
        for (var r = 0; r < _gridSize; r++) {
          next[r][c] = ordered[r];
        }
      }
    }
    return (next, gained);
  }

  /// Slides every live tile one direction, merging equal adjacent pairs —
  /// tile-aware so each tile's new [_Tile.row]/[_Tile.col] can be animated
  /// to, rather than the board just snapping to new values in place. A
  /// merged-away tile slides into its survivor's destination cell (so they
  /// visually meet) and is only actually removed once that slide finishes.
  void _move(int dx, int dy) {
    if (_gameOver || _animating) return;
    final before = {for (final t in _tiles) t.id: (t.row, t.col)};
    var scoreGained = 0;

    void resolveLine(
      List<_Tile> line,
      bool reversed,
      void Function(_Tile, int) setDest,
    ) {
      final ordered = reversed ? line.reversed.toList() : line;
      var slot = 0;
      var i = 0;
      while (i < ordered.length) {
        final tile = ordered[i];
        setDest(tile, slot);
        if (i + 1 < ordered.length && ordered[i + 1].value == tile.value) {
          final other = ordered[i + 1];
          setDest(other, slot);
          tile.value *= 2;
          scoreGained += tile.value;
          other.merged = true;
          i += 2;
        } else {
          i += 1;
        }
        slot++;
      }
    }

    if (dx == -1 || dx == 1) {
      for (var r = 0; r < _gridSize; r++) {
        final line = _tiles.where((t) => t.row == r && !t.merged).toList()
          ..sort((a, b) => a.col.compareTo(b.col));
        resolveLine(line, dx == 1, (tile, slot) {
          tile.col = dx == 1 ? (_gridSize - 1 - slot) : slot;
        });
      }
    } else {
      for (var c = 0; c < _gridSize; c++) {
        final line = _tiles.where((t) => t.col == c && !t.merged).toList()
          ..sort((a, b) => a.row.compareTo(b.row));
        resolveLine(line, dy == 1, (tile, slot) {
          tile.row = dy == 1 ? (_gridSize - 1 - slot) : slot;
        });
      }
    }

    final changed =
        _tiles.any((t) => before[t.id] != (t.row, t.col)) ||
        _tiles.any((t) => t.merged);
    if (!changed) return;

    _score += scoreGained;
    _animating = true;
    setState(() {});

    Future.delayed(Motion.ms(150), () {
      if (!mounted) return;
      setState(() {
        _tiles.removeWhere((t) => t.merged);
        _spawnTile();
        _animating = false;
        if (!_movesAvailable()) {
          _gameOver = true;
          ProgressStore.instance.setBestScore(widget.ctx.gameId, _score);
          widget.ctx.onComplete(score: _score);
        }
      });
    });
  }

  void _onSwipe(SwipeDirection direction) {
    switch (direction) {
      case SwipeDirection.left:
        _move(-1, 0);
      case SwipeDirection.right:
        _move(1, 0);
      case SwipeDirection.up:
        _move(0, -1);
      case SwipeDirection.down:
        _move(0, 1);
    }
  }

  bool _boardsDiffer(List<List<int>> a, List<List<int>> b) {
    for (var r = 0; r < _gridSize; r++) {
      for (var c = 0; c < _gridSize; c++) {
        if (a[r][c] != b[r][c]) return true;
      }
    }
    return false;
  }

  /// A greedy one-ply hint: try all four directions on a scratch board and
  /// suggest whichever gains the most score (any direction that actually
  /// moves something, if none merge yet). Real endless-mode boards have no
  /// fixed target, so this is the best "correct move" a hint can mean here.
  SwipeDirection? _bestDirection() {
    final board = _boardSnapshot();
    SwipeDirection? best;
    var bestGain = -1;
    var bestMoved = false;
    for (final dir in _directions) {
      final (dx, dy) = switch (dir) {
        SwipeDirection.left => (-1, 0),
        SwipeDirection.right => (1, 0),
        SwipeDirection.up => (0, -1),
        SwipeDirection.down => (0, 1),
      };
      final (next, gained) = _simulateMove(board, dx, dy);
      final moved = _boardsDiffer(board, next);
      if (!moved) continue;
      if (gained > bestGain || (gained == bestGain && !bestMoved)) {
        best = dir;
        bestGain = gained;
        bestMoved = moved;
      }
    }
    return best;
  }

  void _showHint() {
    final direction = _bestDirection();
    final message = switch (direction) {
      SwipeDirection.left => 'Try swiping left.',
      SwipeDirection.right => 'Try swiping right.',
      SwipeDirection.up => 'Try swiping up.',
      SwipeDirection.down => 'Try swiping down.',
      null => 'No move available — the board is stuck.',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Color _tileColor(int value) {
    final colors = {
      2: Color(0xFF4B5580),
      4: Color(0xFF6C4FCB),
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
          ...gameActions(
            context: context,
            def: merge2048Definition,
            ctx: widget.ctx,
            onHint: _showHint,
            onRestart: _restart,
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
            child: SwipeArea(
              onSwipe: _onSwipe,
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final board = constraints.biggest.shortestSide.clamp(
                      240.0,
                      520.0,
                    );
                    const padding = 10.0;
                    const spacing = 8.0;
                    final inner = board - 2 * padding;
                    final cellSize =
                        (inner - (_gridSize - 1) * spacing) / _gridSize;
                    final cellUnit = cellSize + spacing;
                    final fontSize = (cellSize * 0.42).clamp(16.0, 30.0);

                    return Container(
                      padding: const EdgeInsets.all(padding),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceHigh,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      width: board,
                      height: board,
                      child: Stack(
                        key: const Key('mergeBoard'),
                        children: [
                          for (var r = 0; r < _gridSize; r++)
                            for (var c = 0; c < _gridSize; c++)
                              Positioned(
                                left: c * cellUnit,
                                top: r * cellUnit,
                                width: cellSize,
                                height: cellSize,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: AppTheme.surface,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                          for (final tile in _tiles)
                            AnimatedPositioned(
                              key: ValueKey(tile.id),
                              duration: Motion.ms(150),
                              curve: Curves.easeInOut,
                              left: tile.col * cellUnit,
                              top: tile.row * cellUnit,
                              width: cellSize,
                              height: cellSize,
                              child: _MergeTileView(
                                value: tile.value,
                                color: _tileColor(tile.value),
                                fontSize: fontSize,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Swipe anywhere to slide the board',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// One rendered tile. A brand-new instance (new [AnimatedPositioned] key
/// above) pops in via the [TweenAnimationBuilder]; an existing tile that's
/// just sliding or changing value keeps its element and doesn't replay it.
class _MergeTileView extends StatelessWidget {
  const _MergeTileView({
    required this.value,
    required this.color,
    required this.fontSize,
  });

  final int value;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: Motion.ms(150),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            '$value',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
