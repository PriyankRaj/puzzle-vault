import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/game_definition.dart';
import '../../core/game_level_context.dart';
import '../../core/motion.dart';
import '../../core/sound.dart';
import '../../core/widgets/game_actions.dart';

/// Original mechanic: the player is shown one or more shuffled rows of
/// color chips, each row sampled along a smooth hue/lightness gradient
/// between two endpoint colors. The player must reorder the chips in each
/// row (via tap-to-select then tap-to-swap) so every row reads as a clean,
/// monotonic gradient again. 15 levels: lane count and chip count per lane
/// both scale up with difficulty.
final GameDefinition gradientSortDefinition = GameDefinition(
  id: 'gradient_sort',
  title: 'Color Sort',
  tagline: 'Arrange the chips into a perfect gradient',
  icon: Icons.gradient_rounded,
  tint: const GameTint(Color(0xFFF472B6), Color(0xFFBE185D)),
  mode: GameMode.levels,
  levelCount: 15,
  helpText:
      'Tap a chip, then tap another chip in the same row to swap them. '
      'Arrange every row so its colors flow smoothly from one endpoint to '
      'the other — fewer swaps earns more stars.',
  builder: (context, ctx) => GradientSortScreen(ctx: ctx),
);

/// One gradient row: [colors] holds the chip colors in their *correct*
/// sorted order (index 0 is the "start" endpoint, last index the "end"
/// endpoint). [order] holds, for each on-screen slot, which correct index
/// is currently displayed there. The lane is solved when [order] is the
/// identity permutation `[0, 1, ..., n - 1]`.
class _Lane {
  _Lane({required this.colors, required this.order, required this.minSwaps});

  final List<Color> colors;
  List<int> order;
  final int minSwaps;

  int get length => colors.length;

  bool get isSolved {
    for (var i = 0; i < order.length; i++) {
      if (order[i] != i) return false;
    }
    return true;
  }
}

class GradientSortScreen extends StatefulWidget {
  const GradientSortScreen({super.key, required this.ctx});

  final GameLevelContext ctx;

  @override
  State<GradientSortScreen> createState() => _GradientSortScreenState();
}

class _GradientSortScreenState extends State<GradientSortScreen> {
  late List<_Lane> _lanes;
  late int _totalMinSwaps;
  int _swapCount = 0;
  bool _finished = false;

  int? _selectedLane;
  int? _selectedChip;

  int get _level => widget.ctx.level;

  @override
  void initState() {
    super.initState();
    _setupLevel();
  }

  /// Builds this level's lanes from its fixed per-level seed, so calling
  /// this again (from [_restartLevel]) reproduces the exact same starting
  /// shuffle rather than a fresh random one.
  void _setupLevel() {
    final rng = Random(5000 + _level);

    final laneCount = _level <= 5
        ? 1
        : _level <= 10
        ? 2
        : 3;
    final chipCount = (5 + (_level - 1) ~/ 3).clamp(5, 9);

    _lanes = List.generate(laneCount, (_) => _buildLane(rng, chipCount));
    _totalMinSwaps = _lanes.fold(0, (sum, lane) => sum + lane.minSwaps);
  }

  /// Restores this level's starting arrangement in place — same seed, same
  /// shuffle, swap count and selection cleared — without leaving the screen
  /// or touching progress.
  void _restartLevel() {
    Sfx.tap();
    setState(() {
      _swapCount = 0;
      _finished = false;
      _selectedLane = null;
      _selectedChip = null;
      _setupLevel();
    });
  }

  _Lane _buildLane(Random rng, int chipCount) {
    final startHue = rng.nextDouble() * 360;
    // Keep endpoints far enough apart in hue that the gradient reads
    // clearly, while wrapping around the color wheel.
    final hueDelta = 80 + rng.nextDouble() * 160;
    final endHue = (startHue + hueDelta) % 360;
    final saturation = 0.55 + rng.nextDouble() * 0.3;
    final startLightness = 0.35 + rng.nextDouble() * 0.15;
    final endLightness = 0.55 + rng.nextDouble() * 0.2;

    final startColor = HSLColor.fromAHSL(
      1,
      startHue,
      saturation,
      startLightness,
    );
    final endColor = HSLColor.fromAHSL(1, endHue, saturation, endLightness);

    final colors = List.generate(chipCount, (i) {
      final t = chipCount == 1 ? 0.0 : i / (chipCount - 1);
      return HSLColor.lerp(startColor, endColor, t)!.toColor();
    });

    List<int> order;
    do {
      order = List.generate(chipCount, (i) => i)..shuffle(rng);
    } while (chipCount > 1 && _isIdentity(order));

    return _Lane(colors: colors, order: order, minSwaps: _minSwaps(order));
  }

