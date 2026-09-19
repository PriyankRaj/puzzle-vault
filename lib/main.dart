import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/theme.dart';
import 'core/progress_store.dart';
import 'core/settings_store.dart';
import 'home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Every game's layout (grids, AppBar + board columns) was built assuming
  // portrait; landscape isn't supported by any of the 19 games' UIs, so
  // lock it here rather than leave dead space or overflow to fix per-game.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await ProgressStore.instance.init();
  await AppSettingsStore.instance.init();
  runApp(const PuzzleVaultApp());
}

class PuzzleVaultApp extends StatelessWidget {
  const PuzzleVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsStore.instance;
    return ValueListenableBuilder<bool>(
      valueListenable: settings.isDarkMode,
      builder: (context, isDark, _) {
        AppTheme.setBrightness(isDark ? Brightness.dark : Brightness.light);
        return ValueListenableBuilder<bool>(
          valueListenable: settings.animationsEnabled,
          builder: (context, animate, _) {
            return MaterialApp(
              title: 'Brainers Time!',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(animate: animate),
              darkTheme: AppTheme.dark(animate: animate),
              themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
              home: const HomeScreen(),
            );
          },
        );
      },
    );
  }
}
