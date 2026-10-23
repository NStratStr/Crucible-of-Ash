import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/features/crucible/crucible_service.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';

void main() {
  group('GDD v2.6 Crucible Duplicate Fusion & Economy Tests', () {
    const parentA = UnitEntity(
      id: 'footman_g1_01',
      speciesId: 'iron_footman',
      name: 'Iron Footman Alpha',
      generation: 1,
      archetype: Archetype.juggernaut,
      slot: FormationSlot.front1,
      level: 10,
      maxLevel: 30,
      currentHp: 1000,
      maxHp: 1000,
      attack: 100,
      defense: 80,
      speed: 90,
      resist: 40,
      nativeTraitId: 'ironclad_guard',
      lineageAncestors: [],
    );

    const parentB = UnitEntity(
      id: 'footman_g1_02',
      speciesId: 'iron_footman',
      name: 'Iron Footman Beta',
      generation: 1,
      archetype: Archetype.juggernaut,
      slot: FormationSlot.front2,
      level: 12,
      maxLevel: 30,
      currentHp: 1100,
      maxHp: 1100,
      attack: 110,
      defense: 90,
      speed: 92,
      resist: 42,
      nativeTraitId: 'ironclad_guard',
      lineageAncestors: [],
    );

    test('Exponential Fusion Tax matches GDD Section 12 formula', () {
      // Cost = 1000 * (1.85)^Gen
      expect(CrucibleService.calculateFusionCostAsh(1), equals(1850));
      expect(CrucibleService.calculateFusionCostAsh(2), equals(3423));
      expect(CrucibleService.calculateFusionCostAsh(3), equals(6332));
    });

    test('G1 + G1 produces G2 with +6% stat ceiling and Gaussian blending', () {
      // With fixed variance 1.0 (mean):
      // Gen = 2 => Stat ceiling modifier = 1 + (2 * 0.03) = 1.06 (+6%)
      final child = CrucibleService.fuseMvpDuplicates(
        parentA: parentA,
        parentB: parentB,
        fixedVariance: 1.0,
      );

      expect(child.generation, equals(2));
      expect(child.maxLevel, equals(40)); // 30 + (2 * 5)
      // HP: ((1000 + 1100) / 2) * 1.06 = 1050 * 1.06 = 1113
      expect(child.maxHp, equals(1113));
      // ATK: ((100 + 110) / 2) * 1.06 = 105 * 1.06 = 111.3 -> 111
      expect(child.attack, equals(111));
      // DEF: ((80 + 90) / 2) * 1.06 = 85 * 1.06 = 90.1 -> 90
      expect(child.defense, equals(90));
      // Lineage ancestors recorded
      expect(child.lineageAncestors, containsAll(['footman_g1_01', 'footman_g1_02']));
    });

    test('G2 + G2 produces G3 with +9% stat ceiling', () {
      final g2ParentA = CrucibleService.fuseMvpDuplicates(
        parentA: parentA,
        parentB: parentB,
        fixedVariance: 1.0,
      );
      final g2ParentB = CrucibleService.fuseMvpDuplicates(
        parentA: parentA,
        parentB: parentB,
        fixedVariance: 1.0,
      );

      final g3Child = CrucibleService.fuseMvpDuplicates(
        parentA: g2ParentA,
        parentB: g2ParentB,
        fixedVariance: 1.0,
      );

      expect(g3Child.generation, equals(3));
      expect(g3Child.maxLevel, equals(45)); // 30 + (3 * 5)
      // Stat ceiling modifier = 1 + (3 * 0.03) = 1.09 (+9%)
      // HP: 1113 * 1.09 = 1213.17 -> 1213
      expect(g3Child.maxHp, equals(1213));
    });

    test('Fusing allows progression up to Gen 6 and blocks beyond Gen 6', () {
      final g2A = CrucibleService.fuseMvpDuplicates(parentA: parentA, parentB: parentB, fixedVariance: 1.0);
      final g2B = CrucibleService.fuseMvpDuplicates(parentA: parentA, parentB: parentB, fixedVariance: 1.0);
      final g3A = CrucibleService.fuseMvpDuplicates(parentA: g2A, parentB: g2B, fixedVariance: 1.0);
      final g3B = CrucibleService.fuseMvpDuplicates(parentA: g2A, parentB: g2B, fixedVariance: 1.0);
      expect(g3A.generation, equals(3));

      final g4A = CrucibleService.fuseMvpDuplicates(parentA: g3A, parentB: g3B, fixedVariance: 1.0);
      final g4B = CrucibleService.fuseMvpDuplicates(parentA: g3A, parentB: g3B, fixedVariance: 1.0);
      expect(g4A.generation, equals(4));

      final g5A = CrucibleService.fuseMvpDuplicates(parentA: g4A, parentB: g4B, fixedVariance: 1.0);
      final g5B = CrucibleService.fuseMvpDuplicates(parentA: g4A, parentB: g4B, fixedVariance: 1.0);
      expect(g5A.generation, equals(5));

      final g6 = CrucibleService.fuseMvpDuplicates(parentA: g5A, parentB: g5B, fixedVariance: 1.0);
      expect(g6.generation, equals(6));
      expect(g6.name, contains('Apex'));

      expect(
        () => CrucibleService.fuseMvpDuplicates(parentA: g6, parentB: g6, fixedVariance: 1.0),
        throwsA(isA<StateError>()),
      );
    });

    test('Auto-Synthesis rolls duplicate G1s and G2s into G3 veterans', () {
      // 4x G1 Iron Footmen
      final inventory = [
        parentA.copyWith(id: 'f1'),
        parentA.copyWith(id: 'f2'),
        parentA.copyWith(id: 'f3'),
        parentA.copyWith(id: 'f4'),
      ];

      final result = CrucibleService.autoSynthesizeDuplicates(
        inventory,
        fixedVariance: 1.0,
      );

      // 4x G1 -> 2x G2 -> 1x G3
      expect(result.synthesizedUnits.length, equals(3)); // two G2s + one G3
      expect(result.remainingInventory.length, equals(1));
      expect(result.remainingInventory.first.generation, equals(3));
      expect(result.consumedUnitIds, containsAll(['f1', 'f2', 'f3', 'f4']));
      // Ash cost: 2x G2 cost (3423 * 2) + 1x G3 cost (6332) = 6846 + 6332 = 13178
      expect(result.totalAshCost, equals(3423 * 2 + 6332));
    });

    test('Auto-Synthesis respects lockedUnitIds', () {
      final inventory = [
        parentA.copyWith(id: 'f1'),
        parentA.copyWith(id: 'f2'),
        parentA.copyWith(id: 'f3'),
        parentA.copyWith(id: 'f4'),
      ];

      // Lock f1
      final result = CrucibleService.autoSynthesizeDuplicates(
        inventory,
        lockedUnitIds: {'f1'},
        fixedVariance: 1.0,
      );

      // Only f2 and f3 fuse into one G2; f4 and f1 remain
      expect(result.synthesizedUnits.length, equals(1));
      expect(result.consumedUnitIds, containsAll(['f2', 'f3']));
      expect(result.consumedUnitIds, isNot(contains('f1')));
    });
  });
}
