import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';
import 'package:ashen_crucible/features/crucible/crucible_service.dart';

void main() {
  group('CrucibleService Tests', () {
    late UnitEntity maxParentA;
    late UnitEntity maxParentB;
    late UnitEntity unmaxedParent;

    setUp(() {
      maxParentA = const UnitEntity(
        id: 'hound_alpha',
        speciesId: 'feral_hound',
        name: 'Hound Alpha',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 10,
        maxLevel: 10,
        currentHp: 1000,
        maxHp: 1000,
        attack: 200,
        defense: 100,
        speed: 100,
        nativeTraitId: 'rend',
        lineageAncestors: [],
      );

      maxParentB = const UnitEntity(
        id: 'hound_beta',
        speciesId: 'feral_hound',
        name: 'Hound Beta',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 10,
        maxLevel: 10,
        currentHp: 1200,
        maxHp: 1200,
        attack: 180,
        defense: 120,
        speed: 110,
        nativeTraitId: 'pack_hunter',
        lineageAncestors: [],
      );

      unmaxedParent = const UnitEntity(
        id: 'hound_gamma',
        speciesId: 'feral_hound',
        name: 'Hound Gamma',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 5,
        maxLevel: 10,
        currentHp: 800,
        maxHp: 800,
        attack: 150,
        defense: 90,
        speed: 95,
        nativeTraitId: 'bark',
        lineageAncestors: [],
      );
    });

    test('Max-level parents transfer full 10% stats to Gen 2 child', () {
      final child = CrucibleService.fuseUnits(
        parentA: maxParentA,
        parentB: maxParentB,
        childSpeciesId: 'feral_hound',
        childName: 'Cerberus Spawn',
        childArchetype: Archetype.juggernaut,
        assignedSlot: FormationSlot.front1,
        speciesBaseHp: 800,
        speciesBaseAtk: 150,
        speciesBaseDef: 100,
        speciesBaseSpd: 100,
        childNativeTraitId: 'rend',
        selectedGraftTraitId: 'pack_hunter',
      );

      expect(child.generation, equals(2));
      // HP: 800 + (1000 * 0.10) + (1200 * 0.10) = 800 + 100 + 120 = 1020
      expect(child.maxHp, equals(1020));
      // ATK: 150 + (200 * 0.10) + (180 * 0.10) = 150 + 20 + 18 = 188
      expect(child.attack, equals(188));
      // DEF: 100 + (100 * 0.10) + (120 * 0.10) = 100 + 10 + 12 = 122
      expect(child.defense, equals(122));
      // SPD: 100 + (100 * 0.10) + (110 * 0.10) = 100 + 10 + 11 = 121
      expect(child.speed, equals(121));

      expect(child.graftedTraitId, equals('pack_hunter'));
      expect(child.lineageAncestors, containsAll(['hound_alpha', 'hound_beta']));
    });

    test('Premature unmaxed parent transfers only 5% stats', () {
      final child = CrucibleService.fuseUnits(
        parentA: maxParentA, // 10% transfer -> (1000 * 0.10) = 100 HP, (200 * 0.10) = 20 ATK
        parentB: unmaxedParent, // 5% transfer -> (800 * 0.05) = 40 HP, (150 * 0.05) = ~8 ATK
        childSpeciesId: 'feral_hound',
        childName: 'Flawed Cerberus',
        childArchetype: Archetype.juggernaut,
        assignedSlot: FormationSlot.front1,
        speciesBaseHp: 800,
        speciesBaseAtk: 150,
        speciesBaseDef: 100,
        speciesBaseSpd: 100,
        childNativeTraitId: 'rend',
        selectedGraftTraitId: 'bark',
      );

      // HP: 800 + 100 + 40 = 940
      expect(child.maxHp, equals(940));
      // ATK: 150 + 20 + 8 = 178
      expect(child.attack, equals(178));
    });

    test('Compounding lineage across 3 generations caps at Gen 4 Pureblood', () {
      final gen2 = CrucibleService.fuseUnits(
        parentA: maxParentA,
        parentB: maxParentB,
        childSpeciesId: 'feral_hound',
        childName: 'Gen 2',
        childArchetype: Archetype.juggernaut,
        assignedSlot: FormationSlot.front1,
        speciesBaseHp: 800,
        speciesBaseAtk: 150,
        speciesBaseDef: 100,
        speciesBaseSpd: 100,
        childNativeTraitId: 'rend',
        selectedGraftTraitId: 'pack_hunter',
      );

      final gen2Maxed = gen2.copyWith(level: gen2.maxLevel);

      final gen3 = CrucibleService.fuseUnits(
        parentA: gen2Maxed,
        parentB: gen2Maxed,
        childSpeciesId: 'feral_hound',
        childName: 'Gen 3',
        childArchetype: Archetype.juggernaut,
        assignedSlot: FormationSlot.front1,
        speciesBaseHp: 800,
        speciesBaseAtk: 150,
        speciesBaseDef: 100,
        speciesBaseSpd: 100,
        childNativeTraitId: 'rend',
        selectedGraftTraitId: 'pack_hunter',
      );

      expect(gen3.generation, equals(3));

      final gen3Maxed = gen3.copyWith(level: gen3.maxLevel);

      final pureblood = CrucibleService.fuseUnits(
        parentA: gen3Maxed,
        parentB: gen3Maxed,
        childSpeciesId: 'feral_hound',
        childName: 'Pureblood Hound',
        childArchetype: Archetype.juggernaut,
        assignedSlot: FormationSlot.front1,
        speciesBaseHp: 800,
        speciesBaseAtk: 150,
        speciesBaseDef: 100,
        speciesBaseSpd: 100,
        childNativeTraitId: 'rend',
        selectedGraftTraitId: 'pack_hunter',
      );

      expect(pureblood.generation, equals(4)); // Pureblood cap
    });
  });
}
