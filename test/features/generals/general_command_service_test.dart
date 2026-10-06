import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';
import 'package:ashen_crucible/features/combat/initiative_tick_manager.dart';
import 'package:ashen_crucible/features/generals/general_command_service.dart';

UnitEntity createTestUnit({
  required String id,
  required String name,
  required Archetype archetype,
  required FormationSlot slot,
  int hp = 1000,
  int attack = 150,
  int defense = 100,
  double turnMeter = 0.0,
}) {
  return UnitEntity(
    id: id,
    speciesId: 'proto_unit',
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
    speed: 100,
    turnMeter: turnMeter,
    nativeTraitId: 'none',
    lineageAncestors: const [],
  );
}

void main() {
  group('GeneralCommandService Tests', () {
    late UnitEntity vanguardHero;
    late UnitEntity arcanumHero;
    late UnitEntity enemyBoss;
    late InitiativeTickManager tickManager;
    late GeneralCommandService commandService;

    setUp(() {
      vanguardHero = createTestUnit(
        id: 'ally_tank',
        name: 'Vanguard Wall',
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        hp: 1000,
        defense: 100,
      );

      arcanumHero = createTestUnit(
        id: 'ally_mage',
        name: 'Arcanum Mystic',
        archetype: Archetype.occultist,
        slot: FormationSlot.back1,
        hp: 600,
        defense: 40,
      );

      enemyBoss = createTestUnit(
        id: 'enemy_boss',
        name: 'Gorgoroth',
        archetype: Archetype.assassin,
        slot: FormationSlot.front1,
        hp: 2000,
        defense: 80,
      );

      tickManager = InitiativeTickManager(
        initialAllies: [vanguardHero, arcanumHero],
        initialEnemies: [enemyBoss],
      );

      commandService = GeneralCommandService(
        tickManager: tickManager,
        generalId: 'vladislav_01',
        generalName: 'Lord Vladislav',
        initialFocus: 1,
      );
    });

    test('Combat damage accumulates and increments Focus at threshold (500 DMG)', () {
      expect(commandService.currentFocus, equals(1));

      commandService.registerCombatDamage(300);
      expect(commandService.currentFocus, equals(1));
      expect(commandService.focusProgressRatio, closeTo(0.60, 0.01));

      commandService.registerCombatDamage(250);
      expect(commandService.currentFocus, equals(2));
      expect(commandService.focusProgressRatio, closeTo(0.10, 0.01));
    });

    test('Focus does not exceed maxFocusCap (3)', () {
      commandService.grantFocus(10);
      expect(commandService.currentFocus, equals(3));

      commandService.registerCombatDamage(1000);
      expect(commandService.currentFocus, equals(3));
      expect(commandService.focusProgressRatio, equals(0.0));
    });

    test('Throws StateError when spending more Focus than available', () {
      expect(
        () => commandService.executeSanguineWard(),
        throwsStateError,
      );
    });

    test('Siphon Vitality drains enemy and heals frontline Vanguard units', () {
      final damagedTank = vanguardHero.copyWith(currentHp: 500);
      tickManager = InitiativeTickManager(
        initialAllies: [damagedTank, arcanumHero],
        initialEnemies: [enemyBoss],
      );
      commandService = GeneralCommandService(
        tickManager: tickManager,
        generalId: 'vladislav_01',
        generalName: 'Lord Vladislav',
        initialFocus: 1,
      );

      final OrderResult result = commandService.executeSiphonVitality('enemy_boss');

      expect(commandService.currentFocus, equals(0));
      expect(result.updatedEnemies.first.currentHp, equals(1700));
      expect(result.updatedAllies.first.currentHp, equals(800));
      expect(result.updatedAllies[1].currentHp, equals(600));
    });

    test('Sanguine Ward sacrifices team HP to grant team armor barrier', () {
      commandService.grantFocus(2); // Focus = 3

      final OrderResult result = commandService.executeSanguineWard();

      expect(commandService.currentFocus, equals(1));
      expect(result.updatedAllies[0].currentHp, equals(850));
      expect(result.updatedAllies[1].currentHp, equals(510));
      expect(result.updatedAllies[0].defense, equals(100 + 240));
      expect(result.updatedAllies[1].defense, equals(40 + 240));
    });

    test('Feast of Ruin executes enemy below 20% HP and surges allied Turn Meter', () {
      commandService.grantFocus(2); // Focus = 3

      final woundedBoss = enemyBoss.copyWith(currentHp: 300); // 15% HP
      tickManager = InitiativeTickManager(
        initialAllies: [vanguardHero, arcanumHero],
        initialEnemies: [woundedBoss],
      );
      commandService = GeneralCommandService(
        tickManager: tickManager,
        generalId: 'vladislav_01',
        generalName: 'Lord Vladislav',
        initialFocus: 3,
      );

      final OrderResult result = commandService.executeFeastOfRuin('enemy_boss');

      expect(commandService.currentFocus, equals(0));
      expect(result.updatedEnemies.first.currentHp, equals(0));
      expect(result.updatedAllies[0].turnMeter, equals(50.0));
      expect(result.updatedAllies[1].turnMeter, equals(50.0));
    });
  });
}
