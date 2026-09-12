import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:topgames/app/theme.dart';
import 'package:topgames/core/game_level_context.dart';
import 'package:topgames/games/sudoku/sudoku_game.dart';

const int _side = 9;
const int _base = 3;

/// Replicates the private puzzle generation in `SudokuScreen.initState`
/// (same seed formula `2000 + level`, same call order: shuffle digits, band
/// order, row order per band, stack order, column order per stack, optional
/// transpose, then blank-count + shuffled positions) so this test can
/// compute the exact solution and blanked cells without reaching into
/// private state. If the in-game generation algorithm changes, update this
/// to match.
({List<List<int>> solution, List<List<int>> board, List<List<bool>> given})
_buildPuzzle(int level) {
  final rng = Random(2000 + level);
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
    grid = List.generate(_side, (r) => List.generate(_side, (c) => grid[c][r]));
  }

  final solution = grid;
  final blanks = (30 + ((level - 1) * 25 / 14)).round().clamp(30, 55);
  final positions = List.generate(_side * _side, (i) => i)..shuffle(rng);
  final board = [for (final row in solution) List<int>.from(row)];
  final given = List.generate(_side, (_) => List.filled(_side, true));
  for (var i = 0; i < blanks; i++) {
    final r = positions[i] ~/ _side;
    final c = positions[i] % _side;
    board[r][c] = 0;
    given[r][c] = false;
  }
  return (solution: solution, board: board, given: given);
}

void main() {
  testWidgets(
    'sudoku: filling every blank cell with the true solution digit solves the puzzle with 3 stars',
    (tester) async {
      const level = 1;
      final puzzle = _buildPuzzle(level);

      var completed = false;
      int? completedStars;

      await tester.pumpWidget(
        MaterialApp(
          home: SudokuScreen(
            ctx: GameLevelContext(
              gameId: 'sudoku',
              level: level,
              isEndless: false,
              onComplete: ({int stars = 0, int? score}) {
                completed = true;
                completedStars = stars;
              },
              onExit: () {},
            ),
          ),
        ),
      );

      for (var r = 0; r < _side; r++) {
        for (var c = 0; c < _side; c++) {
          if (puzzle.given[r][c]) continue;
          final digit = puzzle.solution[r][c];
          await tester.tap(find.byType(GestureDetector).at(r * _side + c));
          await tester.pump();
          await tester.tap(find.byType(InkWell).at(digit - 1));
          await tester.pump();
        }
      }
      // onComplete fires via a microtask on the final correct digit.
      await tester.pump();

      expect(
        completed,
        isTrue,
        reason: 'a fully correct solve must report completion',
      );
      expect(
        completedStars,
        3,
        reason: 'zero mistakes must earn the maximum star rating',
      );
    },
  );

  testWidgets(
    'sudoku: entering a digit that duplicates a value already in its row is flagged as a conflict and never completes the level',
    (tester) async {
      const level = 1;
      final puzzle = _buildPuzzle(level);

      // Find a row that has both a given cell and a blank cell so we can
      // place a duplicate of the given value into the blank cell.
      int? targetRow;
      int? blankCol;
      int? givenCol;
      for (var r = 0; r < _side && targetRow == null; r++) {
        int? blank;
        int? given;
        for (var c = 0; c < _side; c++) {
          if (puzzle.given[r][c]) {
            given ??= c;
          } else {
            blank ??= c;
          }
        }
        if (blank != null && given != null) {
          targetRow = r;
          blankCol = blank;
          givenCol = given;
        }
      }
      expect(
        targetRow,
        isNotNull,
        reason: 'expected at least one row with both a given and a blank cell',
      );

      final conflictingDigit = puzzle.solution[targetRow!][givenCol!];

      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: SudokuScreen(
            ctx: GameLevelContext(
              gameId: 'sudoku',
              level: level,
              isEndless: false,
              onComplete: ({int stars = 0, int? score}) => completed = true,
              onExit: () {},
            ),
          ),
        ),
      );

      await tester.tap(
        find.byType(GestureDetector).at(targetRow * _side + blankCol!),
      );
      await tester.pump();
      await tester.tap(find.byType(InkWell).at(conflictingDigit - 1));
      await tester.pump();

      // The entered digit duplicates a value already present in its row, so
      // it must render flagged as a conflict (danger color) rather than as
      // a normal, unresolved user entry.
      final cellText = tester.widget<Text>(
        find.descendant(
          of: find.byType(GestureDetector).at(targetRow * _side + blankCol),
          matching: find.text('$conflictingDigit'),
        ),
      );
      expect(cellText.style?.color, AppTheme.danger);
      expect(
        completed,
        isFalse,
        reason: 'a single conflicting entry must never report completion',
      );
    },
  );
}
