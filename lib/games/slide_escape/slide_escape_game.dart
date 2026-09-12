import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/game_definition.dart';
import '../../core/game_level_context.dart';
import '../../core/motion.dart';
import '../../core/widgets/game_actions.dart';

/// Original puzzle: a grid holds several rectangular blocks. Every block is
/// restricted to a single axis — horizontal blocks only slide left/right,
/// vertical blocks only slide up/down — and a block always stops the moment
/// it would leave the grid or overlap another block. One block is the
/// TARGET; the player's job is to slide the other blocks out of the way
/// until the target can reach the exit on the grid's edge. This "sliding
/// block escape" mechanic is a decades-old generic puzzle genre with many
/// independent implementations (not owned by any single app); every grid
/// layout, name and pixel of rendering below is an original creation for
/// this app.
final GameDefinition slideEscapeDefinition = GameDefinition(
  id: 'slide_escape',
  title: 'Slide Escape',
  tagline: 'Slide blocks aside to free the exit path',
  icon: Icons.swap_horiz_rounded,
  tint: const GameTint(Color(0xFF60A5FA), Color(0xFF1E3A8A)),
  mode: GameMode.levels,
  levelCount: 15,
  helpText:
      'Every block can only slide along its own axis — horizontal blocks '
      'move left/right, vertical blocks move up/down — and stops the '
      'moment it hits the grid edge or another block. Drag blocks out of '
      'the way to clear a path for the highlighted target block to reach '
      'the exit arrow. Fewer moves earns more stars.',
  builder: (context, ctx) => SlideEscapeScreen(ctx: ctx),
);

enum _Axis { horizontal, vertical }

typedef _Cell = (int, int);

/// One rectangular piece on the board, described by its top-left cell and
/// length along its fixed [axis]. [isTarget] marks the single piece that
/// must reach the exit. Every level below only ever gives the target
/// [_Axis.horizontal] with the exit on the right edge of its row, which
/// keeps both the win check and the exit-arrow rendering simple.
class _BlockSpec {
  const _BlockSpec({
    required this.id,
    required this.axis,
    required this.length,
    required this.row,
    required this.col,
    this.isTarget = false,
  });

  final String id;
  final _Axis axis;
  final int length;
  final int row;
  final int col;
  final bool isTarget;
}

/// A single recorded move in a verified solution: slide block [blockId] one
/// full step in [delta] direction (+1 or -1) along its own axis, going as
/// far as it will legally go (a "maximal slide" — exactly what a drag-to-
/// release gesture produces in this game).
typedef _Move = ({String blockId, int delta});

/// One hand-authored level. [verifiedSolution] is a full, working move
/// sequence that was computed by simulating this exact game's movement rule
/// (slide a block as far as it can legally go in one direction, stopping at
/// the grid edge or the first blocking block) against the level's starting
/// [blocks], step by step, confirming no two blocks ever overlap and the
/// target's trailing cell reaches column `cols - 1` on the final move. Its
/// length is the "par" move count used for star scoring.
class _LevelSpec {
  const _LevelSpec({
    required this.rows,
    required this.cols,
    required this.blocks,
    required this.verifiedSolution,
  });

  final int rows;
  final int cols;
  final List<_BlockSpec> blocks;
  final List<_Move> verifiedSolution;
}

