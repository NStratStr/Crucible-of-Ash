import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';
import 'package:ashen_crucible/features/combat/initiative_tick_manager.dart';

UnitEntity createTestUnit({
  required String id,
  required String name,
  required int speed,
  double turnMeter = 0.0,
  int currentHp = 1000,
  FormationSlot slot = FormationSlot.front1,
  Archetype archetype = Archetype.juggernaut,
}) {
  return UnitEntity(
    id: id,
    speciesId: 'test_spec',
    name: name,
    generation: 1,
    archetype: archetype,
    slot: slot,
    level: 1,
    maxLevel: 30,
    currentHp: currentHp,
    maxHp: 1000,
    attack: 100,
    defense: 100,
    speed: speed,
    turnMeter: turnMeter,
    nativeTraitId: 'none',
    lineageAncestors: const [],
  );
}

void main() {
  group('InitiativeTickManager Tests', () {
    late UnitEntity fastAlly;
    late UnitEntity slowEnemy;

    setUp(() {
      fastAlly = createTestUnit(id: 'ally_1', name: 'Ranger', speed: 120);
      slowEnemy = createTestUnit(
        id: 'enemy_1',
        name: 'Zombie',
        speed: 80,
        slot: FormationSlot.front1,
        archetype: Archetype.occultist,
      );
    });

    test('Turn meter increments correctly per discrete tick', () {
      final manager = InitiativeTickManager(
        initialAllies: [fastAlly],
        initialEnemies: [slowEnemy],
      );

      // Delta formula: (speed / 100) * 10
      // fastAlly: (120 / 100) * 10 = 12.0 TM per tick
      // slowEnemy: (80 / 100) * 10 = 8.0 TM per tick
      manager.advanceTick();

      expect(manager.tickCount, equals(1));
      expect(manager.allies.first.turnMeter, closeTo(12.0, 0.001));
      expect(manager.enemies.first.turnMeter, closeTo(8.0, 0.001));
      expect(manager.phase, equals(CombatPhase.idle));
    });

    test('Pauses engine into awaitingAction when unit crosses 100 TM', () {
      final manager = InitiativeTickManager(
        initialAllies: [fastAlly],
        initialEnemies: [slowEnemy],
      );

      // FastAlly reaches 100 TM in 9 ticks (9 * 12.0 = 108.0)
      for (int i = 0; i < 9; i++) {
        manager.advanceTick();
      }

      expect(manager.tickCount, equals(9));
      expect(manager.phase, equals(CombatPhase.awaitingAction));
      expect(manager.activeUnit?.id, equals('ally_1'));
      expect(manager.allies.first.turnMeter, closeTo(108.0, 0.001));
      expect(manager.enemies.first.turnMeter, closeTo(72.0, 0.001));
    });

    test('Tie-breaking: unit with higher overflow acts first', () {
      final unitA = createTestUnit(id: 'a', name: 'A', speed: 100, turnMeter: 95.0);
      final unitB = createTestUnit(id: 'b', name: 'B', speed: 100, turnMeter: 98.0);

      final manager = InitiativeTickManager(
        initialAllies: [unitA],
        initialEnemies: [unitB],
      );

      manager.advanceTick();

      expect(manager.phase, equals(CombatPhase.awaitingAction));
      expect(manager.activeUnit?.id, equals('b'));
    });

    test('Tie-breaking: equal overflow breaks tie using base speed', () {
      final slowUnit = createTestUnit(id: 'slow', name: 'Slow', speed: 50, turnMeter: 95.0);
      final fastUnit = createTestUnit(id: 'fast', name: 'Fast', speed: 100, turnMeter: 90.0);

      final manager = InitiativeTickManager(
        initialAllies: [slowUnit],
        initialEnemies: [fastUnit],
      );

      manager.advanceTick();

      expect(manager.phase, equals(CombatPhase.awaitingAction));
      expect(manager.activeUnit?.id, equals('fast'));
    });

    test('consumeTurn resets TM to zero and clears activeUnit', () {
      final manager = InitiativeTickManager(
        initialAllies: [fastAlly],
        initialEnemies: [slowEnemy],
      );

      for (int i = 0; i < 9; i++) {
        manager.advanceTick();
      }

      expect(manager.activeUnit?.id, equals('ally_1'));

      manager.consumeTurn(retainedOverflow: false, autoResume: false);

      expect(manager.phase, equals(CombatPhase.idle));
      expect(manager.activeUnit, isNull);
      expect(manager.allies.first.turnMeter, equals(0.0));
      expect(manager.enemies.first.turnMeter, closeTo(72.0, 0.001));
    });

    test('consumeTurn with retainedOverflow keeps surplus above 100', () {
      final unit = createTestUnit(id: 'hero', name: 'Hero', speed: 120, turnMeter: 96.0);

      final manager = InitiativeTickManager(
        initialAllies: [unit],
        initialEnemies: [slowEnemy],
      );

      manager.advanceTick();
      expect(manager.activeUnit?.turnMeter, closeTo(108.0, 0.001));

      manager.consumeTurn(retainedOverflow: true, autoResume: false);
      expect(manager.allies.first.turnMeter, closeTo(8.0, 0.001));
    });

    test('Instant TM manipulation pushes unit to action', () {
      final manager = InitiativeTickManager(
        initialAllies: [fastAlly],
        initialEnemies: [slowEnemy],
      );

      manager.modifyTurnMeter('ally_1', 100.0);
      expect(manager.allies.first.turnMeter, equals(100.0));

      manager.advanceTick();
      expect(manager.phase, equals(CombatPhase.awaitingAction));
      expect(manager.activeUnit?.id, equals('ally_1'));
    });

    test('Dead units do not accumulate TM and battle ends when squad wipes', () {
      final deadAlly = createTestUnit(id: 'dead', name: 'Fallen', speed: 150, currentHp: 0);

      final manager = InitiativeTickManager(
        initialAllies: [deadAlly],
        initialEnemies: [slowEnemy],
      );

      manager.advanceTick();

      expect(manager.allies.first.turnMeter, equals(0.0));
      expect(manager.phase, equals(CombatPhase.battleEnded));
      expect(manager.activeUnit, isNull);
    });
  });
}
