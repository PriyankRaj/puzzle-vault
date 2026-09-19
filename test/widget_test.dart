import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:topgames/core/progress_store.dart';
import 'package:topgames/home/home_screen.dart';
import 'package:topgames/main.dart';

void main() {
  testWidgets('Home screen lists all registered games', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await ProgressStore.instance.init();

    await tester.pumpWidget(const PuzzleVaultApp());
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Brainers Time!'), findsOneWidget);
  });
}
