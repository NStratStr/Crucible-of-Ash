import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/features/combat/post_battle_loot_dialog.dart';
import 'package:ashen_crucible/shared/data/starter_brigades.dart';
import 'package:ashen_crucible/core/combat_math.dart';

void main() {
  group('PostBattleLootDialog Tests', () {
    testWidgets('renders victory extraction rewards accurately with soul-bound thrall and relic drop', (tester) async {
      bool continued = false;
      final capturedUnit = StarterBrigades.createDeathlessCryptReward();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  PostBattleLootDialog.show(
                    context: context,
                    rewards: CombatRewardsData(
                      isVictory: true,
                      rawAsh: 450,
                      emberShards: 35,
                      cryptKeys: 2,
                      xpGained: 750,
                      levelUps: ['Ashen Vanguard (Lv. 2➔3)'],
                      capturedThrall: capturedUnit,
                      relicDropName: 'Obsidian Skull of Malice',
                      encounterTitle: 'Ironwatch Gatekeeper Skirmish',
                    ),
                    onContinue: () {
                      continued = true;
                    },
                  );
                },
                child: const Text('OPEN VICTORY DIALOG'),
              ),
            ),
          ),
        ),
      );

      // Tap button to show dialog
      await tester.tap(find.text('OPEN VICTORY DIALOG'));
      await tester.pumpAndSettle();

      // Check Header
      expect(find.text('EXTRACTION CONCLUDED'), findsOneWidget);
      expect(find.text('IRONWATCH GATEKEEPER SKIRMISH'), findsOneWidget);

      // Check Currencies & XP
      expect(find.text('+450'), findsOneWidget); // Raw Ash
      expect(find.text('+35'), findsOneWidget);  // Ember Shards
      expect(find.text('+2'), findsOneWidget);   // Crypt Keys
      expect(find.text('+750 XP'), findsOneWidget); // XP

      // Check Level Up Alert
      expect(find.textContaining('LEVEL UP: Ashen Vanguard (Lv. 2➔3)'), findsOneWidget);

      // Check Relic Loot
      expect(find.textContaining('FORGED RELIC: Obsidian Skull of Malice'), findsOneWidget);

      // Check Captured Thrall Card
      expect(find.text('VESSEL SOUL BOUND'), findsOneWidget);
      expect(find.textContaining(capturedUnit.name), findsOneWidget);

      // Tap Claim & Continue
      await tester.tap(find.text('COLLECT REWARDS'));
      await tester.pumpAndSettle();

      expect(continued, isTrue);
    });

    testWidgets('renders defeat recovery screen with retreat options', (tester) async {
      bool retreated = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  PostBattleLootDialog.show(
                    context: context,
                    rewards: const CombatRewardsData(
                      isVictory: false,
                      rawAsh: 30,
                      emberShards: 0,
                      cryptKeys: 0,
                      xpGained: 50,
                      encounterTitle: 'Chamber of Bone',
                    ),
                    onContinue: () {
                      retreated = true;
                    },
                  );
                },
                child: const Text('OPEN DEFEAT DIALOG'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN DEFEAT DIALOG'));
      await tester.pumpAndSettle();

      expect(find.text('BRIGADE VANQUISHED'), findsOneWidget);
      expect(find.text('CHAMBER OF BONE'), findsOneWidget);
      expect(find.textContaining('All frontline and arcanum vessels have collapsed'), findsOneWidget);

      await tester.tap(find.text('RETURN TO CAMP'));
      await tester.pumpAndSettle();

      expect(retreated, isTrue);
    });
  });
}
