import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Face options for the home screen "brain buddy" mascot.
enum CharacterExpression { happy, cool, sleepy, surprised, wink }

/// Cosmetic add-ons for the mascot. Purely visual, no gameplay effect.
enum CharacterAccessory { none, cap, glasses, bowtie, headphones }

/// One selectable body-color option: a light/dark pair for the same
/// two-tone hemisphere shading used on the app icon, plus a matching
/// groove color for the wrinkle lines.
class CharacterColorOption {
  const CharacterColorOption({
    required this.label,
    required this.light,
    required this.dark,
    required this.groove,
  });

  final String label;
  final Color light;
  final Color dark;
  final Color groove;
}

/// Body colors the mascot can be customized to. Index 0 (amber) matches the
/// app icon's default brain color; the rest are new hues at the same
/// lightness/contrast so every option reads equally well.
const List<CharacterColorOption> characterColors = [
  CharacterColorOption(
    label: 'Amber',
    light: Color(0xFFFFC94D),
    dark: Color(0xFFF2A200),
    groove: Color(0xFF8A4B00),
  ),
  CharacterColorOption(
    label: 'Mint',
    light: Color(0xFF7FE0C4),
    dark: Color(0xFF2FB894),
    groove: Color(0xFF0E5C46),
  ),
  CharacterColorOption(
    label: 'Pink',
    light: Color(0xFFFF9AC1),
    dark: Color(0xFFE85C99),
    groove: Color(0xFF8A2452),
  ),
  CharacterColorOption(
    label: 'Periwinkle',
    light: Color(0xFF9AB8FF),
    dark: Color(0xFF5B6EF5),
    groove: Color(0xFF29328A),
  ),
  CharacterColorOption(
    label: 'Coral',
    light: Color(0xFFFF9E7A),
    dark: Color(0xFFE0603B),
    groove: Color(0xFF7A2A10),
  ),
];

/// The user's customizable mascot shown on the home screen: a small "brain
/// buddy" that echoes the app icon's brain shape. Backed by
/// [SharedPreferences], following the same pattern as [AppSettingsStore].
class CharacterStore {
  CharacterStore._();
  static final CharacterStore instance = CharacterStore._();

  static const _nameKey = 'character_name';
  static const _colorKey = 'character_color_index';
  static const _expressionKey = 'character_expression_index';
  static const _accessoryKey = 'character_accessory_index';

  static const defaultName = 'Sparky';

  SharedPreferences? _prefs;

  final ValueNotifier<String> name = ValueNotifier<String>(defaultName);
  final ValueNotifier<int> colorIndex = ValueNotifier<int>(0);
  final ValueNotifier<CharacterExpression> expression =
      ValueNotifier<CharacterExpression>(CharacterExpression.happy);
  final ValueNotifier<CharacterAccessory> accessory =
      ValueNotifier<CharacterAccessory>(CharacterAccessory.none);

  Future<void> init() async {
    final p = _prefs ??= await SharedPreferences.getInstance();
    name.value = p.getString(_nameKey) ?? defaultName;
    colorIndex.value = (p.getInt(_colorKey) ?? 0).clamp(
      0,
      characterColors.length - 1,
    );
    expression.value =
        CharacterExpression.values[(p.getInt(_expressionKey) ?? 0).clamp(
          0,
          CharacterExpression.values.length - 1,
        )];
    accessory.value =
        CharacterAccessory.values[(p.getInt(_accessoryKey) ?? 0).clamp(
          0,
          CharacterAccessory.values.length - 1,
        )];
  }

  Future<void> setName(String value) async {
    final trimmed = value.trim();
    name.value = trimmed.isEmpty ? defaultName : trimmed;
    await _prefs?.setString(_nameKey, name.value);
  }

  Future<void> setColorIndex(int value) async {
    colorIndex.value = value;
    await _prefs?.setInt(_colorKey, value);
  }

  Future<void> setExpression(CharacterExpression value) async {
    expression.value = value;
    await _prefs?.setInt(_expressionKey, value.index);
  }

  Future<void> setAccessory(CharacterAccessory value) async {
    accessory.value = value;
    await _prefs?.setInt(_accessoryKey, value.index);
  }
}