/// 15 hand-authored boards, growing from a 6x6 board with 4 blocks up to a
/// 7x7 board with 12 blocks. Every board and its [_LevelSpec.verifiedSolution]
/// below was produced together by tracing legal maximal slides against the
/// level's own occupancy grid (built from [_BlockSpec.row]/[_BlockSpec.col]),
/// confirming each recorded move is legal and the sequence ends with the
/// target's trailing cell at the last column.
const List<_LevelSpec> _levels = [
  // Level 1 — 6x6, 4 blocks. Solve in 2 moves.
  _LevelSpec(
    rows: 6,
    cols: 6,
    blocks: [
      _BlockSpec(
        id: 'T',
        axis: _Axis.horizontal,
        length: 2,
        row: 4,
        col: 0,
        isTarget: true,
      ),
      _BlockSpec(id: 'A', axis: _Axis.vertical, length: 2, row: 3, col: 3),
      _BlockSpec(id: 'B', axis: _Axis.horizontal, length: 2, row: 0, col: 3),
      _BlockSpec(id: 'C', axis: _Axis.vertical, length: 3, row: 0, col: 5),
    ],
    verifiedSolution: [(blockId: 'A', delta: -1), (blockId: 'T', delta: 1)],
  ),
  // Level 2 — 6x6, 5 blocks. Solve in 3 moves.
  _LevelSpec(
    rows: 6,
    cols: 6,
    blocks: [
      _BlockSpec(
        id: 'T',
        axis: _Axis.horizontal,
        length: 2,
        row: 0,
        col: 0,
        isTarget: true,
      ),
      _BlockSpec(id: 'A', axis: _Axis.vertical, length: 2, row: 2, col: 2),
      _BlockSpec(id: 'B', axis: _Axis.vertical, length: 3, row: 3, col: 5),
      _BlockSpec(id: 'C', axis: _Axis.vertical, length: 3, row: 3, col: 4),
      _BlockSpec(id: 'D', axis: _Axis.vertical, length: 2, row: 0, col: 2),
    ],
    verifiedSolution: [
      (blockId: 'A', delta: 1),
      (blockId: 'D', delta: 1),
      (blockId: 'T', delta: 1),
    ],
  ),
  // Level 3 — 6x6, 5 blocks. Solve in 3 moves.
  _LevelSpec(
    rows: 6,
    cols: 6,
    blocks: [
      _BlockSpec(
        id: 'T',
        axis: _Axis.horizontal,
        length: 2,
        row: 4,
        col: 1,
        isTarget: true,
      ),
      _BlockSpec(id: 'A', axis: _Axis.vertical, length: 3, row: 3, col: 5),
      _BlockSpec(id: 'B', axis: _Axis.horizontal, length: 3, row: 0, col: 3),
      _BlockSpec(id: 'C', axis: _Axis.vertical, length: 3, row: 1, col: 1),
      _BlockSpec(id: 'D', axis: _Axis.vertical, length: 3, row: 3, col: 3),
    ],
    verifiedSolution: [
      (blockId: 'A', delta: -1),
      (blockId: 'D', delta: -1),
      (blockId: 'T', delta: 1),
    ],
  ),
  // Level 4 — 6x6, 6 blocks. Solve in 4 moves.
  _LevelSpec(
    rows: 6,
    cols: 6,
    blocks: [
      _BlockSpec(
        id: 'T',
        axis: _Axis.horizontal,
        length: 2,
        row: 2,
        col: 0,
        isTarget: true,
      ),
      _BlockSpec(id: 'A', axis: _Axis.vertical, length: 3, row: 1, col: 3),
      _BlockSpec(id: 'B', axis: _Axis.horizontal, length: 3, row: 5, col: 3),
      _BlockSpec(id: 'C', axis: _Axis.horizontal, length: 2, row: 3, col: 1),
      _BlockSpec(id: 'D', axis: _Axis.horizontal, length: 2, row: 4, col: 1),
      _BlockSpec(id: 'E', axis: _Axis.vertical, length: 3, row: 0, col: 5),
    ],
    verifiedSolution: [
      (blockId: 'B', delta: -1),
      (blockId: 'A', delta: 1),
      (blockId: 'E', delta: 1),
      (blockId: 'T', delta: 1),
    ],
  ),
  // Level 5 — 6x6, 6 blocks. Solve in 4 moves.
  _LevelSpec(
    rows: 6,
    cols: 6,
    blocks: [
      _BlockSpec(
        id: 'T',
        axis: _Axis.horizontal,
        length: 2,
        row: 1,
        col: 0,
        isTarget: true,
      ),
      _BlockSpec(id: 'A', axis: _Axis.vertical, length: 2, row: 1, col: 3),
      _BlockSpec(id: 'B', axis: _Axis.horizontal, length: 3, row: 3, col: 3),
      _BlockSpec(id: 'C', axis: _Axis.vertical, length: 2, row: 2, col: 2),
      _BlockSpec(id: 'D', axis: _Axis.vertical, length: 2, row: 4, col: 4),
      _BlockSpec(id: 'E', axis: _Axis.horizontal, length: 2, row: 2, col: 4),
    ],
    verifiedSolution: [
      (blockId: 'C', delta: 1),
      (blockId: 'B', delta: -1),
      (blockId: 'A', delta: 1),
      (blockId: 'T', delta: 1),
    ],
  ),
  // Level 6 — 6x6, 7 blocks. Solve in 5 moves.
  _LevelSpec(
    rows: 6,
    cols: 6,
    blocks: [
      _BlockSpec(
        id: 'T',
        axis: _Axis.horizontal,
        length: 2,
        row: 2,
        col: 0,
        isTarget: true,
      ),
      _BlockSpec(id: 'A', axis: _Axis.vertical, length: 3, row: 0, col: 3),
      _BlockSpec(id: 'B', axis: _Axis.horizontal, length: 2, row: 0, col: 1),
      _BlockSpec(id: 'C', axis: _Axis.horizontal, length: 2, row: 4, col: 3),
      _BlockSpec(id: 'D', axis: _Axis.horizontal, length: 2, row: 3, col: 0),
      _BlockSpec(id: 'E', axis: _Axis.vertical, length: 3, row: 1, col: 4),
      _BlockSpec(id: 'F', axis: _Axis.horizontal, length: 2, row: 5, col: 2),
    ],
    verifiedSolution: [
      (blockId: 'C', delta: -1),
      (blockId: 'E', delta: 1),
      (blockId: 'F', delta: -1),
      (blockId: 'A', delta: 1),
      (blockId: 'T', delta: 1),
    ],
  ),
  // Level 7 — 6x6, 7 blocks. Solve in 6 moves.
  _LevelSpec(
    rows: 6,
    cols: 6,
    blocks: [
      _BlockSpec(
        id: 'T',
        axis: _Axis.horizontal,
        length: 2,
        row: 3,
        col: 0,
        isTarget: true,
      ),
      _BlockSpec(id: 'A', axis: _Axis.horizontal, length: 2, row: 4, col: 1),
      _BlockSpec(id: 'B', axis: _Axis.horizontal, length: 3, row: 1, col: 2),
      _BlockSpec(id: 'C', axis: _Axis.vertical, length: 3, row: 0, col: 5),
      _BlockSpec(id: 'D', axis: _Axis.vertical, length: 3, row: 2, col: 3),
      _BlockSpec(id: 'E', axis: _Axis.vertical, length: 2, row: 0, col: 0),
      _BlockSpec(id: 'F', axis: _Axis.vertical, length: 2, row: 2, col: 4),
    ],
    verifiedSolution: [
      (blockId: 'T', delta: 1),
      (blockId: 'E', delta: 1),
      (blockId: 'B', delta: -1),
      (blockId: 'D', delta: -1),
      (blockId: 'F', delta: 1),
      (blockId: 'T', delta: 1),
    ],
  ),
  // Level 8 — 6x6, 8 blocks. Solve in 5 moves.
  _LevelSpec(
    rows: 6,
    cols: 6,
    blocks: [
      _BlockSpec(
        id: 'T',
        axis: _Axis.horizontal,
        length: 2,
        row: 1,
        col: 2,
        isTarget: true,
      ),
      _BlockSpec(id: 'A', axis: _Axis.vertical, length: 3, row: 0, col: 5),
      _BlockSpec(id: 'B', axis: _Axis.vertical, length: 2, row: 2, col: 2),
      _BlockSpec(id: 'C', axis: _Axis.horizontal, length: 3, row: 0, col: 1),
      _BlockSpec(id: 'D', axis: _Axis.horizontal, length: 2, row: 3, col: 3),
      _BlockSpec(id: 'E', axis: _Axis.vertical, length: 2, row: 0, col: 4),
      _BlockSpec(id: 'F', axis: _Axis.vertical, length: 2, row: 4, col: 0),
      _BlockSpec(id: 'G', axis: _Axis.vertical, length: 3, row: 1, col: 0),
    ],
    verifiedSolution: [
      (blockId: 'A', delta: 1),
      (blockId: 'B', delta: 1),
      (blockId: 'D', delta: -1),
      (blockId: 'E', delta: 1),
      (blockId: 'T', delta: 1),
    ],
  ),
  // Level 9 — 6x6, 8 blocks. Solve in 6 moves.
  _LevelSpec(
    rows: 6,
    cols: 6,
    blocks: [
      _BlockSpec(
        id: 'T',
        axis: _Axis.horizontal,
        length: 2,
        row: 1,
        col: 2,
        isTarget: true,
      ),
      _BlockSpec(id: 'A', axis: _Axis.horizontal, length: 3, row: 4, col: 2),
      _BlockSpec(id: 'B', axis: _Axis.vertical, length: 2, row: 0, col: 5),
      _BlockSpec(id: 'C', axis: _Axis.horizontal, length: 3, row: 5, col: 0),
      _BlockSpec(id: 'D', axis: _Axis.vertical, length: 3, row: 2, col: 1),
      _BlockSpec(id: 'E', axis: _Axis.horizontal, length: 2, row: 0, col: 0),
      _BlockSpec(id: 'F', axis: _Axis.vertical, length: 2, row: 2, col: 3),
      _BlockSpec(id: 'G', axis: _Axis.horizontal, length: 2, row: 2, col: 4),
    ],
    verifiedSolution: [
      (blockId: 'D', delta: -1),
      (blockId: 'A', delta: -1),
      (blockId: 'F', delta: 1),
      (blockId: 'G', delta: -1),
      (blockId: 'B', delta: 1),
      (blockId: 'T', delta: 1),
    ],
  ),
  // Level 10 — first 7x7 board, 9 blocks. Solve in 6 moves.
  _LevelSpec(
    rows: 7,
    cols: 7,
    blocks: [
      _BlockSpec(
        id: 'T',
        axis: _Axis.horizontal,
        length: 2,
        row: 1,
        col: 2,
        isTarget: true,
      ),
      _BlockSpec(id: 'A', axis: _Axis.horizontal, length: 2, row: 2, col: 0),
      _BlockSpec(id: 'B', axis: _Axis.vertical, length: 2, row: 0, col: 4),
      _BlockSpec(id: 'C', axis: _Axis.horizontal, length: 2, row: 5, col: 4),
      _BlockSpec(id: 'D', axis: _Axis.vertical, length: 2, row: 4, col: 2),
      _BlockSpec(id: 'E', axis: _Axis.vertical, length: 3, row: 1, col: 5),
      _BlockSpec(id: 'F', axis: _Axis.horizontal, length: 2, row: 2, col: 3),
      _BlockSpec(id: 'G', axis: _Axis.vertical, length: 2, row: 5, col: 1),
      _BlockSpec(id: 'H', axis: _Axis.vertical, length: 2, row: 3, col: 4),
    ],
    verifiedSolution: [
      (blockId: 'C', delta: 1),
      (blockId: 'E', delta: 1),
      (blockId: 'F', delta: -1),
      (blockId: 'H', delta: 1),
      (blockId: 'B', delta: 1),
      (blockId: 'T', delta: 1),
    ],
  ),
  // Level 11 — 7x7, 9 blocks. Solve in 8 moves.
  _LevelSpec(
    rows: 7,
    cols: 7,
    blocks: [
      _BlockSpec(
        id: 'T',
        axis: _Axis.horizontal,
        length: 2,
        row: 1,
        col: 4,
        isTarget: true,
      ),
      _BlockSpec(id: 'A', axis: _Axis.horizontal, length: 2, row: 5, col: 5),
      _BlockSpec(id: 'B', axis: _Axis.horizontal, length: 2, row: 2, col: 3),
      _BlockSpec(id: 'C', axis: _Axis.vertical, length: 3, row: 0, col: 6),
      _BlockSpec(id: 'D', axis: _Axis.horizontal, length: 2, row: 3, col: 5),
      _BlockSpec(id: 'E', axis: _Axis.vertical, length: 2, row: 5, col: 4),
      _BlockSpec(id: 'F', axis: _Axis.vertical, length: 2, row: 3, col: 4),
      _BlockSpec(id: 'G', axis: _Axis.vertical, length: 2, row: 5, col: 2),
      _BlockSpec(id: 'H', axis: _Axis.horizontal, length: 2, row: 1, col: 1),
    ],
    verifiedSolution: [
      (blockId: 'B', delta: -1),
      (blockId: 'H', delta: -1),
      (blockId: 'T', delta: -1),
      (blockId: 'F', delta: -1),
      (blockId: 'D', delta: -1),
      (blockId: 'C', delta: 1),
      (blockId: 'F', delta: 1),
      (blockId: 'T', delta: 1),
    ],
  ),
  // Level 12 — 7x7, 10 blocks. Solve in 7 moves.
  _LevelSpec(
    rows: 7,
    cols: 7,
    blocks: [
      _BlockSpec(
        id: 'T',
        axis: _Axis.horizontal,
        length: 3,
        row: 3,
        col: 2,
        isTarget: true,
      ),
      _BlockSpec(id: 'A', axis: _Axis.vertical, length: 2, row: 5, col: 3),
      _BlockSpec(id: 'B', axis: _Axis.horizontal, length: 2, row: 5, col: 4),
      _BlockSpec(id: 'C', axis: _Axis.vertical, length: 3, row: 0, col: 0),
      _BlockSpec(id: 'D', axis: _Axis.horizontal, length: 2, row: 0, col: 5),
      _BlockSpec(id: 'E', axis: _Axis.vertical, length: 3, row: 1, col: 5),
      _BlockSpec(id: 'F', axis: _Axis.vertical, length: 2, row: 5, col: 2),
      _BlockSpec(id: 'G', axis: _Axis.vertical, length: 3, row: 0, col: 3),
      _BlockSpec(id: 'H', axis: _Axis.horizontal, length: 2, row: 6, col: 0),
      _BlockSpec(id: 'I', axis: _Axis.vertical, length: 2, row: 2, col: 6),
    ],
    verifiedSolution: [
      (blockId: 'T', delta: -1),
      (blockId: 'G', delta: 1),
      (blockId: 'D', delta: -1),
      (blockId: 'E', delta: -1),
      (blockId: 'G', delta: -1),
      (blockId: 'I', delta: 1),
      (blockId: 'T', delta: 1),
    ],
  ),
  // Level 13 — 7x7, 11 blocks. Solve in 8 moves.
  _LevelSpec(
    rows: 7,
    cols: 7,
    blocks: [
      _BlockSpec(
        id: 'T',
        axis: _Axis.horizontal,
        length: 2,
        row: 4,
        col: 3,
        isTarget: true,
      ),
      _BlockSpec(id: 'A', axis: _Axis.vertical, length: 2, row: 5, col: 0),
      _BlockSpec(id: 'B', axis: _Axis.vertical, length: 3, row: 3, col: 6),
      _BlockSpec(id: 'C', axis: _Axis.vertical, length: 2, row: 1, col: 1),
      _BlockSpec(id: 'D', axis: _Axis.vertical, length: 2, row: 3, col: 1),
      _BlockSpec(id: 'E', axis: _Axis.horizontal, length: 3, row: 1, col: 4),
      _BlockSpec(id: 'F', axis: _Axis.vertical, length: 2, row: 5, col: 4),
      _BlockSpec(id: 'G', axis: _Axis.horizontal, length: 2, row: 5, col: 1),
      _BlockSpec(id: 'H', axis: _Axis.horizontal, length: 3, row: 3, col: 3),
      _BlockSpec(id: 'I', axis: _Axis.vertical, length: 2, row: 3, col: 0),
      _BlockSpec(id: 'J', axis: _Axis.vertical, length: 2, row: 0, col: 3),
    ],
    verifiedSolution: [
      (blockId: 'T', delta: 1),
      (blockId: 'B', delta: 1),
      (blockId: 'H', delta: 1),
      (blockId: 'J', delta: 1),
      (blockId: 'E', delta: -1),
      (blockId: 'H', delta: -1),
      (blockId: 'B', delta: -1),
      (blockId: 'T', delta: 1),
    ],
  ),
  // Level 14 — 7x7, 12 blocks. Solve in 9 moves.
  _LevelSpec(
    rows: 7,
    cols: 7,
    blocks: [
      _BlockSpec(
        id: 'T',
        axis: _Axis.horizontal,
        length: 2,
        row: 1,
        col: 0,
        isTarget: true,
      ),
      _BlockSpec(id: 'A', axis: _Axis.vertical, length: 2, row: 0, col: 4),
      _BlockSpec(id: 'B', axis: _Axis.horizontal, length: 2, row: 4, col: 3),
      _BlockSpec(id: 'C', axis: _Axis.horizontal, length: 2, row: 3, col: 3),
      _BlockSpec(id: 'D', axis: _Axis.horizontal, length: 2, row: 4, col: 5),
      _BlockSpec(id: 'E', axis: _Axis.horizontal, length: 2, row: 4, col: 1),
      _BlockSpec(id: 'F', axis: _Axis.vertical, length: 3, row: 1, col: 6),
      _BlockSpec(id: 'G', axis: _Axis.horizontal, length: 2, row: 5, col: 2),
      _BlockSpec(id: 'H', axis: _Axis.vertical, length: 2, row: 5, col: 5),
      _BlockSpec(id: 'I', axis: _Axis.vertical, length: 2, row: 1, col: 5),
      _BlockSpec(id: 'J', axis: _Axis.horizontal, length: 2, row: 2, col: 3),
      _BlockSpec(id: 'K', axis: _Axis.vertical, length: 2, row: 2, col: 1),
    ],
    verifiedSolution: [
      (blockId: 'C', delta: -1),
      (blockId: 'E', delta: -1),
      (blockId: 'B', delta: -1),
      (blockId: 'D', delta: -1),
      (blockId: 'F', delta: 1),
      (blockId: 'I', delta: 1),
      (blockId: 'J', delta: -1),
      (blockId: 'A', delta: 1),
      (blockId: 'T', delta: 1),
    ],
  ),
  // Level 15 — hardest: 7x7, 12 blocks. Solve in 10 moves.
  _LevelSpec(
    rows: 7,
    cols: 7,
    blocks: [
      _BlockSpec(
        id: 'T',
        axis: _Axis.horizontal,
        length: 2,
        row: 1,
        col: 1,
        isTarget: true,
      ),
      _BlockSpec(id: 'A', axis: _Axis.vertical, length: 2, row: 0, col: 6),
      _BlockSpec(id: 'B', axis: _Axis.horizontal, length: 3, row: 6, col: 3),
      _BlockSpec(id: 'C', axis: _Axis.vertical, length: 3, row: 3, col: 5),
      _BlockSpec(id: 'D', axis: _Axis.vertical, length: 2, row: 0, col: 3),
      _BlockSpec(id: 'E', axis: _Axis.horizontal, length: 3, row: 3, col: 1),
      _BlockSpec(id: 'F', axis: _Axis.vertical, length: 2, row: 5, col: 2),
      _BlockSpec(id: 'G', axis: _Axis.vertical, length: 3, row: 3, col: 4),
      _BlockSpec(id: 'H', axis: _Axis.vertical, length: 2, row: 5, col: 1),
      _BlockSpec(id: 'I', axis: _Axis.horizontal, length: 2, row: 2, col: 2),
      _BlockSpec(id: 'J', axis: _Axis.vertical, length: 3, row: 0, col: 0),
      _BlockSpec(id: 'K', axis: _Axis.vertical, length: 2, row: 1, col: 4),
    ],
    verifiedSolution: [
      (blockId: 'A', delta: 1),
      (blockId: 'E', delta: -1),
      (blockId: 'F', delta: -1),
      (blockId: 'H', delta: -1),
      (blockId: 'B', delta: -1),
      (blockId: 'G', delta: 1),
      (blockId: 'I', delta: -1),
      (blockId: 'D', delta: 1),
      (blockId: 'K', delta: 1),
      (blockId: 'T', delta: 1),
    ],
  ),
];

