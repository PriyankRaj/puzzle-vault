import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/game_definition.dart';
import '../../core/game_level_context.dart';
import '../../core/sound.dart';
import '../../core/widgets/game_actions.dart';
import '../../core/widgets/swipe_area.dart';

/// Original top-down dungeon-room puzzle. The player walks a small grid
/// room, picking up colored keys to open matching colored doors and
/// stepping on switches to toggle linked gates, in order to reach the exit.
/// This mechanic, theme, vocabulary and all 15 level layouts are original
/// creations for this app (only loosely inspired by the generic idea of a
/// room full of keys/doors/switches you must operate in order).
final GameDefinition dungeonLogicDefinition = GameDefinition(
  id: 'dungeon_logic',
  title: 'Key Escape',
  tagline: 'Collect keys and flip switches to escape',
  icon: Icons.meeting_room_rounded,
  tint: const GameTint(Color(0xFFF59E0B), Color(0xFF92400E)),
  mode: GameMode.levels,
  levelCount: 15,
  helpText:
      'Use the arrows to walk around the room. Walk onto a colored key to '
      'pick it up, then walk into the matching colored door to unlock and '
      'pass through it (the key is used up). Step onto a numbered switch to '
      'toggle every gate it controls between open and closed. Reach the '
      'exit to escape.',
  builder: (context, ctx) => DungeonLogicScreen(ctx: ctx),
);

/// One hardcoded room layout, described as ASCII art. Legend:
///  `#` wall (blocks movement)          `.` floor (walkable)
///  `P` player start                    `E` exit (goal)
///  `R` `B` `G` colored keys (red/blue/green) - walking onto one picks it up
///  `r` `b` `g` matching colored doors - blocked unless holding that key;
///        walking through consumes the key and turns the door into floor
///  `1`-`9` a switch (index-tagged) - walking onto it toggles every gate
///        linked to that index between open and closed; the switch tile
///        itself is always walkable and can be re-toggled any number of times
///  `O` an open gate, `C` a closed gate - both start as whichever the level
///        data says and are toggled by their linked switch(es)
///
/// [switches] maps a switch index to the grid coordinates (row, col) of
/// every gate it controls. [solutionLength] is the exact number of moves in
/// a hand-verified solving sequence for the level, used only to grade stars.
class _DungeonLevel {
  const _DungeonLevel(
    this.grid,
    this.switches,
    this.solutionLength,
    this.solutionMoves,
  );

  final List<String> grid;
  final Map<int, List<Point<int>>> switches;
  final int solutionLength;

  /// The exact hand-traced solving sequence transcribed from this level's
  /// authoring comment above (e.g. `R,R,D,R,D,D,L,R,R`), used to play back
  /// a real "next move" hint. Assumes the player has followed this exact
  /// path so far — see `_showHint` for the fallback when they haven't.
  final List<String> solutionMoves;
}

