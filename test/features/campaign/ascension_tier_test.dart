import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/features/campaign/ascension_tier_data.dart';
import 'package:ashen_crucible/features/campaign/ascension_tier_dialog.dart';
import 'package:ashen_crucible/features/campaign/campaign_map_screen.dart';
import 'package:ashen_crucible/features/campaign/campaign_map_generator.dart';

void main() {
  group('Ascension Tier Modifier System (A0–A10) Tests (GDD v2.6 Sec 1)', () {
    test('AscensionTierData includes all 11 tiers (A0 to A10) with increasing modifiers', () {
      expect(AscensionTierData.allTiers.length, 11);

      final a0 = AscensionTierData.forTier(0);
      expect(a0.tierNumber, 0);
      expect(a0.enemyHpMultiplier, 1.0);
      expect(a0.enemyDamageMultiplier, 1.0);

      final a1 = AscensionTierData.forTier(1);
      expect(a1.tierNumber, 1);
      expect(a1.enemyHpMultiplier, greaterThan(1.0));
      expect(a1.enemyDamageMultiplier, greaterThan(1.0));

      final a10 = AscensionTierData.forTier(10);
      expect(a10.tierNumber, 10);
      expect(a10.enemyHpMultiplier, greaterThanOrEqualTo(2.0));
      expect(a10.title, contains('TRUE CRUCIBLE'));
    });

    testWidgets('AscensionTierDialog renders all tiers and allows engaging an unlocked tier', (tester) async {
      int? selectedTier;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AscensionTierDialog.show(
                    context: context,
                    currentAscension: 0,
                    maxUnlockedAscension: 2,
                    onSelectAscension: (tier) {
                      selectedTier = tier;
                    },
                  );
                },
                child: const Text('OPEN ASCENSION DIALOG'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('OPEN ASCENSION DIALOG'));
      await tester.pumpAndSettle();

      // Check header
      expect(find.text('ASCENSION MODIFIERS (A0–A10)'), findsOneWidget);
      expect(find.text('ACTIVE: A0 • UNLOCKED: A2'), findsOneWidget);

      // A0 should have ACTIVE badge
      expect(find.text('ACTIVE'), findsOneWidget);

      // A1 and A2 should have ENGAGE buttons
      expect(find.text('ENGAGE'), findsNWidgets(2));

      // Tap ENGAGE on A1
      await tester.tap(find.text('ENGAGE').first);
      await tester.pumpAndSettle();

      expect(selectedTier, 1);
    });

    testWidgets('CampaignMapScreen renders Ascension Tier pill in AppBar and opens dialog', (tester) async {
      bool opened = false;
      final nodes = CampaignMapGenerator.generateCampaignForChapter(1);

      await tester.pumpWidget(
        MaterialApp(
          home: CampaignMapScreen(
            nodes: nodes,
            onSelectNode: (_) {},
            currentChapter: 1,
            maxUnlockedChapter: 1,
            currentAscension: 2,
            maxUnlockedAscension: 3,
            onAscensionChanged: (_) {
              opened = true;
            },
          ),
        ),
      );

      // Should show the A2 badge in AppBar
      expect(find.byKey(const ValueKey('ascension_tier_button')), findsOneWidget);
      expect(find.text('A2'), findsOneWidget);

      // Tap on the ascension pill
      await tester.tap(find.byKey(const ValueKey('ascension_tier_button')));
      await tester.pumpAndSettle();

      // Modal dialog appears
      expect(find.text('ASCENSION MODIFIERS (A0–A10)'), findsOneWidget);
    });
  });
}
