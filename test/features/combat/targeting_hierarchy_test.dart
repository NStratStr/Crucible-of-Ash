import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/features/combat/combat_resolution_service.dart';
import 'package:ashen_crucible/features/combat/enemy_ai_service.dart';
import 'package:ashen_crucible/features/combat/initiative_tick_manager.dart';
import 'package:ashen_crucible/features/generals/general_command_service.dart';
import 'package:ashen_crucible/shared/models/skill_entity.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';

void main() {
  group('GDD v2.6 Section 3.3 Dynamic Targeting Hierarchy Tests', () {
    const allyVanguardTank = UnitEntity(
      id: 'ally_vg_tank',
      name: 'Iron Footman',
      level: 10,
      maxLevel: 30,
      archetype: Archetype.juggernaut,
      slot: FormationSlot.front1,
      currentHp: 1000,
      maxHp: 1000,
      attack: 100,
      defense: 150,
      speed: 90,
      speciesId: 'test',
      generation: 1,
      nativeTraitId: 'none',
      lineageAncestors: [],
    );

    const allyVanguardDPS = UnitEntity(
      id: 'ally_vg_dps',
      name: 'Grave Duelist',
      level: 10,
      maxLevel: 30,
      archetype: Archetype.assassin,
      slot: FormationSlot.front2,
      currentHp: 600,
      maxHp: 600,
      attack: 180,
      defense: 60,
      speed: 125,
      speciesId: 'test',
      generation: 1,
      nativeTraitId: 'none',
      lineageAncestors: [],
    );

    const allyArcanumHealer = UnitEntity(
      id: 'ally_arc_healer',
      name: 'Field Medicus',
      level: 10,
      maxLevel: 30,
      archetype: Archetype.support,
      slot: FormationSlot.back1,
      currentHp: 500,
      maxHp: 500,
      attack: 90,
      defense: 50,
      speed: 100,
      speciesId: 'test',
      generation: 1,
      nativeTraitId: 'none',
      lineageAncestors: [],
    );

    const enemyStandardAttacker = UnitEntity(
      id: 'enemy_standard',
      name: 'Rotting Husk',
      level: 10,
      maxLevel: 30,
      archetype: Archetype.juggernaut,
      slot: FormationSlot.front1,
      currentHp: 800,
      maxHp: 800,
      attack: 120,
      defense: 80,
      speed: 95,
      speciesId: 'test',
      generation: 1,
      nativeTraitId: 'none',
      lineageAncestors: [],
    );

    const enemyFlyerSkirmisher = UnitEntity(
      id: 'enemy_flyer',
      name: 'Gargoyle Skirmisher',
      level: 10,
      maxLevel: 30,
      archetype: Archetype.skirmisher,
      slot: FormationSlot.front2,
      currentHp: 650,
      maxHp: 650,
      attack: 130,
      defense: 70,
      speed: 120,
      speciesId: 'test',
      generation: 1,
      nativeTraitId: 'dive_bomb',
      lineageAncestors: [],
    );

    test('Standard attacker targets lowest EHP Vanguard first (respects line-of-sight)', () {
      final tickManager = InitiativeTickManager(
        initialAllies: [allyVanguardTank, allyVanguardDPS, allyArcanumHealer],
        initialEnemies: [enemyStandardAttacker],
      );
      final commandService = GeneralCommandService(tickManager: tickManager);
      final combatService = CombatResolutionService(tickManager: tickManager, commandService: commandService);
      final aiService = EnemyAiService(
        tickManager: tickManager,
        combatService: combatService,
        commandService: commandService,
      );

      final target = aiService.selectTargetAlly(actingUnit: enemyStandardAttacker);

      // Must select Vanguard with lower EHP (DPS) over higher EHP (Tank), and cannot hit backline Arcanum Healer
      expect(target, isNotNull);
      expect(target!.id, equals(allyVanguardDPS.id));
    });

    test('Taunt override forces targeting of taunting unit even if higher EHP or in backline', () {
      final tauntingTank = allyVanguardTank.copyWith(
        activeEffects: [const StatusEffect(type: StatusEffectType.taunt, durationTurns: 2)],
      );

      final tickManager = InitiativeTickManager(
        initialAllies: [tauntingTank, allyVanguardDPS, allyArcanumHealer],
        initialEnemies: [enemyStandardAttacker],
      );
      final commandService = GeneralCommandService(tickManager: tickManager);
      final combatService = CombatResolutionService(tickManager: tickManager, commandService: commandService);
      final aiService = EnemyAiService(
        tickManager: tickManager,
        combatService: combatService,
        commandService: commandService,
      );

      final target = aiService.selectTargetAlly(actingUnit: enemyStandardAttacker);

      // Hard constraint override: Must target the taunting tank
      expect(target, isNotNull);
      expect(target!.id, equals(tauntingTank.id));
    });

    test('Aerial Skirmisher with dive_bomb bypasses Vanguard LoS to strike rear Arcanum directly', () {
      final tickManager = InitiativeTickManager(
        initialAllies: [allyVanguardTank, allyVanguardDPS, allyArcanumHealer],
        initialEnemies: [enemyFlyerSkirmisher],
      );
      final commandService = GeneralCommandService(tickManager: tickManager);
      final combatService = CombatResolutionService(tickManager: tickManager, commandService: commandService);
      final aiService = EnemyAiService(
        tickManager: tickManager,
        combatService: combatService,
        commandService: commandService,
      );

      final target = aiService.selectTargetAlly(actingUnit: enemyFlyerSkirmisher);

      // Skirmisher / dive_bomb bypasses frontline to pick off rear Arcanum healer directly!
      expect(target, isNotNull);
      expect(target!.id, equals(allyArcanumHealer.id));
    });
  });
}

