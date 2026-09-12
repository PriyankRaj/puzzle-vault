import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/game_definition.dart';
import '../../core/game_level_context.dart';

/// Reference implementation notes:
///
/// This is an original take on the generic, decades-old "Numberlink" style
/// puzzle genre (connect matching endpoint pairs on a grid with
/// non-crossing paths). Grid layouts, naming and rendering below are all
/// original; no third-party branding, art or text is reused.
final GameDefinition flowConnectDefinition = GameDefinition(
  id: 'flow_connect',
  title: 'Pipe Connect',
  tagline: 'Link every matching pair without crossing',
  icon: Icons.polyline_rounded,
  tint: const GameTint(Color(0xFF5EEAD4), Color(0xFF0F766E)),
  mode: GameMode.levels,
  levelCount: 15,
  helpText:
      'Drag from a colored dot to its matching dot to lay a pipe between '
      'them. Pipes must travel through adjacent cells and cannot cross or '
      'overlap another pipe. Connect every pair to clear the level — '
      'fewer restarts earns more stars.',
  builder: (context, ctx) => FlowConnectScreen(ctx: ctx),
);

/// Colors used to render each pair's pipe, cycled by pair index. Kept
/// distinct from the app's semantic success/warning/danger meaning by
/// simply reusing them as decorative hues here (no semantic use in this
/// game), plus three extra hardcoded hues for levels with more pairs.
List<Color> get _pipeColors => [
  AppTheme.accent,
  AppTheme.success,
  AppTheme.warning,
  AppTheme.danger,
  const Color(0xFFA78BFA), // purple
  const Color(0xFF22D3EE), // teal/cyan
  const Color(0xFFF472B6), // pink
];

/// One endpoint pair: [color] indexes into [_pipeColors], [a] and [b] are
/// the two grid cells (x = col, y = row) that must be connected.
class _Pair {
  const _Pair(this.color, this.a, this.b);
  final int color;
  final Point<int> a;
  final Point<int> b;

  Point<int>? other(Point<int> endpoint) {
    if (endpoint == a) return b;
    if (endpoint == b) return a;
    return null;
  }
}

/// One hand-authored puzzle: an NxN grid plus its endpoint pairs, and a
/// verified reference solution (one non-overlapping path per color,
/// together covering every cell) used purely to guarantee solvability
/// while authoring. Never shown to the player.
class _LevelData {
  const _LevelData({
    required this.size,
    required this.pairs,
    required this.solution,
  });

  final int size;
  final List<_Pair> pairs;
  final List<List<Point<int>>> solution;
}

