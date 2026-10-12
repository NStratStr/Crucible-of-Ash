import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/features/combat/combat_resolution_service.dart';
import 'package:ashen_crucible/features/combat/enemy_ai_service.dart';
import 'package:ashen_crucible/features/combat/initiative_tick_manager.dart';
import 'package:ashen_crucible/features/generals/general_command_service.dart';
import 'package:ashen_crucible/shared/models/skill_entity.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';

void main() {
  group('GDD v2.9 Rule-Breaking AoE & Cleave Skill Targeting Tests', () {
    const allyFront1 = UnitEntity(
      id: 'ally_front_1',
      name: 'Iron Footman',
      level: 10,
      maxLevel: 30,
      archetype: Archetype.juggernaut,
      slot: FormationSlot.front1, // Col 0, Frontline
      currentHp: 1000,
      maxHp: 1000,
      attack: 100,
      defense: 100,
      speed: 90,
      speciesId: 'iron_footman',
      generation: 1,
      nativeTraitId: 'none',
      lineageAncestors: [],
    );

    const allyFront2 = UnitEntity(
      id: 'ally_front_2',
      name: 'Sun-Forged Veteran',
      level: 10,
      maxLevel: 30,
      archetype: Archetype.juggernaut,
      slot: FormationSlot.front2, // Col 1, Frontline
      currentHp: 900,
      maxHp: 900,
      attack: 120,
      defense: 80,
      speed: 95,
      speciesId: 'sun_forged_veteran',
      generation: 2,
      nativeTraitId: 'none',
      lineageAncestors: [],
    );

    const allyBack1 = UnitEntity(
      id: 'ally_back_1',
      name: 'Field Medicus',
      level: 10,
      maxLevel: 30,
      archetype: Archetype.support,
      slot: FormationSlot.back1, // Col 3, Backline
      currentHp: 600,
      maxHp: 600,
      attack: 90,
      defense: 50,
      speed: 100,
      speciesId: 'medicus',
      generation: 1,
      nativeTraitId: 'none',
      lineageAncestors: [],
    );

    const enemyBoss = UnitEntity(
      id: 'enemy_boss',
      name: 'Slag Behemoth',
      level: 15,
      maxLevel: 50,
      archetype: Archetype.juggernaut,
      slot: FormationSlot.front1, // Col 0
      currentHp: 3000,
      maxHp: 3000,
      attack: 200,
      defense: 120,
      speed: 110,
      turnMeter: 0.0,
      speciesId: 'boss_golem',
      generation: 3,
      nativeTraitId: 'none',
      lineageAncestors: [],
    );

    test('frontlineEnemies skill damages all living Frontline units while sparing Backline', () {
      final tickManager = InitiativeTickManager(
        initialAllies: [allyFront1, allyFront2, allyBack1],
        initialEnemies: [enemyBoss.copyWith(turnMeter: 100.0)],
      );
      tickManager.advanceTick(); // primes boss turn

      final combatService = CombatResolutionService(
        tickManager: tickManager,
      );

      const frontlineCleave = SkillEntity(
        id: 'titanic_cleave',
        name: 'Titanic Cleave',
        description: 'Sweeps across all frontline units',
        damageCoefficient: 1.2,
        targetType: SkillTargetType.frontlineEnemies,
      );

      final result = combatService.executeSkill(
        targetUnitId: allyFront1.id,
        skill: frontlineCleave,
      );

      expect(result.damageDealt, greaterThan(0));

      final updatedFront1 = tickManager.allies.firstWhere((u) => u.id == allyFront1.id);
      final updatedFront2 = tickManager.allies.firstWhere((u) => u.id == allyFront2.id);
      final updatedBack1 = tickManager.allies.firstWhere((u) => u.id == allyBack1.id);

      // Both frontline units took damage
      expect(updatedFront1.currentHp, lessThan(allyFront1.maxHp));
      expect(updatedFront2.currentHp, lessThan(allyFront2.maxHp));
      // Backline healer was not cleaved!
      expect(updatedBack1.currentHp, equals(allyBack1.maxHp));
    });

    test('allEnemies AoE skill damages all opposing units regardless of line', () {
      final tickManager = InitiativeTickManager(
        initialAllies: [allyFront1, allyFront2, allyBack1],
        initialEnemies: [enemyBoss.copyWith(turnMeter: 100.0)],
      );
      tickManager.advanceTick();

      final combatService = CombatResolutionService(
        tickManager: tickManager,
      );

      const novaAoE = SkillEntity(
        id: 'abyssal_nova',
        name: 'Abyssal Nova',
        description: 'Hits all units',
        damageCoefficient: 1.5,
        targetType: SkillTargetType.allEnemies,
      );

      final result = combatService.executeSkill(
        targetUnitId: allyFront1.id,
        skill: novaAoE,
      );

      expect(result.damageDealt, greaterThan(0));

      final updatedFront1 = tickManager.allies.firstWhere((u) => u.id == allyFront1.id);
      final updatedFront2 = tickManager.allies.firstWhere((u) => u.id == allyFront2.id);
      final updatedBack1 = tickManager.allies.firstWhere((u) => u.id == allyBack1.id);

      // All 3 allies took damage from full room AoE
      expect(updatedFront1.currentHp, lessThan(allyFront1.maxHp));
      expect(updatedFront2.currentHp, lessThan(allyFront2.maxHp));
      expect(updatedBack1.currentHp, lessThan(allyBack1.maxHp));
    });

    test('allAllies support skill heals and buffs all living squad members', () {
      final woundedFront1 = allyFront1.copyWith(currentHp: 500);
      final woundedFront2 = allyFront2.copyWith(currentHp: 400);
      final primedMedicus = allyBack1.copyWith(turnMeter: 100.0);

      final tickManager = InitiativeTickManager(
        initialAllies: [woundedFront1, woundedFront2, primedMedicus],
        initialEnemies: [enemyBoss],
      );
      tickManager.advanceTick(); // primes Medicus turn

      final combatService = CombatResolutionService(
        tickManager: tickManager,
      );

      const ancestralWard = SkillEntity(
        id: 'ancestral_ward',
        name: 'Ancestral Ward',
        description: 'Heals team and grants Armor Up',
        damageCoefficient: 0.0,
        targetType: SkillTargetType.allAllies,
        appliedStatus: StatusEffect(type: StatusEffectType.defenseUp, durationTurns: 2, value: 30),
      );

      combatService.executeSkill(
        targetUnitId: primedMedicus.id,
        skill: ancestralWard,
      );

      final updatedFront1 = tickManager.allies.firstWhere((u) => u.id == woundedFront1.id);
      final updatedFront2 = tickManager.allies.firstWhere((u) => u.id == woundedFront2.id);
      final updatedMedicus = tickManager.allies.firstWhere((u) => u.id == primedMedicus.id);

      // Both wounded allies received heals
      expect(updatedFront1.currentHp, greaterThan(500));
      expect(updatedFront2.currentHp, greaterThan(400));
      // All allies received the Armor Up buff
      expect(updatedFront1.activeEffects.any((e) => e.type == StatusEffectType.defenseUp), isTrue);
      expect(updatedFront2.activeEffects.any((e) => e.type == StatusEffectType.defenseUp), isTrue);
      expect(updatedMedicus.activeEffects.any((e) => e.type == StatusEffectType.defenseUp), isTrue);
    });
  });
}
