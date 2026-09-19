import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/game_definition.dart';
import '../../core/game_level_context.dart';
import '../../core/sound.dart';
import '../../core/widgets/game_actions.dart';
import '../../core/widgets/swipe_area.dart';

/// Original rule-block pushing puzzle. Word-tiles like WALL / IS / STOP sit
/// on the grid alongside ordinary shaped objects (wall, box, rock, flag) and
/// can be pushed around. Whenever three word-tiles line up as
/// `NOUN IS PROPERTY` the matching rule becomes active and changes how that
/// noun's objects behave for the rest of the level. This mechanic, theme,
/// vocabulary and all 15 level layouts are original creations for this app.
final GameDefinition ruleBreakerDefinition = GameDefinition(
  id: 'rule_breaker',
  title: 'Rule Puzzle',
  tagline: 'Push words to rewrite the rules',
  icon: Icons.extension_rounded,
  tint: const GameTint(Color(0xFFA78BFA), Color(0xFF6D28D9)),
  mode: GameMode.levels,
  levelCount: 15,
  helpText:
      'Swipe to walk your character around the grid. Word-tiles like WALL, '
      'IS and STOP can be pushed like blocks — line three of them up as '
      'NOUN IS PROPERTY (e.g. WALL IS STOP) to make that rule active, which '
      'changes how matching objects behave. Reach an object with an active '
      '"WIN" rule to clear the level. Some levels need the opposite move '
      'too: push a word out of formation to break a rule that is in your '
      'way (e.g. shove the WALL tile out of "WALL IS STOP" so walls stop '
      'blocking you).',
  builder: (context, ctx) => RuleBreakerScreen(ctx: ctx),
);

/// The small fixed vocabulary of tiles that can appear on the grid.
enum TileKind {
  wall,
  box,
  rock,
  flag,
  player,
  wordWall,
  wordBox,
  wordRock,
  wordFlag,
  wordIs,
  wordStop,
  wordPush,
  wordWin,
}

const Set<TileKind> _wordKinds = {
  TileKind.wordWall,
  TileKind.wordBox,
  TileKind.wordRock,
  TileKind.wordFlag,
  TileKind.wordIs,
  TileKind.wordStop,
  TileKind.wordPush,
  TileKind.wordWin,
};

const Set<TileKind> _nounKinds = {
  TileKind.wall,
  TileKind.box,
  TileKind.rock,
  TileKind.flag,
};

const Map<TileKind, TileKind> _wordToNoun = {
  TileKind.wordWall: TileKind.wall,
  TileKind.wordBox: TileKind.box,
  TileKind.wordRock: TileKind.rock,
  TileKind.wordFlag: TileKind.flag,
};

const Map<TileKind, String> _wordToProperty = {
  TileKind.wordStop: 'stop',
  TileKind.wordPush: 'push',
  TileKind.wordWin: 'win',
};

const Map<String, TileKind> _charToKind = {
  '#': TileKind.wall,
  'B': TileKind.box,
  'R': TileKind.rock,
  'F': TileKind.flag,
  'P': TileKind.player,
  'w': TileKind.wordWall,
  'b': TileKind.wordBox,
  'r': TileKind.wordRock,
  'g': TileKind.wordFlag,
  'i': TileKind.wordIs,
  's': TileKind.wordStop,
  'u': TileKind.wordPush,
  'n': TileKind.wordWin,
};

const Map<TileKind, String> _wordLabel = {
  TileKind.wordWall: 'WALL',
  TileKind.wordBox: 'BOX',
  TileKind.wordRock: 'ROCK',
  TileKind.wordFlag: 'FLAG',
  TileKind.wordIs: 'IS',
  TileKind.wordStop: 'STOP',
  TileKind.wordPush: 'PUSH',
  TileKind.wordWin: 'WIN',
};

const Map<TileKind, String> _nounLabel = {
  TileKind.wall: 'WALL',
  TileKind.box: 'BOX',
  TileKind.rock: 'ROCK',
  TileKind.flag: 'FLAG',
};

/// One tile / object placed on the grid. Every level starts by parsing a
/// small ASCII layout into a list of these; positions mutate as tiles are
/// pushed around during play.
class GameObject {
  GameObject({
    required this.id,
    required this.kind,
    required this.row,
    required this.col,
  });

  final int id;
  final TileKind kind;
  int row;
  int col;

  bool get isWordTile => _wordKinds.contains(kind);
}

