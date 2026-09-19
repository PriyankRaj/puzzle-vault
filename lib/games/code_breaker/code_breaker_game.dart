import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/game_definition.dart';
import '../../core/game_level_context.dart';
import '../../core/motion.dart';
import '../../core/sound.dart';
import '../../core/widgets/game_actions.dart';
import '../../core/widgets/result_dialog.dart';

/// Original deduction puzzle: a Mastermind-style code-breaking mechanic
/// (public domain since the 1970s pegs-and-board version — no board game's
/// name or art is referenced here, only the generic "guess the hidden
/// sequence, get exact/partial feedback" idea). 15 levels; peg count and
/// palette size scale up together to grow the search space, not the guess
/// budget, which stays fixed.
final GameDefinition codeBreakerDefinition = GameDefinition(
  id: 'code_breaker',
  title: 'Code Breaker',
  tagline: 'Crack the secret color code before you run out of guesses',
  icon: Icons.password_rounded,
  tint: const GameTint(Color(0xFFBEF264), Color(0xFF3F6212)),
  mode: GameMode.levels,
  levelCount: 15,
  helpText:
      'A secret sequence of colored pegs is hidden. Tap colors from the '
      'palette to fill your guess row, then submit it. Each submitted '
      'guess is scored: a filled dot means one peg is the right color in '
      'the right spot, a ring means the right color in the wrong spot. Use '
      'that feedback to narrow down the code before you run out of '
      'guesses.',
  builder: (context, ctx) => CodeBreakerScreen(ctx: ctx),
);

class _PegColor {
  const _PegColor(this.name, this.color, this.icon);
  final String name;
  final Color color;
  final IconData icon;
}

/// Fixed, theme-independent palette — these are semantic game colors (like
/// `rule_breaker`'s icon/color pairs), not brand tokens, so they stay the
/// same in light and dark mode. Each also gets a distinct icon shape so the
/// puzzle stays solvable without relying on color perception alone.
const List<_PegColor> _palette = [
  _PegColor('Red', Color(0xFFEF4444), Icons.circle_rounded),
  _PegColor('Blue', Color(0xFF3B82F6), Icons.square_rounded),
  _PegColor('Green', Color(0xFF22C55E), Icons.change_history_rounded),
  _PegColor('Yellow', Color(0xFFEAB308), Icons.star_rounded),
  _PegColor('Purple', Color(0xFFA855F7), Icons.diamond_rounded),
  _PegColor('Orange', Color(0xFFF97316), Icons.hexagon_rounded),
];

const int _maxGuesses = 10;

class _GuessResult {
  const _GuessResult(this.guess, this.exact, this.colorOnly);
  final List<int> guess;
  final int exact;
  final int colorOnly;
}

class CodeBreakerScreen extends StatefulWidget {
  const CodeBreakerScreen({super.key, required this.ctx});

  final GameLevelContext ctx;

  @override
  State<CodeBreakerScreen> createState() => _CodeBreakerScreenState();
}

class _CodeBreakerScreenState extends State<CodeBreakerScreen> {
  late int _pegCount;
  late int _colorCount;
  late List<int> _secret;
  late List<int?> _current;
  final List<_GuessResult> _history = [];
  int _guessesLeft = _maxGuesses;
  bool _failed = false;

  int get _level => widget.ctx.level;

  @override
  void initState() {
    super.initState();
    _startLevel();
  }

  /// Deterministic per level (same `4000 + level` seed formula every time)
  /// so a failed attempt's "Retry" reproduces the exact same code, and so a
  /// logic test can replicate this generation locally instead of reaching
  /// into private state.
  void _startLevel() {
    _pegCount = _level <= 5
        ? 4
        : _level <= 10
        ? 4
        : 5;
    _colorCount = _level <= 5
        ? 4
        : _level <= 10
        ? 5
        : 6;
    final rng = Random(4000 + _level);
    _secret = List.generate(_pegCount, (_) => rng.nextInt(_colorCount));
    _current = List<int?>.filled(_pegCount, null);
    _history.clear();
    _guessesLeft = _maxGuesses;
    _failed = false;
  }

  void _retry() {
    Sfx.tap();
    setState(_startLevel);
  }

  void _pickColor(int colorIndex) {
    if (_failed) return;
    final slot = _current.indexWhere((c) => c == null);
    if (slot == -1) return;
    setState(() => _current[slot] = colorIndex);
  }

  void _clearSlot(int slot) {
    if (_failed || _current[slot] == null) return;
    setState(() => _current[slot] = null);
  }

  bool get _guessReady => !_current.contains(null);

  /// Standard Mastermind scoring: `exact` counts pegs matching in both
  /// color and position; `colorOnly` counts additional pegs that match in
  /// color but not position, capped per-color by how many of that color
  /// remain unmatched on each side (so duplicate colors can't be double
  /// counted on either side).
  ({int exact, int colorOnly}) _score(List<int> guess) {
    var exact = 0;
    final secretRemainder = <int, int>{};
    final guessRemainder = <int, int>{};
    for (var i = 0; i < _pegCount; i++) {
      if (guess[i] == _secret[i]) {
        exact++;
      } else {
        secretRemainder[_secret[i]] = (secretRemainder[_secret[i]] ?? 0) + 1;
        guessRemainder[guess[i]] = (guessRemainder[guess[i]] ?? 0) + 1;
      }
    }
    var colorOnly = 0;
    for (final entry in guessRemainder.entries) {
      final avail = secretRemainder[entry.key] ?? 0;
      colorOnly += min(entry.value, avail);
    }
    return (exact: exact, colorOnly: colorOnly);
  }

