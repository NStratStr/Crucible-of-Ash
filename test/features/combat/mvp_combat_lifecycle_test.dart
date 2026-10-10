import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/features/combat/combat_resolution_service.dart';
import 'package:ashen_crucible/features/combat/initiative_tick_manager.dart';
import 'package:ashen_crucible/shared/data/starter_brigades.dart';
import 'package:ashen_crucible/shared/models/skill_entity.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';

void main() {
  group('GDD v2.6 MVP Combat Lifecycle Tests', () {
    test('StarterBrigades provides 5 Ash Legion player units and 5 Crypt Stalkers enemy units', () {
      final ashLegion = StarterBrigades.createAshLegionPlayerSquad();
      expect(ashLegion.length, equals(5));
      expect(ashLegion[0].name, equals('Lord Vladislav'));
      expect(ashLegion[0].isCommander, isTrue);
      expect(ashLegion[1].name, equals('Iron Footman'));
      expect(ashLegion[1].archetype, equals(Archetype.juggernaut));
      expect(ashLegion[2].name, equals('Grave Duelist'));
      expect(ashLegion[2].archetype, equals(Archetype.assassin));
      expect(ashLegion[3].name, equals('Iron Arbalest'));
      expect(ashLegion[3].archetype, equals(Archetype.marksman));
      expect(ashLegion[4].name, equals('Field Medicus'));
      expect(ashLegion[4].archetype, equals(Archetype.support));

      final cryptStalkers = StarterBrigades.createCryptStalkersEnemySquad();
      expect(cryptStalkers.length, equals(5));
      expect(cryptStalkers[0].name, equals('Rotting Husk'));
      expect(cryptStalkers[0].archetype, equals(Archetype.juggernaut));
      expect(cryptStalkers[1].name, equals('Grave Ghoul'));
      expect(cryptStalkers[1].archetype, equals(Archetype.assassin));
      expect(cryptStalkers[2].name, equals('Blood Alchemist'));
      expect(cryptStalkers[2].archetype, equals(Archetype.support));
      expect(cryptStalkers[3].name, equals('Bone Archer'));
      expect(cryptStalkers[3].archetype, equals(Archetype.marksman));
      expect(cryptStalkers[4].name, equals('Blight Necromancer'));
      expect(cryptStalkers[4].archetype, equals(Archetype.occultist));
    });

    test('Section 3.4: Infused Vitae Revive restores HP, adds Aegis shield, cleanses debuffs, and applies Soul Fracture', () {
      final allies = StarterBrigades.createAshLegionPlayerSquad();
      final enemies = StarterBrigades.createCryptStalkersEnemySquad();

      // Down Lord Vladislav (front1) into an Inert Vessel with a debuff
      final downedUnit = allies[0].copyWith(
        currentHp: 0,
        activeEffects: [
          const StatusEffect(type: StatusEffectType.bleed, durationTurns: 2, value: 30),
          const StatusEffect(type: StatusEffectType.defenseUp, durationTurns: 2, value: 20),
        ],
      );

      final modifiedAllies = [downedUnit, ...allies.sublist(1)];

      final tickManager = InitiativeTickManager(
        initialAllies: modifiedAllies,
        initialEnemies: enemies,
      );

      final combatService = CombatResolutionService(tickManager: tickManager);

      // Force Field Medicus (allies[4]) to be the active unit
      final medicus = allies[4].copyWith(turnMeter: 100.0);
      tickManager.updateSquads(allies: [downedUnit, allies[1], allies[2], allies[3], medicus]);
      tickManager.advanceTick(); // Trigger awaitingAction

      // Medicus ATK = 120, Gen = 1, SkillCoeff = 2.0
      // raw heal = (120 * 2.0) * (1 + 1 * 0.15) = 240 * 1.15 = 276 HP
      // Target maxHp = 900. After 1st revive, effectiveMaxHp = (900 * 0.8) = 720.
      final result = combatService.executeInfusedVitaeRevive(
        targetUnitId: downedUnit.id,
        skillCoefficient: 2.0,
      );

      expect(result, isNotNull);
      expect(result!.healAmount, equals(276));
      expect(result.target.currentHp, equals(276));
      expect(result.target.isAlive, isTrue);
      expect(result.target.reviveCount, equals(1));
      expect(result.target.effectiveMaxHp, equals(720)); // -20% Soul Fracture!

      // Debuffs (bleed) should be cleansed, buffs (defenseUp) kept, and invulnerable grace + shield added
      expect(result.target.activeEffects.any((e) => e.type == StatusEffectType.bleed), isFalse);
      expect(result.target.activeEffects.any((e) => e.type == StatusEffectType.defenseUp), isTrue);
      expect(result.target.activeEffects.any((e) => e.type == StatusEffectType.invulnerable), isTrue);

      tickManager.dispose();
    });

    test('Section 3.4: Revive overflow converts 50% excess into Aegis Shield', () {
      final allies = StarterBrigades.createAshLegionPlayerSquad();
      final enemies = StarterBrigades.createCryptStalkersEnemySquad();

      // Low max HP unit downed (Grave Duelist in slot 2)
      final downedDuelist = allies[2].copyWith(
        maxHp: 200,
        currentHp: 0,
      );

      final modifiedAllies = [allies[0], allies[1], downedDuelist, ...allies.sublist(3)];
      final tickManager = InitiativeTickManager(
        initialAllies: modifiedAllies,
        initialEnemies: enemies,
      );
      final combatService = CombatResolutionService(tickManager: tickManager);

      // High attack caster: ATK = 500, Gen = 2, Coeff = 1.0 -> 500 * (1 + 0.3) = 650
      // Target effectiveMaxHp = (200 * 0.8) = 160.
      // Overflow = 650 - 160 = 490. Aegis shield = 490 * 0.50 = 245.
      final caster = allies[4].copyWith(attack: 500, generation: 2, turnMeter: 100.0);
      tickManager.updateSquads(allies: [allies[0], allies[1], downedDuelist, allies[3], caster]);
      tickManager.advanceTick();

      final result = combatService.executeInfusedVitaeRevive(
        targetUnitId: downedDuelist.id,
        skillCoefficient: 1.0,
      );

      expect(result, isNotNull);
      expect(result!.target.currentHp, equals(160));
      final shieldEffect = result.target.activeEffects.firstWhere((e) => e.type == StatusEffectType.shield);
      expect(shieldEffect.value, equals(245));

      tickManager.dispose();
    });

    test('Section 13.1: The Ashen Reckoning escalates through warning, reckoning, collapse, and adjudication', () {
      final allies = StarterBrigades.createAshLegionPlayerSquad();
      final enemies = StarterBrigades.createCryptStalkersEnemySquad();

      final tickManager = InitiativeTickManager(
        initialAllies: allies,
        initialEnemies: enemies,
      );

      // At start (0 ticks): normal phase
      expect(tickManager.reckoningPhase, equals(AshenReckoningPhase.normal));
      expect(tickManager.reckoningDamageMultiplier, equals(1.0));
      expect(tickManager.reckoningHealingMultiplier, equals(1.0));
      expect(tickManager.areRevivesDisabled, isFalse);

      // Advance to 2,250 ticks (1:15 warning chime)
      while (tickManager.tickCount < 2250) {
        tickManager.advanceTick();
        if (tickManager.phase == CombatPhase.awaitingAction) {
          tickManager.consumeTurn();
        }
      }
      expect(tickManager.reckoningPhase, equals(AshenReckoningPhase.warning));

      // Advance to 2,700 ticks (1:30 Phase 1 Ashen Reckoning: 2.0x dmg, 0.5x heals)
      while (tickManager.tickCount < 2700) {
        tickManager.advanceTick();
        if (tickManager.phase == CombatPhase.awaitingAction) {
          tickManager.consumeTurn();
        }
      }
      expect(tickManager.reckoningPhase, equals(AshenReckoningPhase.reckoning));
      expect(tickManager.reckoningDamageMultiplier, equals(2.0));
      expect(tickManager.reckoningHealingMultiplier, equals(0.5));

      // Advance to 3,150 ticks (1:45 Phase 2 Terminal Collapse: revives disabled)
      while (tickManager.tickCount < 3150) {
        tickManager.advanceTick();
        if (tickManager.phase == CombatPhase.awaitingAction) {
          tickManager.consumeTurn();
        }
      }
      expect(tickManager.reckoningPhase, equals(AshenReckoningPhase.terminalCollapse));
      expect(tickManager.areRevivesDisabled, isTrue);

      // Verify revives are blocked during Terminal Collapse
      final combatService = CombatResolutionService(tickManager: tickManager);
      final reviveAttempt = combatService.executeInfusedVitaeRevive(targetUnitId: allies[0].id);
      expect(reviveAttempt, null);

      // Reset clock (Section 13.2: Multi-phase boss timer reset)
      tickManager.resetReckoningClock();
      expect(tickManager.tickCount, equals(0));
      expect(tickManager.reckoningPhase, equals(AshenReckoningPhase.normal));

      tickManager.dispose();
    });
  });
}
