import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/main.dart';

void main() {
  group('Brigade Roster & Thrall Deployment Tests', () {
    testWidgets('Tapping DEPLOY on reserve thrall opens slot replacement modal and deploys to brigade', (tester) async {
      await tester.pumpWidget(const AshenCrucibleApp());
      await tester.pumpAndSettle();

      // Navigate to Brigade Roster tab (Tab 4)
      final rosterTab = find.byIcon(Icons.people_alt);
      expect(rosterTab, findsOneWidget);
      await tester.tap(rosterTab);
      await tester.pumpAndSettle();

      expect(find.text('YOUR LINEAGE ROSTER'), findsOneWidget);

      // Scroll until the first reserve thrall with DEPLOY button is visible
      await tester.scrollUntilVisible(
        find.widgetWithText(ElevatedButton, 'DEPLOY'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      final deployButtons = find.widgetWithText(ElevatedButton, 'DEPLOY');
      expect(deployButtons, findsWidgets);

      // Tap DEPLOY on the first reserve thrall
      await tester.tap(deployButtons.first);
      await tester.pumpAndSettle();

      // Verify the deployment sheet opened
      expect(find.textContaining('DEPLOY '), findsWidgets);
      expect(find.textContaining('Choose an active squad position'), findsOneWidget);

      // Find REPLACE buttons for active squad positions
      final replaceButtons = find.widgetWithText(ElevatedButton, 'REPLACE');
      expect(replaceButtons, findsWidgets);

      // Tap the first REPLACE button (replaces frontliner 1)
      await tester.tap(replaceButtons.first);
      await tester.pumpAndSettle();

      // Verify SnackBar confirmation
      expect(find.textContaining('Vessel Deployed'), findsOneWidget);
    });
  });
}
