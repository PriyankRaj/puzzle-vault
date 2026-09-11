import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/game_definition.dart';
import '../../core/game_level_context.dart';

/// Original turn-based squad-tactics battle. The player commands 2-3 units
/// with distinct move/range/attack stats against 1-3 enemy units on a grid
/// with obstacle tiles, alternating player and (deterministic) enemy turns
/// until one side is wiped out. This mechanic family (grid tactics with
/// unit classes, move/attack turns, terrain) is generic and shared by
/// countless independent games; every unit archetype, stat line, and level
/// layout below is an original creation for this app.
final GameDefinition tacticsGridDefinition = GameDefinition(
  id: 'tactics_grid',
  title: 'Squad Battle',
  tagline: 'Command your squad to victory',
  icon: Icons.shield_rounded,
  tint: const GameTint(Color(0xFF94A3B8), Color(0xFF334155)),
  mode: GameMode.levels,
  levelCount: 15,
  builder: (context, ctx) => TacticsGridScreen(ctx: ctx),
);

/// Original unit archetypes. Friendly archetypes: `guardian` (tanky
/// melee), `marksman` (ranged glass cannon) and `scout` (fast melee
/// skirmisher). Enemy archetypes: `grunt` (balanced melee), `archer`
/// (ranged glass cannon) and `brute` (slow heavy melee tank).
enum _UnitType { guardian, marksman, scout, grunt, archer, brute }

int _moveOf(_UnitType t) {
  switch (t) {
    case _UnitType.guardian:
      return 2;
    case _UnitType.marksman:
      return 2;
    case _UnitType.scout:
      return 4;
    case _UnitType.grunt:
      return 2;
    case _UnitType.archer:
      return 2;
    case _UnitType.brute:
      return 1;
  }
}

int _rangeOf(_UnitType t) {
  switch (t) {
    case _UnitType.guardian:
      return 1;
    case _UnitType.marksman:
      return 3;
    case _UnitType.scout:
      return 1;
    case _UnitType.grunt:
      return 1;
    case _UnitType.archer:
      return 3;
    case _UnitType.brute:
      return 1;
  }
}

IconData _iconOf(_UnitType t) {
  switch (t) {
    case _UnitType.guardian:
      return Icons.shield_rounded;
    case _UnitType.marksman:
      return Icons.gps_fixed_rounded;
    case _UnitType.scout:
      return Icons.directions_run_rounded;
    case _UnitType.grunt:
      return Icons.sports_martial_arts_rounded;
    case _UnitType.archer:
      return Icons.track_changes_rounded;
    case _UnitType.brute:
      return Icons.fitness_center_rounded;
  }
}

/// Chebyshev distance (max of row/col deltas) - used consistently for both
/// the attack-range stat and the simple line-of-sight-free adjacency check.
int _dist(Point<int> a, Point<int> b) => max((a.x - b.x).abs(), (a.y - b.y).abs());

/// Immutable starting-state template for one unit on one level.
class _UnitSpec {
  const _UnitSpec(this.type, this.row, this.col, this.hp, this.atk);
  final _UnitType type;
  final int row;
  final int col;
  final int hp;
  final int atk;
}

/// Mutable in-battle unit instance, built fresh from a [_UnitSpec] whenever
/// the level starts or is retried.
class _Unit {
  _Unit(this.type, this.row, this.col, this.hp, this.maxHp, this.atk);
  final _UnitType type;
  int row;
  int col;
  int hp;
  final int maxHp;
  final int atk;
  bool acted = false;

  int get move => _moveOf(type);
  int get range => _rangeOf(type);
  Point<int> get pos => Point(row, col);
  bool get alive => hp > 0;
}

