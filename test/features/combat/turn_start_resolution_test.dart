import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/features/combat/combat_resolution_service.dart';
import 'package:ashen_crucible/features/combat/initiative_tick_manager.dart';
import 'package:ashen_crucible/features/generals/general_command_service.dart';
import 'package:ashen_crucible/shared/models/skill_entity.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';

void main() {
  group('CombatResolutionService Turn-Start Processing Tests', () {
    test('Trait dark_heal (Sanguine Bloom) regenerates 8% max HP at turn start', () {
      const woundedHound = UnitEntity(
        id: 'ally_bloom',
        speciesId: 'feral_hound',
        name: 'Hound of Bloom',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 10,
        maxLevel: 10,
        currentHp: 400,
        maxHp: 1000, // 8% = 80 HP
        attack: 100,
        defense: 100,
        speed: 100,
        nativeTraitId: 'dark_heal',
        lineageAncestors: [],
      );

      final manager = InitiativeTickManager(
        initialAllies: [woundedHound],
        initialEnemies: const [
          UnitEntity(
            id: 'enemy_1',
            speciesId: 'goblin',
            name: 'Goblin',
            generation: 1,
            archetype: Archetype.assassin,
            slot: FormationSlot.front1,
            level: 10,
            maxLevel: 10,
            currentHp: 500,
            maxHp: 500,
            attack: 80,
            defense: 50,
            speed: 80,
            nativeTraitId: 'claw_slash',
            lineageAncestors: [],
          ),
        ],
      );

      final combatService = CombatResolutionService(tickManager: manager);

      final result = combatService.processTurnStart(unitId: woundedHound.id);

      expect(result.healAmount, equals(80));
      expect(result.dotDamage, equals(0));
      expect(result.isDefeated, isFalse);
      expect(result.isStunned, isFalse);
      expect(result.triggeredTraits, contains('dark_heal'));
      expect(manager.allies.first.currentHp, equals(480));
    });

    test('Trait sanguine_mend heals self and lowest HP ally at turn start', () {
      const mender = UnitEntity(
        id: 'ally_mender',
        speciesId: 'grave_disciple',
        name: 'Mender Disciple',
        generation: 1,
        archetype: Archetype.support,
        slot: FormationSlot.back1,
        level: 10,
        maxLevel: 10,
        currentHp: 400,
        maxHp: 600, // 6% = 36 HP
        attack: 100,
        defense: 100,
        speed: 100,
        nativeTraitId: 'sanguine_mend',
        lineageAncestors: [],
      );

      const woundedTank = UnitEntity(
        id: 'ally_tank',
        speciesId: 'iron_knight',
        name: 'Wounded Tank',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 10,
        maxLevel: 10,
        currentHp: 200,
        maxHp: 1000, // 6% = 60 HP
        attack: 100,
        defense: 100,
        speed: 80,
        nativeTraitId: 'iron_bastion',
        lineageAncestors: [],
      );

      final manager = InitiativeTickManager(
        initialAllies: [mender, woundedTank],
        initialEnemies: const [
          UnitEntity(
            id: 'enemy_1',
            speciesId: 'goblin',
            name: 'Goblin',
            generation: 1,
            archetype: Archetype.assassin,
            slot: FormationSlot.front1,
            level: 10,
            maxLevel: 10,
            currentHp: 500,
            maxHp: 500,
            attack: 80,
            defense: 50,
            speed: 80,
            nativeTraitId: 'claw_slash',
            lineageAncestors: [],
          ),
        ],
      );

      final combatService = CombatResolutionService(tickManager: manager);

      final result = combatService.processTurnStart(unitId: mender.id);

      expect(result.healAmount, equals(36));
      expect(result.triggeredTraits, contains('sanguine_mend'));
      expect(manager.allies.firstWhere((u) => u.id == mender.id).currentHp, equals(436));
      expect(manager.allies.firstWhere((u) => u.id == woundedTank.id).currentHp, equals(260));
    });

    test('Bleed and Blight DoTs inflict damage and tick down durations', () {
      const afflictedUnit = UnitEntity(
        id: 'ally_poisoned',
        speciesId: 'feral_hound',
        name: 'Afflicted Hound',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 10,
        maxLevel: 10,
        currentHp: 500,
        maxHp: 800,
        attack: 100,
        defense: 100,
        speed: 100,
        nativeTraitId: 'rend_flesh',
        lineageAncestors: [],
        activeEffects: [
          StatusEffect(type: StatusEffectType.bleed, durationTurns: 2, value: 50),
          StatusEffect(type: StatusEffectType.blight, durationTurns: 1, value: 40),
        ],
      );

      final manager = InitiativeTickManager(
        initialAllies: [afflictedUnit],
        initialEnemies: const [
          UnitEntity(
            id: 'enemy_1',
            speciesId: 'goblin',
            name: 'Goblin',
            generation: 1,
            archetype: Archetype.assassin,
            slot: FormationSlot.front1,
            level: 10,
            maxLevel: 10,
            currentHp: 500,
            maxHp: 500,
            attack: 80,
            defense: 50,
            speed: 80,
            nativeTraitId: 'claw_slash',
            lineageAncestors: [],
          ),
        ],
      );

      final combatService = CombatResolutionService(tickManager: manager);

      final result = combatService.processTurnStart(unitId: afflictedUnit.id);

      expect(result.dotDamage, equals(90)); // 50 Bleed + 40 Blight
      expect(manager.allies.first.currentHp, equals(410));

      // Bleed had 2 turns -> now 1 turn; Blight had 1 turn -> expired and removed
      final remainingEffects = manager.allies.first.activeEffects;
      expect(remainingEffects.length, equals(1));
      expect(remainingEffects.first.type, equals(StatusEffectType.bleed));
      expect(remainingEffects.first.durationTurns, equals(1));
    });

    test('Unit succumbing to DoT dies and skips turn', () {
      const dyingUnit = UnitEntity(
        id: 'ally_dying',
        speciesId: 'feral_hound',
        name: 'Dying Hound',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 10,
        maxLevel: 10,
        currentHp: 30,
        maxHp: 500,
        attack: 100,
        defense: 100,
        speed: 100,
        turnMeter: 100.0,
        nativeTraitId: 'rend_flesh',
        lineageAncestors: [],
        activeEffects: [
          StatusEffect(type: StatusEffectType.bleed, durationTurns: 2, value: 60),
        ],
      );

      final manager = InitiativeTickManager(
        initialAllies: [dyingUnit],
        initialEnemies: const [
          UnitEntity(
            id: 'enemy_1',
            speciesId: 'goblin',
            name: 'Goblin',
            generation: 1,
            archetype: Archetype.assassin,
            slot: FormationSlot.front1,
            level: 10,
            maxLevel: 10,
            currentHp: 500,
            maxHp: 500,
            attack: 80,
            defense: 50,
            speed: 80,
            nativeTraitId: 'claw_slash',
            lineageAncestors: [],
          ),
        ],
      );

      manager.advanceTick(); // primes unit if needed

      final combatService = CombatResolutionService(tickManager: manager);

      final result = combatService.processTurnStart(unitId: dyingUnit.id, autoResumeIfTurnSkipped: false);

      expect(result.isDefeated, isTrue);
      expect(result.dotDamage, equals(60));
      expect(result.unit.currentHp, equals(0));
    });
  });
}
