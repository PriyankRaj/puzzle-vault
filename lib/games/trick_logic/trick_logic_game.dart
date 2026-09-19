import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/game_definition.dart';
import '../../core/game_level_context.dart';
import '../../core/sound.dart';
import '../../core/widgets/game_actions.dart';

/// Original lateral-thinking puzzle set. Each level shows one short,
/// literally-worded instruction plus a small interactive widget that looks
/// deceptively simple — the "obvious" action is always a trap, and the
/// real solution only appears if you read the instruction carefully.
final GameDefinition trickLogicDefinition = GameDefinition(
  id: 'trick_logic',
  title: 'Brain Trick',
  tagline: 'Read carefully — the obvious answer is a trap',
  icon: Icons.psychology_alt_rounded,
  tint: const GameTint(Color(0xFFFACC15), Color(0xFFA16207)),
  mode: GameMode.levels,
  levelCount: 15,
  helpText:
      'Each level gives you a short instruction and a simple-looking '
      'control. Read the instruction word-for-word — the obvious action '
      'is usually a trap, and the real solution only appears if you '
      'follow the wording exactly.',
  builder: (context, ctx) => TrickLogicScreen(ctx: ctx),
);

/// Shared card used by every level to present its instruction text in a
/// consistent way.
Widget _instructionCard(String text) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: AppTheme.textPrimary,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
    ),
  );
}

