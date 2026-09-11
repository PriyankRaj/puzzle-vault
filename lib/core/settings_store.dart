import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide user preferences: theme, sound effects, animations.
/// Backed by [SharedPreferences] only — no network calls. Exposed as
/// [ValueNotifier]s so widgets can listen and rebuild directly, without
/// pulling in a wider state-management dependency for three flags.
class AppSettingsStore {
  AppSettingsStore._();
  static final AppSettingsStore instance = AppSettingsStore._();

  static const _themeKey = 'settings_dark_mode';
  static const _soundKey = 'settings_sound_enabled';
  static const _animationsKey = 'settings_animations_enabled';

  SharedPreferences? _prefs;

  final ValueNotifier<bool> isDarkMode = ValueNotifier<bool>(true);
  final ValueNotifier<bool> soundEnabled = ValueNotifier<bool>(true);
  final ValueNotifier<bool> animationsEnabled = ValueNotifier<bool>(true);

  Future<void> init() async {
    final p = _prefs ??= await SharedPreferences.getInstance();
    isDarkMode.value = p.getBool(_themeKey) ?? true;
    soundEnabled.value = p.getBool(_soundKey) ?? true;
    animationsEnabled.value = p.getBool(_animationsKey) ?? true;
  }

  Future<void> setDarkMode(bool value) async {
    isDarkMode.value = value;
    await _prefs?.setBool(_themeKey, value);
  }

  Future<void> setSoundEnabled(bool value) async {
    soundEnabled.value = value;
    await _prefs?.setBool(_soundKey, value);
  }

  Future<void> setAnimationsEnabled(bool value) async {
    animationsEnabled.value = value;
    await _prefs?.setBool(_animationsKey, value);
  }
}
