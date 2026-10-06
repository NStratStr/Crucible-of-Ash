import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';
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
}) {
  return UnitEntity(
    id: id,
    speciesId: 'proto_species',
    name: name,
    generation: 1,
    archetype: archetype,
    slot: FormationSlot.front1,
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
  });
}