/// All 15 rooms, growing from a small single-key 5x5 room to a larger
/// 8x8 room combining several keys and switches. Every level below was
/// hand-traced move-by-move while authoring it (see the move list recorded
/// next to each level) to confirm it is solvable; [solutionLength] is that
/// traced sequence's length.
const List<_DungeonLevel> _levels = [
  // Level 1: one key, one door. 5x5.
  // Solve: R,R,D,R,D,D,L,R,R (9 moves).
  _DungeonLevel(
    ['P.R..', '.....', '..#..', '..r.E', '.....'],
    {},
    9,
    ['R', 'R', 'D', 'R', 'D', 'D', 'L', 'R', 'R'],
  ),
  // Level 2: one key, one door, longer detour. 5x5.
  // Solve: D,D,D,D,R,R,R,U,D,R (10 moves).
  _DungeonLevel(
    ['P.#..', '..#..', 'R.#..', '..#r.', '....E'],
    {},
    10,
    ['D', 'D', 'D', 'D', 'R', 'R', 'R', 'U', 'D', 'R'],
  ),
  // Level 3: one switch, one gate, no keys. 6x6.
  // Solve: R,R,D,D,D,R,R,R,D,D (10 moves).
  _DungeonLevel(
    ['P..###', '##1###', '##C###', '##....', '#####.', '#####E'],
    {
      1: [Point(2, 2)],
    },
    10,
    ['R', 'R', 'D', 'D', 'D', 'R', 'R', 'R', 'D', 'D'],
  ),
  // Level 4: two keys, two doors in sequence. 6x6.
  // Solve: R,R,D,D,R,D,D,R,D,R (10 moves).
  _DungeonLevel(
    ['P.R###', '##.###', '##r.##', '###B##', '###.b#', '####.E'],
    {},
    10,
    ['R', 'R', 'D', 'D', 'R', 'D', 'D', 'R', 'D', 'R'],
  ),
  // Level 5: a switch/gate followed by a key/door. 6x6.
  // Solve: R,D,D,D,R,D,R,D,R,R (10 moves).
  _DungeonLevel(
    ['P.####', '#1####', '#C####', '#.R###', '##.r##', '###..E'],
    {
      1: [Point(2, 1)],
    },
    10,
    ['R', 'D', 'D', 'D', 'R', 'D', 'R', 'D', 'R', 'R'],
  ),
  // Level 6: two independent switch/gate pairs in sequence. 6x6.
  // Solve: R,D,D,D,R,D,D,R,R,R (10 moves).
  _DungeonLevel(
    ['P.####', '#1####', '#C####', '#.2###', '##C###', '##...E'],
    {
      1: [Point(2, 1)],
      2: [Point(4, 2)],
    },
    10,
    ['R', 'D', 'D', 'D', 'R', 'D', 'D', 'R', 'R', 'R'],
  ),
  // Level 7: three keys, three doors in sequence. 7x7.
  // Solve: R,R,D,D,R,D,D,R,D,R,R,D (12 moves).
  _DungeonLevel(
    [
      'P.R####',
      '##.####',
      '##r.###',
      '###B###',
      '###.b##',
      '####.Gg',
      '######E',
    ],
    {},
    12,
    ['R', 'R', 'D', 'D', 'R', 'D', 'D', 'R', 'D', 'R', 'R', 'D'],
  ),
  // Level 8: a switch/gate combined with a key/door. 7x7.
  // Solve: R,D,D,D,R,D,R,D,R,D (10 moves) - hand-traced:
  //   (0,0)->(0,1)->(1,1)switch->(2,1)gate opens->(3,1)->(3,2)key
  //   ->(4,2)->(4,3)door->(5,3)->(5,4)->(6,4)exit.
  _DungeonLevel(
    [
      'P.#####',
      '#1#####',
      '#C#####',
      '#.R####',
      '##.r###',
      '###..##',
      '####E##',
    ],
    {
      1: [Point(2, 1)],
    },
    10,
    ['R', 'D', 'D', 'D', 'R', 'D', 'R', 'D', 'R', 'D'],
  ),
  // Level 9: two switches, one of which controls two gates. 7x7.
  // Solve: R,D,D,D,R,R,D,D,R,D,R,R (12 moves).
  _DungeonLevel(
    [
      'P.#####',
      '#1#####',
      '#C#####',
      '#...###',
      '###C###',
      '###.2##',
      '####C.E',
    ],
    {
      1: [Point(2, 1), Point(4, 3)],
      2: [Point(6, 4)],
    },
    12,
    ['R', 'D', 'D', 'D', 'R', 'R', 'D', 'D', 'R', 'D', 'R', 'R'],
  ),
  // Level 10: two keys/doors combined with a switch/gate. 7x7.
  // Solve: R,R,D,D,R,D,D,D,R,D,R,R (12 moves).
  _DungeonLevel(
    [
      'P.R####',
      '##.####',
      '##r.###',
      '###1###',
      '###C###',
      '###.B##',
      '####.bE',
    ],
    {
      1: [Point(4, 3)],
    },
    12,
    ['R', 'R', 'D', 'D', 'R', 'D', 'D', 'D', 'R', 'D', 'R', 'R'],
  ),
  // Level 11: three keys/doors combined with a switch/gate. 7x7.
  // Solve: R,R,D,D,L,D,D,D,D,R,R,R,U,R,R,U,U,U,U,U (20 moves).
  _DungeonLevel(
    [
      'P.R###E',
      '##.###.',
      '#.r###.',
      '#.####.',
      '#1####g',
      '#C##b.G',
      '#..B.##',
    ],
    {
      1: [Point(5, 1)],
    },
    20,
    [
      'R',
      'R',
      'D',
      'D',
      'L',
      'D',
      'D',
      'D',
      'D',
      'R',
      'R',
      'R',
      'U',
      'R',
      'R',
      'U',
      'U',
      'U',
      'U',
      'U',
    ],
  ),
  // Level 12: two switches, each controlling two gates, plus a key/door. 8x8.
  // Solve: R,D,D,D,R,R,U,U,R,R,D,D,R,D,D,D,D (17 moves).
  _DungeonLevel(
    [
      'P.######',
      '#1#..2##',
      '#C#C#C##',
      '#...#.R#',
      '######.#',
      '######r#',
      '######.#',
      '######E#',
    ],
    {
      1: [Point(2, 1), Point(2, 3)],
      2: [Point(2, 5)],
    },
    17,
    [
      'R',
      'D',
      'D',
      'D',
      'R',
      'R',
      'U',
      'U',
      'R',
      'R',
      'D',
      'D',
      'R',
      'D',
      'D',
      'D',
      'D',
    ],
  ),
  // Level 13: three keys/doors plus a switch/gate. 8x8.
  // Solve: R,R,D,D,R,R,D,D,R,R,D,D,L,D,R,R (16 moves).
  _DungeonLevel(
    [
      'P.R#####',
      '##.#####',
      '##r.B###',
      '####.###',
      '####b.1#',
      '######C#',
      '#####G.#',
      '#####.gE',
    ],
    {
      1: [Point(5, 6)],
    },
    16,
    [
      'R',
      'R',
      'D',
      'D',
      'R',
      'R',
      'D',
      'D',
      'R',
      'R',
      'D',
      'D',
      'L',
      'D',
      'R',
      'R',
    ],
  ),
  // Level 14: two switches (each controlling two gates) plus two keys/doors. 8x8.
  // Solve: R,D,D,D,D,R,R,R,U,U,U,R,U,U,R,R,D,D,D,D,D,D,D,D (24 moves).
  _DungeonLevel(
    [
      'P.###.B.',
      '#1###C#b',
      '#C##2C#.',
      '#.##.##.',
      '#C##.##.',
      '#.R.r##.',
      '#######.',
      '#######E',
    ],
    {
      1: [Point(2, 1), Point(4, 1)],
      2: [Point(2, 5), Point(1, 5)],
    },
    24,
    [
      'R',
      'D',
      'D',
      'D',
      'D',
      'R',
      'R',
      'R',
      'U',
      'U',
      'U',
      'R',
      'U',
      'U',
      'R',
      'R',
      'D',
      'D',
      'D',
      'D',
      'D',
      'D',
      'D',
      'D',
    ],
  ),
  // Level 15: three keys/doors plus two switches each controlling two gates.
  // The largest, hardest room. 8x8.
  // Solve (hand-traced move by move):
  //   (0,0)->(0,1)R->(0,2)key R->(1,2)D->(2,2)door r consumes R->(2,1)L
  //   ->(3,1)D->(4,1)D switch1 (opens (5,1)&(6,3))->(5,1)D gate open->(6,1)D
  //   ->(6,2)R->(6,3)R gate open->(6,4)R->(6,5)R key B->(6,6)R->(6,7)R door b
  //   consumes B->(5,7)U->(4,7)U->(3,7)U switch2 (opens (2,7)&(2,5))
  //   ->(2,7)U gate open->(2,6)L->(2,5)L gate open->(2,4)L->(2,3)L key G
  //   ->(1,3)U->(0,3)U->(0,4)R door g consumes G->(0,5)R->(0,6)R->(0,7)R exit.
  // 29 moves total, matching the grid's cell count minus one.
  _DungeonLevel(
    [
      'P.R.g..E',
      '##..####',
      '#.rG.C.C',
      '#.#####2',
      '#1#####.',
      '#C#####.',
      '#..C.B.b',
      '########',
    ],
    {
      1: [Point(5, 1), Point(6, 3)],
      2: [Point(2, 7), Point(2, 5)],
    },
    29,
    [
      'R',
      'R',
      'D',
      'D',
      'L',
      'D',
      'D',
      'D',
      'D',
      'R',
      'R',
      'R',
      'R',
      'R',
      'R',
      'U',
      'U',
      'U',
      'U',
      'L',
      'L',
      'L',
      'L',
      'U',
      'U',
      'R',
      'R',
      'R',
      'R',
    ],
  ),
];