// Level data below is generated from a Hamiltonian "snake" traversal of
// each grid, split into contiguous chunks (one per color). Because each
// chunk is a contiguous slice of a single non-repeating path over the
// grid, every chunk is automatically a valid adjacent, non-self-crossing
// path, and chunks are automatically disjoint from one another (and
// together cover the whole grid). This was verified programmatically
// before authoring (see level 1/8/15 spot checks) and guarantees, by
// construction, that every level below is solvable.
final List<_LevelData> _levels = [
  // Level 1: 5x5 grid, 3 pairs.
  _LevelData(
    size: 5,
    pairs: [
      _Pair(0, Point(0, 0), Point(1, 1)),
      _Pair(1, Point(0, 1), Point(3, 3)),
      _Pair(2, Point(2, 3), Point(4, 4)),
    ],
    solution: [
      [
        Point(0, 0),
        Point(1, 0),
        Point(2, 0),
        Point(3, 0),
        Point(4, 0),
        Point(4, 1),
        Point(3, 1),
        Point(2, 1),
        Point(1, 1),
      ],
      [
        Point(0, 1),
        Point(0, 2),
        Point(1, 2),
        Point(2, 2),
        Point(3, 2),
        Point(4, 2),
        Point(4, 3),
        Point(3, 3),
      ],
      [
        Point(2, 3),
        Point(1, 3),
        Point(0, 3),
        Point(0, 4),
        Point(1, 4),
        Point(2, 4),
        Point(3, 4),
        Point(4, 4),
      ],
    ],
  ),
  // Level 2: 5x5 grid, 3 pairs.
  _LevelData(
    size: 5,
    pairs: [
      _Pair(0, Point(0, 0), Point(1, 1)),
      _Pair(1, Point(1, 0), Point(3, 3)),
      _Pair(2, Point(3, 2), Point(4, 4)),
    ],
    solution: [
      [
        Point(0, 0),
        Point(0, 1),
        Point(0, 2),
        Point(0, 3),
        Point(0, 4),
        Point(1, 4),
        Point(1, 3),
        Point(1, 2),
        Point(1, 1),
      ],
      [
        Point(1, 0),
        Point(2, 0),
        Point(2, 1),
        Point(2, 2),
        Point(2, 3),
        Point(2, 4),
        Point(3, 4),
        Point(3, 3),
      ],
      [
        Point(3, 2),
        Point(3, 1),
        Point(3, 0),
        Point(4, 0),
        Point(4, 1),
        Point(4, 2),
        Point(4, 3),
        Point(4, 4),
      ],
    ],
  ),
  // Level 3: 5x5 grid, 4 pairs.
  _LevelData(
    size: 5,
    pairs: [
      _Pair(0, Point(0, 0), Point(3, 1)),
      _Pair(1, Point(2, 1), Point(2, 2)),
      _Pair(2, Point(3, 2), Point(1, 3)),
      _Pair(3, Point(0, 3), Point(4, 4)),
    ],
    solution: [
      [
        Point(0, 0),
        Point(1, 0),
        Point(2, 0),
        Point(3, 0),
        Point(4, 0),
        Point(4, 1),
        Point(3, 1),
      ],
      [
        Point(2, 1),
        Point(1, 1),
        Point(0, 1),
        Point(0, 2),
        Point(1, 2),
        Point(2, 2),
      ],
      [
        Point(3, 2),
        Point(4, 2),
        Point(4, 3),
        Point(3, 3),
        Point(2, 3),
        Point(1, 3),
      ],
      [
        Point(0, 3),
        Point(0, 4),
        Point(1, 4),
        Point(2, 4),
        Point(3, 4),
        Point(4, 4),
      ],
    ],
  ),
  // Level 4: 5x5 grid, 4 pairs.
  _LevelData(
    size: 5,
    pairs: [
      _Pair(0, Point(0, 0), Point(1, 3)),
      _Pair(1, Point(1, 2), Point(2, 2)),
      _Pair(2, Point(2, 3), Point(3, 1)),
      _Pair(3, Point(3, 0), Point(4, 4)),
    ],
    solution: [
      [
        Point(0, 0),
        Point(0, 1),
        Point(0, 2),
        Point(0, 3),
        Point(0, 4),
        Point(1, 4),
        Point(1, 3),
      ],
      [
        Point(1, 2),
        Point(1, 1),
        Point(1, 0),
        Point(2, 0),
        Point(2, 1),
        Point(2, 2),
      ],
      [
        Point(2, 3),
        Point(2, 4),
        Point(3, 4),
        Point(3, 3),
        Point(3, 2),
        Point(3, 1),
      ],
      [
        Point(3, 0),
        Point(4, 0),
        Point(4, 1),
        Point(4, 2),
        Point(4, 3),
        Point(4, 4),
      ],
    ],
  ),
  // Level 5: 6x6 grid, 4 pairs.
  _LevelData(
    size: 6,
    pairs: [
      _Pair(0, Point(0, 0), Point(3, 1)),
      _Pair(1, Point(2, 1), Point(5, 2)),
      _Pair(2, Point(5, 3), Point(2, 4)),
      _Pair(3, Point(3, 4), Point(0, 5)),
    ],
    solution: [
      [
        Point(0, 0),
        Point(1, 0),
        Point(2, 0),
        Point(3, 0),
        Point(4, 0),
        Point(5, 0),
        Point(5, 1),
        Point(4, 1),
        Point(3, 1),
      ],
      [
        Point(2, 1),
        Point(1, 1),
        Point(0, 1),
        Point(0, 2),
        Point(1, 2),
        Point(2, 2),
        Point(3, 2),
        Point(4, 2),
        Point(5, 2),
      ],
      [
        Point(5, 3),
        Point(4, 3),
        Point(3, 3),
        Point(2, 3),
        Point(1, 3),
        Point(0, 3),
        Point(0, 4),
        Point(1, 4),
        Point(2, 4),
      ],
      [
        Point(3, 4),
        Point(4, 4),
        Point(5, 4),
        Point(5, 5),
        Point(4, 5),
        Point(3, 5),
        Point(2, 5),
        Point(1, 5),
        Point(0, 5),
      ],
    ],
  ),
  // Level 6: 6x6 grid, 4 pairs.
  _LevelData(
    size: 6,
    pairs: [
      _Pair(0, Point(0, 0), Point(1, 3)),
      _Pair(1, Point(1, 2), Point(2, 5)),
      _Pair(2, Point(3, 5), Point(4, 2)),
      _Pair(3, Point(4, 3), Point(5, 0)),
    ],
    solution: [
      [
        Point(0, 0),
        Point(0, 1),
        Point(0, 2),
        Point(0, 3),
        Point(0, 4),
        Point(0, 5),
        Point(1, 5),
        Point(1, 4),
        Point(1, 3),
      ],
      [
        Point(1, 2),
        Point(1, 1),
        Point(1, 0),
        Point(2, 0),
        Point(2, 1),
        Point(2, 2),
        Point(2, 3),
        Point(2, 4),
        Point(2, 5),
      ],
      [
        Point(3, 5),
        Point(3, 4),
        Point(3, 3),
        Point(3, 2),
        Point(3, 1),
        Point(3, 0),
        Point(4, 0),
        Point(4, 1),
        Point(4, 2),
      ],
      [
        Point(4, 3),
        Point(4, 4),
        Point(4, 5),
        Point(5, 5),
        Point(5, 4),
        Point(5, 3),
        Point(5, 2),
        Point(5, 1),
        Point(5, 0),
      ],
    ],
  ),
  // Level 7: 6x6 grid, 5 pairs.
  _LevelData(
    size: 6,
    pairs: [
      _Pair(0, Point(0, 0), Point(4, 1)),
      _Pair(1, Point(3, 1), Point(2, 2)),
      _Pair(2, Point(3, 2), Point(2, 3)),
      _Pair(3, Point(1, 3), Point(4, 4)),
      _Pair(4, Point(5, 4), Point(0, 5)),
    ],
    solution: [
      [
        Point(0, 0),
        Point(1, 0),
        Point(2, 0),
        Point(3, 0),
        Point(4, 0),
        Point(5, 0),
        Point(5, 1),
        Point(4, 1),
      ],
      [
        Point(3, 1),
        Point(2, 1),
        Point(1, 1),
        Point(0, 1),
        Point(0, 2),
        Point(1, 2),
        Point(2, 2),
      ],
      [
        Point(3, 2),
        Point(4, 2),
        Point(5, 2),
        Point(5, 3),
        Point(4, 3),
        Point(3, 3),
        Point(2, 3),
      ],
      [
        Point(1, 3),
        Point(0, 3),
        Point(0, 4),
        Point(1, 4),
        Point(2, 4),
        Point(3, 4),
        Point(4, 4),
      ],
      [
        Point(5, 4),
        Point(5, 5),
        Point(4, 5),
        Point(3, 5),
        Point(2, 5),
        Point(1, 5),
        Point(0, 5),
      ],
    ],
  ),
  // Level 8: 6x6 grid, 5 pairs.
  _LevelData(
    size: 6,
    pairs: [
      _Pair(0, Point(0, 0), Point(1, 4)),
      _Pair(1, Point(1, 3), Point(2, 2)),
      _Pair(2, Point(2, 3), Point(3, 2)),
      _Pair(3, Point(3, 1), Point(4, 4)),
      _Pair(4, Point(4, 5), Point(5, 0)),
    ],
    solution: [
      [
        Point(0, 0),
        Point(0, 1),
        Point(0, 2),
        Point(0, 3),
        Point(0, 4),
        Point(0, 5),
        Point(1, 5),
        Point(1, 4),
      ],
      [
        Point(1, 3),
        Point(1, 2),
        Point(1, 1),
        Point(1, 0),
        Point(2, 0),
        Point(2, 1),
        Point(2, 2),
      ],
      [
        Point(2, 3),
        Point(2, 4),
        Point(2, 5),
        Point(3, 5),
        Point(3, 4),
        Point(3, 3),
        Point(3, 2),
      ],
      [
        Point(3, 1),
        Point(3, 0),
        Point(4, 0),
        Point(4, 1),
        Point(4, 2),
        Point(4, 3),
        Point(4, 4),
      ],
      [
        Point(4, 5),
        Point(5, 5),
        Point(5, 4),
        Point(5, 3),
        Point(5, 2),
        Point(5, 1),
        Point(5, 0),
      ],
    ],
  ),
  // Level 9: 7x7 grid, 5 pairs.
  _LevelData(
    size: 7,
    pairs: [
      _Pair(0, Point(0, 0), Point(4, 1)),
      _Pair(1, Point(3, 1), Point(5, 2)),
      _Pair(2, Point(6, 2), Point(1, 4)),
      _Pair(3, Point(2, 4), Point(2, 5)),
      _Pair(4, Point(1, 5), Point(6, 6)),
    ],
    solution: [
      [
        Point(0, 0),
        Point(1, 0),
        Point(2, 0),
        Point(3, 0),
        Point(4, 0),
        Point(5, 0),
        Point(6, 0),
        Point(6, 1),
        Point(5, 1),
        Point(4, 1),
      ],
      [
        Point(3, 1),
        Point(2, 1),
        Point(1, 1),
        Point(0, 1),
        Point(0, 2),
        Point(1, 2),
        Point(2, 2),
        Point(3, 2),
        Point(4, 2),
        Point(5, 2),
      ],
      [
        Point(6, 2),
        Point(6, 3),
        Point(5, 3),
        Point(4, 3),
        Point(3, 3),
        Point(2, 3),
        Point(1, 3),
        Point(0, 3),
        Point(0, 4),
        Point(1, 4),
      ],
      [
        Point(2, 4),
        Point(3, 4),
        Point(4, 4),
        Point(5, 4),
        Point(6, 4),
        Point(6, 5),
        Point(5, 5),
        Point(4, 5),
        Point(3, 5),
        Point(2, 5),
      ],
      [
        Point(1, 5),
        Point(0, 5),
        Point(0, 6),
        Point(1, 6),
        Point(2, 6),
        Point(3, 6),
        Point(4, 6),
        Point(5, 6),
        Point(6, 6),
      ],
    ],
  ),
  // Level 10: 7x7 grid, 5 pairs.
  _LevelData(
    size: 7,
    pairs: [
      _Pair(0, Point(0, 0), Point(1, 4)),
      _Pair(1, Point(1, 3), Point(2, 5)),
      _Pair(2, Point(2, 6), Point(4, 1)),
      _Pair(3, Point(4, 2), Point(5, 2)),
      _Pair(4, Point(5, 1), Point(6, 6)),
    ],
    solution: [
      [
        Point(0, 0),
        Point(0, 1),
        Point(0, 2),
        Point(0, 3),
        Point(0, 4),
        Point(0, 5),
        Point(0, 6),
        Point(1, 6),
        Point(1, 5),
        Point(1, 4),
      ],
      [
        Point(1, 3),
        Point(1, 2),
        Point(1, 1),
        Point(1, 0),
        Point(2, 0),
        Point(2, 1),
        Point(2, 2),
        Point(2, 3),
        Point(2, 4),
        Point(2, 5),
      ],
      [
        Point(2, 6),
        Point(3, 6),
        Point(3, 5),
        Point(3, 4),
        Point(3, 3),
        Point(3, 2),
        Point(3, 1),
        Point(3, 0),
        Point(4, 0),
        Point(4, 1),
      ],
      [
        Point(4, 2),
        Point(4, 3),
        Point(4, 4),
        Point(4, 5),
        Point(4, 6),
        Point(5, 6),
        Point(5, 5),
        Point(5, 4),
        Point(5, 3),
        Point(5, 2),
      ],
      [
        Point(5, 1),
        Point(5, 0),
        Point(6, 0),
        Point(6, 1),
        Point(6, 2),
        Point(6, 3),
        Point(6, 4),
        Point(6, 5),
        Point(6, 6),
      ],
    ],
  ),
  // Level 11: 7x7 grid, 6 pairs.
  _LevelData(
    size: 7,
    pairs: [
      _Pair(0, Point(0, 0), Point(5, 1)),
      _Pair(1, Point(4, 1), Point(2, 2)),
      _Pair(2, Point(3, 2), Point(3, 3)),
      _Pair(3, Point(2, 3), Point(4, 4)),
      _Pair(4, Point(5, 4), Point(1, 5)),
      _Pair(5, Point(0, 5), Point(6, 6)),
    ],
    solution: [
      [
        Point(0, 0),
        Point(1, 0),
        Point(2, 0),
        Point(3, 0),
        Point(4, 0),
        Point(5, 0),
        Point(6, 0),
        Point(6, 1),
        Point(5, 1),
      ],
      [
        Point(4, 1),
        Point(3, 1),
        Point(2, 1),
        Point(1, 1),
        Point(0, 1),
        Point(0, 2),
        Point(1, 2),
        Point(2, 2),
      ],
      [
        Point(3, 2),
        Point(4, 2),
        Point(5, 2),
        Point(6, 2),
        Point(6, 3),
        Point(5, 3),
        Point(4, 3),
        Point(3, 3),
      ],
      [
        Point(2, 3),
        Point(1, 3),
        Point(0, 3),
        Point(0, 4),
        Point(1, 4),
        Point(2, 4),
        Point(3, 4),
        Point(4, 4),
      ],
      [
        Point(5, 4),
        Point(6, 4),
        Point(6, 5),
        Point(5, 5),
        Point(4, 5),
        Point(3, 5),
        Point(2, 5),
        Point(1, 5),
      ],
      [
        Point(0, 5),
        Point(0, 6),
        Point(1, 6),
        Point(2, 6),
        Point(3, 6),
        Point(4, 6),
        Point(5, 6),
        Point(6, 6),
      ],
    ],
  ),
  // Level 12: 7x7 grid, 6 pairs.
  _LevelData(
    size: 7,
    pairs: [
      _Pair(0, Point(0, 0), Point(1, 5)),
      _Pair(1, Point(1, 4), Point(2, 2)),
      _Pair(2, Point(2, 3), Point(3, 3)),
      _Pair(3, Point(3, 2), Point(4, 4)),
      _Pair(4, Point(4, 5), Point(5, 1)),
      _Pair(5, Point(5, 0), Point(6, 6)),
    ],
    solution: [
      [
        Point(0, 0),
        Point(0, 1),
        Point(0, 2),
        Point(0, 3),
        Point(0, 4),
        Point(0, 5),
        Point(0, 6),
        Point(1, 6),
        Point(1, 5),
      ],
      [
        Point(1, 4),
        Point(1, 3),
        Point(1, 2),
        Point(1, 1),
        Point(1, 0),
        Point(2, 0),
        Point(2, 1),
        Point(2, 2),
      ],
      [
        Point(2, 3),
        Point(2, 4),
        Point(2, 5),
        Point(2, 6),
        Point(3, 6),
        Point(3, 5),
        Point(3, 4),
        Point(3, 3),
      ],
      [
        Point(3, 2),
        Point(3, 1),
        Point(3, 0),
        Point(4, 0),
        Point(4, 1),
        Point(4, 2),
        Point(4, 3),
        Point(4, 4),
      ],
      [
        Point(4, 5),
        Point(4, 6),
        Point(5, 6),
        Point(5, 5),
        Point(5, 4),
        Point(5, 3),
        Point(5, 2),
        Point(5, 1),
      ],
      [
        Point(5, 0),
        Point(6, 0),
        Point(6, 1),
        Point(6, 2),
        Point(6, 3),
        Point(6, 4),
        Point(6, 5),
        Point(6, 6),
      ],
    ],
  ),
  // Level 13: 8x8 grid, 6 pairs.
  _LevelData(
    size: 8,
    pairs: [
      _Pair(0, Point(0, 0), Point(5, 1)),
      _Pair(1, Point(4, 1), Point(5, 2)),
      _Pair(2, Point(6, 2), Point(0, 4)),
      _Pair(3, Point(1, 4), Point(4, 5)),
      _Pair(4, Point(3, 5), Point(5, 6)),
      _Pair(5, Point(6, 6), Point(0, 7)),
    ],
    solution: [
      [
        Point(0, 0),
        Point(1, 0),
        Point(2, 0),
        Point(3, 0),
        Point(4, 0),
        Point(5, 0),
        Point(6, 0),
        Point(7, 0),
        Point(7, 1),
        Point(6, 1),
        Point(5, 1),
      ],
      [
        Point(4, 1),
        Point(3, 1),
        Point(2, 1),
        Point(1, 1),
        Point(0, 1),
        Point(0, 2),
        Point(1, 2),
        Point(2, 2),
        Point(3, 2),
        Point(4, 2),
        Point(5, 2),
      ],
      [
        Point(6, 2),
        Point(7, 2),
        Point(7, 3),
        Point(6, 3),
        Point(5, 3),
        Point(4, 3),
        Point(3, 3),
        Point(2, 3),
        Point(1, 3),
        Point(0, 3),
        Point(0, 4),
      ],
      [
        Point(1, 4),
        Point(2, 4),
        Point(3, 4),
        Point(4, 4),
        Point(5, 4),
        Point(6, 4),
        Point(7, 4),
        Point(7, 5),
        Point(6, 5),
        Point(5, 5),
        Point(4, 5),
      ],
      [
        Point(3, 5),
        Point(2, 5),
        Point(1, 5),
        Point(0, 5),
        Point(0, 6),
        Point(1, 6),
        Point(2, 6),
        Point(3, 6),
        Point(4, 6),
        Point(5, 6),
      ],
      [
        Point(6, 6),
        Point(7, 6),
        Point(7, 7),
        Point(6, 7),
        Point(5, 7),
        Point(4, 7),
        Point(3, 7),
        Point(2, 7),
        Point(1, 7),
        Point(0, 7),
      ],
    ],
  ),
  // Level 14: 8x8 grid, 7 pairs.
  _LevelData(
    size: 8,
    pairs: [
      _Pair(0, Point(0, 0), Point(6, 1)),
      _Pair(1, Point(5, 1), Point(2, 2)),
      _Pair(2, Point(3, 2), Point(4, 3)),
      _Pair(3, Point(3, 3), Point(4, 4)),
      _Pair(4, Point(5, 4), Point(2, 5)),
      _Pair(5, Point(1, 5), Point(6, 6)),
      _Pair(6, Point(7, 6), Point(0, 7)),
    ],
    solution: [
      [
        Point(0, 0),
        Point(1, 0),
        Point(2, 0),
        Point(3, 0),
        Point(4, 0),
        Point(5, 0),
        Point(6, 0),
        Point(7, 0),
        Point(7, 1),
        Point(6, 1),
      ],
      [
        Point(5, 1),
        Point(4, 1),
        Point(3, 1),
        Point(2, 1),
        Point(1, 1),
        Point(0, 1),
        Point(0, 2),
        Point(1, 2),
        Point(2, 2),
      ],
      [
        Point(3, 2),
        Point(4, 2),
        Point(5, 2),
        Point(6, 2),
        Point(7, 2),
        Point(7, 3),
        Point(6, 3),
        Point(5, 3),
        Point(4, 3),
      ],
      [
        Point(3, 3),
        Point(2, 3),
        Point(1, 3),
        Point(0, 3),
        Point(0, 4),
        Point(1, 4),
        Point(2, 4),
        Point(3, 4),
        Point(4, 4),
      ],
      [
        Point(5, 4),
        Point(6, 4),
        Point(7, 4),
        Point(7, 5),
        Point(6, 5),
        Point(5, 5),
        Point(4, 5),
        Point(3, 5),
        Point(2, 5),
      ],
      [
        Point(1, 5),
        Point(0, 5),
        Point(0, 6),
        Point(1, 6),
        Point(2, 6),
        Point(3, 6),
        Point(4, 6),
        Point(5, 6),
        Point(6, 6),
      ],
      [
        Point(7, 6),
        Point(7, 7),
        Point(6, 7),
        Point(5, 7),
        Point(4, 7),
        Point(3, 7),
        Point(2, 7),
        Point(1, 7),
        Point(0, 7),
      ],
    ],
  ),
  // Level 15: 8x8 grid, 7 pairs.
  _LevelData(
    size: 8,
    pairs: [
      _Pair(0, Point(0, 0), Point(1, 6)),
      _Pair(1, Point(1, 5), Point(2, 2)),
      _Pair(2, Point(2, 3), Point(3, 4)),
      _Pair(3, Point(3, 3), Point(4, 4)),
      _Pair(4, Point(4, 5), Point(5, 2)),
      _Pair(5, Point(5, 1), Point(6, 6)),
      _Pair(6, Point(6, 7), Point(7, 0)),
    ],
    solution: [
      [
        Point(0, 0),
        Point(0, 1),
        Point(0, 2),
        Point(0, 3),
        Point(0, 4),
        Point(0, 5),
        Point(0, 6),
        Point(0, 7),
        Point(1, 7),
        Point(1, 6),
      ],
      [
        Point(1, 5),
        Point(1, 4),
        Point(1, 3),
        Point(1, 2),
        Point(1, 1),
        Point(1, 0),
        Point(2, 0),
        Point(2, 1),
        Point(2, 2),
      ],
      [
        Point(2, 3),
        Point(2, 4),
        Point(2, 5),
        Point(2, 6),
        Point(2, 7),
        Point(3, 7),
        Point(3, 6),
        Point(3, 5),
        Point(3, 4),
      ],
      [
        Point(3, 3),
        Point(3, 2),
        Point(3, 1),
        Point(3, 0),
        Point(4, 0),
        Point(4, 1),
        Point(4, 2),
        Point(4, 3),
        Point(4, 4),
      ],
      [
        Point(4, 5),
        Point(4, 6),
        Point(4, 7),
        Point(5, 7),
        Point(5, 6),
        Point(5, 5),
        Point(5, 4),
        Point(5, 3),
        Point(5, 2),
      ],
      [
        Point(5, 1),
        Point(5, 0),
        Point(6, 0),
        Point(6, 1),
        Point(6, 2),
        Point(6, 3),
        Point(6, 4),
        Point(6, 5),
        Point(6, 6),
      ],
      [
        Point(6, 7),
        Point(7, 7),
        Point(7, 6),
        Point(7, 5),
        Point(7, 4),
        Point(7, 3),
        Point(7, 2),
        Point(7, 1),
        Point(7, 0),
      ],
    ],
  ),
];