  bool _isIdentity(List<int> perm) {
    for (var i = 0; i < perm.length; i++) {
      if (perm[i] != i) return false;
    }
    return true;
  }

  /// Minimum number of swaps to sort a permutation: for a permutation of
  /// N elements decomposed into disjoint cycles, the minimum swap count is
  /// `N - (number of cycles)`. E.g. [1, 0] is a single 2-cycle -> 2 - 1 = 1
  /// swap. [2, 0, 1] is a single 3-cycle -> 3 - 1 = 2 swaps.
  int _minSwaps(List<int> perm) {
    final n = perm.length;
    final visited = List.filled(n, false);
    var cycles = 0;
    for (var i = 0; i < n; i++) {
      if (visited[i]) continue;
      cycles++;
      var j = i;
      while (!visited[j]) {
        visited[j] = true;
        j = perm[j];
      }
    }
    return n - cycles;
  }

  void _onTapChip(int laneIndex, int chipIndex) {
    if (_finished) return;
    setState(() {
      if (_selectedLane == null) {
        _selectedLane = laneIndex;
        _selectedChip = chipIndex;
        return;
      }
      if (_selectedLane == laneIndex && _selectedChip == chipIndex) {
        // Tapping the same chip again deselects it.
        _selectedLane = null;
        _selectedChip = null;
        return;
      }
      if (_selectedLane != laneIndex) {
        // Selecting in a different lane just moves the selection there;
        // swaps only make sense within a single lane.
        _selectedLane = laneIndex;
        _selectedChip = chipIndex;
        return;
      }

      final lane = _lanes[laneIndex];
      final a = _selectedChip!;
      final b = chipIndex;
      final tmp = lane.order[a];
      lane.order[a] = lane.order[b];
      lane.order[b] = tmp;
      _swapCount++;
      _selectedLane = null;
      _selectedChip = null;
    });

    if (_lanes.every((lane) => lane.isSolved)) {
      _finished = true;
      final stars = _swapCount == _totalMinSwaps
          ? 3
          : _swapCount <= _totalMinSwaps + 2
          ? 2
          : 1;
      Future.microtask(() => widget.ctx.onComplete(stars: stars));
    }
  }

  /// Reuses the same cycle-decomposition logic as [_minSwaps] to find one
  /// swap that brings a chip home, then performs it through [_onTapChip]
  /// exactly as if the player had tapped those two chips — so it's a
  /// genuine correct move, not a duplicated swap implementation.
  void _showHint() {
    for (var laneIndex = 0; laneIndex < _lanes.length; laneIndex++) {
      final lane = _lanes[laneIndex];
      for (var i = 0; i < lane.length; i++) {
        if (lane.order[i] != i) {
          final j = lane.order[i];
          _onTapChip(laneIndex, i);
          _onTapChip(laneIndex, j);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Swapped two chips in row ${laneIndex + 1} closer to sorted.',
              ),
            ),
          );
          return;
        }
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Every row is already sorted!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gradient Sort · Level $_level'),
        actions: [
          ...gameActions(
            context: context,
            def: gradientSortDefinition,
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
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Swaps: $_swapCount',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < _lanes.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: _buildLaneWidget(i),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Tap a chip, then tap another in the same row to swap them.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLaneWidget(int laneIndex) {
    final lane = _lanes[laneIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Target preview: a thin bar showing the lane's true endpoint
        // colors, so the player knows what "sorted" should roughly look
        // like.
        Container(
          height: 10,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: LinearGradient(
              colors: [lane.colors.first, lane.colors.last],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        Row(
          children: [
            for (var slot = 0; slot < lane.length; slot++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _buildChip(laneIndex, slot),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildChip(int laneIndex, int slot) {
    final lane = _lanes[laneIndex];
    final color = lane.colors[lane.order[slot]];
    final selected = _selectedLane == laneIndex && _selectedChip == slot;

    return GestureDetector(
      onTap: () => _onTapChip(laneIndex, slot),
      child: AspectRatio(
        aspectRatio: 1,
        child: AnimatedContainer(
          duration: Motion.ms(120),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppTheme.textPrimary : Colors.transparent,
              width: 3,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppTheme.textPrimary.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}
