import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/game_definition.dart';
import '../../core/game_level_context.dart';
import '../../core/widgets/game_actions.dart';

/// Reference implementation: classic 9x9 Sudoku (public domain mechanic).
/// A full solved grid is built deterministically from a base pattern and a
/// sequence of validity-preserving permutations (digit relabelling, row/band
/// shuffles, column/stack shuffles, transpose), then cells are blanked out
/// to form the puzzle. 15 levels, blank count scales with difficulty.
final GameDefinition sudokuDefinition = GameDefinition(
  id: 'sudoku',
  title: 'Sudoku',
  tagline: 'Classic 9x9 number logic',
  icon: Icons.apps_rounded,
  tint: const GameTint(Color(0xFF60A5FA), Color(0xFF2563EB)),
  mode: GameMode.levels,
  levelCount: 15,
  helpText:
      'Tap a cell, then tap a number to fill it in. Fill the whole grid so '
      'every row, every column and every 3x3 box contains each digit 1-9 '
      'exactly once. Given (bold) numbers can\'t be changed — fewer mistakes '
      'earns more stars.',
  builder: (context, ctx) => SudokuScreen(ctx: ctx),
);

const int _side = 9;
const int _base = 3;

class SudokuScreen extends StatefulWidget {
  const SudokuScreen({super.key, required this.ctx});