class FlowConnectScreen extends StatefulWidget {
  const FlowConnectScreen({super.key, required this.ctx});

  final GameLevelContext ctx;

  @override
  State<FlowConnectScreen> createState() => _FlowConnectScreenState();
}

class _FlowConnectScreenState extends State<FlowConnectScreen> {
  late _LevelData _data;

  /// color -> the ordered cells its current pipe occupies (may be a
  /// partial, in-progress pipe, or a completed one).
  final Map<int, List<Point<int>>> _pipes = {};

  /// cell -> color currently occupying it (across all pipes, active or
  /// completed). A cell can be claimed by at most one color at a time.
  final Map<Point<int>, int> _occupied = {};

  final Set<int> _completedColors = {};

  int? _activeColor;
  int _restarts = 0;
  bool _won = false;

  @override
  void initState() {
    super.initState();
    final index = (widget.ctx.level - 1).clamp(0, _levels.length - 1);
    _data = _levels[index];
  }

  int _colorAtEndpoint(Point<int> cell) {
    for (final pair in _data.pairs) {
      if (pair.a == cell || pair.b == cell) return pair.color;
    }
    return -1;
  }

  _Pair _pairForColor(int color) =>
      _data.pairs.firstWhere((p) => p.color == color);

  void _abandonActivePipe() {
    final color = _activeColor;
    if (color == null) return;
    final cells = _pipes.remove(color);
    if (cells != null) {
      for (final c in cells) {
        _occupied.remove(c);
      }
    }
    _activeColor = null;
  }