class SlideEscapeScreen extends StatefulWidget {
  const SlideEscapeScreen({super.key, required this.ctx});

  final GameLevelContext ctx;

  @override
  State<SlideEscapeScreen> createState() => _SlideEscapeScreenState();
}

class _SlideEscapeScreenState extends State<SlideEscapeScreen> {
  late _LevelSpec _spec;
  late Map<String, _Cell> _pos;
  int _moves = 0;
  bool _won = false;

  String? _draggingId;
  int _dragStartCoord = 0;
  int _dragMinCoord = 0;
  int _dragMaxCoord = 0;
  _Cell? _dragOriginalPos;
  double _dragAccumPx = 0;

  int get _level => widget.ctx.level;

  @override
  void initState() {
    super.initState();
    _spec = _levels[(_level - 1).clamp(0, _levels.length - 1)];
    _resetPositions();
  }

  void _resetPositions() {
    _pos = {for (final b in _spec.blocks) b.id: (b.row, b.col)};
    _moves = 0;
    _won = false;
    _draggingId = null;
  }

  _BlockSpec _blockOf(String id) => _spec.blocks.firstWhere((b) => b.id == id);

  _BlockSpec get _target => _spec.blocks.firstWhere((b) => b.isTarget);

  List<_Cell> _cellsFor(_BlockSpec b, _Cell topLeft) {
    final (r, c) = topLeft;
    if (b.axis == _Axis.horizontal) {
      return [for (var i = 0; i < b.length; i++) (r, c + i)];
    }
    return [for (var i = 0; i < b.length; i++) (r + i, c)];
  }