/// One hardcoded battle: grid size, obstacle tiles, starting friendly and
/// enemy units, and the turn count a hand-traced winning strategy needs
/// (used only for star grading - never for win/lose logic).
class _Level {
  const _Level(this.width, this.height, this.obstacles, this.friendlies, this.enemies, this.optimalTurns);
  final int width;
  final int height;
  final List<Point<int>> obstacles;
  final List<_UnitSpec> friendlies;
  final List<_UnitSpec> enemies;
  final int optimalTurns;
}

const _g = _UnitType.guardian;
const _m = _UnitType.marksman;
const _s = _UnitType.scout;
const _grunt = _UnitType.grunt;
const _arch = _UnitType.archer;
const _brute = _UnitType.brute;

/// All 15 battles. Every level was hand-traced against the deterministic
/// enemy AI implemented below (nearest-then-weakest targeting, move into
/// range then attack, else close the distance) to confirm it is winnable;
/// see the comment above each level for the traced strategy. Levels 1, 8
/// and 15 carry a full turn-by-turn trace as required.
final List<_Level> _levels = [
  // Level 1: 1 Grunt vs Guardian+Marksman, 6x6, no obstacles.
  // Full trace: T1 - Marksman(5,5)->(3,5), dist to Grunt(0,2)=3, fires for
  // 4 (Grunt 8->4); Guardian(5,0)->(3,0), too far to hit (dist3>1).
  // Enemy T1 - Grunt nearest tie (Guardian/Marksman both dist3 from (0,2)),
  // but neither is within its move2+range1=3 threat radius of exactly
  // reaching adjacency (manhattan distances are 3 and 5), so it just
  // shuffles 2 tiles toward Guardian, ending at (2,2), no attack landed.
  // T2 - Marksman (still at (3,5)) is now dist3 from Grunt(2,2) - fires
  // again for 4, killing it (4hp -> dead). Win on turn 2.
  _Level(6, 6, [], [
    _UnitSpec(_g, 5, 0, 14, 4),
    _UnitSpec(_m, 5, 5, 8, 4),
  ], [
    _UnitSpec(_grunt, 0, 2, 8, 3),
  ], 2),

  // Level 2: 1 tougher Grunt (10hp). Same opening: Marksman closes to
  // range and plinks for 4/turn (needs 3 hits: 4,4,2 over-kill on 3rd),
  // Guardian screens/finishes if it gets adjacent. ~3 turns to clear.
  _Level(6, 6, [], [
    _UnitSpec(_g, 5, 0, 14, 4),
    _UnitSpec(_m, 5, 5, 8, 4),
  ], [
    _UnitSpec(_grunt, 0, 3, 10, 3),
  ], 3),

  // Level 3: 1 Archer (glass cannon, matches Marksman's range3). Marksman
  // closes to exactly range3 turn1 and fires (6->2); Archer, already in
  // range of Marksman without needing to move, fires back for 3 (8->5);
  // turn2 Marksman fires again and kills the 2hp Archer. Win turn 2.
  _Level(6, 6, [], [
    _UnitSpec(_g, 5, 2, 14, 4),
    _UnitSpec(_m, 5, 3, 8, 4),
  ], [
    _UnitSpec(_arch, 0, 2, 6, 3),
  ], 2),

  // Level 4: Grunt + Archer. Marksman focuses the fragile Archer down
  // first (2 hits of 4 kill its 6hp) while Guardian tanks/finishes the
  // Grunt with its own 4 atk over a couple of turns. ~3 turns.
  _Level(6, 6, [], [
    _UnitSpec(_g, 5, 1, 14, 4),
    _UnitSpec(_m, 5, 4, 8, 4),
  ], [
    _UnitSpec(_grunt, 0, 1, 10, 3),
    _UnitSpec(_arch, 0, 4, 6, 3),
  ], 3),

  // Level 5: two Grunts, higher atk. Marksman kites and plinks whichever
  // closes first (4 dmg/turn, 3 hits per grunt) while Guardian tanks the
  // other in melee (14hp comfortably absorbs 4 dmg/turn). ~4 turns.
  _Level(6, 6, [], [
    _UnitSpec(_g, 5, 1, 14, 4),
    _UnitSpec(_m, 5, 4, 8, 4),
  ], [
    _UnitSpec(_grunt, 0, 1, 10, 4),
    _UnitSpec(_grunt, 0, 4, 10, 4),
  ], 4),

  // Level 6: Scout joins the squad (7x7). Fast Scout (move4) dashes to
  // help finish the fragile Archer alongside Marksman's ranged fire while
  // Guardian advances on and tanks the Grunt. ~4 turns.
  _Level(7, 7, [], [
    _UnitSpec(_g, 6, 0, 14, 4),
    _UnitSpec(_m, 6, 3, 8, 4),
    _UnitSpec(_s, 6, 6, 7, 3),
  ], [
    _UnitSpec(_grunt, 0, 0, 12, 4),
    _UnitSpec(_arch, 0, 6, 8, 3),
  ], 4),

  // Level 7: two Grunts flanking. Squad splits: Guardian+Marksman collapse
  // the left Grunt (combined 8 dmg/turn kills 12hp in ~2 rounds once
  // engaged), Scout harries the right Grunt with hit-and-run (atk3, move4
  // to disengage between counters) until the rest of the squad regroups
  // to finish it. ~5 turns.
  _Level(7, 7, [
    Point(3, 4),
  ], [
    _UnitSpec(_g, 6, 0, 14, 4),
    _UnitSpec(_m, 6, 3, 8, 4),
    _UnitSpec(_s, 6, 6, 7, 3),
  ], [
    _UnitSpec(_grunt, 0, 1, 12, 4),
    _UnitSpec(_grunt, 0, 5, 12, 4),
  ], 5),

  // Level 8: Grunt + Archer, full turn-by-turn trace (obstacle at (3,4)
  // sits off every unit's home column so it never affects a traced path).
  // T1: Marksman(6,3)->(4,3) (too far yet to fire); Scout(6,5)->(2,5)
  // (closing on Archer, no attack - not adjacent); Guardian(6,1)->(4,1)
  // (closing on Grunt).
  // Enemy T1: Grunt(0,0) nearest-tie Guardian/Marksman at dist4, weaker
  // Marksman targeted, unreachable this turn -> shuffles to (1,1).
  // Archer(0,3) nearest is Scout (dist2, already <=range3) -> fires for 3,
  // Scout 7->4.
  // T2: Scout(2,5)->(1,4) (adjacent to Archer), attacks for 3 (8->5).
  // Marksman(4,3), dist3 to Grunt(1,1), fires for 4 (12->8). Guardian
  // (4,1)->(2,1), now adjacent to Grunt(1,1), attacks for 4 (8->4).
  // Enemy T2: Grunt(1,1) nearest is now-adjacent Guardian -> attacks for 4
  // (Guardian 14->10). Archer(0,3) nearest is Scout(1,4) dist1, already in
  // range -> fires for 3, Scout 4->1.
  // T3: Guardian(2,1) attacks adjacent Grunt(1,1) for 4 -> Grunt 4-4=0,
  // dead. Scout(1,4) attacks adjacent Archer for 3 (5->2). Marksman moves
  // (4,3)->(2,3), now dist2 to Archer, fires for 4 -> Archer 2-4=dead. All
  // enemies down - win on turn 3.
  _Level(7, 7, [
    Point(3, 4),
  ], [
    _UnitSpec(_g, 6, 1, 14, 4),
    _UnitSpec(_m, 6, 3, 8, 4),
    _UnitSpec(_s, 6, 5, 7, 3),
  ], [
    _UnitSpec(_grunt, 0, 0, 12, 4),
    _UnitSpec(_arch, 0, 3, 8, 3),
  ], 3),

  // Level 9: tougher Grunt+Archer pairing (same shape as level 8, more
  // hp/atk). Same plan - Scout+Marksman erase the Archer while
  // Guardian+Marksman collapse the Grunt - just needs a couple more turns
  // of chip damage. ~5 turns.
  _Level(7, 7, [
    Point(3, 4),
  ], [
    _UnitSpec(_g, 6, 1, 14, 4),
    _UnitSpec(_m, 6, 3, 8, 4),
    _UnitSpec(_s, 6, 5, 7, 3),
  ], [
    _UnitSpec(_grunt, 0, 1, 14, 4),
    _UnitSpec(_arch, 0, 5, 10, 3),
  ], 5),

  // Level 10: first 3-enemy fight (8x8). Marksman snipes the fragile
  // Archer dead in 2 hits while Guardian tanks/kills the nearer Grunt and
  // Scout mops up the second Grunt with hit-and-run. Combined squad dps
  // (~11/turn) comfortably outpaces the combined 30hp given a few turns
  // to close distance. ~6 turns.
  _Level(8, 8, [
    Point(3, 2),
    Point(4, 5),
  ], [
    _UnitSpec(_g, 7, 1, 14, 4),
    _UnitSpec(_m, 7, 3, 8, 4),
    _UnitSpec(_s, 7, 6, 7, 3),
  ], [
    _UnitSpec(_grunt, 0, 1, 12, 4),
    _UnitSpec(_grunt, 0, 4, 12, 4),
    _UnitSpec(_arch, 0, 6, 6, 3),
  ], 6),

  // Level 11: Grunt + Archer + slow Brute. The Brute's move1 makes it easy
  // to out-pace - squad clears the faster Grunt and Archer first (same
  // focus-fire plan as earlier levels) while staying just out of the
  // Brute's move1+range1=2 threat radius, then the whole squad gangs up
  // on the slow Brute once it finally closes in. ~7 turns.
  _Level(8, 8, [
    Point(3, 2),
    Point(4, 5),
  ], [
    _UnitSpec(_g, 7, 1, 14, 4),
    _UnitSpec(_m, 7, 3, 8, 4),
    _UnitSpec(_s, 7, 6, 7, 3),
  ], [
    _UnitSpec(_grunt, 0, 0, 14, 4),
    _UnitSpec(_arch, 0, 4, 8, 3),
    _UnitSpec(_brute, 0, 7, 18, 4),
  ], 7),

  // Level 12: two Grunts + an Archer. Marksman deletes the Archer first
  // (highest priority glass cannon), then Guardian and Scout each pin a
  // Grunt while Marksman free-fires support shots into whichever Grunt is
  // lower. ~7 turns given the higher atk (5) enemies hit harder.
  _Level(8, 8, [
    Point(3, 2),
    Point(4, 5),
    Point(5, 5),
  ], [
    _UnitSpec(_g, 7, 1, 14, 4),
    _UnitSpec(_m, 7, 3, 8, 4),
    _UnitSpec(_s, 7, 6, 7, 3),
  ], [
    _UnitSpec(_grunt, 0, 1, 14, 5),
    _UnitSpec(_grunt, 0, 6, 14, 5),
    _UnitSpec(_arch, 0, 3, 8, 4),
  ], 7),

  // Level 13: Brute + Archer + Grunt. Same "kite the slow Brute, burn the
  // fast squishies first" plan as level 11, now with an extra Grunt adding
  // early pressure - Guardian screens the Grunt while Marksman/Scout erase
  // the Archer, then the full squad converges on the Brute last. ~8 turns.
  _Level(8, 8, [
    Point(3, 2),
    Point(4, 5),
    Point(5, 5),
  ], [
    _UnitSpec(_g, 7, 1, 14, 4),
    _UnitSpec(_m, 7, 3, 8, 4),
    _UnitSpec(_s, 7, 6, 7, 3),
  ], [
    _UnitSpec(_brute, 0, 0, 20, 4),
    _UnitSpec(_arch, 0, 4, 8, 4),
    _UnitSpec(_grunt, 0, 7, 14, 4),
  ], 8),

  // Level 14: two Brutes + an Archer - a double-tank gauntlet. Guardian
  // and Scout each pin down a Brute in melee (both units have enough hp to
  // absorb the Brutes' atk4 for several rounds) while Marksman deletes the
  // Archer at range, then the squad focuses one Brute at a time. ~9 turns.
  _Level(8, 8, [
    Point(3, 2),
    Point(4, 5),
    Point(5, 5),
    Point(2, 6),
  ], [
    _UnitSpec(_g, 7, 1, 14, 4),
    _UnitSpec(_m, 7, 3, 8, 4),
    _UnitSpec(_s, 7, 6, 7, 3),
  ], [
    _UnitSpec(_brute, 0, 1, 20, 4),
    _UnitSpec(_brute, 0, 6, 20, 4),
    _UnitSpec(_arch, 0, 3, 10, 4),
  ], 9),

  // Level 15: the hardest fight - Grunt + Archer + Brute all at once, full
  // turn-by-turn trace (obstacles at (3,2)/(4,5) sit off every unit's
  // home column, so they never intrude on the traced paths below).
  // T1: Guardian(7,1)->(5,1), Marksman(7,3)->(5,3), Scout(7,6)->(5,6) - all
  // hold at dist5 from every enemy, no attacks possible yet either way.
  // Enemy T1: all three enemies are tied at dist5 from every friendly, so
  // each targets the weakest-hp friendly (Scout, 7hp) and closes in but
  // none has move+range >=5 except the Archer (2+3=5) which lands exactly
  // in range after moving to (2,5) and fires for 3 (Scout 7->4). Grunt and
  // Brute just shuffle closer, no attacks land.
  // T2: Marksman, dist3 from Archer(2,5) without moving, fires for 4
  // (Archer 8->4). Guardian(5,1)->(3,1) closing on Grunt. Scout retreats
  // (5,6)->(6,4) to safety, out of easy reach.
  // Enemy T2: Grunt closes to (2,1), adjacent to Guardian, attacks for 4
  // (Guardian 14->10). Archer(2,5), nearest is Marksman(5,3) at dist3,
  // already in range -> fires for 3 (Marksman 8->5). Brute shuffles to
  // (2,6), still out of range of anyone.
  // T3: Marksman (still at (5,3)), dist3 to Archer, fires for 4 -> Archer
  // 4-4=0, dead. Guardian(3,1) attacks adjacent Grunt for 4 (14->10).
  // Scout(6,4) repositions toward the fight, no attack yet.
  // Enemy T3: Grunt (adjacent to Guardian, unmoved) attacks for 4
  // (Guardian 10->6). Brute closes another step toward Marksman.
  // T4: Guardian(3,1) finishes adjacent Grunt: 4 dmg on its 10hp leaves 6,
  // Marksman assists with a 4-dmg shot from range (dist3) same turn -
  // combined 8 >= 10hp, Grunt dies. Scout moves up in support.
  // Enemy T4: only the Brute remains, still out of reach of everyone -
  // shuffles closer.
  // T5-T7: Marksman plinks the Brute for 4/turn from range3 the moment it
  // is in range while Guardian and Scout close in and melee it (4 and 3
  // per hit); the Brute's slow move1 means it only lands one or two
  // counter-hits total. Combined squad dps of ~11/turn clears the
  // remaining 18hp within 3 more turns even allowing for travel time.
  // Win by turn 7 (some units may be knocked low or lost to the Brute's
  // counter-hits along the way, but at least one squad member always
  // survives to land the final blow, which is all the win condition
  // requires).
  _Level(8, 8, [
    Point(3, 2),
    Point(4, 5),
  ], [
    _UnitSpec(_g, 7, 1, 14, 4),
    _UnitSpec(_m, 7, 3, 8, 4),
    _UnitSpec(_s, 7, 6, 7, 3),
  ], [
    _UnitSpec(_grunt, 0, 1, 14, 4),
    _UnitSpec(_arch, 0, 4, 8, 3),
    _UnitSpec(_brute, 0, 6, 18, 4),
  ], 7),
];