  Point<int>? _cellFromOffset(Offset local, double cellSize) {
    final gx = (local.dx / cellSize).floor();
    final gy = (local.dy / cellSize).floor();
    if (gx < 0 || gx >= _data.size || gy < 0 || gy >= _data.size) return null;
    return Point(gx, gy);
  }

  void _handlePanStart(Offset local, double cellSize) {
    if (_won) return;
    final cell = _cellFromOffset(local, cellSize);
    if (cell == null) return;

    final endpointColor = _colorAtEndpoint(cell);
    if (endpointColor == -1) return;
    if (_completedColors.contains(endpointColor)) return;

    // Starting a fresh drag from either endpoint of this color: drop any
    // previous incomplete pipe for this color and begin again from here.
    if (_activeColor != null && _activeColor != endpointColor) {
      _abandonActivePipe();
      setState(() => _restarts++);
    }
    setState(() {
      final old = _pipes.remove(endpointColor);
      if (old != null) {
        for (final c in old) {
          _occupied.remove(c);
        }
      }
      _activeColor = endpointColor;
      _pipes[endpointColor] = [cell];
      _occupied[cell] = endpointColor;
    });
  }

  void _handlePanUpdate(Offset local, double cellSize) {
    if (_won) return;
    final color = _activeColor;
    if (color == null) return;
    final cell = _cellFromOffset(local, cellSize);
    if (cell == null) return;

    final pipe = _pipes[color];
    if (pipe == null || pipe.isEmpty) return;
    final last = pipe.last;
    if (cell == last) return;

    // Forgiving drag-back undo: returning to the previous cell in the
    // pipe pops the last segment and frees that cell.
    if (pipe.length >= 2 && cell == pipe[pipe.length - 2]) {
      setState(() {
        pipe.removeLast();
        _occupied.remove(last);
      });
      return;
    }

    final isAdjacent = (cell.x - last.x).abs() + (cell.y - last.y).abs() == 1;
    if (!isAdjacent) return;
    if (pipe.contains(cell)) return;

    final occupant = _occupied[cell];
    if (occupant != null && occupant != color) return;

    setState(() {
      pipe.add(cell);
      _occupied[cell] = color;
    });

    final pair = _pairForColor(color);
    final target = pair.other(pipe.first);
    if (target != null && cell == target) {
      setState(() {
        _completedColors.add(color);
        _activeColor = null;
      });
      _maybeWin();
    }
  }

