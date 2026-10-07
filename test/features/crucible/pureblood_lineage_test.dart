import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/features/crucible/crucible_service.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';
import 'package:ashen_crucible/shared/widgets/gothic_card_frame_widget.dart';
import 'package:ashen_crucible/shared/widgets/pedigree_inspector_dialog.dart';

void main() {
  group('Pureblood Generational Lineage & Crucible Tests', () {
    test('Fusing Gen 3 units produces Gen 4 Pureblood with +15% Resonance stats and Lv 50 cap', () {
      const parentA = UnitEntity(
        id: 'parent_g3_a',
        speciesId: 'feral_hound',
        name: 'Cerberus Heir Alpha',
        generation: 3,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 45,
        maxLevel: 45, // Max level
        currentHp: 1200,
        maxHp: 1200,
        attack: 240,
        defense: 180,
        speed: 120,
        nativeTraitId: 'rend_flesh',
        lineageAncestors: ['gen1_alpha', 'gen2_alpha'],
      );

      const parentB = UnitEntity(
        id: 'parent_g3_b',
        speciesId: 'feral_hound',
        name: 'Cerberus Heir Beta',
        generation: 3,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front2,
        level: 45,
        maxLevel: 45, // Max level
        currentHp: 1150,
        maxHp: 1150,
        attack: 230,
        defense: 190,
        speed: 115,
        nativeTraitId: 'iron_bastion',
        lineageAncestors: ['gen1_beta', 'gen2_beta'],
      );

      final child = CrucibleService.fuseUnits(
        parentA: parentA,
        parentB: parentB,
        childSpeciesId: 'cerberus_hound',
        childName: 'Pureblood Cerberus Sovereign',
        childArchetype: Archetype.juggernaut,
        assignedSlot: FormationSlot.front1,
        speciesBaseHp: 800,
        speciesBaseAtk: 150,
        speciesBaseDef: 100,
        speciesBaseSpd: 100,
        childNativeTraitId: 'rend_flesh',
        selectedGraftTraitId: 'iron_bastion',
      );

      // Verify Gen 4 Pureblood status
      expect(child.generation, 4);
      expect(child.isPureblood, isTrue);
      expect(child.generationTitle, 'Pureblood (Gen 4)');
      expect(child.maxLevel, 50);

      // Verify Pureblood Resonance (+15% compounded stats)
      // Base bonus from parents: 10% of (1200 + 1150) = 235 HP bonus -> 800 + 235 = 1035 -> 1035 * 1.15 = 1190
      final expectedBonusHp = ((1200 * 0.10) + (1150 * 0.10)).round(); // 235
      final expectedFinalHp = ((800 + expectedBonusHp) * 1.15).round(); // 1190
      expect(child.maxHp, expectedFinalHp);
      expect(child.currentHp, expectedFinalHp);

      final expectedBonusAtk = ((240 * 0.10) + (230 * 0.10)).round(); // 47
      final expectedFinalAtk = ((150 + expectedBonusAtk) * 1.15).round(); // 227
      expect(child.attack, expectedFinalAtk);

      // Verify ancestry lineage contains both parent pedigrees
      expect(child.lineageAncestors, contains('parent_g3_a'));
      expect(child.lineageAncestors, contains('parent_g3_b'));
      expect(child.lineageAncestors, contains('gen1_alpha'));
      expect(child.lineageAncestors, contains('gen2_beta'));
    });

    testWidgets('GothicCardFrameWidget renders glowing PUREBLOOD crest for Gen 4 champions', (tester) async {
      const purebloodUnit = UnitEntity(
        id: 'pureblood_champ',
        speciesId: 'cerberus_hound',
        name: 'Pureblood Cerberus Sovereign',
        generation: 4,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 1,
        maxLevel: 50,
        currentHp: 1200,
        maxHp: 1200,
        attack: 230,
        defense: 180,
        speed: 140,
        nativeTraitId: 'rend_flesh',
        graftedTraitId: 'iron_bastion',
        lineageAncestors: ['ancestor_1', 'ancestor_2'],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GothicCardFrameWidget(
              unit: purebloodUnit,
              width: 200,
              height: 280,
            ),
          ),
        ),
      );

      expect(find.text('PUREBLOOD'), findsOneWidget);
      expect(find.text('GEN 4'), findsNothing);
    });

    testWidgets('PedigreeInspectorDialog displays Pureblood Sovereignty banner for Gen 4 unit', (tester) async {
      const purebloodUnit = UnitEntity(
        id: 'pureblood_champ',
        speciesId: 'cerberus_hound',
        name: 'Pureblood Cerberus Sovereign',
        generation: 4,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 25,
        maxLevel: 50,
        currentHp: 1200,
        maxHp: 1200,
        attack: 230,
        defense: 180,
        speed: 140,
        nativeTraitId: 'rend_flesh',
        graftedTraitId: 'iron_bastion',
        lineageAncestors: ['ancestor_1', 'ancestor_2'],
      );

      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PedigreeInspectorDialog(
              unit: purebloodUnit,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PUREBLOOD SOVEREIGNTY ACTIVE'), findsOneWidget);
      expect(find.textContaining('+15% Pureblood resonance across all attributes'), findsOneWidget);
    });
  });
}