  bool _cellOccupied(int row, int col, {required String excludeId}) {
    for (final b in _spec.blocks) {
      if (b.id == excludeId) continue;
      for (final cell in _cellsFor(b, _pos[b.id]!)) {
        if (cell.$1 == row && cell.$2 == col) return true;
      }
    }
    return false;
  }

  /// Scans cell-by-cell in both directions along [id]'s axis to find the
  /// furthest legal leading-edge coordinate the block could slide to from
  /// its *current* position, given every other block's current position.
  (int, int) _legalRange(String id) {
    final b = _blockOf(id);
    final (row, col) = _pos[id]!;
    if (b.axis == _Axis.horizontal) {
      var minC = col;
      while (minC - 1 >= 0 && !_cellOccupied(row, minC - 1, excludeId: id)) {
        minC -= 1;
      }
      var maxC = col;
      while (maxC + b.length < _spec.cols &&
          !_cellOccupied(row, maxC + b.length, excludeId: id)) {
        maxC += 1;
      }
      return (minC, maxC);
    }
    var minR = row;
    while (minR - 1 >= 0 && !_cellOccupied(minR - 1, col, excludeId: id)) {
      minR -= 1;
    }
    var maxR = row;
    while (maxR + b.length < _spec.rows &&
        !_cellOccupied(maxR + b.length, col, excludeId: id)) {
      maxR += 1;
    }
    return (minR, maxR);
  }