  void _handlePanEnd() {
    if (_won) return;
    final color = _activeColor;
    if (color == null) return;
    // Drag lifted without completing the pipe: clear it and free cells.
    _abandonActivePipe();
    setState(() => _restarts++);
  }

  void _clearAll() {
    if (_won) return;
    setState(() {
      final hadProgress = _pipes.isNotEmpty;
      _pipes.clear();
      _occupied.clear();
      _completedColors.clear();
      _activeColor = null;
      if (hadProgress) _restarts++;
    });
  }

  int _starsForRestarts() {
    if (_restarts <= 0) return 3;
    if (_restarts <= 2) return 2;
    return 1;
  }

  void _maybeWin() {
    if (_completedColors.length < _data.pairs.length) return;
    setState(() => _won = true);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      widget.ctx.onComplete(stars: _starsForRestarts());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Level ${widget.ctx.level}'),
        actions: [
          TextButton(
            onPressed: widget.ctx.onExit,
            child: const Text('Give up'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'Connected: ${_completedColors.length}/${_data.pairs.length}'
              '   Restarts: $_restarts',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = constraints.maxWidth;
                      final cellSize = size / _data.size;
                      return GestureDetector(
                        onPanStart: (d) =>
                            _handlePanStart(d.localPosition, cellSize),
                        onPanUpdate: (d) =>
                            _handlePanUpdate(d.localPosition, cellSize),
                        onPanEnd: (_) => _handlePanEnd(),
                        onPanCancel: _handlePanEnd,
                        child: CustomPaint(
                          size: Size(size, size),
                          painter: _FlowConnectPainter(
                            data: _data,
                            pipes: _pipes,
                            completedColors: _completedColors,
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
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: ElevatedButton(
              onPressed: _clearAll,
              child: const Text('Clear all'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Drag from a colored dot to its matching dot. Pipes cannot '
              'cross or overlap.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowConnectPainter extends CustomPainter {
  _FlowConnectPainter({
    required this.data,
    required this.pipes,
    required this.completedColors,
  });

  final _LevelData data;
  final Map<int, List<Point<int>>> pipes;
  final Set<int> completedColors;

  Color _colorFor(int index) => _pipeColors[index % _pipeColors.length];

  @override
  void paint(Canvas canvas, Size size) {
    final n = data.size;
    final cellSize = size.width / n;

    final boardRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect, const Radius.circular(16)),
      Paint()..color = AppTheme.surfaceHigh,
    );

    // Faint grid lines.
    final gridPaint = Paint()
      ..color = AppTheme.accentSoft.withValues(alpha: 0.2)
      ..strokeWidth = 1;
    for (var i = 0; i <= n; i++) {
      final x = i * cellSize;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      final y = i * cellSize;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    Offset centerOf(Point<int> cell) => Offset(
      cell.x * cellSize + cellSize / 2,
      cell.y * cellSize + cellSize / 2,
    );

    // Pipes (drawn first so endpoint dots render on top).
    for (final entry in pipes.entries) {
      final path = entry.value;
      if (path.length < 2) continue;
      final paint = Paint()
        ..color = _colorFor(entry.key)
        ..strokeWidth = cellSize * 0.28
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final uiPath = Path()
        ..moveTo(centerOf(path.first).dx, centerOf(path.first).dy);
      for (final cell in path.skip(1)) {
        final c = centerOf(cell);
        uiPath.lineTo(c.dx, c.dy);
      }
      canvas.drawPath(uiPath, paint);
    }

    // Endpoint dots.
    for (final pair in data.pairs) {
      final color = _colorFor(pair.color);
      final radius = cellSize * 0.32;
      final dotPaint = Paint()..color = color;
      canvas.drawCircle(centerOf(pair.a), radius, dotPaint);
      canvas.drawCircle(centerOf(pair.b), radius, dotPaint);
      if (completedColors.contains(pair.color)) {
        final ringPaint = Paint()
          ..color = AppTheme.textPrimary.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawCircle(centerOf(pair.a), radius + 2, ringPaint);
        canvas.drawCircle(centerOf(pair.b), radius + 2, ringPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FlowConnectPainter oldDelegate) {
    return oldDelegate.pipes != pipes ||
        oldDelegate.completedColors != completedColors;
  }
}