void _hint(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Proactive, forward-looking nudges shown when the player taps the Hint
/// action — one per level. Unlike [_hint] (fired reactively, after a wrong
/// answer, to explain what went wrong), these are worded to point at each
/// level's trick *before* the player commits to an answer, without stating
/// the solution outright.
const Map<int, String> _forwardHints = {
  1:
      'Colors are lying to you here — read what the button actually says, '
      "not what shade it's painted.",
  2:
      "Don't just look at the checkbox — check whether the condition in the "
      'instruction is even true first.',
  3:
      'The number on screen isn\'t the slider\'s raw position — it\'s been '
      'flipped. Think about what raw value produces the target.',
  4:
      'The box wants a number, but the sentence is asking about the word '
      'itself, not the quantity it usually describes.',
  5:
      'One button is explicitly off-limits — the instruction tells you '
      'which one to leave alone.',
  6:
      'A tap is the obvious move, but "obvious" is usually the trap in this '
      'game — try holding your finger down instead.',
  7:
      'Order matters more than which icon looks more "correct" to press '
      'first — re-read which one comes first.',
  8:
      'The big, prominent button is drawing all your attention on purpose — '
      'scan the corners of the card for something smaller.',
  9:
      "Don't just pick numbers that feel special — check each one actually "
      'meets the mathematical definition given.',
  10:
      "Don't eyeball it — compare all three squares directly before you "
      'decide which one truly is the smallest.',
  11:
      'Not every tap you make is being counted — watch the score, not your '
      'own tap count, to know when you\'re done.',
  12:
      "You already know the arithmetic — the trap is in the format the "
      'answer needs to be typed in.',
  13:
      'The switches already match their own labels — that itself is a clue '
      'about what state they need to end up in.',
  14:
      "Don't estimate — the sentence has an exact, countable answer if you "
      'go letter by letter.',
  15:
      'Order matters, and one color is explicitly not part of that order — '
      'notice which shape needs to be skipped entirely.',
};

class TrickLogicScreen extends StatefulWidget {
  const TrickLogicScreen({super.key, required this.ctx});

  final GameLevelContext ctx;

  @override
  State<TrickLogicScreen> createState() => _TrickLogicScreenState();
}

class _TrickLogicScreenState extends State<TrickLogicScreen> {
  bool _solved = false;

  /// Bumped by [_restartLevel] and used as the level widget's key, so
  /// giving up mid-level (a checked box, a half-typed answer, a partial
  /// tap sequence) throws away that per-level widget's `State` and
  /// remounts it fresh, instead of merely resetting this screen's own
  /// `_solved` flag.
  int _attempt = 0;

  int get _level => widget.ctx.level;

  void _onSolved() {
    if (_solved) return;
    _solved = true;
    widget.ctx.onComplete(stars: 3);
  }

  /// Same-level restart reachable at any time from the AppBar — does not
  /// touch `widget.ctx` and shows no dialog, distinct from "Give up".
  void _restartLevel() {
    Sfx.tap();
    setState(() {
      _solved = false;
      _attempt++;
    });
  }

  void _showHint() {
    final hint = _forwardHints[_level] ?? 'Read the instruction word-for-word.';
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(hint)));
  }

  Widget _buildLevel(BuildContext context) {
    switch (_level) {
      case 1:
        return _level1(context, _onSolved);
      case 2:
        return _Level2(onSolved: _onSolved);
      case 3:
        return _Level3(onSolved: _onSolved);
      case 4:
        return _Level4(onSolved: _onSolved);
      case 5:
        return _Level5(onSolved: _onSolved);
      case 6:
        return _level6(context, _onSolved);
      case 7:
        return _Level7(onSolved: _onSolved);
      case 8:
        return _level8(context, _onSolved);
      case 9:
        return _Level9(onSolved: _onSolved);
      case 10:
        return _Level10(onSolved: _onSolved);
      case 11:
        return _Level11(onSolved: _onSolved);
      case 12:
        return _Level12(onSolved: _onSolved);
      case 13:
        return _Level13(onSolved: _onSolved);
      case 14:
        return _Level14(onSolved: _onSolved);
      case 15:
      default:
        return _Level15(onSolved: _onSolved);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Level $_level'),
        actions: [
          ...gameActions(
            context: context,
            def: trickLogicDefinition,
            ctx: widget.ctx,
            onHint: _showHint,
            onRestart: _restartLevel,
          ),
          IconButton(
            onPressed: widget.ctx.onExit,
            tooltip: 'Give up',
            icon: const Icon(Icons.flag_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: KeyedSubtree(
            key: ValueKey(_attempt),
            child: _buildLevel(context),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Level 1 — "Tap the button labelled GO" — colors are swapped vs. labels.
// ---------------------------------------------------------------------------

Widget _level1(BuildContext context, VoidCallback onSolved) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _instructionCard(
        'Tap the button whose LABEL reads "GO". Ignore its color.',
      ),
      const SizedBox(height: 40),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
            onPressed: () => _hint(context, 'That button is labelled STOP.'),
            child: const Text('STOP'),
          ),
          const SizedBox(width: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: onSolved,
            child: const Text('GO'),
          ),
        ],
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Level 2 — a conditional checkbox where the condition is false.
// ---------------------------------------------------------------------------

class _Level2 extends StatefulWidget {
  const _Level2({required this.onSolved});
  final VoidCallback onSolved;

  @override
  State<_Level2> createState() => _Level2State();
}

class _Level2State extends State<_Level2> {
  bool _checked = false;

  void _confirm(BuildContext context) {
    if (_checked) {
      _hint(context, '7 is odd — the box should stay unchecked.');
    } else {
      widget.onSolved();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _instructionCard(
          'Check the box below ONLY IF 7 is an even number. Then press Confirm.',
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Checkbox(
              value: _checked,
              onChanged: (v) => setState(() => _checked = v ?? false),
            ),
            const Text('Check this box'),
          ],
        ),
        const SizedBox(height: 20),
        Center(
          child: ElevatedButton(
            onPressed: () => _confirm(context),
            child: const Text('Confirm'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Level 3 — slider whose displayed counter is inverted from its raw value.
// ---------------------------------------------------------------------------

class _Level3 extends StatefulWidget {
  const _Level3({required this.onSolved});
  final VoidCallback onSolved;

  @override
  State<_Level3> createState() => _Level3State();
}

class _Level3State extends State<_Level3> {
  double _raw = 0;

  @override
  Widget build(BuildContext context) {
    final counter = 10 - _raw.round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _instructionCard(
          'The counter below is 10 minus the slider\'s position. '
          'Drag the slider until the COUNTER reads 4.',
        ),
        const SizedBox(height: 40),
        Text(
          'Counter: $counter',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Slider(
          value: _raw,
          min: 0,
          max: 10,
          divisions: 10,
          label: _raw.round().toString(),
          onChanged: (v) {
            setState(() => _raw = v);
            if (10 - v.round() == 4) widget.onSolved();
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Level 4 — type the letter-count of a word, not the word itself.
// ---------------------------------------------------------------------------

class _Level4 extends StatefulWidget {
  const _Level4({required this.onSolved});
  final VoidCallback onSolved;

  @override
  State<_Level4> createState() => _Level4State();
}

class _Level4State extends State<_Level4> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (_controller.text.trim() == '6') {
      widget.onSolved();
    } else {
      _hint(context, 'Count the letters in BRIDGE, not the word itself.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _instructionCard(
          'Type the NUMBER OF LETTERS in the word "BRIDGE" into the box below.',
        ),
        const SizedBox(height: 40),
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        const SizedBox(height: 20),
        Center(
          child: ElevatedButton(
            onPressed: () => _submit(context),
            child: const Text('Submit'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Level 5 — tap every button except the one labelled 3.
// ---------------------------------------------------------------------------

class _Level5 extends StatefulWidget {
  const _Level5({required this.onSolved});
  final VoidCallback onSolved;

  @override
  State<_Level5> createState() => _Level5State();
}

class _Level5State extends State<_Level5> {
  final Set<int> _tapped = {};
  static const _required = {1, 2, 4, 5};

  void _tap(BuildContext context, int n) {
    if (n == 3) {
      setState(_tapped.clear);
      _hint(context, 'Button 3 was off-limits — progress reset.');
      return;
    }
    setState(() => _tapped.add(n));
    if (_tapped.containsAll(_required)) widget.onSolved();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _instructionCard('Tap every button EXCEPT the one labelled 3.'),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var n = 1; n <= 5; n++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _tapped.contains(n)
                        ? AppTheme.success
                        : null,
                  ),
                  onPressed: () => _tap(context, n),
                  child: Text('$n'),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Level 6 — the button only reacts to a long press, not a tap.
// ---------------------------------------------------------------------------

Widget _level6(BuildContext context, VoidCallback onSolved) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _instructionCard('This button only responds to a LONG PRESS, not a tap.'),
      const SizedBox(height: 40),
      Center(
        child: GestureDetector(
          onTap: () =>
              _hint(context, 'Nothing happens... try holding it down.'),
          onLongPress: onSolved,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            decoration: BoxDecoration(
              color: AppTheme.surfaceHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text('Press me', style: TextStyle(fontSize: 18)),
          ),
        ),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Level 7 — tap the star, then the moon, in that exact order.
// ---------------------------------------------------------------------------

class _Level7 extends StatefulWidget {
  const _Level7({required this.onSolved});
  final VoidCallback onSolved;

  @override
  State<_Level7> createState() => _Level7State();
}

class _Level7State extends State<_Level7> {
  int _step = 0;

  void _tapStar() {
    if (_step == 0) setState(() => _step = 1);
  }

  void _tapMoon() {
    if (_step == 1) {
      widget.onSolved();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _instructionCard('Tap the star, then the moon — in that order.'),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              iconSize: 56,
              onPressed: _tapMoon,
              tooltip: 'Moon',
              icon: Icon(
                Icons.nightlight_round,
                color: _step >= 1 ? AppTheme.accent : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 40),
            IconButton(
              iconSize: 56,
              onPressed: _tapStar,
              tooltip: 'Star',
              icon: Icon(
                Icons.star_rounded,
                color: _step >= 1 ? AppTheme.success : AppTheme.warning,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Level 8 — the big button is a decoy; the real target is the small × icon.
// ---------------------------------------------------------------------------

Widget _level8(BuildContext context, VoidCallback onSolved) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _instructionCard(
        'The button below is a decoy. To continue, tap the small × in the '
        'corner of the card instead.',
      ),
      const SizedBox(height: 40),
      Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: ElevatedButton(
                onPressed: () =>
                    _hint(context, "That's the decoy — look for the ×."),
                child: const Text('Continue'),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              onPressed: onSolved,
              tooltip: 'Close',
              icon: Icon(Icons.close, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Level 9 — select every prime number, then submit.
// ---------------------------------------------------------------------------

class _Level9 extends StatefulWidget {
  const _Level9({required this.onSolved});
  final VoidCallback onSolved;

  @override
  State<_Level9> createState() => _Level9State();
}

class _Level9State extends State<_Level9> {
  static const _numbers = [2, 3, 4, 6, 7, 9, 11, 12];
  static const _primes = {2, 3, 7, 11};
  final Set<int> _selected = {};

  void _submit(BuildContext context) {
    if (_selected.length == _primes.length && _selected.containsAll(_primes)) {
      widget.onSolved();
    } else {
      _hint(context, 'Not quite — check your selection again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _instructionCard('Select every PRIME number below, then press Submit.'),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            for (final n in _numbers)
              CheckboxListTile(
                title: Text('$n'),
                value: _selected.contains(n),
                onChanged: (v) => setState(() {
                  if (v ?? false) {
                    _selected.add(n);
                  } else {
                    _selected.remove(n);
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: ElevatedButton(
            onPressed: () => _submit(context),
            child: const Text('Submit'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Level 10 — drag the smallest square into the box.
// ---------------------------------------------------------------------------

class _Level10 extends StatefulWidget {
  const _Level10({required this.onSolved});
  final VoidCallback onSolved;

  @override
  State<_Level10> createState() => _Level10State();
}

class _Level10State extends State<_Level10> {
  static const _sizes = [70.0, 40.0, 55.0];
  bool _accepting = false;

  void _drop(BuildContext context, double size) {
    if (size == _sizes.reduce((a, b) => a < b ? a : b)) {
      widget.onSolved();
    } else {
      _hint(context, 'Too big — drag the SMALLEST square.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _instructionCard('Drag the SMALLEST square into the box on the right.'),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final size in _sizes)
                  Draggable<double>(
                    data: size,
                    feedback: Container(
                      width: size,
                      height: size,
                      color: AppTheme.accent.withValues(alpha: 0.7),
                    ),
                    childWhenDragging: Container(
                      width: size,
                      height: size,
                      color: AppTheme.surfaceHigh,
                    ),
                    child: Container(
                      width: size,
                      height: size,
                      color: AppTheme.accent,
                    ),
                  ),
              ],
            ),
            DragTarget<double>(
              onAcceptWithDetails: (details) => _drop(context, details.data),
              onWillAcceptWithDetails: (_) {
                setState(() => _accepting = true);
                return true;
              },
              onLeave: (_) => setState(() => _accepting = false),
              builder: (context, candidate, rejected) {
                return Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _accepting
                          ? AppTheme.success
                          : AppTheme.textSecondary,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Level 11 — only every second raw tap actually counts.
// ---------------------------------------------------------------------------

class _Level11 extends StatefulWidget {
  const _Level11({required this.onSolved});
  final VoidCallback onSolved;

  @override
  State<_Level11> createState() => _Level11State();
}

class _Level11State extends State<_Level11> {
  int _raw = 0;
  int _score = 0;

  void _tap() {
    setState(() {
      _raw++;
      if (_raw.isEven) _score++;
    });
    if (_score == 3) widget.onSolved();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _instructionCard(
          'Only every SECOND tap actually registers. Tap the button until '
          'the SCORE shows 3.',
        ),
        const SizedBox(height: 40),
        Text(
          'Score: $_score',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 20),
        Center(
          child: ElevatedButton(onPressed: _tap, child: const Text('Tap')),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Level 12 — answer a multiplication, but write the answer in words.
// ---------------------------------------------------------------------------

class _Level12 extends StatefulWidget {
  const _Level12({required this.onSolved});
  final VoidCallback onSolved;

  @override
  State<_Level12> createState() => _Level12State();
}

class _Level12State extends State<_Level12> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (_controller.text.trim().toLowerCase() == 'fifteen') {
      widget.onSolved();
    } else {
      _hint(context, 'Write the answer as a WORD, not digits.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _instructionCard(
          'Compute 5 × 3. Type the answer IN WORDS (not digits) below.',
        ),
        const SizedBox(height: 40),
        TextField(
          controller: _controller,
          textAlign: TextAlign.center,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        const SizedBox(height: 20),
        Center(
          child: ElevatedButton(
            onPressed: () => _submit(context),
            child: const Text('Submit'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Level 13 — swap two switches relative to their (already matching) labels.
// ---------------------------------------------------------------------------

class _Level13 extends StatefulWidget {
  const _Level13({required this.onSolved});
  final VoidCallback onSolved;

  @override
  State<_Level13> createState() => _Level13State();
}

class _Level13State extends State<_Level13> {
  bool _switchLabelledOff = false;
  bool _switchLabelledOn = true;

  void _confirm(BuildContext context) {
    if (_switchLabelledOff && !_switchLabelledOn) {
      widget.onSolved();
    } else {
      _hint(
        context,
        "Both switches currently match their own labels — that's wrong.",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _instructionCard(
          'Flip the switch labelled OFF to ON, and the switch labelled ON to '
          'OFF. Then press Confirm.',
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              children: [
                const Text('OFF'),
                Switch(
                  value: _switchLabelledOff,
                  onChanged: (v) => setState(() => _switchLabelledOff = v),
                ),
              ],
            ),
            Column(
              children: [
                const Text('ON'),
                Switch(
                  value: _switchLabelledOn,
                  onChanged: (v) => setState(() => _switchLabelledOn = v),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        Center(
          child: ElevatedButton(
            onPressed: () => _confirm(context),
            child: const Text('Confirm'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Level 14 — the code is the number of vowels in the given sentence.
// ---------------------------------------------------------------------------

class _Level14 extends StatefulWidget {
  const _Level14({required this.onSolved});
  final VoidCallback onSolved;

  @override
  State<_Level14> createState() => _Level14State();
}

class _Level14State extends State<_Level14> {
  static const _sentence = 'Owls glide quietly above the moonlit valley.';
  final _controller = TextEditingController();

  int get _vowelCount => _sentence
      .toLowerCase()
      .split('')
      .where((c) => 'aeiou'.contains(c))
      .length;

  void _submit(BuildContext context) {
    if (int.tryParse(_controller.text.trim()) == _vowelCount) {
      widget.onSolved();
    } else {
      _hint(context, 'Recount the vowels in the sentence, carefully.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _instructionCard(
          'The CODE equals the number of vowels (a, e, i, o, u) in this '
          'sentence: "$_sentence" — enter the code below.',
        ),
        const SizedBox(height: 40),
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        const SizedBox(height: 20),
        Center(
          child: ElevatedButton(
            onPressed: () => _submit(context),
            child: const Text('Submit'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Level 15 — tap shapes fewest-to-most sides, skipping the red one.
// ---------------------------------------------------------------------------

class _ShapeSpec {
  const _ShapeSpec(this.sides, this.color, this.icon);
  final int sides;
  final Color color;
  final IconData icon;

  /// Accessible label for this shape's button — includes color, since the
  /// level's own instructions ("skip any shape that is coloured red")
  /// require knowing color to solve it, not just shape name.
  String get accessibleLabel {
    const names = {3: 'Triangle', 4: 'Square', 5: 'Pentagon', 6: 'Hexagon'};
    final shapeName = names[sides] ?? 'Shape';
    final colorName = color == AppTheme.danger
        ? 'red'
        : color == AppTheme.success
        ? 'green'
        : 'blue';
    return '$colorName $shapeName';
  }
}

class _Level15 extends StatefulWidget {
  const _Level15({required this.onSolved});
  final VoidCallback onSolved;

  @override
  State<_Level15> createState() => _Level15State();
}

class _Level15State extends State<_Level15> {
  static List<_ShapeSpec> get _shapes => [
    _ShapeSpec(3, AppTheme.accent, Icons.change_history_rounded),
    _ShapeSpec(4, AppTheme.danger, Icons.square_rounded),
    _ShapeSpec(5, AppTheme.success, Icons.pentagon_rounded),
    _ShapeSpec(6, AppTheme.accent, Icons.hexagon_rounded),
  ];

  late List<_ShapeSpec> _correctOrder;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _correctOrder = _shapes.where((s) => s.color != AppTheme.danger).toList()
      ..sort((a, b) => a.sides.compareTo(b.sides));
  }

  void _tap(BuildContext context, _ShapeSpec shape) {
    if (shape.color == AppTheme.danger) {
      setState(() => _progress = 0);
      _hint(context, 'Red shapes are skipped — order reset.');
      return;
    }
    if (shape == _correctOrder[_progress]) {
      setState(() => _progress++);
      if (_progress == _correctOrder.length) widget.onSolved();
    } else {
      setState(() => _progress = 0);
      _hint(context, 'Wrong order — start again from the fewest sides.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _instructionCard(
          'Tap the shapes in order from FEWEST sides to MOST sides — but '
          'skip any shape that is coloured red.',
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final shape in _shapes)
              IconButton(
                iconSize: 48,
                onPressed: () => _tap(context, shape),
                tooltip: shape.accessibleLabel,
                icon: Icon(shape.icon, color: shape.color),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Progress: $_progress/${_correctOrder.length}',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