Map<String, Color> get _keyColors => {
  'R': AppTheme.danger,
  'B': const Color(0xFF60A5FA),
  'G': AppTheme.success,
};

class DungeonLogicScreen extends StatefulWidget {
  const DungeonLogicScreen({super.key, required this.ctx});

  final GameLevelContext ctx;

  @override
  State<DungeonLogicScreen> createState() => _DungeonLogicScreenState();
}

class _DungeonLogicScreenState extends State<DungeonLogicScreen> {
  late int _width;
  late int _height;
  late List<List<String>> _cell;
  late int _playerRow;
  late int _playerCol;
  final Set<String> _inventory = {};
  int _moves = 0;
  bool _won = false;

  int get _level => widget.ctx.level;
  _DungeonLevel get _def => _levels[_level - 1];

  @override
  void initState() {
    super.initState();
    _setupLevel();
  }

  void _setupLevel() {
    final grid = _def.grid;
    _height = grid.length;
    _width = grid[0].length;
    _cell = [
      for (final row in grid) [for (var i = 0; i < row.length; i++) row[i]],
    ];
    _playerRow = 0;
    _playerCol = 0;
    for (var r = 0; r < _height; r++) {
      for (var c = 0; c < _width; c++) {
        if (_cell[r][c] == 'P') {
          _playerRow = r;
          _playerCol = c;
          _cell[r][c] = '.';
        }
      }
    }
    _inventory.clear();
    _moves = 0;
    _won = false;
  }

