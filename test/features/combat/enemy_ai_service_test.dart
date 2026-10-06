import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';
import 'package:ashen_crucible/features/combat/initiative_tick_manager.dart';
import 'package:ashen_crucible/features/combat/combat_resolution_service.dart';
import 'package:ashen_crucible/features/combat/enemy_ai_service.dart';
import 'package:ashen_crucible/features/generals/general_command_service.dart';

UnitEntity createUnit({
  required String id,
  required String name,
  required Archetype archetype,
  required FormationSlot slot,
  int hp = 1000,
  int speed = 100,
  double turnMeter = 0.0,
}) {
  return UnitEntity(
    id: id,
    speciesId: 'species',
    name: name,
    generation: 1,
    archetype: archetype,
    slot: slot,
    level: 10,
    maxLevel: 30,
    currentHp: hp,
    maxHp: hp,
    attack: 120,
    defense: 80,
    speed: speed,
    turnMeter: turnMeter,
    nativeTraitId: 'trait',
    lineageAncestors: const [],
  );
}

void main() {
  group('EnemyAiService Tests', () {
    late UnitEntity vanguardAlly;
    late UnitEntity arcanumAlly;
    late UnitEntity fastEnemy;
    late InitiativeTickManager tickManager;
    late CombatResolutionService combatService;
    late GeneralCommandService commandService;
    late EnemyAiService aiService;

    setUp(() {
      vanguardAlly = createUnit(
        id: 'ally_tank',
        name: 'Vanguard Tank',
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        hp: 1000,
      );

      arcanumAlly = createUnit(
        id: 'ally_mage',
        name: 'Arcanum Mage',
        archetype: Archetype.occultist,
        slot: FormationSlot.back1,
        hp: 500,
      );

      fastEnemy = createUnit(
        id: 'enemy_stalker',
        name: 'Stalker',
        archetype: Archetype.assassin,
        slot: FormationSlot.front1,
        speed: 130,
        turnMeter: 100.0,
      );

      tickManager = InitiativeTickManager(
        initialAllies: [vanguardAlly, arcanumAlly],
        initialEnemies: [fastEnemy],
      );

      combatService = CombatResolutionService(tickManager: tickManager);
      commandService = GeneralCommandService(
        tickManager: tickManager,
        generalId: 'vlad',
        generalName: 'Vlad',
      );

      aiService = EnemyAiService(
        tickManager: tickManager,
        combatService: combatService,
        commandService: commandService,
      );
    });

    test('Identifies enemy turn when fast enemy hits 100 TM', () {
      tickManager.advanceTick();
      expect(tickManager.phase, equals(CombatPhase.awaitingAction));
      expect(aiService.isEnemyTurn, isTrue);
    });

    test('Targets frontline Vanguard ally first and executes attack', () {
      tickManager.advanceTick();
      expect(aiService.isEnemyTurn, isTrue);

      final result = aiService.executeEnemyTurn(autoResume: false);
      expect(result, isNotNull);
      expect(result!.target.id, equals('ally_tank')); // Targeted Vanguard!
      expect(result.damageDealt, greaterThan(0));
      // Turn consumed
      expect(tickManager.phase, equals(CombatPhase.idle));
      expect(tickManager.enemies.first.turnMeter, equals(0.0));
    });
  });
}