/// Literal ASCII level data. Legend:
/// `.` empty  `X` permanent border (never interactive)
/// `#` wall   `B` box   `R` rock   `F` flag   `P` player (noun objects)
/// `w b r g` word-tiles WALL/BOX/ROCK/FLAG   `i` word IS
/// `s u n`  word-tiles STOP/PUSH/WIN
// Ordering deliberately front-loads mechanic *introductions* (WIN-walk,
// STOP-break, PUSH) within the first half instead of spending 3-4 levels
// per mechanic before moving on, then spends the second half stacking
// reassembly + decorative decoys + a genuine two-mechanic combo before the
// largest board as a capstone — the original ordering introduced one new
// idea roughly every 2 levels and never combined two required mechanics
// until level 14, which read as flat. Levels 1 and 4 are hard-coded against
// in test/games/rule_breaker_logic_test.dart (exact tap sequences) and must
// keep this exact content; every other layout is unchanged content from
// the original 15, just resequenced.
const List<List<String>> _levels = [
  // 1: walk straight onto a flag that is already WIN.
  ['.....', '.P...', '.....', '.gin.', '..F..'],
  // 2: same idea, ROCK IS WIN, slightly larger.
  ['....P.', '......', '......', '.rin..', 'R.....'],
  // 3: FLAG IS WIN again, bigger open grid.
  ['......', '..P...', '......', '......', '.gin..', '...F..'],
  // 4: WALL IS STOP blocks the direct route; push WALL out of line to break it.
  ['P.#.F', '.wis.', '.....', '.gin.'],
  // 5: BOX IS PUSH introduced already (was level 8) — second mechanic
  // appears right after the first, instead of three levels later.
  ['P.B.F', '.....', '.biu.', '.gin.'],
  // 6: WALL IS STOP alcove variant (was level 5), a second STOP-break.
  ['P..#.F', 'X.wisX', 'X....X', 'XginXX'],
  // 7: ROCK IS STOP variant (was level 6).
  ['P..R.F', '......', '.ris..', '......', '.gin..'],
  // 8: ROCK IS PUSH variant (was level 9) — by here both STOP and PUSH have
  // each been seen twice, in half the levels the original took.
  ['P..R.F', '......', '.riu..', '......', '.gin..'],
  // 9: WALL IS STOP again, largest of that band (was level 7).
  ['P...#.F', '.......', '..wis..', '.......', '..gin..', '.......'],
  // 10: BOX IS PUSH, bigger grid (was level 10).
  ['P.B..F', '......', '.biu..', '......', '.gin..'],
  // 11: FLAG IS WIN is *broken* by a gap; push WIN tile into place to form
  // it — reassembly introduced (was level 12).
  ['P......', '.......', '.gi.n.F', '.......', '..biu..', '.......'],
  // 12: BOX IS PUSH, largest of that band (was level 11).
  ['P...B.F', '.......', '..biu..', '.......', '..gin..', '.......'],
  // 13: same reassembly trick with ROCK IS WIN, plus a decorative unused
  // rule (was level 13).
  ['P......', '.......', '.ri.n.R', '.......', '..wis..', '.......', '.......'],
  // 14: combine WALL IS STOP (must break) with a pre-set FLAG IS WIN — the
  // one level requiring two mechanics at once, right before the capstone.
  ['P...#.F', '.......', '..wis..', '.......', '..gin..', '.......', '.biu...'],
  // 15: largest board, combine a WIN tile that must be assembled with two
  // decorative rules already active elsewhere.
  [
    'P.......',
    '........',
    '........',
    '.gi.n..F',
    '........',
    '.biu....',
    '.wis....',
    '........',
  ],
];

class RuleBreakerScreen extends StatefulWidget {
  const RuleBreakerScreen({super.key, required this.ctx});

  final GameLevelContext ctx;

  @override
  State<RuleBreakerScreen> createState() => _RuleBreakerScreenState();
}

class _RuleBreakerScreenState extends State<RuleBreakerScreen> {
  late int _width;
  late int _height;
  late List<GameObject> _objects;
  late GameObject _player;
  final Set<Point<int>> _borders = {};
  final Set<String> _activeRules = {};
  final List<List<Point<int>>> _history = [];
  int _moves = 0;
  bool _won = false;

