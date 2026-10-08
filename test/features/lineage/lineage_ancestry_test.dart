import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/features/campaign/endgame_gauntlet_dialog.dart';
import 'package:ashen_crucible/features/crucible/crucible_service.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';
import 'package:ashen_crucible/shared/widgets/pedigree_inspector_dialog.dart';

void main() {
  group('Lineage Ancestry & Crypt Verification Tests', () {
    const parentHoundA = UnitEntity(
      id: 'hound_parent_a',
      speciesId: 'feral_hound',
      name: 'Feral Hound Alpha',
      generation: 1,
      archetype: Archetype.juggernaut,
      slot: FormationSlot.front1,
      level: 10,
      maxLevel: 10,
      currentHp: 750,
      maxHp: 750,
      attack: 135,
      defense: 120,
      speed: 105,
      nativeTraitId: 'rend_flesh',
      lineageAncestors: ['bloodline_beast'],
    );

    const parentHoundB = UnitEntity(
      id: 'hound_parent_b',
      speciesId: 'feral_hound',
      name: 'Feral Hound Beta',
      generation: 1,
      archetype: Archetype.juggernaut,
      slot: FormationSlot.front1,
      level: 10,
      maxLevel: 10,
      currentHp: 720,
      maxHp: 720,
      attack: 140,
      defense: 115,
      speed: 110,
      nativeTraitId: 'pack_instinct',
      lineageAncestors: ['bloodline_beast'],
    );

    test('Crucible fusion preserves species lineage and compounds ancestral pedigree', () {
      final child = CrucibleService.fuseUnits(
        parentA: parentHoundA,
        parentB: parentHoundB,
        childSpeciesId: 'feral_hound',
        childName: 'Cerberus Whelp',
        childArchetype: Archetype.skirmisher,
        assignedSlot: FormationSlot.front2,
        speciesBaseHp: 800,
        speciesBaseAtk: 150,
        speciesBaseDef: 130,
        speciesBaseSpd: 115,
        childNativeTraitId: 'rend_flesh',
        selectedGraftTraitId: 'pack_instinct',
      );

      expect(child.generation, equals(2));
      expect(child.hasBeastLineage, isTrue);
      expect(child.lineageAncestors, contains('bloodline_beast'));
      expect(child.lineageAncestors, contains('feral_hound'));
      expect(child.verifiedLineageTags, contains('Beastline'));
    });

    test('Unit with deathless ancestry is recognized by hasUndeadLineage', () {
      const graveWarlock = UnitEntity(
        id: 'grave_descendant_1',
        speciesId: 'void_chimera',
        name: 'Void Necromancer',
        generation: 3,
        archetype: Archetype.marksman, // Even if class is marksman, bloodline carries undead!
        slot: FormationSlot.back1,
        level: 20,
        maxLevel: 40,
        currentHp: 700,
        maxHp: 700,
        attack: 210,
        defense: 90,
        speed: 110,
        nativeTraitId: 'blight_curse',
        lineageAncestors: ['grave_disciple', 'bloodline_undead'],
      );

      expect(graveWarlock.hasUndeadLineage, isTrue);
      expect(graveWarlock.verifiedLineageTags, contains('Deathless'));
    });

    testWidgets('EndgameGauntletDialog unlocks Den of Fangs when 2+ units have verified Beast ancestry', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Squad with 2 Beastline descendants
      final childHound = CrucibleService.fuseUnits(
        parentA: parentHoundA,
        parentB: parentHoundB,
        childSpeciesId: 'feral_hound',
        childName: 'Cerberus Whelp',
        childArchetype: Archetype.skirmisher,
        assignedSlot: FormationSlot.front1,
        speciesBaseHp: 800,
        speciesBaseAtk: 150,
        speciesBaseDef: 130,
        speciesBaseSpd: 115,
        childNativeTraitId: 'rend_flesh',
        selectedGraftTraitId: 'pack_instinct',
      );

      final squad = [
        childHound,
        parentHoundA,
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EndgameGauntletDialog(
              activeSquad: squad,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('LINEAGE CRYPT: DEN OF FANGS'), findsOneWidget);
      expect(find.textContaining('RESTRICTION MET: 2 Beasts/Skirmishers Ready'), findsOneWidget);
    });

    testWidgets('PedigreeInspectorDialog displays VERIFIED LINEAGE BLOODLINES badge', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const beastChampion = UnitEntity(
        id: 'beast_champ_01',
        speciesId: 'feral_hound',
        name: 'Bloodfang Warlord',
        generation: 3,
        archetype: Archetype.skirmisher,
        slot: FormationSlot.front1,
        level: 30,
        maxLevel: 45,
        currentHp: 1100,
        maxHp: 1100,
        attack: 280,
        defense: 180,
        speed: 135,
        nativeTraitId: 'rend_flesh',
        lineageAncestors: ['bloodline_beast', 'feral_hound'],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PedigreeInspectorDialog(
              unit: beastChampion,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('VERIFIED LINEAGE BLOODLINES'), findsOneWidget);
      expect(find.text('BEASTLINE'), findsOneWidget);
    });
  });
}
