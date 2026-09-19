import 'package:flutter/material.dart';

/// Shared visual language for the whole app. Every game screen builds on
/// top of this instead of inventing its own palette.
///
/// Colors are exposed as getters (not `static const`) so the whole app can
/// switch between the dark and light palette at runtime — every game
/// screen that references e.g. `AppTheme.surface` automatically picks up
/// the current palette without needing a [BuildContext].
class AppTheme {
  AppTheme._();

  static Brightness _brightness = Brightness.dark;

  static bool get isDark => _brightness == Brightness.dark;

  /// Called once by the app root whenever the user's theme setting changes.
  static void setBrightness(Brightness brightness) {
    _brightness = brightness;
  }

  static Color get background =>
      isDark ? const Color(0xFF0F1220) : const Color(0xFFF6F7FB);
  static Color get surface =>
      isDark ? const Color(0xFF171B2E) : const Color(0xFFFFFFFF);
  static Color get surfaceHigh =>
      isDark ? const Color(0xFF1F2440) : const Color(0xFFEEF0F8);
  static Color get accent => const Color(0xFF5B6EF5);
  static Color get accentSoft =>
      isDark ? const Color(0xFF4E5A9E) : const Color(0xFFC7CEFB);
  static Color get success => const Color(0xFF22B573);
  static Color get warning => const Color(0xFFD97706);
  static Color get danger => const Color(0xFFE0433B);
  static Color get textPrimary =>
      isDark ? const Color(0xFFF4F6FF) : const Color(0xFF181B29);
  static Color get textSecondary =>
      isDark ? const Color(0xFF9AA3C7) : const Color(0xFF5B6178);

  static ThemeData dark({bool animate = true}) =>
      _build(Brightness.dark, animate);
  static ThemeData light({bool animate = true}) =>
      _build(Brightness.light, animate);

  static ThemeData _build(Brightness brightness, bool animate) {
    final bg = brightness == Brightness.dark
        ? const Color(0xFF0F1220)
        : const Color(0xFFF6F7FB);
    final surf = brightness == Brightness.dark
        ? const Color(0xFF171B2E)
        : const Color(0xFFFFFFFF);
    final surfHigh = brightness == Brightness.dark
        ? const Color(0xFF1F2440)
        : const Color(0xFFEEF0F8);
    final txt = brightness == Brightness.dark
        ? const Color(0xFFF4F6FF)
        : const Color(0xFF181B29);
    const acc = Color(0xFF5B6EF5);
    final dang = brightness == Brightness.dark
        ? const Color(0xFFF87171)
        : const Color(0xFFE0433B);

    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      colorScheme: brightness == Brightness.dark
          ? ColorScheme.dark(
              primary: acc,
              secondary: const Color(0xFF4E5A9E),
              surface: surf,
              error: dang,
            )
          : ColorScheme.light(
              primary: acc,
              secondary: const Color(0xFFC7CEFB),
              surface: surf,
              error: dang,
            ),
      fontFamily: 'Roboto',
    );
    final coloredText = base.textTheme.apply(
      bodyColor: txt,
      displayColor: txt,
    );
    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        foregroundColor: txt,
        titleTextStyle: TextStyle(
          color: txt,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        actionsIconTheme: const IconThemeData(size: 22),
      ),
      // Each game AppBar can carry up to 6 action icons (restart, hint, how
      // to play, levels, reset, menu) — Material's default 48px minimum
      // tap target per IconButton doesn't fit that many on a narrow real
      // phone (320 logical px), so this shrinks the tap target rather than
      // the icon glyph itself (kept readable via actionsIconTheme above).
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(36, 36),
          padding: EdgeInsets.zero,
        ),
      ),
      // Named sizes bumped above the Material3 defaults (titleMedium 16->18,
      // titleLarge 22->24, headlineSmall 24->26) since these are what the
      // games' level headers use, on top of the size fixes already applied
      // to per-game explicit TextStyle(fontSize: ...) literals — the app
      // was reading small everywhere, not just in a few spots. Only styles
      // with a non-null base fontSize are touched; `.apply(fontSizeFactor:)`
      // asserts if used on a null-fontSize style, which some defaults are.
      textTheme: coloredText.copyWith(
        titleMedium: coloredText.titleMedium?.copyWith(fontSize: 18),
        titleLarge: coloredText.titleLarge?.copyWith(fontSize: 24),
        headlineSmall: coloredText.headlineSmall?.copyWith(fontSize: 26),
        bodyMedium: coloredText.bodyMedium?.copyWith(fontSize: 15),
      ),
      cardTheme: CardThemeData(
        color: surf,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: acc,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: txt,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? acc : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? acc.withValues(alpha: 0.5)
              : null,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfHigh,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfHigh,
        contentTextStyle: TextStyle(color: txt),
        behavior: SnackBarBehavior.floating,
      ),
      pageTransitionsTheme: animate
          ? const PageTransitionsTheme()
          : const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: _InstantPageTransitionsBuilder(),
                TargetPlatform.iOS: _InstantPageTransitionsBuilder(),
              },
            ),
    );
  }
}

/// Used when Settings > Animations is off: swaps the page route transition
/// for an instant cut, with no slide/fade. Shared framework navigation
/// (home → level select → game, and back) all goes through Flutter's
/// normal `Navigator.push`, so this one hook turns off that whole class of
/// motion app-wide without touching any of the 20 game files individually.
class _InstantPageTransitionsBuilder extends PageTransitionsBuilder {
  const _InstantPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

/// A `GridView` `childAspectRatio` that shrinks (taller cells) as the
/// system text-scale setting grows, so fixed-aspect grid cards/tiles that
/// hold scalable text don't overflow under accessibility text scaling.
/// [base] is the ratio at a 1.0 text scale; [minRatio] bounds how tall a
/// cell is allowed to get at very large scales, so it doesn't grow
/// unboundedly on a system set to the maximum text size.
double textScaleAdjustedAspectRatio(
  BuildContext context,
  double base, {
  double minRatio = 0.45,
}) {
  // TextScaler has no single "factor" for non-linear system scalers, so
  // this samples the scaler at a representative font size as a proxy —
  // close enough to keep cells from overflowing without needing to know
  // the exact scaling curve.
  const referenceFontSize = 14.0;
  final scale =
      MediaQuery.textScalerOf(context).scale(referenceFontSize) /
      referenceFontSize;
  if (scale <= 1) return base;
  return (base / scale).clamp(minRatio, base);
}

/// Category tint used for a game's card + accents, purely decorative.
/// Deliberately brightness-independent — vivid icon-tile gradients read
/// fine on both the light and dark home screen.
class GameTint {
  const GameTint(this.primary, this.secondary);
  final Color primary;
  final Color secondary;

  LinearGradient get gradient => LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