  int get _level => widget.ctx.level;

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }

  /// Parses the current level's ASCII layout into fresh [_objects] and
  /// resets all mutable play state. Called from [initState] and again from
  /// [_restartLevel] so a same-level restart re-lays-out the level exactly
  /// as it started, instead of duplicating this parsing logic.
  void _loadLevel() {
    final rows = _levels[_level - 1];
    _height = rows.length;
    _width = rows[0].length;
    _objects = [];
    _borders.clear();
    var nextId = 0;
    for (var r = 0; r < _height; r++) {
      final row = rows[r];
      for (var c = 0; c < _width; c++) {
        final ch = row[c];
        if (ch == '.') continue;
        if (ch == 'X') {
          _borders.add(Point(r, c));
          continue;
        }
        final kind = _charToKind[ch];
        if (kind == null) continue;
        _objects.add(GameObject(id: nextId++, kind: kind, row: r, col: c));
      }
    }
    _player = _objects.firstWhere((o) => o.kind == TileKind.player);
    _moves = 0;
    _won = false;
    _history.clear();
    _rescanRules();
  }

  /// Resets the current level attempt back to its just-started layout —
  /// distinct from [_undo] (steps back one move) and from "Give up"
  /// (`widget.ctx.onExit()`, leaves the screen entirely).
  void _restartLevel() {
    Sfx.tap();
    setState(_loadLevel);
  }

  GameObject? _at(int r, int c, {GameObject? exclude}) {
    for (final o in _objects) {
      if (o == exclude) continue;
      if (o.row == r && o.col == c) return o;
    }
    return null;
  }

  bool _isBorderOrOutOfBounds(int r, int c) {
    if (r < 0 || r >= _height || c < 0 || c >= _width) return true;
    return _borders.contains(Point(r, c));
  }

  bool _hasProperty(TileKind nounKind, String property) {
    return _activeRules.contains('${nounKind.name}|$property');
  }

  void _tryRule(int r0, int c0, int dr, int dc) {
    final a = _at(r0, c0);
    final b = _at(r0 + dr, c0 + dc);
    final d = _at(r0 + 2 * dr, c0 + 2 * dc);
    if (a == null || b == null || d == null) return;
    if (!a.isWordTile || !b.isWordTile || !d.isWordTile) return;
    if (b.kind != TileKind.wordIs) return;
    final noun = _wordToNoun[a.kind];
    final property = _wordToProperty[d.kind];
    if (noun == null || property == null) return;
    _activeRules.add('${noun.name}|$property');
  }

  void _rescanRules() {
    _activeRules.clear();
    for (var r = 0; r < _height; r++) {
      for (var c = 0; c <= _width - 3; c++) {
        _tryRule(r, c, 0, 1);
      }
    }
    for (var c = 0; c < _width; c++) {
      for (var r = 0; r <= _height - 3; r++) {
        _tryRule(r, c, 1, 0);
      }
    }
  }

  List<Point<int>> _snapshot() => [
    for (final o in _objects) Point(o.row, o.col),
  ];

  void _restore(List<Point<int>> snap) {
    for (var i = 0; i < _objects.length; i++) {
      _objects[i].row = snap[i].x;
      _objects[i].col = snap[i].y;
    }
  }

  void _checkWin() {
    for (final o in _objects) {
      if (!_nounKinds.contains(o.kind)) continue;
      if (o.row == _player.row &&
          o.col == _player.col &&
          _hasProperty(o.kind, 'win')) {
        _won = true;
        return;
      }
    }
  }

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

  /// This game's rules mutate mid-play (pushing word-tiles rewrites what's
  /// walkable), so a real "next correct move" hint needs a search over that
  /// changing rule set — out of scope here. The undo stack already exists
  /// for the cheaper consolation: nudge the player toward re-reading the
  /// active rules rather than guessing blind.
  void _showHint() {
    final labels = _activeRuleLabels();
    final message = labels.isEmpty
        ? 'No rules are active yet — push word-tiles into a row to form '
              'NOUN IS PROPERTY.'
        : 'Active rules: ${labels.join(', ')}. Look for a WIN tile, or push '
              'a word out of formation to break a rule blocking your path.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _move(int dr, int dc) {
    if (_won) return;
    final nr = _player.row + dr;
    final nc = _player.col + dc;
    if (_isBorderOrOutOfBounds(nr, nc)) return;

    final occupant = _at(nr, nc, exclude: _player);
    var moved = false;
    final before = _snapshot();

    if (occupant == null) {
      _player.row = nr;
      _player.col = nc;
      moved = true;
    } else if (occupant.isWordTile) {
      final br = nr + dr;
      final bc = nc + dc;
      if (!_isBorderOrOutOfBounds(br, bc) && _at(br, bc) == null) {
        occupant.row = br;
        occupant.col = bc;
        _player.row = nr;
        _player.col = nc;
        moved = true;
      }
    } else if (_hasProperty(occupant.kind, 'win')) {
      // WIN objects are always walkable so the player can reach them.
      _player.row = nr;
      _player.col = nc;
      moved = true;
    } else if (_hasProperty(occupant.kind, 'push')) {
      final br = nr + dr;
      final bc = nc + dc;
      if (!_isBorderOrOutOfBounds(br, bc) && _at(br, bc) == null) {
        occupant.row = br;
        occupant.col = bc;
        _player.row = nr;
        _player.col = nc;
        moved = true;
      }
    } else if (_hasProperty(occupant.kind, 'stop')) {
      // blocked
    } else {
      // neutral noun object with no active rule: purely decorative, walkable.
      _player.row = nr;
      _player.col = nc;
      moved = true;
    }

    if (!moved) return;

    _history.add(before);
    _moves++;
    _rescanRules();
    _checkWin();
    setState(() {});
    if (_won) {
      Future.microtask(() => widget.ctx.onComplete(stars: 3));
    }
  }

  void _undo() {
    if (_won || _history.isEmpty) return;
    setState(() {
      _restore(_history.removeLast());
      _moves = _moves > 0 ? _moves - 1 : 0;
      _rescanRules();
    });
  }

  List<String> _activeRuleLabels() {
    final labels = <String>[];
    for (final rule in _activeRules) {
      final parts = rule.split('|');
      final noun = TileKind.values.firstWhere((k) => k.name == parts[0]);
      labels.add('${_nounLabel[noun]} IS ${parts[1].toUpperCase()}');
    }
    labels.sort();
    return labels;
  }

  ({IconData icon, Color color}) _nounVisual(TileKind kind) {
    switch (kind) {
      case TileKind.wall:
        return (icon: Icons.square_rounded, color: Colors.grey);
      case TileKind.box:
        return (icon: Icons.crop_square_rounded, color: Colors.orange);
      case TileKind.rock:
        return (icon: Icons.circle_rounded, color: const Color(0xFF8D6E63));
      case TileKind.flag:
        return (icon: Icons.flag_rounded, color: AppTheme.success);
      default:
        return (icon: Icons.help_outline, color: AppTheme.textSecondary);
    }
  }

  Color? _ruleBorderColor(TileKind kind) {
    if (_hasProperty(kind, 'win')) return AppTheme.warning;
    if (_hasProperty(kind, 'stop')) return AppTheme.danger;
    if (_hasProperty(kind, 'push')) return AppTheme.accent;
    return null;
  }

  Widget _buildCell(int r, int c) {
    if (_borders.contains(Point(r, c))) {
      return Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(6),
        ),
      );
    }

    final occupant = _at(r, c, exclude: _player);
    final hasPlayer = _player.row == r && _player.col == c;

    Widget base;
    if (occupant == null) {
      base = Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(6),
        ),
      );
    } else if (occupant.isWordTile) {
      base = Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: AppTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.accentSoft, width: 1.5),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              _wordLabel[occupant.kind] ?? '',
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppTheme.textPrimary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      );
    } else {
      final visual = _nounVisual(occupant.kind);
      final ruleColor = _ruleBorderColor(occupant.kind);
      base = Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: visual.color.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(10),
          border: ruleColor != null
              ? Border.all(color: ruleColor, width: 2.5)
              : null,
        ),
        alignment: Alignment.center,
        child: Icon(visual.icon, color: visual.color, size: 26),
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
        Icon(Icons.person_rounded, color: AppTheme.accent, size: 28),
      ],
    );
  }

  Widget _dpadButton(IconData icon, int dr, int dc, String label) {
    return IconButton(
      onPressed: () => _move(dr, dc),
      icon: Icon(icon, color: AppTheme.textPrimary),
      style: IconButton.styleFrom(backgroundColor: AppTheme.surfaceHigh),
      tooltip: 'Move $label',
    );
  }

  @override
  Widget build(BuildContext context) {
    final ruleLabels = _activeRuleLabels();
    return Scaffold(
      appBar: AppBar(
        title: Text('Level $_level'),
        actions: [
          ...gameActions(
            context: context,
            def: ruleBreakerDefinition,
            ctx: widget.ctx,
            onHint: _showHint,
            onRestart: _restartLevel,
          ),
          IconButton(
            icon: const Icon(Icons.flag_outlined),
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
                TextButton.icon(
                  onPressed: _history.isEmpty ? null : _undo,
                  icon: const Icon(Icons.undo_rounded, size: 18),
                  label: const Text('Undo'),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: ruleLabels.isEmpty
                  ? [
                      Center(
                        child: Text(
                          'No active rules',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ]
                  : [
                      for (final label in ruleLabels)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Chip(
                            label: Text(
                              label,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            backgroundColor: AppTheme.accentSoft,
                            visualDensity: VisualDensity.compact,
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
                    padding: const EdgeInsets.all(16),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _width * _height,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _width,
                      ),
                      itemBuilder: (context, index) {
                        final r = index ~/ _width;
                        final c = index % _width;
                        return _buildCell(r, c);
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
              'Push word-tiles to form NOUN IS PROPERTY rules, then reach a WIN tile',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