  void _startDrag(String id) {
    if (_won) return;
    final b = _blockOf(id);
    final range = _legalRange(id);
    final current = _pos[id]!;
    setState(() {
      _draggingId = id;
      _dragOriginalPos = current;
      _dragStartCoord = b.axis == _Axis.horizontal ? current.$2 : current.$1;
      _dragMinCoord = range.$1;
      _dragMaxCoord = range.$2;
      _dragAccumPx = 0;
    });
  }

  void _updateDrag(String id, Offset delta, double cellSize) {
    if (_draggingId != id) return;
    final b = _blockOf(id);
    final axisDelta = b.axis == _Axis.horizontal ? delta.dx : delta.dy;
    _dragAccumPx += axisDelta;
    final deltaCells = (_dragAccumPx / cellSize).round();
    var candidate = _dragStartCoord + deltaCells;
    if (candidate < _dragMinCoord) candidate = _dragMinCoord;
    if (candidate > _dragMaxCoord) candidate = _dragMaxCoord;
    setState(() {
      final current = _pos[id]!;
      _pos[id] = b.axis == _Axis.horizontal
          ? (current.$1, candidate)
          : (candidate, current.$2);
    });
  }

  void _endDrag(String id) {
    if (_draggingId != id) return;
    final moved = _pos[id] != _dragOriginalPos;
    setState(() {
      _draggingId = null;
      if (moved) _moves += 1;
    });
    if (moved) _checkWin();
  }

