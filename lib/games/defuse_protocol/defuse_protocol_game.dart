import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/game_definition.dart';
import '../../core/game_level_context.dart';

/// Reference implementation: an original solo rule-manual deduction puzzle.
/// The player is shown a short on-screen "manual" rule and a module with
/// visible state (wires / a symbol keypad / toggle switches) and must find
/// the single action the rule implies. The correct action is always
/// computed programmatically from the same logic described in the manual
/// text and the actually-generated module state - never hardcoded
/// separately. 15 levels, module count and complexity scale up.
final GameDefinition defuseProtocolDefinition = GameDefinition(
  id: 'defuse_protocol',
  title: 'Rule Manual',
  tagline: 'Follow the manual, defuse the device',
  icon: Icons.bolt_rounded,
  tint: const GameTint(Color(0xFFEF4444), Color(0xFF7F1D1D)),
  mode: GameMode.levels,
  levelCount: 15,
  builder: (context, ctx) => DefuseProtocolScreen(ctx: ctx),
);

enum _ModuleType { wire, keypad, toggle }

/// Small fixed wire-color palette. Kept as an ordered list so both
/// generation and the on-screen legend agree on names.
const List<Color> _wirePalette = [
  Color(0xFFEF4444), // red
  Color(0xFF3B82F6), // blue
  Color(0xFFFACC15), // yellow
  Color(0xFF22C55E), // green
  Color(0xFFF8FAFC), // white
];
const List<String> _wirePaletteNames = ['RED', 'BLUE', 'YELLOW', 'GREEN', 'WHITE'];

String _wireColorName(Color c) {
  final idx = _wirePalette.indexOf(c);
  return idx == -1 ? '?' : _wirePaletteNames[idx];
}

const List<IconData> _keypadIconPool = [
  Icons.star_rounded,
  Icons.circle,
  Icons.change_history_rounded,
  Icons.square_rounded,
  Icons.favorite,
];

/// One wire-cutting module instance.
class _WireModule {
  _WireModule({
    required this.colors,
    required this.ruleId,
    required this.manualText,
    required this.correctIndex,
  });

  final List<Color> colors;
  final int ruleId;
  final String manualText;
  final int correctIndex;
}

/// One symbol-keypad module instance.
class _KeypadModule {
  _KeypadModule({
    required this.icons,
    required this.ruleId,
    required this.manualText,
    required this.correctIcon,
  });

  final List<IconData> icons; // length 9, row-major 3x3
  final int ruleId;
  final String manualText;
  final IconData correctIcon;
}

/// One toggle-switch module instance.
class _ToggleModule {
  _ToggleModule({
    required this.initialStates,
    required this.ruleId,
    required this.manualText,
  });

  final List<bool> initialStates;
  final int ruleId;
  final String manualText;

  /// Evaluates the manual rule against a candidate final switch state.
  /// This is the ONLY place correctness is decided for toggle modules, and
  /// it is re-used both for generation sanity and for live gameplay checks.
  bool isCorrect(List<bool> finalStates) {
    switch (ruleId) {
      case 0:
        // "Flip switches until the number of ON switches is EVEN."
        return finalStates.where((s) => s).length.isEven;
      case 1:
        // "Flip exactly the switches that are currently OFF" -> every
        // switch that starts OFF must end ON, and every switch that starts
        // ON must stay ON: i.e. the final state is all switches ON.
        return finalStates.every((s) => s);
      default:
        return false;
    }
  }
}

/// One module slot in a level: exactly one of the three fields is set.
class _ModuleSpec {
  _ModuleSpec.wire(this.wire) : keypad = null, toggle = null, type = _ModuleType.wire;
  _ModuleSpec.keypad(this.keypad) : wire = null, toggle = null, type = _ModuleType.keypad;
  _ModuleSpec.toggle(this.toggle) : wire = null, keypad = null, type = _ModuleType.toggle;

  final _ModuleType type;
  final _WireModule? wire;
  final _KeypadModule? keypad;
  final _ToggleModule? toggle;
}

class DefuseProtocolScreen extends StatefulWidget {
  const DefuseProtocolScreen({super.key, required this.ctx});

  final GameLevelContext ctx;

  @override
  State<DefuseProtocolScreen> createState() => _DefuseProtocolScreenState();
}

class _DefuseProtocolScreenState extends State<DefuseProtocolScreen> {
  late List<_ModuleSpec> _modules;
  int _moduleIndex = 0;
  int _wrongCount = 0;
  late int _secondsLeft;
  Timer? _timer;
  List<bool>? _toggleLiveStates;