  final GameLevelContext ctx;

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen> {
  late List<List<int>> _solution;
  late List<List<int>> _board;
  late List<List<bool>> _given;
  int? _selectedRow;
  int? _selectedCol;
  int _mistakes = 0;
  bool _finished = false;

  int get _level => widget.ctx.level;

  @override
  void initState() {
    super.initState();
    final rng = Random(2000 + _level);
    _solution = _generateSolved(rng);
    final blanks = (30 + ((_level - 1) * 25 / 14)).round().clamp(30, 55);
    final positions = List.generate(_side * _side, (i) => i)..shuffle(rng);
    _board = [for (final row in _solution) List<int>.from(row)];
    _given = List.generate(_side, (_) => List.filled(_side, true));
    for (var i = 0; i < blanks; i++) {
      final r = positions[i] ~/ _side;
      final c = positions[i] % _side;
      _board[r][c] = 0;
      _given[r][c] = false;
    }
  }

  /// Builds a full, valid solved 9x9 grid using the well-known base pattern
  /// plus a chain of permutations that always preserve Sudoku validity:
  /// digit relabelling, shuffling rows within a band (and band order),
  /// shuffling columns within a stack (and stack order), and transposing.
  List<List<int>> _generateSolved(Random rng) {
    var grid = List.generate(
      _side,
      (r) => List.generate(
        _side,
        (c) => (_base * (r % _base) + r ~/ _base + c) % _side + 1,
      ),
    );

    final digits = List.generate(_side, (i) => i + 1)..shuffle(rng);
    grid = grid.map((row) => row.map((v) => digits[v - 1]).toList()).toList();

    final bandOrder = [0, 1, 2]..shuffle(rng);
    final rowPerm = <int>[];
    for (final b in bandOrder) {
      final rowsInBand = [0, 1, 2]..shuffle(rng);
      for (final r in rowsInBand) {
        rowPerm.add(b * 3 + r);
      }
    }
    grid = [for (final idx in rowPerm) grid[idx]];

    final stackOrder = [0, 1, 2]..shuffle(rng);
    final colPerm = <int>[];
    for (final s in stackOrder) {
      final colsInStack = [0, 1, 2]..shuffle(rng);
      for (final c in colsInStack) {
        colPerm.add(s * 3 + c);
      }
    }
    grid = grid.map((row) => [for (final idx in colPerm) row[idx]]).toList();

    if (rng.nextBool()) {
      grid = List.generate(
        _side,
        (r) => List.generate(_side, (c) => grid[c][r]),
      );
    }

    return grid;
  }

  bool _conflictAt(int r, int c) {
    final v = _board[r][c];
    if (v == 0) return false;
    for (var i = 0; i < _side; i++) {
      if (i != c && _board[r][i] == v) return true;
      if (i != r && _board[i][c] == v) return true;
    }
    final boxRow = (r ~/ _base) * _base;
    final boxCol = (c ~/ _base) * _base;
    for (var br = boxRow; br < boxRow + _base; br++) {
      for (var bc = boxCol; bc < boxCol + _base; bc++) {
        if ((br != r || bc != c) && _board[br][bc] == v) return true;
      }
    }
    return false;
  }

  bool get _isComplete {
    for (var r = 0; r < _side; r++) {
      for (var c = 0; c < _side; c++) {
        if (_board[r][c] == 0) return false;
      }
    }
    return true;
  }

  bool get _hasAnyConflict {
    for (var r = 0; r < _side; r++) {
      for (var c = 0; c < _side; c++) {
        if (_conflictAt(r, c)) return true;
      }
    }
    return false;
  }

  void _selectCell(int r, int c) {
    if (_finished) return;
    setState(() {
      _selectedRow = r;
      _selectedCol = c;
    });
  }

  void _enterDigit(int digit) {
    if (_finished) return;
    final r = _selectedRow;
    final c = _selectedCol;
    if (r == null || c == null || _given[r][c]) return;
    setState(() {
      _board[r][c] = digit;
      if (digit != 0 && digit != _solution[r][c]) {
        _mistakes++;
      }
    });
    if (_isComplete && !_hasAnyConflict) {
      _finished = true;
      final stars = _mistakes == 0
          ? 3
          : _mistakes <= 3
          ? 2
          : 1;
      Future.microtask(() => widget.ctx.onComplete(stars: stars));
    }
  }

  void _erase() => _enterDigit(0);

  /// Fills in one currently-wrong (or blank) non-given cell with its true
  /// solution digit, routed through [_enterDigit] so it runs the exact same
  /// mistake-tracking / completion-check / `onComplete` path as a manual
  /// numpad tap — completing the puzzle purely via hints still finishes the
  /// level correctly.
  void _showHint() {
    for (var r = 0; r < _side; r++) {
      for (var c = 0; c < _side; c++) {
        if (_given[r][c]) continue;
        if (_board[r][c] != _solution[r][c]) {
          setState(() {
            _selectedRow = r;
            _selectedCol = c;
          });
          _enterDigit(_solution[r][c]);
          return;
        }
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Nothing left to hint — you're done!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Level $_level'),
        actions: [
          ...gameActions(
            context: context,
            def: sudokuDefinition,
            ctx: widget.ctx,
            onHint: _showHint,
          ),
          TextButton(
            onPressed: widget.ctx.onExit,
            child: const Text('Give up'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Mistakes: $_mistakes',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cellSize = constraints.maxWidth / _side;
                      final fontSize = (cellSize * 0.45).clamp(14.0, 26.0);
                      return Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceHigh,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.textSecondary,
                            width: 2,
                          ),
                        ),
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _side * _side,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: _side,
                              ),
                          itemBuilder: (context, index) {
                            final r = index ~/ _side;
                            final c = index % _side;
                            return _buildCell(r, c, fontSize);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildNumberPad(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Tap a cell, then pick a number. Fill the grid so every row, '
              'column and 3x3 box has 1-9.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCell(int r, int c, double fontSize) {
    final value = _board[r][c];
    final given = _given[r][c];
    final selected = r == _selectedRow && c == _selectedCol;
    final conflict = _conflictAt(r, c);

    Color bg = AppTheme.surfaceHigh;
    if (selected) {
      bg = AppTheme.accentSoft;
    } else if (r == _selectedRow || c == _selectedCol) {
      bg = AppTheme.surface;
    }

    Color textColor = AppTheme.textPrimary;
    if (conflict) {
      textColor = AppTheme.danger;
    } else if (given) {
      textColor = AppTheme.textPrimary;
    } else {
      textColor = AppTheme.accent;
    }

    return GestureDetector(
      onTap: () => _selectCell(r, c),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            top: BorderSide(
              color: AppTheme.textSecondary,
              width: r % _base == 0 ? 1.6 : 0.4,
            ),
            left: BorderSide(
              color: AppTheme.textSecondary,
              width: c % _base == 0 ? 1.6 : 0.4,
            ),
            right: BorderSide(
              color: AppTheme.textSecondary,
              width: c == _side - 1 ? 1.6 : 0.4,
            ),
            bottom: BorderSide(
              color: AppTheme.textSecondary,
              width: r == _side - 1 ? 1.6 : 0.4,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: value == 0
            ? null
            : Text(
                '$value',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: given ? FontWeight.w800 : FontWeight.w500,
                  color: textColor,
                ),
              ),
      ),
    );
  }

  Widget _buildNumberPad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (var d = 1; d <= 9; d++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _padButton(
                  child: Text('$d'),
                  onTap: () => _enterDigit(d),
                ),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _padButton(
                child: const Icon(Icons.backspace_outlined, size: 18),
                onTap: _erase,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _padButton({required Widget child, required VoidCallback onTap}) {
    return AspectRatio(
      aspectRatio: 1,
      child: Material(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Center(
            child: DefaultTextStyle(
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
