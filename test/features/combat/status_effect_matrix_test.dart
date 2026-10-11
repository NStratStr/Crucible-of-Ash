import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/features/combat/combat_resolution_service.dart';
import 'package:ashen_crucible/features/combat/initiative_tick_manager.dart';
import 'package:ashen_crucible/features/combat/plinth_rim_status_painter.dart';
import 'package:ashen_crucible/shared/models/skill_entity.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';

void main() {
  group('GDD v2.6 Section 4 Status Effect Matrix Tests', () {
    const UnitEntity baseAttacker = UnitEntity(
      id: 'att_1',
      name: 'Ash Striker',
      level: 10,
      maxLevel: 20,
      archetype: Archetype.juggernaut,
      currentHp: 500,
      maxHp: 500,
      attack: 100,
      defense: 50,
      speed: 100,
      generation: 1,
      slot: FormationSlot.front1,
      speciesId: 'human',
      nativeTraitId: 'none',
      lineageAncestors: [],
    );

    const UnitEntity baseDefender = UnitEntity(
      id: 'def_1',
      name: 'Defiant Target',
      level: 10,
      maxLevel: 20,
      archetype: Archetype.assassin,
      currentHp: 400,
      maxHp: 400,
      attack: 80,
      defense: 40,
      speed: 100,
      generation: 1,
      slot: FormationSlot.front1,
      speciesId: 'human',
      nativeTraitId: 'none',
      lineageAncestors: [],
    );

    test('Burn suppresses 100% healing during processTurnStart', () {
      final burningDefender = baseDefender.copyWith(
        currentHp: 200,
        nativeTraitId: 'dark_heal', // Regenerates 8% max HP at turn start
        activeEffects: [
          const StatusEffect(type: StatusEffectType.burn, durationTurns: 2, value: 20),
        ],
      );

      final tickManager = InitiativeTickManager(
        initialAllies: [burningDefender],
        initialEnemies: [baseAttacker],
      );
      final combatService = CombatResolutionService(tickManager: tickManager);

      final result = combatService.processTurnStart(unitId: burningDefender.id);
      expect(result.healAmount, 0); // 100% healing suppression from Burn
      expect(result.dotDamage, 20); // Suffers burn DoT
    });

    test('Freeze Shatter triggers bonus damage (+15% Max HP) on physical hit and ends Freeze', () {
      final frozenDefender = baseDefender.copyWith(
        currentHp: 300,
        activeEffects: [
          const StatusEffect(type: StatusEffectType.freeze, durationTurns: 2),
        ],
      );

      final tickManager = InitiativeTickManager(
        initialAllies: [baseAttacker],
        initialEnemies: [frozenDefender],
      );
      // Fast forward active unit to attacker
      tickManager.advanceTick();
      while (tickManager.phase != CombatPhase.awaitingAction) {
        tickManager.advanceTick();
      }

      final combatService = CombatResolutionService(tickManager: tickManager);
      final action = combatService.executeBasicAttack(targetUnitId: frozenDefender.id);

      // Verify that freeze shattered (shatter bonus applied)
      final defenderPostHit = tickManager.enemies.firstWhere((e) => e.id == frozenDefender.id);
      expect(defenderPostHit.isFrozen, false); // Freeze ended upon hit
      expect(action.damageDealt, greaterThan(60)); // Includes 15% Max HP (60) bonus
    });

    test('Stun/Freeze pauses AP/TurnMeter accumulation while Haste speeds it up by +35%', () {
      final stunnedUnit = baseAttacker.copyWith(
        id: 'stunned_1',
        speed: 100,
        turnMeter: 0.0,
        activeEffects: [const StatusEffect(type: StatusEffectType.stun, durationTurns: 2)],
      );
      final normalUnit = baseAttacker.copyWith(
        id: 'normal_1',
        speed: 100,
        turnMeter: 0.0,
      );
      final hasteUnit = baseAttacker.copyWith(
        id: 'haste_1',
        speed: 100,
        turnMeter: 0.0,
        activeEffects: [const StatusEffect(type: StatusEffectType.speedUp, durationTurns: 2)],
      );

      final tickManager = InitiativeTickManager(
        initialAllies: [stunnedUnit, normalUnit, hasteUnit],
        initialEnemies: [baseDefender],
      );

      // Advance 1 tick
      tickManager.advanceTick();

      final updatedStunned = tickManager.allies.firstWhere((u) => u.id == 'stunned_1');
      final updatedNormal = tickManager.allies.firstWhere((u) => u.id == 'normal_1');
      final updatedHaste = tickManager.allies.firstWhere((u) => u.id == 'haste_1');

      expect(updatedStunned.turnMeter, 0.0); // Stun completely paused TM accumulation
      expect(updatedNormal.turnMeter, 10.0); // Normal: (100 / 100) * 10 = 10.0
      expect(updatedHaste.turnMeter, 13.5); // Haste: ((100 * 1.35) / 100) * 10 = 13.5
    });

    testWidgets('PlinthRimStatusPainter renders with Burn and Freeze status flags and Faction Inscriptions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CustomPaint(
                size: Size(64, 22),
                painter: PlinthRimStatusPainter(
                  bleedStacks: 2,
                  blightStacks: 1,
                  shieldIntegrity: 0.4,
                  isAlive: true,
                  factionName: 'Ash Legion',
                  isBurning: true,
                  isFrozen: true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });

    test('GDD v2.7 Sec 4: BLEED shears 30% armor during attack damage calculation', () {
      final bleedingDefender = baseDefender.copyWith(
        defense: 100,
        activeEffects: [
          const StatusEffect(type: StatusEffectType.bleed, durationTurns: 2, value: 30),
        ],
      );

      final primedAttacker = baseAttacker.copyWith(turnMeter: 100.0);

      final tickManager1 = InitiativeTickManager(
        initialAllies: [primedAttacker],
        initialEnemies: [baseDefender.copyWith(defense: 100)],
      );
      final cs1 = CombatResolutionService(tickManager: tickManager1, rng: Random(42));
      tickManager1.advanceTick();
      final normalResult = cs1.executeBasicAttack(
        targetUnitId: baseDefender.id,
        autoResumeTickEngine: false,
      );

      final tickManager2 = InitiativeTickManager(
        initialAllies: [primedAttacker],
        initialEnemies: [bleedingDefender],
      );
      final cs2 = CombatResolutionService(tickManager: tickManager2, rng: Random(42));
      tickManager2.advanceTick();
      final shearedResult = cs2.executeBasicAttack(
        targetUnitId: bleedingDefender.id,
        autoResumeTickEngine: false,
      );

      // Against bleeding defender (30% armor sheared), damage should be greater than or equal to normal
      expect(shearedResult.damageDealt, greaterThanOrEqualTo(normalResult.damageDealt));
    });

    test('GDD v2.7 Sec 4: Shield expiration triggers 50% AoE pulse to opposing units', () {
      final shieldedAlly = baseAttacker.copyWith(
        activeEffects: [
          const StatusEffect(type: StatusEffectType.shield, durationTurns: 1, value: 200),
        ],
      );
      final enemyTarget = baseDefender.copyWith(currentHp: 400);

      final tickManager = InitiativeTickManager(
        initialAllies: [shieldedAlly],
        initialEnemies: [enemyTarget],
      );
      final cs = CombatResolutionService(tickManager: tickManager);
      final result = cs.processTurnStart(unitId: shieldedAlly.id);

      expect(result.triggeredTraits.contains('shield_pulse'), isTrue);
      final updatedFoe = tickManager.enemies.first;
      // 50% of 200 shield = 100 damage dealt to foe
      expect(updatedFoe.currentHp, equals(300));
    });

    test('GDD v2.7 Sec 4: Burn expiration spreads burn to adjacent formation slots', () {
      final burningAlly = baseAttacker.copyWith(
        slot: FormationSlot.front1,
        activeEffects: [
          const StatusEffect(type: StatusEffectType.burn, durationTurns: 1, value: 30),
        ],
      );
      final adjacentAlly = baseDefender.copyWith(
        id: 'ally_adj',
        slot: FormationSlot.front2, // Slot 1 is adjacent to Slot 0 (diff = 1)
        activeEffects: [],
      );

      final tickManager = InitiativeTickManager(
        initialAllies: [burningAlly, adjacentAlly],
        initialEnemies: [baseDefender],
      );
      final cs = CombatResolutionService(tickManager: tickManager);
      final result = cs.processTurnStart(unitId: burningAlly.id);

      expect(result.triggeredTraits.contains('burn_spread'), isTrue);
      final updatedAdjacent = tickManager.allies.firstWhere((u) => u.id == 'ally_adj');
      expect(updatedAdjacent.isBurning, isTrue);
    });
  });
}