  int get _level => widget.ctx.level;

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _loadLevel() {
    final rng = Random(4242 + _level);
    _modules = _generateModules(rng, _level);
    _moduleIndex = 0;
    _toggleLiveStates = null;
    _secondsLeft = (90 - _level * 3).clamp(45, 90);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        _timer?.cancel();
        _fail("Time's up!");
      }
    });
  }

  void _resetLevel() {
    _timer?.cancel();
    setState(_loadLevel);
  }

  // ---- Level generation ------------------------------------------------

  List<_ModuleSpec> _generateModules(Random rng, int level) {
    final count = (1 + (level - 1) ~/ 4).clamp(1, 4);
    return List.generate(count, (_) {
      switch (rng.nextInt(3)) {
        case 0:
          return _ModuleSpec.wire(_generateWireModule(rng, level));
        case 1:
          return _ModuleSpec.keypad(_generateKeypadModule(rng));
        default:
          return _ModuleSpec.toggle(_generateToggleModule(rng, level));
      }
    });
  }

  _WireModule _generateWireModule(Random rng, int level) {
    final wireCount = (3 + (level - 1) ~/ 3).clamp(3, 6);
    final colors = List.generate(wireCount, (_) => _wirePalette[rng.nextInt(_wirePalette.length)]);
    final ruleId = rng.nextInt(3);
    final correctIndex = _wireRuleIndex(ruleId, colors);
    return _WireModule(
      colors: colors,
      ruleId: ruleId,
      manualText: _wireRuleText(ruleId),
      correctIndex: correctIndex,
    );
  }

  String _wireRuleText(int ruleId) {
    switch (ruleId) {
      case 0:
        return 'WIRE PROTOCOL A: If any color repeats among the wires, cut '
            'the LAST wire whose color also appears elsewhere. Otherwise, '
            'cut the FIRST blue wire. If there is no blue wire either, cut '
            'the LAST wire.';
      case 1:
        return 'WIRE PROTOCOL B: If there is exactly one white wire, cut '
            'it. Otherwise, cut the wire immediately AFTER the LAST red '
            'wire (wrapping to the first wire if red is last). If there is '
            'no red wire either, cut the FIRST wire.';
      default:
        return 'WIRE PROTOCOL C: If the number of wires is even, cut the '
            'FIRST wire (excluding the last one) that matches the color of '
            'the LAST wire. Otherwise - or if no earlier match exists - cut '
            'the middle wire (round down).';
    }
  }

  /// Computes the correct wire index by literally implementing the same
  /// logic described in [_wireRuleText] for the same ruleId.
  int _wireRuleIndex(int ruleId, List<Color> colors) {
    switch (ruleId) {
      case 0:
        bool repeats(int i) => colors.where((c) => c == colors[i]).length > 1;
        for (var i = colors.length - 1; i >= 0; i--) {
          if (repeats(i)) return i;
        }
        final blueIndex = colors.indexOf(_wirePalette[1]);
        if (blueIndex != -1) return blueIndex;
        return colors.length - 1;
      case 1:
        final whiteIdx = <int>[];
        for (var i = 0; i < colors.length; i++) {
          if (colors[i] == _wirePalette[4]) whiteIdx.add(i);
        }
        if (whiteIdx.length == 1) return whiteIdx[0];
        final lastRed = colors.lastIndexOf(_wirePalette[0]);
        if (lastRed != -1) return (lastRed + 1) % colors.length;
        return 0;
      default:
        if (colors.length % 2 == 0) {
          final lastColor = colors.last;
          for (var i = 0; i < colors.length - 1; i++) {
            if (colors[i] == lastColor) return i;
          }
        }
        return colors.length ~/ 2;
    }
  }

  static const List<List<int>> _patternsAppearsTwice = [
    [2, 3, 4],
    [2, 1, 3, 3],
    [2, 1, 1, 1, 4],
    [2, 7],
  ];
  static const List<List<int>> _patternsAppearsOnce = [
    [1, 2, 6],
    [1, 2, 3, 3],
    [1, 4, 4],
    [1, 2, 2, 2, 2],
  ];

  _KeypadModule _generateKeypadModule(Random rng) {
    final ruleId = rng.nextInt(2); // 0 = appears twice, 1 = appears once
    final patterns = ruleId == 0 ? _patternsAppearsTwice : _patternsAppearsOnce;
    final pattern = List<int>.from(patterns[rng.nextInt(patterns.length)])..shuffle(rng);
    final iconPool = List<IconData>.from(_keypadIconPool)..shuffle(rng);

    final flat = <IconData>[];
    for (var i = 0; i < pattern.length; i++) {
      final icon = iconPool[i % iconPool.length];
      for (var n = 0; n < pattern[i]; n++) {
        flat.add(icon);
      }
    }
    flat.shuffle(rng);

    // Compute the correct icon from the ACTUAL generated grid, not from the
    // pattern used to build it.
    final counts = <IconData, int>{};
    for (final icon in flat) {
      counts[icon] = (counts[icon] ?? 0) + 1;
    }
    final target = ruleId == 0 ? 2 : 1;
    final correctIcon = counts.entries.firstWhere((e) => e.value == target).key;

    return _KeypadModule(
      icons: flat,
      ruleId: ruleId,
      manualText: ruleId == 0
          ? 'KEYPAD PROTOCOL: Exactly one symbol on this pad appears '
              'exactly TWICE. Press that symbol.'
          : 'KEYPAD PROTOCOL: Exactly one symbol on this pad appears only '
              'ONCE. Press that symbol.',
      correctIcon: correctIcon,
    );
  }

  _ToggleModule _generateToggleModule(Random rng, int level) {
    final switchCount = (3 + (level - 1) ~/ 5).clamp(3, 5);
    final ruleId = rng.nextInt(2);
    List<bool> states;
    do {
      states = List.generate(switchCount, (_) => rng.nextBool());
    } while (
      // Avoid a starting state that is already solved (no action needed).
      (ruleId == 0 && states.where((s) => s).length.isEven) ||
          (ruleId == 1 && states.every((s) => s)));
    return _ToggleModule(
      initialStates: states,
      ruleId: ruleId,
      manualText: ruleId == 0
          ? 'TOGGLE PROTOCOL: Flip switches (any order) until the number '
              'of ON switches is EVEN, then confirm.'
          : 'TOGGLE PROTOCOL: Flip exactly the switches that are currently '
              'OFF, leave the rest untouched, then confirm.',
    );
  }

  // ---- Actions -----------------------------------------------------------

  void _onWireTap(int index) {
    final module = _modules[_moduleIndex].wire!;
    if (index == module.correctIndex) {
      _advance();
    } else {
      _fail('Wrong wire!');
    }
  }

  void _onKeypadTap(IconData icon) {
    final module = _modules[_moduleIndex].keypad!;
    if (icon == module.correctIcon) {
      _advance();
    } else {
      _fail('Wrong symbol!');
    }
  }

  void _onToggleFlip(int index) {
    setState(() {
      _toggleLiveStates![index] = !_toggleLiveStates![index];
    });
  }

  void _onToggleConfirm() {
    final module = _modules[_moduleIndex].toggle!;
    if (module.isCorrect(_toggleLiveStates!)) {
      _advance();
    } else {
      _fail('Switches misconfigured!');
    }
  }

  void _advance() {
    setState(() {
      _moduleIndex++;
      _toggleLiveStates = null;
    });
    if (_moduleIndex >= _modules.length) {
      _timer?.cancel();
      final stars = _wrongCount == 0
          ? 3
          : _wrongCount == 1
              ? 2
              : 1;
      Future.microtask(() => widget.ctx.onComplete(stars: stars));
    }
  }

  void _fail(String reason) {
    _wrongCount++;
    _timer?.cancel();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Device triggered'),
          content: Text('$reason The device has locked you out of this attempt.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                widget.ctx.onExit();
              },
              child: const Text('Menu'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _resetLevel();
              },
              child: const Text('Retry'),
            ),
          ],
        );
      },
    );
  }

  // ---- UI ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final module = _modules[_moduleIndex];
    return Scaffold(
      appBar: AppBar(
        title: Text('Defuse Protocol · Level $_level'),
        actions: [
          TextButton(
            onPressed: widget.ctx.onExit,
            child: const Text('Menu'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Module ${_moduleIndex + 1}/${_modules.length}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Row(
                  children: [
                    Icon(Icons.timer_outlined,
                        size: 18,
                        color: _secondsLeft <= 10 ? AppTheme.danger : AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      '${_secondsLeft.clamp(0, 999)}s',
                      style: TextStyle(
                        color: _secondsLeft <= 10 ? AppTheme.danger : AppTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.danger.withValues(alpha: 0.4)),
              ),
              child: Text(
                _manualTextFor(module),
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: _buildModule(module),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Wrong actions this level: $_wrongCount',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  String _manualTextFor(_ModuleSpec module) {
    switch (module.type) {
      case _ModuleType.wire:
        return module.wire!.manualText;
      case _ModuleType.keypad:
        return module.keypad!.manualText;
      case _ModuleType.toggle:
        return module.toggle!.manualText;
    }
  }

  Widget _buildModule(_ModuleSpec module) {
    switch (module.type) {
      case _ModuleType.wire:
        return _buildWireModule(module.wire!);
      case _ModuleType.keypad:
        return _buildKeypadModule(module.keypad!);
      case _ModuleType.toggle:
        return _buildToggleModule(module.toggle!);
    }
  }

  Widget _buildWireModule(_WireModule module) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < module.colors.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: GestureDetector(
                onTap: () => _onWireTap(i),
                child: Column(
                  children: [
                    Container(
                      width: 28,
                      height: 140,
                      decoration: BoxDecoration(
                        color: module.colors[i],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.textSecondary, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: module.colors[i].withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _wireColorName(module.colors[i]),
                      style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKeypadModule(_KeypadModule module) {
    return SizedBox(
      width: 260,
      height: 260,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: module.icons.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemBuilder: (context, index) {
          final icon = module.icons[index];
          return GestureDetector(
            onTap: () => _onKeypadTap(icon),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.accent, size: 30),
            ),
          );
        },
      ),
    );
  }

  Widget _buildToggleModule(_ToggleModule module) {
    _toggleLiveStates ??= List<bool>.from(module.initialStates);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _toggleLiveStates!.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  children: [
                    Text('${i + 1}', style: TextStyle(color: AppTheme.textSecondary)),
                    Switch(
                      value: _toggleLiveStates![i],
                      activeThumbColor: AppTheme.success,
                      onChanged: (_) => _onToggleFlip(i),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _onToggleConfirm,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
