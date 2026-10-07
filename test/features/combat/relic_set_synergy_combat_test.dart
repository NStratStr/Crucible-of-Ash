import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/features/combat/combat_resolution_service.dart';
import 'package:ashen_crucible/features/combat/initiative_tick_manager.dart';
import 'package:ashen_crucible/features/relics/relic_service.dart';
import 'package:ashen_crucible/shared/models/relic_entity.dart';
import 'package:ashen_crucible/shared/models/skill_entity.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';

void main() {
  group('Relic Set Synergy Combat & Service Tests', () {
    late RelicService relicService;

    setUp(() {
      relicService = RelicService(initialRelics: []);
    });

    test('Shadowstalker 2-piece set grants +15% Crit Rate and +10 Speed', () {
      final relics = [
        const RelicEntity(
          id: 'ss_1',
          name: 'Shadow Cloak',
          slot: RelicSlot.armor,
          rarity: RelicRarity.rare,
          setType: RelicSetType.shadowstalker,
          description: 'Shadow Cloak',
        ),
        const RelicEntity(
          id: 'ss_2',
          name: 'Shadow Dagger',
          slot: RelicSlot.weapon,
          rarity: RelicRarity.rare,
          setType: RelicSetType.shadowstalker,
          description: 'Shadow Dagger',
        ),
      ];

      final bonuses = relicService.calculateBonusesForRelics(relics);
      expect(bonuses.bonusCritRate, 0.15);
      expect(bonuses.bonusSpeed, 10);
      expect(bonuses.activeSetBonuses.contains(RelicSetType.shadowstalker), isTrue);
    });

    test('Blightweaver 4-piece set grants +20 bonus ATK and activates blightweaver set', () {
      final relics = List.generate(
        4,
        (i) => RelicEntity(
          id: 'bw_$i',
          name: 'Blight Trinket $i',
          slot: RelicSlot.values[i],
          rarity: RelicRarity.rare,
          setType: RelicSetType.blightweaver,
          description: 'Blight relic',
        ),
      );

      final bonuses = relicService.calculateBonusesForRelics(relics);
      expect(bonuses.activeSetBonuses.contains(RelicSetType.blightweaver), isTrue);
      expect(bonuses.bonusAttack, 20);
    });

    test('Dreadnought 4-piece set grants +150 bonus HP and activates dreadnought set', () {
      final relics = List.generate(
        4,
        (i) => RelicEntity(
          id: 'dn_$i',
          name: 'Dreadnought Plate $i',
          slot: RelicSlot.values[i],
          rarity: RelicRarity.rare,
          setType: RelicSetType.dreadnought,
          description: 'Dreadnought plate',
        ),
      );

      final bonuses = relicService.calculateBonusesForRelics(relics);
      expect(bonuses.activeSetBonuses.contains(RelicSetType.dreadnought), isTrue);
      expect(bonuses.bonusHp, 150);
    });

    test('Blightweaver 4-piece set inflicts Blight and amplifies damage by 30% against Blighted targets', () {
      final bwRelics = List.generate(
        4,
        (i) => RelicEntity(
          id: 'bw_$i',
          name: 'Blight Relic $i',
          slot: RelicSlot.values[i],
          rarity: RelicRarity.rare,
          setType: RelicSetType.blightweaver,
          description: 'Blight relic',
          equippedUnitId: 'ally_blightweaver',
        ),
      );

      final relicSvc = RelicService(initialRelics: bwRelics);

      final attacker = const UnitEntity(
        id: 'ally_blightweaver',
        speciesId: 'plague_doctor',
        name: 'Plague Doctor',
        generation: 1,
        archetype: Archetype.occultist,
        slot: FormationSlot.front1,
        level: 10,
        maxLevel: 30,
        currentHp: 500,
        maxHp: 500,
        attack: 100,
        defense: 50,
        speed: 100,
        turnMeter: 100.0,
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      final target = const UnitEntity(
        id: 'enemy_tank',
        speciesId: 'stone_golem',
        name: 'Stone Golem',
        generation: 1,
        archetype: Archetype.occultist, // Neutral affinity vs Occultist
        slot: FormationSlot.front1,
        level: 10,
        maxLevel: 30,
        currentHp: 2000,
        maxHp: 2000,
        attack: 80,
        defense: 0,
        speed: 50,
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      final tickManager = InitiativeTickManager(
        initialAllies: [attacker],
        initialEnemies: [target],
      );
      tickManager.advanceTick(); // attacker active

      final service = CombatResolutionService(
        tickManager: tickManager,
        relicService: relicSvc,
        rng: Random(42),
      );

      // Attack 1: Not blighted initially -> damage applied, target gets blighted by 4-pc Blightweaver
      final attackSkill = const SkillEntity(
        id: 'strike',
        name: 'Toxic Strike',
        description: 'Hits target',
        damageCoefficient: 1.0,
      );

      final result1 = service.executeSkill(
        targetUnitId: 'enemy_tank',
        skill: attackSkill,
        autoResumeTickEngine: false,
      );

      final damagedEnemy = tickManager.enemies.firstWhere((e) => e.id == 'enemy_tank');
      expect(damagedEnemy.activeEffects.any((e) => e.type == StatusEffectType.blight), isTrue);

      // Reset turn meter for second strike
      final refreshedAttacker = attacker.copyWith(turnMeter: 100.0);
      tickManager.updateSquads(allies: [refreshedAttacker], enemies: [damagedEnemy]);
      tickManager.advanceTick();

      // Attack 2: Target is now Blighted -> Blightweaver 4-pc triggers +30% damage amplification
      final baselineDamage = result1.damageDealt;
      final result2 = service.executeSkill(
        targetUnitId: 'enemy_tank',
        skill: attackSkill,
        autoResumeTickEngine: false,
      );

      // Result 2 damage should be ~30% higher than baseline
      expect(result2.damageDealt, greaterThan(baselineDamage));
    });

    test('Dreadnought 4-piece set reflects 20% incoming damage back to attacker', () {
      final dnRelics = List.generate(
        4,
        (i) => RelicEntity(
          id: 'dn_$i',
          name: 'Dread Relic $i',
          slot: RelicSlot.values[i],
          rarity: RelicRarity.rare,
          setType: RelicSetType.dreadnought,
          description: 'Dread relic',
          equippedUnitId: 'ally_dreadnought',
        ),
      );

      final relicSvc = RelicService(initialRelics: dnRelics);

      final defender = const UnitEntity(
        id: 'ally_dreadnought',
        speciesId: 'iron_wall',
        name: 'Iron Wall',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 10,
        maxLevel: 30,
        currentHp: 1000,
        maxHp: 1000,
        attack: 60,
        defense: 20,
        speed: 50,
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      final enemyAttacker = const UnitEntity(
        id: 'enemy_striker',
        speciesId: 'berserker',
        name: 'Berserker',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 10,
        maxLevel: 30,
        currentHp: 500,
        maxHp: 500,
        attack: 150,
        defense: 0,
        speed: 100,
        turnMeter: 100.0,
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      final tickManager = InitiativeTickManager(
        initialAllies: [defender],
        initialEnemies: [enemyAttacker],
      );
      tickManager.advanceTick(); // enemyAttacker active

      final service = CombatResolutionService(
        tickManager: tickManager,
        relicService: relicSvc,
        rng: Random(42),
      );

      final attackSkill = const SkillEntity(
        id: 'smash',
        name: 'Heavy Smash',
        description: 'Strikes target',
        damageCoefficient: 1.0,
      );

      final result = service.executeSkill(
        targetUnitId: 'ally_dreadnought',
        skill: attackSkill,
        autoResumeTickEngine: false,
      );

      // Thorns reflection: Attacker should take ~20% of dealt damage
      final updatedAttacker = tickManager.enemies.firstWhere((e) => e.id == 'enemy_striker');
      final reflectedExpected = (result.damageDealt * 0.20).round();
      expect(updatedAttacker.currentHp, closeTo(500 - reflectedExpected, 1));
    });
  });

  group('Abyssal Descent Tier II and III Modifiers Tests', () {
    test('Void Corruption inflicts 45 poison to non-Occultists at turn start', () {
      final knight = const UnitEntity(
        id: 'ally_knight',
        speciesId: 'paladin',
        name: 'Paladin',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 10,
        maxLevel: 30,
        currentHp: 500,
        maxHp: 500,
        attack: 100,
        defense: 60,
        speed: 100,
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      final tickManager = InitiativeTickManager(
        initialAllies: [knight],
        initialEnemies: [
          const UnitEntity(
            id: 'enemy_1',
            speciesId: 'fiend',
            name: 'Fiend',
            generation: 1,
            archetype: Archetype.occultist,
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
        battleModifier: BattleModifier.voidCorruption,
      );

      final result = service.processTurnStart(unitId: 'ally_knight');
      expect(result.dotDamage, 45);
      expect(result.unit.currentHp, 455);
      expect(result.triggeredTraits.contains('void_corruption'), isTrue);
    });

    test('Abyssal Eclipse deals 40 poison at turn start and cleaves 75% to other Vanguard units', () {
      final v1 = const UnitEntity(
        id: 'ally_v1',
        speciesId: 'knight',
        name: 'Knight 1',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 10,
        maxLevel: 30,
        currentHp: 600,
        maxHp: 600,
        attack: 100,
        defense: 0,
        speed: 80,
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      final v2 = const UnitEntity(
        id: 'ally_v2',
        speciesId: 'knight',
        name: 'Knight 2',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front2,
        level: 10,
        maxLevel: 30,
        currentHp: 600,
        maxHp: 600,
        attack: 100,
        defense: 0,
        speed: 80,
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      final enemyTitan = const UnitEntity(
        id: 'enemy_titan',
        speciesId: 'void_lord',
        name: 'Void Lord',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 20,
        maxLevel: 50,
        currentHp: 1500,
        maxHp: 1500,
        attack: 100,
        defense: 0,
        speed: 100,
        turnMeter: 100.0,
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      final tickManager = InitiativeTickManager(
        initialAllies: [v1, v2],
        initialEnemies: [enemyTitan],
      );

      final service = CombatResolutionService(
        tickManager: tickManager,
        battleModifier: BattleModifier.abyssalEclipse,
        rng: Random(42),
      );

      // Turn start: non-occultist takes 40 poison
      final turnStart = service.processTurnStart(unitId: 'ally_v1');
      expect(turnStart.dotDamage, 40);

      // Enemy attacks v1: should cleave onto v2
      tickManager.advanceTick(); // enemyTitan active
      final skill = const SkillEntity(
        id: 'cleave_strike',
        name: 'Void Sever',
        description: 'Hits target',
        damageCoefficient: 1.0,
      );

      final result = service.executeSkill(
        targetUnitId: 'ally_v1',
        skill: skill,
        autoResumeTickEngine: false,
      );

      expect(result.damageDealt, greaterThan(0));
      final allyV2After = tickManager.allies.firstWhere((a) => a.id == 'ally_v2');
      final cleaveExpected = (result.damageDealt * 0.75).round();
      expect(allyV2After.currentHp, closeTo(600 - cleaveExpected, 1));
    });
  });
}
