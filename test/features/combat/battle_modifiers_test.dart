import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/features/combat/combat_resolution_service.dart';
import 'package:ashen_crucible/features/combat/initiative_tick_manager.dart';
import 'package:ashen_crucible/shared/models/skill_entity.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';

void main() {
  group('Endgame Gauntlet Battle Modifiers Tests', () {
    test('Corrosive Miasma deals 30 poison damage to non-Occultists at turn start', () {
      final juggernaut = const UnitEntity(
        id: 'ally_tank',
        speciesId: 'iron_golem',
        name: 'Iron Golem',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 10,
        maxLevel: 30,
        currentHp: 500,
        maxHp: 500,
        attack: 100,
        defense: 100,
        speed: 100,
        nativeTraitId: 'iron_skin',
        lineageAncestors: [],
      );

      final tickManager = InitiativeTickManager(
        initialAllies: [juggernaut],
        initialEnemies: [
          const UnitEntity(
            id: 'enemy_1',
            speciesId: 'goblin',
            name: 'Goblin',
            generation: 1,
            archetype: Archetype.assassin,
            slot: FormationSlot.front1,
            level: 10,
            maxLevel: 30,
            currentHp: 300,
            maxHp: 300,
            attack: 80,
            defense: 50,
            speed: 90,
            nativeTraitId: 'none',
            lineageAncestors: [],
          ),
        ],
      );

      final service = CombatResolutionService(
        tickManager: tickManager,
        battleModifier: BattleModifier.corrosiveMiasma,
      );

      final result = service.processTurnStart(unitId: 'ally_tank');
      expect(result.dotDamage, 30);
      expect(result.unit.currentHp, 470);
      expect(result.triggeredTraits.contains('corrosive_miasma'), isTrue);
    });

    test('Corrosive Miasma spares Occultist units at turn start', () {
      final occultist = const UnitEntity(
        id: 'ally_mage',
        speciesId: 'warlock',
        name: 'Blight Warlock',
        generation: 1,
        archetype: Archetype.occultist,
        slot: FormationSlot.back1,
        level: 10,
        maxLevel: 30,
        currentHp: 400,
        maxHp: 400,
        attack: 150,
        defense: 50,
        speed: 100,
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      final tickManager = InitiativeTickManager(
        initialAllies: [occultist],
        initialEnemies: [
          const UnitEntity(
            id: 'enemy_1',
            speciesId: 'goblin',
            name: 'Goblin',
            generation: 1,
            archetype: Archetype.assassin,
            slot: FormationSlot.front1,
            level: 10,
            maxLevel: 30,
            currentHp: 300,
            maxHp: 300,
            attack: 80,
            defense: 50,
            speed: 90,
            nativeTraitId: 'none',
            lineageAncestors: [],
          ),
        ],
      );

      final service = CombatResolutionService(
        tickManager: tickManager,
        battleModifier: BattleModifier.corrosiveMiasma,
      );

      final result = service.processTurnStart(unitId: 'ally_mage');
      expect(result.dotDamage, 0);
      expect(result.unit.currentHp, 400);
      expect(result.triggeredTraits.contains('corrosive_miasma'), isFalse);
    });

    test('Blood Moon amplifies critical strike damage by +50%', () {
      final attacker = const UnitEntity(
        id: 'ally_critter',
        speciesId: 'assassin_stalker',
        name: 'Assassin Stalker',
        generation: 1,
        archetype: Archetype.assassin,
        slot: FormationSlot.front1,
        level: 10,
        maxLevel: 30,
        currentHp: 500,
        maxHp: 500,
        attack: 200,
        defense: 50,
        speed: 100,
        turnMeter: 100.0,
        critRate: 1.0, // Guaranteed crit
        critDamage: 1.50,
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      final target = const UnitEntity(
        id: 'enemy_1',
        speciesId: 'target_dummy',
        name: 'Target Dummy',
        generation: 1,
        archetype: Archetype.assassin, // Neutral affinity vs Assassin
        slot: FormationSlot.front1,
        level: 10,
        maxLevel: 30,
        currentHp: 1000,
        maxHp: 1000,
        attack: 50,
        defense: 0,
        speed: 80,
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      final tickManagerDefault = InitiativeTickManager(
        initialAllies: [attacker],
        initialEnemies: [target],
      );
      tickManagerDefault.advanceTick();

      final tickManagerBloodMoon = InitiativeTickManager(
        initialAllies: [attacker],
        initialEnemies: [target],
      );
      tickManagerBloodMoon.advanceTick();

      final serviceDefault = CombatResolutionService(
        tickManager: tickManagerDefault,
        battleModifier: BattleModifier.none,
        rng: Random(42),
      );
      final resDefault = serviceDefault.executeSkill(
        targetUnitId: 'enemy_1',
        skill: const SkillEntity(
          id: 'test_hit',
          name: 'Strike',
          description: '',
          damageCoefficient: 1.0,
        ),
      );

      final serviceBloodMoon = CombatResolutionService(
        tickManager: tickManagerBloodMoon,
        battleModifier: BattleModifier.bloodMoon,
        rng: Random(42),
      );
      final resBloodMoon = serviceBloodMoon.executeSkill(
        targetUnitId: 'enemy_1',
        skill: const SkillEntity(
          id: 'test_hit',
          name: 'Strike',
          description: '',
          damageCoefficient: 1.0,
        ),
      );

      expect(resDefault.isCritical, isTrue);
      expect(resBloodMoon.isCritical, isTrue);
      // Blood Moon crit multiplier is 1.50 + 0.50 = 2.00 vs 1.50 default (33% higher overall damage)
      expect(resBloodMoon.damageDealt, greaterThan(resDefault.damageDealt));
      expect(resBloodMoon.damageDealt / resDefault.damageDealt, closeTo(2.00 / 1.50, 0.05));
    });

    test('Titanic Fury boss attack cleaves all alive frontline Vanguard units', () {
      final boss = const UnitEntity(
        id: 'boss_titan',
        speciesId: 'ashen_titan',
        name: 'The Ashen World Titan',
        generation: 4,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 40,
        maxLevel: 40,
        currentHp: 4500,
        maxHp: 4500,
        attack: 300,
        defense: 250,
        speed: 80,
        turnMeter: 100.0,
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      final vanguard1 = const UnitEntity(
        id: 'ally_v1',
        speciesId: 'footman',
        name: 'Vanguard 1',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1, // Vanguard
        level: 10,
        maxLevel: 30,
        currentHp: 600,
        maxHp: 600,
        attack: 100,
        defense: 100,
        speed: 90,
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      final vanguard2 = const UnitEntity(
        id: 'ally_v2',
        speciesId: 'footman',
        name: 'Vanguard 2',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front2, // Vanguard
        level: 10,
        maxLevel: 30,
        currentHp: 600,
        maxHp: 600,
        attack: 100,
        defense: 100,
        speed: 90,
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      final arcanum = const UnitEntity(
        id: 'ally_arc',
        speciesId: 'mage',
        name: 'Arcanum 1',
        generation: 1,
        archetype: Archetype.occultist,
        slot: FormationSlot.back1, // Backline Arcanum
        level: 10,
        maxLevel: 30,
        currentHp: 400,
        maxHp: 400,
        attack: 150,
        defense: 50,
        speed: 90,
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      final tickManager = InitiativeTickManager(
        initialAllies: [vanguard1, vanguard2, arcanum],
        initialEnemies: [boss],
      );
      tickManager.advanceTick();

      final service = CombatResolutionService(
        tickManager: tickManager,
        battleModifier: BattleModifier.titanicFury,
      );

      // Boss strikes vanguard1
      service.executeSkill(
        targetUnitId: 'ally_v1',
        skill: const SkillEntity(
          id: 'boss_smash',
          name: 'Colossal Slam',
          description: '',
          damageCoefficient: 1.0,
        ),
      );

      final updatedV1 = tickManager.allies.firstWhere((u) => u.id == 'ally_v1');
      final updatedV2 = tickManager.allies.firstWhere((u) => u.id == 'ally_v2');
      final updatedArc = tickManager.allies.firstWhere((u) => u.id == 'ally_arc');

      // Primary target took damage
      expect(updatedV1.currentHp, lessThan(600));
      // Vanguard 2 was cleaved simultaneously by Titanic Fury
      expect(updatedV2.currentHp, lessThan(600));
      // Backline Arcanum was NOT cleaved by frontline Titanic Fury
      expect(updatedArc.currentHp, equals(400));
    });
  });
}
