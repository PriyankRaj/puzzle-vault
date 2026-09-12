import 'package:flutter_test/flutter_test.dart';

import 'package:topgames/home/home_screen.dart';
import 'package:topgames/main.dart';

void main() {
  testWidgets('Home screen lists all registered games', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PuzzleVaultApp());
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Puzzle Vault'), findsOneWidget);
  });
}