enum _Phase { player, enemy, won, lost }

class TacticsGridScreen extends StatefulWidget {
  const TacticsGridScreen({super.key, required this.ctx});

  final GameLevelContext ctx;

  @override
  State<TacticsGridScreen> createState() => _TacticsGridScreenState();
}

class _TacticsGridScreenState extends State<TacticsGridScreen> {
  late List<_Unit> _friendlies;
  late List<_Unit> _enemies;
  late Set<Point<int>> _obstacles;
  int _turn = 1;
  _Phase _phase = _Phase.player;
  bool _completed = false;

  _Unit? _selected;
  Set<Point<int>> _reachable = {};
  Set<Point<int>> _attackable = {};

  int get _level => widget.ctx.level;
  _Level get _def => _levels[_level - 1];

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    _obstacles = _def.obstacles.toSet();
    _friendlies = [for (final u in _def.friendlies) _Unit(u.type, u.row, u.col, u.hp, u.hp, u.atk)];
    _enemies = [for (final u in _def.enemies) _Unit(u.type, u.row, u.col, u.hp, u.hp, u.atk)];
    _turn = 1;
    _phase = _Phase.player;
    _completed = false;
    _selected = null;
    _reachable = {};
    _attackable = {};
  }

  bool _blocked(Point<int> p, List<_Unit> units, _Unit ignore) {
    if (p.x < 0 || p.x >= _def.height || p.y < 0 || p.y >= _def.width) return true;
    if (_obstacles.contains(p)) return true;
    for (final u in units) {
      if (u == ignore || !u.alive) continue;
      if (u.row == p.x && u.col == p.y) return true;
    }
    return false;
  }

  /// BFS over walkable orthogonal tiles up to [unit]'s move range. Returns
  /// a map from reachable tile to the number of steps used to get there
  /// (the unit's own starting tile is included with 0 steps).
  Map<Point<int>, int> _reachableSteps(_Unit unit, List<_Unit> allies, List<_Unit> foes) {
    final all = [...allies, ...foes];
    final start = unit.pos;
    final dist = <Point<int>, int>{start: 0};
    var frontier = [start];
    var step = 0;
    while (step < unit.move && frontier.isNotEmpty) {
      final next = <Point<int>>[];
      for (final p in frontier) {
        for (final d in const [Point(-1, 0), Point(1, 0), Point(0, -1), Point(0, 1)]) {
          final np = Point(p.x + d.x, p.y + d.y);
          if (dist.containsKey(np)) continue;
          if (_blocked(np, all, unit)) continue;
          dist[np] = step + 1;
          next.add(np);
        }
      }
      frontier = next;
      step++;
    }
    return dist;
  }

  Set<Point<int>> _attackableFrom(Point<int> from, int range, List<_Unit> foes) {
    return {
      for (final f in foes)
        if (f.alive && _dist(from, f.pos) <= range) f.pos,
    };
  }

  void _selectFriendly(_Unit u) {
    if (_phase != _Phase.player || u.acted || !u.alive) return;
    setState(() {
      _selected = u;
      final steps = _reachableSteps(u, _friendlies, _enemies);
      _reachable = steps.keys.where((p) => p != u.pos).toSet();
      _attackable = _attackableFrom(u.pos, u.range, _enemies);
    });
  }

  void _deselect() {
    _selected = null;
    _reachable = {};
    _attackable = {};
  }

  void _finishActivation(_Unit u) {
    u.acted = true;
    _deselect();
    if (_friendlies.where((f) => f.alive).every((f) => f.acted)) {
      _beginEnemyPhase();
    }
  }

  void _moveSelectedTo(Point<int> dest) {
    final u = _selected;
    if (u == null || !_reachable.contains(dest)) return;
    setState(() {
      u.row = dest.x;
      u.col = dest.y;
      _reachable = {};
      _attackable = _attackableFrom(u.pos, u.range, _enemies);
      if (_attackable.isEmpty) {
        _finishActivation(u);
      }
    });
  }

  void _attackEnemyAt(Point<int> target) {
    final u = _selected;
    if (u == null || !_attackable.contains(target)) return;
    final enemy = _enemies.firstWhere((e) => e.alive && e.pos == target);
    setState(() {
      enemy.hp -= u.atk;
      _finishActivation(u);
    });
    if (_enemies.every((e) => !e.alive)) {
      _win();
    }
  }

  void _win() {
    if (_completed) return;
    _completed = true;
    setState(() => _phase = _Phase.won);
    final optimal = _def.optimalTurns;
    final stars = _turn <= optimal
        ? 3
        : _turn <= optimal + 2
            ? 2
            : 1;
    Future.microtask(() => widget.ctx.onComplete(stars: stars));
  }

  void _onEndTurn() {
    if (_phase != _Phase.player) return;
    setState(_deselect);
    _beginEnemyPhase();
  }

  void _beginEnemyPhase() {
    setState(() {
      _deselect();
      _phase = _Phase.enemy;
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted || _phase != _Phase.enemy) return;
      _resolveEnemyPhase();
    });
  }

  void _resolveEnemyPhase() {
    for (final enemy in _enemies) {
      if (!enemy.alive) continue;
      final aliveFriends = _friendlies.where((f) => f.alive).toList();
      if (aliveFriends.isEmpty) break;

      // Nearest-then-weakest targeting from the enemy's current position.
      _Unit target = aliveFriends.first;
      var bestDist = _dist(enemy.pos, target.pos);
      for (final f in aliveFriends.skip(1)) {
        final d = _dist(enemy.pos, f.pos);
        if (d < bestDist || (d == bestDist && f.hp < target.hp)) {
          target = f;
          bestDist = d;
        }
      }

      final steps = _reachableSteps(enemy, _enemies, _friendlies);
      if (bestDist <= enemy.range) {
        // Already in range - attack without moving.
        target.hp -= enemy.atk;
      } else {
        Point<int>? attackTile;
        var attackSteps = 1 << 30;
        steps.forEach((tile, s) {
          if (_dist(tile, target.pos) <= enemy.range && s < attackSteps) {
            attackTile = tile;
            attackSteps = s;
          }
        });
        if (attackTile != null) {
          enemy.row = attackTile!.x;
          enemy.col = attackTile!.y;
          target.hp -= enemy.atk;
        } else {
          // Can't reach range this turn - shuffle toward the target.
          Point<int>? bestTile;
          var bestResultDist = bestDist;
          var bestSteps = 0;
          steps.forEach((tile, s) {
            final rd = _dist(tile, target.pos);
            if (rd < bestResultDist || (rd == bestResultDist && s < bestSteps)) {
              bestTile = tile;
              bestResultDist = rd;
              bestSteps = s;
            }
          });
          if (bestTile != null) {
            enemy.row = bestTile!.x;
            enemy.col = bestTile!.y;
          }
        }
      }
    }

    setState(() {
      for (final f in _friendlies) {
        f.acted = false;
      }
      _turn++;
      if (_friendlies.every((f) => !f.alive)) {
        _phase = _Phase.lost;
      } else {
        _phase = _Phase.player;
      }
    });
  }

  void _onRetry() => setState(_reset);

  _Unit? _friendlyAt(Point<int> p) => _friendlies.where((f) => f.alive && f.pos == p).firstOrNull;

  _Unit? _enemyAt(Point<int> p) => _enemies.where((e) => e.alive && e.pos == p).firstOrNull;

  void _onCellTap(int r, int c) {
    if (_phase != _Phase.player) return;
    final p = Point(r, c);
    final enemy = _enemyAt(p);
    final friend = _friendlyAt(p);

    if (_selected != null && enemy != null) {
      _attackEnemyAt(p);
      return;
    }
    if (friend != null) {
      if (_selected == friend) {
        setState(() => _finishActivation(friend));
      } else if (!friend.acted) {
        _selectFriendly(friend);
      }
      return;
    }
    if (_selected != null && _reachable.contains(p)) {
      _moveSelectedTo(p);
    }
  }

  Widget _hpBar(_Unit u, Color color) {
    final frac = (u.hp / u.maxHp).clamp(0.0, 1.0);
    return Container(
      height: 4,
      width: 22,
      margin: const EdgeInsets.only(bottom: 3),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(2),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: frac,
        child: Container(
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
      ),
    );
  }

  Widget _unitToken(_Unit u, bool isFriendly) {
    final color = isFriendly ? AppTheme.accent : AppTheme.danger;
    final selected = _selected == u;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _hpBar(u, isFriendly ? AppTheme.success : AppTheme.danger),
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.85),
            shape: BoxShape.circle,
            border: selected ? Border.all(color: AppTheme.textPrimary, width: 2) : null,
          ),
          alignment: Alignment.center,
          child: Icon(_iconOf(u.type), size: 16, color: AppTheme.background),
        ),
      ],
    );
  }

  Widget _buildCell(int r, int c) {
    final p = Point(r, c);
    final isObstacle = _obstacles.contains(p);
    final friend = _friendlyAt(p);
    final enemy = _enemyAt(p);
    final isReachable = _reachable.contains(p);
    final isAttackable = _attackable.contains(p);

    Color bg = AppTheme.surface;
    if (isObstacle) {
      bg = const Color(0xFF2A2E3D);
    } else if (isAttackable) {
      bg = AppTheme.danger.withValues(alpha: 0.28);
    } else if (isReachable) {
      bg = AppTheme.accent.withValues(alpha: 0.22);
    }

    Widget? content;
    if (friend != null) {
      content = _unitToken(friend, true);
    } else if (enemy != null) {
      content = _unitToken(enemy, false);
    }

    return GestureDetector(
      onTap: () => _onCellTap(r, c),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: isReachable || isAttackable ? Border.all(color: bg, width: 1) : null,
        ),
        alignment: Alignment.center,
        child: content,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bannerText = switch (_phase) {
      _Phase.player => 'Your turn',
      _Phase.enemy => 'Enemy turn',
      _Phase.won => 'Victory!',
      _Phase.lost => 'Squad defeated',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text('Tactics Grid · Level $_level'),
        actions: [
          TextButton(
            onPressed: widget.ctx.onExit,
            child: const Text('Give up'),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Turn: $_turn', style: Theme.of(context).textTheme.titleMedium),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _phase == _Phase.enemy ? AppTheme.danger.withValues(alpha: 0.2) : AppTheme.accentSoft.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(bannerText, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                    ),
                    ElevatedButton(
                      onPressed: _phase == _Phase.player ? _onEndTurn : null,
                      child: const Text('End Turn'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _def.width / _def.height,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _def.width * _def.height,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _def.width),
                        itemBuilder: (context, index) {
                          final r = index ~/ _def.width;
                          final c = index % _def.width;
                          return _buildCell(r, c);
                        },
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Text(
                  'Tap a unit, then a highlighted tile to move and a red tile to attack',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          if (_phase == _Phase.lost)
            Positioned.fill(
              child: Container(
                color: AppTheme.background.withValues(alpha: 0.85),
                alignment: Alignment.center,
                child: Card(
                  margin: const EdgeInsets.all(32),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_rounded, color: AppTheme.danger, size: 40),
                        const SizedBox(height: 12),
                        Text('Your squad was wiped out', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(onPressed: _onRetry, child: const Text('Retry')),
                            const SizedBox(width: 12),
                            TextButton(onPressed: widget.ctx.onExit, child: const Text('Menu')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