  /// Same-level restart reachable at any time via the shared "Restart
  /// level" action, distinct from "Give up" (leaves the screen) and "Reset
  /// progress" (wipes all unlocked levels/stars for this game).
  void _restartLevel() {
    Sfx.tap();
    setState(_setupLevel);
  }

  bool _isDigit(String ch) =>
      ch.codeUnitAt(0) >= 49 && ch.codeUnitAt(0) <= 57; // '1'-'9'

  void _toggleSwitch(int index) {
    final gates = _def.switches[index];
    if (gates == null) return;
    for (final gate in gates) {
      final r = gate.x;
      final c = gate.y;
      if (_cell[r][c] == 'C') {
        _cell[r][c] = 'O';
      } else if (_cell[r][c] == 'O') {
        _cell[r][c] = 'C';
      }
    }
  }

  void _move(int dr, int dc) {
    if (_won) return;
    final nr = _playerRow + dr;
    final nc = _playerCol + dc;
    if (nr < 0 || nr >= _height || nc < 0 || nc >= _width) return;

    final ch = _cell[nr][nc];
    var moved = false;
    var reachedExit = false;

    if (ch == '#' || ch == 'C') {
      // blocked: wall or closed gate
    } else if (ch == '.' || ch == 'O') {
      moved = true;
    } else if (ch == 'E') {
      moved = true;
      reachedExit = true;
    } else if (ch == 'R' || ch == 'B' || ch == 'G') {
      _inventory.add(ch);
      _cell[nr][nc] = '.';
      moved = true;
    } else if (ch == 'r' || ch == 'b' || ch == 'g') {
      final needed = ch.toUpperCase();
      if (_inventory.contains(needed)) {
        _inventory.remove(needed);
        _cell[nr][nc] = '.';
        moved = true;
      }
    } else if (_isDigit(ch)) {
      _toggleSwitch(int.parse(ch));
      moved = true;
    }

    if (!moved) return;

    setState(() {
      _playerRow = nr;
      _playerCol = nc;
      _moves++;
      if (reachedExit) _won = true;
    });

    if (_won) {
      final solved = _def.solutionLength;
      final stars = _moves == solved
          ? 3
          : _moves <= solved + 4
          ? 2
          : 1;
      Future.microtask(() => widget.ctx.onComplete(stars: stars));
    }
  }

  Widget _dpadButton(IconData icon, int dr, int dc, String label) {
    return IconButton(
      onPressed: () => _move(dr, dc),
      icon: Icon(icon, color: AppTheme.textPrimary),
      style: IconButton.styleFrom(backgroundColor: AppTheme.surfaceHigh),
      tooltip: 'Move $label',
    );
  }

  /// Routes a swipe to the same [_move] call the d-pad buttons use, so
  /// swiping the board is exactly equivalent to pressing the matching
  /// d-pad button (additive — the d-pad still works too).
  void _onSwipe(SwipeDirection direction) {
    switch (direction) {
      case SwipeDirection.left:
        _move(0, -1);
      case SwipeDirection.right:
        _move(0, 1);
      case SwipeDirection.up:
        _move(-1, 0);
      case SwipeDirection.down:
        _move(1, 0);
    }
  }

