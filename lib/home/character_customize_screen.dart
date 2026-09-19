import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/character_store.dart';
import '../core/sound.dart';
import '../core/widgets/character_avatar.dart';

class CharacterCustomizeScreen extends StatefulWidget {
  const CharacterCustomizeScreen({super.key});

  @override
  State<CharacterCustomizeScreen> createState() =>
      _CharacterCustomizeScreenState();
}

class _CharacterCustomizeScreenState extends State<CharacterCustomizeScreen> {
  late final TextEditingController _nameController = TextEditingController(
    text: CharacterStore.instance.name.value,
  );

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = CharacterStore.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Customize your buddy')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          Center(
            child: ValueListenableBuilder<int>(
              valueListenable: store.colorIndex,
              builder: (context, colorIndex, _) {
                return ValueListenableBuilder<CharacterExpression>(
                  valueListenable: store.expression,
                  builder: (context, expression, _) {
                    return ValueListenableBuilder<CharacterAccessory>(
                      valueListenable: store.accessory,
                      builder: (context, accessory, _) {
                        return CharacterAvatar(
                          size: 140,
                          color: characterColors[colorIndex],
                          expression: expression,
                          accessory: accessory,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Name',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            maxLength: 16,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppTheme.surface,
              counterText: '',
              hintText: CharacterStore.defaultName,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) => store.setName(value),
          ),
          const SizedBox(height: 24),
          Text(
            'Color',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<int>(
            valueListenable: store.colorIndex,
            builder: (context, selected, _) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < characterColors.length; i++)
                    _ColorSwatch(
                      option: characterColors[i],
                      selected: i == selected,
                      onTap: () {
                        Sfx.tap();
                        store.setColorIndex(i);
                      },
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Expression',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<int>(
            valueListenable: store.colorIndex,
            builder: (context, colorIndex, _) {
              return ValueListenableBuilder<CharacterExpression>(
                valueListenable: store.expression,
                builder: (context, selected, _) {
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final option in CharacterExpression.values)
                        _OptionTile(
                          selected: option == selected,
                          label: _expressionLabel(option),
                          preview: CharacterAvatar(
                            size: 56,
                            color: characterColors[colorIndex],
                            expression: option,
                            accessory: CharacterAccessory.none,
                          ),
                          onTap: () {
                            Sfx.tap();
                            store.setExpression(option);
                          },
                        ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Accessory',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<int>(
            valueListenable: store.colorIndex,
            builder: (context, colorIndex, _) {
              return ValueListenableBuilder<CharacterAccessory>(
                valueListenable: store.accessory,
                builder: (context, selected, _) {
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final option in CharacterAccessory.values)
                        _OptionTile(
                          selected: option == selected,
                          label: _accessoryLabel(option),
                          preview: CharacterAvatar(
                            size: 56,
                            color: characterColors[colorIndex],
                            expression: CharacterExpression.happy,
                            accessory: option,
                          ),
                          onTap: () {
                            Sfx.tap();
                            store.setAccessory(option);
                          },
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

String _expressionLabel(CharacterExpression e) => switch (e) {
  CharacterExpression.happy => 'Happy',
  CharacterExpression.cool => 'Cool',
  CharacterExpression.sleepy => 'Sleepy',
  CharacterExpression.surprised => 'Surprised',
  CharacterExpression.wink => 'Wink',
};

String _accessoryLabel(CharacterAccessory a) => switch (a) {
  CharacterAccessory.none => 'None',
  CharacterAccessory.cap => 'Cap',
  CharacterAccessory.glasses => 'Glasses',
  CharacterAccessory.bowtie => 'Bow tie',
  CharacterAccessory.headphones => 'Headphones',
};

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final CharacterColorOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${option.label} color',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [option.light, option.dark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: selected
                ? Border.all(color: AppTheme.textPrimary, width: 3)
                : null,
          ),
          child: selected
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
              : null,
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.selected,
    required this.label,
    required this.preview,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final Widget preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: ExcludeSemantics(
          child: Container(
            width: 84,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: selected
                  ? Border.all(color: AppTheme.accent, width: 2)
                  : null,
            ),
            child: Column(
              children: [
                preview,
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
