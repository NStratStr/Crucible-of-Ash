import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/features/campaign/endgame_gauntlet_dialog.dart';

void main() {
  group('Endgame Gauntlet Mastery & Torment Descent Tests', () {
    testWidgets('Renders Gauntlet Mastery counter and CONQUERED badge for cleared trials', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => EndgameGauntletDialog.show(
                  ctx,
                  clearedTrials: {
                    EndgameTrialType.worldTitan,
                    EndgameTrialType.abyssalDescent,
                  },
                ),
                child: const Text('OPEN GAUNTLET'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN GAUNTLET'));
      await tester.pumpAndSettle();

      // Verify mastery progress ribbon
      expect(find.text('MASTERY: 2/6'), findsOneWidget);

      // Verify CONQUERED badge and replay action on World Titan
      expect(find.text('CONQUERED'), findsWidgets);
      expect(find.text('REPLAY CONQUERED TRIAL'), findsWidgets);
    });

    testWidgets('Tapping REPLAY CONQUERED TRIAL dispatches trial to caller', (tester) async {
      EndgameTrialType? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  selected = await EndgameGauntletDialog.show(
                    ctx,
                    clearedTrials: {EndgameTrialType.worldTitan},
                  );
                },
                child: const Text('OPEN GAUNTLET'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN GAUNTLET'));
      await tester.pumpAndSettle();

      // Tap REPLAY CONQUERED TRIAL on the first card (World Titan)
      await tester.tap(find.text('REPLAY CONQUERED TRIAL').first);
      await tester.pumpAndSettle();

      expect(selected, EndgameTrialType.worldTitan);
    });
  });
}
