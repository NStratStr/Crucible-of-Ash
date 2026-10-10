import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';
import 'package:ashen_crucible/shared/models/skill_entity.dart';
import 'package:ashen_crucible/features/combat/initiative_tick_manager.dart';
import 'package:ashen_crucible/features/combat/combat_resolution_service.dart';

UnitEntity buildUnit({
  required String id,
  required String name,
  required Archetype archetype,
  required int speed,
  int hp = 1000,
  int attack = 150,
  int defense = 100,
  double turnMeter = 0.0,
  double critRate = 0.0,
  FormationSlot slot = FormationSlot.front1,
}) {
  return UnitEntity(
    id: id,
    speciesId: 'proto_species',
    name: name,
    generation: 1,
    archetype: archetype,
    slot: slot,
    level: 10,
    maxLevel: 30,
    currentHp: hp,
    maxHp: hp,
    attack: attack,
    defense: defense,
    speed: speed,
    critRate: critRate,
    critDamage: 1.50,
    turnMeter: turnMeter,
    nativeTraitId: 'none',
    lineageAncestors: const [],
  );
}

void main() {
  group('CombatResolutionService Tests', () {
    late UnitEntity juggernautHero;
    late UnitEntity assassinFoe;
    late InitiativeTickManager tickManager;
    late CombatResolutionService combatService;

    setUp(() {
      juggernautHero = buildUnit(
        id: 'hero_jug',
        name: 'Iron Wall',
        archetype: Archetype.juggernaut,
        speed: 100,
        attack: 200,
        defense: 150,
      );

      assassinFoe = buildUnit(
        id: 'enemy_assassin',
        name: 'Shadow Blade',
        archetype: Archetype.assassin,
        speed: 80,
        hp: 500,
        defense: 50,
      );
    });

    test('Throws StateError if executing attack without an active unit awaiting turn', () {
      tickManager = InitiativeTickManager(
        initialAllies: [juggernautHero],
        initialEnemies: [assassinFoe],
      );
      combatService = CombatResolutionService(tickManager: tickManager);

      expect(
        () => combatService.executeBasicAttack(targetUnitId: 'enemy_assassin'),
        throwsStateError,
      );
    });

    test('Executes basic attack with advantage multiplier against target prey', () {
      final primedHero = juggernautHero.copyWith(turnMeter: 100.0);
      tickManager = InitiativeTickManager(
        initialAllies: [primedHero],
        initialEnemies: [assassinFoe],
      );

      tickManager.advanceTick();
      expect(tickManager.phase, equals(CombatPhase.awaitingAction));

      combatService = CombatResolutionService(
        tickManager: tickManager,
        rng: Random(42),
      );

      final ActionResult result = combatService.executeBasicAttack(
        targetUnitId: 'enemy_assassin',
        autoResumeTickEngine: false,
      );

      expect(result.affinityMultiplier, equals(1.30));
      expect(result.isGlancing, isFalse);
      expect(result.damageDealt, greaterThan(0));
      expect(result.target.currentHp, equals(500 - result.damageDealt));

      expect(tickManager.phase, equals(CombatPhase.idle));
      expect(tickManager.allies.first.turnMeter, equals(0.0));
      expect(tickManager.enemies.first.currentHp, equals(result.target.currentHp));
    });

    test('Lifesteal ratio correctly heals the attacker up to maxHp cap', () {
      final damagedHero = juggernautHero.copyWith(currentHp: 400, turnMeter: 100.0);
      tickManager = InitiativeTickManager(
        initialAllies: [damagedHero],
        initialEnemies: [assassinFoe],
      );
      tickManager.advanceTick();

      combatService = CombatResolutionService(
        tickManager: tickManager,
        rng: Random(42),
      );

      final ActionResult result = combatService.executeBasicAttack(
        targetUnitId: 'enemy_assassin',
        lifestealRatio: 0.50,
        autoResumeTickEngine: false,
      );

      expect(result.lifestealRecovered, greaterThan(0));
      expect(result.lifestealRecovered, equals((result.damageDealt * 0.50).round()));
      expect(tickManager.allies.first.currentHp, equals(400 + result.lifestealRecovered));
    });

    test('Target is flagged as defeated and battle concludes when last enemy dies', () {
      final fragileFoe = assassinFoe.copyWith(currentHp: 10, turnMeter: 0.0);
      final primedHero = juggernautHero.copyWith(turnMeter: 100.0);

      tickManager = InitiativeTickManager(
        initialAllies: [primedHero],
        initialEnemies: [fragileFoe],
      );
      tickManager.advanceTick();

      combatService = CombatResolutionService(tickManager: tickManager);

      final ActionResult result = combatService.executeBasicAttack(
        targetUnitId: 'enemy_assassin',
        autoResumeTickEngine: false,
      );

      expect(result.targetDefeated, isTrue);
      expect(result.target.currentHp, equals(0));
      expect(tickManager.phase, equals(CombatPhase.battleEnded));
    });

    test('Attacker with rend_flesh trait applies Bleed status effect to target on hit', () {
      final rendHero = juggernautHero.copyWith(
        turnMeter: 100.0,
        nativeTraitId: 'rend_flesh',
      );
      final foe = assassinFoe.copyWith(currentHp: 1000, turnMeter: 0.0);

      tickManager = InitiativeTickManager(
        initialAllies: [rendHero],
        initialEnemies: [foe],
      );
      tickManager.advanceTick();

      combatService = CombatResolutionService(tickManager: tickManager);

      final result = combatService.executeBasicAttack(
        targetUnitId: 'enemy_assassin',
        autoResumeTickEngine: false,
      );

      expect(result.target.activeEffects.any((e) => e.type == StatusEffectType.bleed), isTrue);
    });

    test('Defender with blight_curse trait applies Blight back to the attacker when damaged', () {
      final hero = juggernautHero.copyWith(turnMeter: 100.0);
      final cursedFoe = assassinFoe.copyWith(
        currentHp: 1000,
        turnMeter: 0.0,
        nativeTraitId: 'blight_curse',
      );

      tickManager = InitiativeTickManager(
        initialAllies: [hero],
        initialEnemies: [cursedFoe],
      );
      tickManager.advanceTick();

      combatService = CombatResolutionService(tickManager: tickManager);

      final result = combatService.executeBasicAttack(
        targetUnitId: 'enemy_assassin',
        autoResumeTickEngine: false,
      );

      expect(result.attacker.activeEffects.any((e) => e.type == StatusEffectType.blight), isTrue);
    });

    test('Attacker with keen_eye trait never suffers Glancing Blow against predator role', () {
      // Occultist is predator of Juggernaut (disadvantage 0.75x)
      final occultistFoe = buildUnit(
        id: 'foe_occ',
        name: 'Dark Occultist',
        archetype: Archetype.occultist,
        speed: 80,
      );
      final keenHero = juggernautHero.copyWith(
        turnMeter: 100.0,
        nativeTraitId: 'keen_eye',
      );

      // Run multiple attacks to ensure zero glancing blows occur
      for (int i = 0; i < 5; i++) {
        tickManager = InitiativeTickManager(
          initialAllies: [keenHero],
          initialEnemies: [occultistFoe],
        );
        tickManager.advanceTick();
        combatService = CombatResolutionService(tickManager: tickManager);

        final result = combatService.executeBasicAttack(
          targetUnitId: 'foe_occ',
          autoResumeTickEngine: false,
        );
        expect(result.isGlancing, isFalse);
      }
    });

    test('GDD v2.8 Sec 3.4: Backline Guarded buff reduces damage by 20% while frontline standing', () {
      final frontlineHero = buildUnit(
        id: 'front_hero',
        name: 'Front Wall',
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        speed: 100,
      );
      final backlineHero = buildUnit(
        id: 'back_hero',
        name: 'Back Sniper',
        archetype: Archetype.marksman,
        slot: FormationSlot.back1,
        speed: 100,
        defense: 100,
      );
      final attackerFoe = buildUnit(
        id: 'attacker_foe',
        name: 'Enemy Striker',
        archetype: Archetype.assassin,
        speed: 100,
        turnMeter: 100.0,
      );

      // 1. Attack backline hero with frontline ally alive
      tickManager = InitiativeTickManager(
        initialAllies: [frontlineHero, backlineHero],
        initialEnemies: [attackerFoe],
      );
      tickManager.advanceTick();
      combatService = CombatResolutionService(tickManager: tickManager, rng: Random(42));
      final guardedRes = combatService.executeBasicAttack(
        targetUnitId: 'back_hero',
        autoResumeTickEngine: false,
      );

      // 2. Attack backline hero without frontline ally alive
      tickManager = InitiativeTickManager(
        initialAllies: [frontlineHero.copyWith(currentHp: 0), backlineHero],
        initialEnemies: [attackerFoe],
      );
      tickManager.advanceTick();
      combatService = CombatResolutionService(tickManager: tickManager, rng: Random(42));
      final unguardedRes = combatService.executeBasicAttack(
        targetUnitId: 'back_hero',
        autoResumeTickEngine: false,
      );

      // Guarded damage should be ~20% lower than unguarded damage
      expect(guardedRes.damageDealt, lessThan(unguardedRes.damageDealt));
    });

    test('GDD v2.8 Sec 3.4: Frontline slot gains +15% Action Point / TM upon taking direct hits', () {
      final frontlineDefender = buildUnit(
        id: 'front_defender',
        name: 'Front Guard',
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        turnMeter: 10.0,
        speed: 100,
      );
      final attackerFoe = buildUnit(
        id: 'attacker_foe',
        name: 'Enemy Striker',
        archetype: Archetype.assassin,
        speed: 100,
        turnMeter: 100.0,
      );

      tickManager = InitiativeTickManager(
        initialAllies: [frontlineDefender],
        initialEnemies: [attackerFoe],
      );
      tickManager.advanceTick();
      combatService = CombatResolutionService(tickManager: tickManager);
      final res = combatService.executeBasicAttack(
        targetUnitId: 'front_defender',
        autoResumeTickEngine: false,
      );

      // 10.0 initial + 10.0 from advanceTick + 15.0 on-hit Frontline bonus = 35.0
      expect(res.target.turnMeter, equals(35.0));
    });
  });
}