  void _submit() {
    if (!_guessReady || _failed) return;
    final guess = _current.map((c) => c!).toList();
    final result = _score(guess);
    setState(() {
      _history.insert(0, _GuessResult(guess, result.exact, result.colorOnly));
      _guessesLeft--;
      _current = List<int?>.filled(_pegCount, null);
    });

    if (result.exact == _pegCount) {
      final used = _maxGuesses - _guessesLeft;
      final stars = used <= _pegCount + 1
          ? 3
          : used <= _pegCount + 4
          ? 2
          : 1;
      Future.microtask(() => widget.ctx.onComplete(stars: stars));
      return;
    }
    if (_guessesLeft <= 0) {
      setState(() => _failed = true);
      final secretNames = _secret.map((i) => _palette[i].name).join(', ');
      Future.microtask(() {
        if (!mounted) return;
        showLevelFailedDialog(
          context,
          message: 'Out of guesses. The code was: $secretNames.',
          onRetry: _retry,
          onMenu: widget.ctx.onExit,
        );
      });
    }
  }

  /// A real deduction shortcut, not a heuristic nudge: reveals the true
  /// color of one position the most recent guess got wrong (or position 1,
  /// before any guess has been made).
  void _showHint() {
    var target = 0;
    if (_history.isNotEmpty) {
      final last = _history.first.guess;
      final wrong = [
        for (var i = 0; i < _pegCount; i++)
          if (last[i] != _secret[i]) i,
      ];
      if (wrong.isNotEmpty) target = wrong[Random().nextInt(wrong.length)];
    }
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Position ${target + 1} is ${_palette[_secret[target]].name}.',
          ),
        ),
      );
  }

  Widget _peg(_PegColor c, {double size = 40}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: c.color.withValues(alpha: 0.45),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(c.icon, size: size * 0.55, color: Colors.white),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildCurrentGuessRow() {
    // The next empty slot gets a bold, dashed-look accent ring so it's
    // obvious at a glance where the next palette tap will land, instead of
    // every empty slot looking identically inert.
    final nextSlot = _current.indexWhere((c) => c == null);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _pegCount; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Semantics(
              button: true,
              label: _current[i] == null
                  ? 'Guess slot ${i + 1}, empty'
                  : 'Guess slot ${i + 1}, ${_palette[_current[i]!].name}, tap to clear',
              child: GestureDetector(
                key: ValueKey('slot_$i'),
                onTap: () => _clearSlot(i),
                child: AnimatedContainer(
                  duration: Motion.ms(150),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _current[i] == null
                        ? AppTheme.surfaceHigh
                        : _palette[_current[i]!].color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: i == nextSlot
                          ? AppTheme.accent
                          : AppTheme.accent.withValues(alpha: 0.35),
                      width: i == nextSlot ? 3 : 1.5,
                    ),
                    boxShadow: _current[i] == null
                        ? null
                        : [
                            BoxShadow(
                              color: _palette[_current[i]!].color.withValues(
                                alpha: 0.4,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                  ),
                  alignment: Alignment.center,
                  child: _current[i] == null
                      ? null
                      : Icon(
                          _palette[_current[i]!].icon,
                          size: 26,
                          color: Colors.white,
                        ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPalette() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 14,
      children: [
        for (var i = 0; i < _colorCount; i++)
          Semantics(
            button: true,
            label: 'Pick ${_palette[i].name}',
            child: InkWell(
              key: ValueKey('palette_$i'),
              onTap: () => _pickColor(i),
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: _peg(_palette[i], size: 52),
              ),
            ),
          ),
      ],
    );
  }

  /// A labeled score chip instead of a bare row of tiny dots — "2 exact"
  /// and "1 close" are spelled out so the feedback is legible at a glance
  /// rather than requiring the player to count near-invisible pips.
  Widget _scoreChip({
    required IconData icon,
    required int count,
    required String label,
    required Color color,
  }) {
    if (count == 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$count $label',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_rounded,
              size: 36,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              'Your guesses will appear here',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final attemptNumber = _history.length - index;
        final entry = _history[index];
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: AppTheme.surfaceHigh,
                child: Text(
                  '$attemptNumber',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              for (final colorIndex in entry.guess)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _peg(_palette[colorIndex], size: 32),
                ),
              const Spacer(),
              Wrap(
                children: [
                  _scoreChip(
                    icon: Icons.check_circle_rounded,
                    count: entry.exact,
                    label: 'exact',
                    color: AppTheme.success,
                  ),
                  _scoreChip(
                    icon: Icons.swap_horiz_rounded,
                    count: entry.colorOnly,
                    label: 'close',
                    color: AppTheme.warning,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Code Breaker · Level $_level'),
        actions: [
          ...gameActions(
            context: context,
            def: codeBreakerDefinition,
            ctx: widget.ctx,
            onHint: _showHint,
            onRestart: _retry,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (_guessesLeft <= 3
                              ? AppTheme.danger
                              : AppTheme.accent)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Guesses left: $_guessesLeft',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: _guessesLeft <= 3
                            ? AppTheme.danger
                            : AppTheme.accent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    '$_colorCount colors · $_pegCount pegs',
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _sectionLabel('Your guess'),
            ),
          ),
          _buildCurrentGuessRow(),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _sectionLabel('Palette'),
            ),
          ),
          _buildPalette(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const ValueKey('submit_guess'),
                onPressed: _guessReady && !_failed ? _submit : null,
                child: const Text('Submit guess'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: AppTheme.success,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'exact = right color & spot',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.swap_horiz_rounded,
                      size: 14,
                      color: AppTheme.warning,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'close = right color, wrong spot',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          Expanded(child: _buildHistory()),
        ],
      ),
    );
  }
}