  void _checkWin() {
    if (_won) return;
    final target = _target;
    final (_, col) = _pos[target.id]!;
    final reached = col + target.length - 1 == _spec.cols - 1;
    if (!reached) return;
    setState(() => _won = true);
    final par = _spec.verifiedSolution.length;
    final stars = _moves == par ? 3 : (_moves <= par + 3 ? 2 : 1);
    Future.microtask(() => widget.ctx.onComplete(stars: stars, score: _moves));
  }

  void _restart() {
    setState(_resetPositions);
  }

  /// [_LevelSpec.verifiedSolution] is only guaranteed valid when replayed
  /// from the level's exact starting layout — if the player has already
  /// made any moves, blindly applying the next scripted move could be
  /// illegal or simply wrong. So this only reveals a move when the board
  /// still matches the untouched start state; otherwise it's honest about
  /// the limitation instead of doing something incorrect.
  void _showHint() {
    if (_won) return;
    final atStart = _spec.blocks.every((b) => _pos[b.id] == (b.row, b.col));
    if (!atStart || _spec.verifiedSolution.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Hint only works from the start of the level — try Restart '
            'first, then ask for a hint again.',
          ),
        ),
      );
      return;
    }
    final move = _spec.verifiedSolution.first;
    final block = _blockOf(move.blockId);
    final direction = block.axis == _Axis.horizontal
        ? (move.delta > 0 ? 'right' : 'left')
        : (move.delta > 0 ? 'down' : 'up');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Slide block ${move.blockId} $direction to get started.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Slide Escape · Level $_level'),
        actions: [
          ...gameActions(
            context: context,
            def: slideEscapeDefinition,
            ctx: widget.ctx,
            onHint: _won ? null : _showHint,
          ),
          TextButton(onPressed: _restart, child: const Text('Restart')),
          TextButton(onPressed: widget.ctx.onExit, child: const Text('Menu')),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Moves: $_moves',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  _won ? 'Escaped!' : 'Slide the target block to the exit',
                  style: TextStyle(
                    color: _won ? AppTheme.success : AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const arrowSpace = 34.0;
                  final maxBoardWidth = constraints.maxWidth - 32 - arrowSpace;
                  final maxBoardHeight = constraints.maxHeight - 32;
                  final cellFromWidth = maxBoardWidth / _spec.cols;
                  final cellFromHeight = maxBoardHeight / _spec.rows;
                  var cellSize = cellFromWidth < cellFromHeight
                      ? cellFromWidth
                      : cellFromHeight;
                  cellSize = cellSize.clamp(24.0, 120.0);
                  final boardWidth = cellSize * _spec.cols;
                  final boardHeight = cellSize * _spec.rows;

                  return SizedBox(
                    width: boardWidth + arrowSpace,
                    height: boardHeight,
                    child: Stack(
                      children: [
                        SizedBox(
                          width: boardWidth,
                          height: boardHeight,
                          child: _GridBackground(
                            rows: _spec.rows,
                            cols: _spec.cols,
                          ),
                        ),
                        for (final b in _spec.blocks) _buildBlock(b, cellSize),
                        Positioned(
                          left: boardWidth + 4,
                          top: _target.row * cellSize + cellSize / 2 - 12,
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: AppTheme.success,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Drag blocks along their axis. Get the highlighted block '
              'to the green arrow to escape.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlock(_BlockSpec b, double cellSize) {
    final (row, col) = _pos[b.id]!;
    final width = b.axis == _Axis.horizontal ? cellSize * b.length : cellSize;
    final height = b.axis == _Axis.vertical ? cellSize * b.length : cellSize;
    final isDragging = _draggingId == b.id;

    return AnimatedPositioned(
      duration: isDragging ? Duration.zero : Motion.ms(140),
      curve: Curves.easeOut,
      left: col * cellSize,
      top: row * cellSize,
      width: width,
      height: height,
      child: GestureDetector(
        onPanStart: (_) => _startDrag(b.id),
        onPanUpdate: (details) => _updateDrag(b.id, details.delta, cellSize),
        onPanEnd: (_) => _endDrag(b.id),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Container(
            decoration: BoxDecoration(
              color: b.isTarget ? AppTheme.success : AppTheme.surfaceHigh,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: b.isTarget ? AppTheme.success : AppTheme.accentSoft,
                width: b.isTarget ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: isDragging ? 0.35 : 0.2,
                  ),
                  blurRadius: isDragging ? 10 : 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GridBackground extends StatelessWidget {
  const _GridBackground({required this.rows, required this.cols});

  final int rows;
  final int cols;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentSoft, width: 1.5),
      ),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: rows * cols,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
        ),
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        },
      ),
    );
  }
}
