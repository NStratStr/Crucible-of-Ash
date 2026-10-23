import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/features/crucible/crucible_screen.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';
import 'package:ashen_crucible/shared/widgets/pedigree_inspector_dialog.dart';

void main() {
  group('Unit Level Progression & Bloodline Infusion Tests', () {
    const freshThrall = UnitEntity(
      id: 'fresh_thrall_01',
      speciesId: 'feral_hound',
      name: 'Feral Pup',
      generation: 1,
      archetype: Archetype.skirmisher,
      slot: FormationSlot.front1,
      level: 1,
      maxLevel: 10,
      currentHp: 400,
      maxHp: 400,
      attack: 100,
      defense: 80,
      speed: 100,
      nativeTraitId: 'rend_flesh',
      lineageAncestors: [],
      currentXp: 0,
    );

    test('UnitEntity calculates xpNeededForNextLevel and xpNeededForMaxLevel accurately', () {
      expect(freshThrall.isMaxLevel, isFalse);
      expect(freshThrall.xpNeededForNextLevel, equals(100)); // Level 1 needs 100 XP
      // Total to reach Lv 10 from Lv 1: 100 + 200 + 300 + 400 + 500 + 600 + 700 + 800 + 900 = 4500
      expect(freshThrall.xpNeededForMaxLevel, equals(4500));
    });

    test('UnitEntity.levelUp increases level and compounds stats', () {
      final lvl2 = freshThrall.levelUp(levels: 1);
      expect(lvl2.level, equals(2));
      expect(lvl2.attack, greaterThan(freshThrall.attack));
      expect(lvl2.maxHp, greaterThan(freshThrall.maxHp));
      expect(lvl2.speed, equals(freshThrall.speed + 2));

      final maxed = freshThrall.levelUp(levels: 20);
      expect(maxed.level, equals(10));
      expect(maxed.isMaxLevel, isTrue);
      expect(maxed.xpNeededForNextLevel, equals(0));
      expect(maxed.xpNeededForMaxLevel, equals(0));
    });

    testWidgets('PedigreeInspectorDialog renders Bloodline Infusion and levels up unit', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      UnitEntity? updatedReceived;
      int? costReceived;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PedigreeInspectorDialog(
              unit: freshThrall,
              totalIchor: 1000,
              onLevelUp: (u, cost) {
                updatedReceived = u;
                costReceived = cost;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Bloodline Infusion section should be visible
      expect(find.text('BLOODLINE INFUSION'), findsOneWidget);
      expect(find.text('+1 LEVEL'), findsOneWidget);
      expect(find.text('MAX LEVEL'), findsOneWidget);
      expect(find.text('+100 XP'), findsOneWidget);
      expect(find.text('Available: 1000 Ichor'), findsOneWidget);

      // Tap +1 LEVEL
      await tester.tap(find.text('+1 LEVEL'));
      await tester.pumpAndSettle();

      expect(updatedReceived, isNotNull);
      expect(updatedReceived!.level, equals(2));
      // Rebalanced Ichor-to-XP training: 100 XP to reach Lv 2 costs 40 Ichor
      expect(costReceived, equals(40));

      // Dialog should now display updated level and remaining Ichor (1000 - 40 = 960)
      expect(find.text('Lv. 2/10'), findsWidgets);
      expect(find.text('Available: 960 Ichor'), findsOneWidget);
    });

    testWidgets('CrucibleScreen allows progenitor infusion before fusion', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const parentHoundA = UnitEntity(
        id: 'hound_parent_a',
        speciesId: 'feral_hound',
        name: 'Hound Alpha',
        generation: 1,
        archetype: Archetype.skirmisher,
        slot: FormationSlot.front1,
        level: 1, // Not maxed (5% premature inheritance)
        maxLevel: 10,
        currentHp: 500,
        maxHp: 500,
        attack: 110,
        defense: 90,
        speed: 100,
        nativeTraitId: 'rend_flesh',
        lineageAncestors: [],
      );

      const parentHoundB = UnitEntity(
        id: 'hound_parent_b',
        speciesId: 'feral_hound',
        name: 'Hound Beta',
        generation: 1,
        archetype: Archetype.skirmisher,
        slot: FormationSlot.front2,
        level: 10, // Maxed (10% full inheritance)
        maxLevel: 10,
        currentHp: 700,
        maxHp: 700,
        attack: 140,
        defense: 110,
        speed: 105,
        nativeTraitId: 'pack_instinct',
        lineageAncestors: [],
      );

      UnitEntity? leveledProgenitor;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CrucibleScreen(
              availableInventory: const [parentHoundA, parentHoundB],
              totalIchor: 500,
              bloodlineSigils: 2,
              onFusionComplete: (_) {},
              onUnitLeveled: (u, cost) {
                leveledProgenitor = u;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Progenitor A should show INFUSE (Lv.2) button since it's Lv 1/10
      expect(find.text('INFUSE (Lv.2)'), findsOneWidget);

      await tester.tap(find.text('INFUSE (Lv.2)'));
      await tester.pumpAndSettle();

      expect(leveledProgenitor, isNotNull);
      expect(leveledProgenitor!.level, equals(2));
      expect(find.text('Lv. 2/10'), findsOneWidget);
    });
  });
}