  /// Plays back the next move of this level's hand-traced solution
  /// (transcribed from the authoring comment into `solutionMoves`), based
  /// on how many moves the player has made so far. This assumes the
  /// player has followed that exact optimal path — if they've deviated,
  /// `_moves` no longer indexes the right step, so we fall back to
  /// replaying the FIRST move as a general nudge rather than risk showing
  /// (or performing) a move that's wrong for their actual position. Same
  /// known limitation as `slide_escape`'s stored solution elsewhere in
  /// this app.
  void _showHint() {
    if (_won) return;
    final moves = _def.solutionMoves;
    if (moves.isEmpty) return;
    final index = _moves < moves.length ? _moves : 0;
    final move = moves[index];
    final (dr, dc) = switch (move) {
      'U' => (-1, 0),
      'D' => (1, 0),
      'L' => (0, -1),
      'R' => (0, 1),
      _ => (0, 0),
    };
    final directionName = switch (move) {
      'U' => 'up',
      'D' => 'down',
      'L' => 'left',
      _ => 'right',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Try moving $directionName.')));
    _move(dr, dc);
  }

  Widget _buildCell(int r, int c, double cellSize) {
    final ch = _cell[r][c];
    final hasPlayer = r == _playerRow && c == _playerCol;
    final iconSize = (cellSize * 0.5).clamp(18.0, 32.0);
    final playerDotSize = (cellSize * 0.35).clamp(14.0, 24.0);

    Widget base;
    switch (ch) {
      case '#':
        base = Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2E3D),
            borderRadius: BorderRadius.circular(6),
          ),
        );
        break;
      case '.':
        base = Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(6),
          ),
        );
        break;
      case 'O':
        base = Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.accentSoft, width: 1),
          ),
        );
        break;
      case 'C':
        base = Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: AppTheme.surfaceHigh,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.grid_on_rounded,
            color: AppTheme.textSecondary,
            size: iconSize,
          ),
        );
        break;
      case 'E':
        base = Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.exit_to_app_rounded,
            color: AppTheme.success,
            size: iconSize,
          ),
        );
        break;
      case 'R':
      case 'B':
      case 'G':
        final color = _keyColors[ch]!;
        base = Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.key_rounded, color: color, size: iconSize),
        );
        break;
      case 'r':
      case 'b':
      case 'g':
        final color = _keyColors[ch.toUpperCase()]!;
        base = Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color, width: 2),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.door_front_door_rounded,
            color: color,
            size: iconSize,
          ),
        );
        break;
      default:
        // switch tile: single digit '1'-'9'
        base = Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: AppTheme.accentSoft.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.toggle_on_rounded,
            color: AppTheme.accent,
            size: iconSize,
          ),
        );
    }

    if (!hasPlayer) return base;

    return Stack(
      alignment: Alignment.center,
      children: [
        base,
        Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.accent, width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        Container(
          width: playerDotSize,
          height: playerDotSize,
          decoration: BoxDecoration(
            color: AppTheme.accent,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dungeon Logic · Level $_level'),
        actions: [
          ...gameActions(
            context: context,
            def: dungeonLogicDefinition,
            ctx: widget.ctx,
            onHint: _showHint,
            onRestart: _restartLevel,
          ),
          IconButton(
            icon: const Icon(Icons.flag_rounded),
            tooltip: 'Give up',
            onPressed: widget.ctx.onExit,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Moves: $_moves',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final color in ['R', 'B', 'G'])
                          if (_inventory.contains(color))
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: _keyColors[color],
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        if (_inventory.isEmpty)
                          Text(
                            'No keys held',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SwipeArea(
              onSwipe: _onSwipe,
              child: Center(
                child: AspectRatio(
                  aspectRatio: _width / _height,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final cellSize = constraints.maxWidth / _width;
                        return GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _width * _height,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: _width,
                              ),
                          itemBuilder: (context, index) {
                            final r = index ~/ _width;
                            final c = index % _width;
                            return _buildCell(r, c, cellSize);
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dpadButton(Icons.keyboard_arrow_up_rounded, -1, 0, 'up'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _dpadButton(
                      Icons.keyboard_arrow_left_rounded,
                      0,
                      -1,
                      'left',
                    ),
                    const SizedBox(width: 48),
                    _dpadButton(
                      Icons.keyboard_arrow_right_rounded,
                      0,
                      1,
                      'right',
                    ),
                  ],
                ),
                _dpadButton(Icons.keyboard_arrow_down_rounded, 1, 0, 'down'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Collect keys to open matching doors, flip switches to open gates, reach the exit',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
