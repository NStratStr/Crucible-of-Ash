import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/features/combat/initiative_tick_manager.dart';
import 'package:ashen_crucible/features/generals/general_command_service.dart';
import 'package:ashen_crucible/shared/data/starter_brigades.dart';
import 'package:ashen_crucible/shared/models/skill_entity.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';

void main() {
  group('Lord Vladislav 6-Card Grimoire & Hand Management Tests (GDD v2.6 Sec 5 & 14.1)', () {
    late InitiativeTickManager tickManager;
    late GeneralCommandService commandService;

    setUp(() {
      tickManager = InitiativeTickManager(
        initialAllies: StarterBrigades.createAshLegionPlayerSquad(),
        initialEnemies: StarterBrigades.createCryptStalkersEnemySquad(),
      );

      commandService = GeneralCommandService(
        tickManager: tickManager,
        generalType: GeneralType.vladislav,
        initialFocus: 6,
        maxFocus: GeneralCommandService.grimoireMaxFocusCap,
      );
    });

    test('initializeGrimoire builds 12-card deck for Vladislav and draws 3-card hand (GDD v2.9 Sec 4.1)', () {
      commandService.initializeGrimoire();

      expect(commandService.hand.length, equals(3));
      expect(commandService.grimoireDeck.length, equals(9));
      expect(commandService.deckLimit, equals(12));
      expect(commandService.discardPile, isEmpty);
      expect(commandService.burnCooldownTicks, equals(0));
      expect(commandService.maxFocus, equals(6));
    });

    test('Burn Pit discards card with 0 Focus, grants +1 Focus, and draws fresh card after 8-tick cooldown', () {
      commandService.initializeGrimoire();
      // Spend down to 3 focus so +1 gain does not clamp at max 6
      commandService.executeRendFlesh(tickManager.enemies.first.id); // costs 1 -> 5
      commandService.executeIronBulwark(tickManager.allies.first.id); // costs 2 -> 3
      final cardToBurn = commandService.hand.first;
      final initialFocus = commandService.currentFocus;

      commandService.burnCard(cardToBurn.id);

      // Card moved to discard pile, hand reduced, +1 Focus granted
      expect(commandService.currentFocus, equals(initialFocus + 1));
      expect(commandService.hand.length, equals(2));
      expect(commandService.discardPile.length, equals(1));
      expect(commandService.burnCooldownTicks, equals(8));

      // Simulate 7 ticks -> still in cooldown
      for (int i = 0; i < 7; i++) {
        commandService.onSimulationTick();
      }
      expect(commandService.burnCooldownTicks, equals(1));
      expect(commandService.hand.length, equals(2));

      // 8th tick -> draws replacement card
      commandService.onSimulationTick();
      expect(commandService.burnCooldownTicks, equals(0));
      expect(commandService.hand.length, equals(3));
    });

    test('Deck Reshuffle recycles discard pile when draw deck empties', () {
      commandService.initializeGrimoire();

      // Repeatedly burn cards and tick until draw deck is exhausted
      while (commandService.grimoireDeck.isNotEmpty) {
        final card = commandService.hand.first;
        commandService.burnCard(card.id);
        for (int i = 0; i < 8; i++) {
          commandService.onSimulationTick();
        }
      }

      expect(commandService.grimoireDeck, isEmpty);
      expect(commandService.discardPile, isNotEmpty);

      // Burn one more card from hand: draw deck is empty, so reshuffle occurs!
      final burnedId = commandService.hand.first.id;
      commandService.burnCard(burnedId);
      for (int i = 0; i < 8; i++) {
        commandService.onSimulationTick();
      }

      // Deck was recycled from discard pile and hand replenished
      expect(commandService.hand.length, equals(3));
    });

    test('Bullet-Time slows simulation speed multiplier to 30%', () {
      expect(commandService.isBulletTimeActive, isFalse);
      expect(commandService.simulationSpeedMultiplier, equals(1.0));

      commandService.setBulletTime(true);
      expect(commandService.isBulletTimeActive, isTrue);
      expect(commandService.simulationSpeedMultiplier, equals(0.30));

      commandService.setBulletTime(false);
      expect(commandService.isBulletTimeActive, isFalse);
      expect(commandService.simulationSpeedMultiplier, equals(1.0));
    });

    test('Rend Flesh (1 Focus) applies physical damage and 2 Bleed stacks', () {
      final target = tickManager.enemies.first;
      final initialHp = target.currentHp;

      final res = commandService.executeRendFlesh(target.id);

      expect(res.focusSpent, equals(1));
      expect(commandService.currentFocus, equals(5));

      final updatedTarget = tickManager.enemies.firstWhere((e) => e.id == target.id);
      expect(updatedTarget.currentHp, lessThan(initialHp));
      final bleedStacks = updatedTarget.activeEffects.where((e) => e.type == StatusEffectType.bleed).length;
      expect(bleedStacks, equals(2));
    });

    test('Iron Bulwark (2 Focus) grants Aegis Shield and Armor buff', () {
      final ally = tickManager.allies.first;
      final initialDefense = ally.defense;

      final res = commandService.executeIronBulwark(ally.id);

      expect(res.focusSpent, equals(2));
      expect(commandService.currentFocus, equals(4));

      final updatedAlly = tickManager.allies.firstWhere((a) => a.id == ally.id);
      expect(updatedAlly.defense, equals(initialDefense + 25));
      expect(updatedAlly.activeEffects.any((e) => e.type == StatusEffectType.shield), isTrue);
      expect(updatedAlly.activeEffects.any((e) => e.type == StatusEffectType.defenseUp), isTrue);
    });

    test('Exsanguinating Strike (3 Focus) triggers 2.5x damage against Bleeding targets', () {
      final target = tickManager.enemies.first;
      // Inflict Bleed
      commandService.executeRendFlesh(target.id);

      final hpBefore = tickManager.enemies.firstWhere((e) => e.id == target.id).currentHp;
      final res = commandService.executeExsanguinatingStrike(target.id);

      expect(res.focusSpent, equals(3));
      final hpAfter = tickManager.enemies.firstWhere((e) => e.id == target.id).currentHp;
      final damage = hpBefore - hpAfter;

      // 2.5x base 200 = 500 damage mitigated by hyperbolic target armor PRR
      expect(damage, greaterThan(200));
      expect(res.summary, contains('2.5x vs Bleed'));
    });

    test('Exsanguinating Strike executes enemy directly if HP <= 25%', () {
      final target = tickManager.enemies.first;
      final lowHpTarget = target.copyWith(currentHp: (target.maxHp * 0.20).round());
      tickManager = InitiativeTickManager(
        initialAllies: tickManager.allies,
        initialEnemies: [lowHpTarget, ...tickManager.enemies.sublist(1)],
      );
      commandService = GeneralCommandService(
        tickManager: tickManager,
        generalType: GeneralType.vladislav,
        initialFocus: 6,
        maxFocus: GeneralCommandService.grimoireMaxFocusCap,
      );

      final res = commandService.executeExsanguinatingStrike(target.id);

      expect(res.summary, contains('Executed'));
      final updated = tickManager.enemies.firstWhere((e) => e.id == target.id);
      expect(updated.currentHp, equals(0));
    });

    test('Sanguine Revival (4 Focus) revives fallen ally with Infused Vitae formula, Grace, and Soul Fracture', () {
      final ally = tickManager.allies.first;
      final fallenAlly = ally.copyWith(currentHp: 0);
      tickManager = InitiativeTickManager(
        initialAllies: [fallenAlly, ...tickManager.allies.sublist(1)],
        initialEnemies: tickManager.enemies,
      );
      commandService = GeneralCommandService(
        tickManager: tickManager,
        generalType: GeneralType.vladislav,
        initialFocus: 6,
        maxFocus: GeneralCommandService.grimoireMaxFocusCap,
      );

      final res = commandService.executeSanguineRevival(fallenAlly.id);

      expect(res.focusSpent, equals(4));
      final revived = tickManager.allies.firstWhere((a) => a.id == ally.id);
      expect(revived.isAlive, isTrue);
      expect(revived.reviveCount, equals(1));
      // Soul Fracture -20% Max HP ceiling
      expect(revived.effectiveMaxHp, equals((ally.maxHp * 0.80).round()));
      // 6-tick Invulnerability grace
      expect(revived.activeEffects.any((e) => e.type == StatusEffectType.invulnerable), isTrue);
    });

    test('Sanguine Revival is strictly blocked during Terminal Collapse (Phase 2)', () {
      final ally = tickManager.allies.first;
      final fallenAlly = ally.copyWith(currentHp: 0);
      tickManager = InitiativeTickManager(
        initialAllies: [fallenAlly, ...tickManager.allies.sublist(1)],
        initialEnemies: tickManager.enemies,
      );
      commandService = GeneralCommandService(
        tickManager: tickManager,
        generalType: GeneralType.vladislav,
        initialFocus: 6,
        maxFocus: GeneralCommandService.grimoireMaxFocusCap,
      );

      // Advance clock past 3,150 ticks to trigger Terminal Collapse
      while (tickManager.tickCount < 3151) {
        tickManager.advanceTick();
        if (tickManager.phase == CombatPhase.awaitingAction) {
          tickManager.consumeTurn();
        }
      }
      expect(tickManager.areRevivesDisabled, isTrue);

      expect(
        () => commandService.executeSanguineRevival(ally.id),
        throwsStateError,
      );
    });

    test('Disrupting Cleave (2 Focus) deals damage and staggers target AP / Turn Meter by 25%', () {
      final target = tickManager.enemies.first;
      final surgedTarget = target.copyWith(turnMeter: 80.0);
      tickManager = InitiativeTickManager(
        initialAllies: tickManager.allies,
        initialEnemies: [surgedTarget, ...tickManager.enemies.sublist(1)],
      );
      commandService = GeneralCommandService(
        tickManager: tickManager,
        generalType: GeneralType.vladislav,
        initialFocus: 6,
        maxFocus: GeneralCommandService.grimoireMaxFocusCap,
      );

      final res = commandService.executeDisruptingCleave(target.id);

      expect(res.focusSpent, equals(2));
      final updated = tickManager.enemies.firstWhere((e) => e.id == target.id);
      expect(updated.turnMeter, equals(55.0)); // 80 - 25
    });

    test('Blood Boil (2 Focus) grants +35% Haste with 5% HP recoil', () {
      final ally = tickManager.allies.first;
      final initialHp = ally.currentHp;
      final initialSpeed = ally.speed;

      final res = commandService.executeBloodBoil(ally.id);

      expect(res.focusSpent, equals(2));
      final updated = tickManager.allies.firstWhere((a) => a.id == ally.id);
      expect(updated.currentHp, lessThan(initialHp));
      expect(updated.speed, equals((initialSpeed * 1.35).round()));
      expect(updated.activeEffects.any((e) => e.type == StatusEffectType.speedUp), isTrue);
    });

    test('GDD v2.9 Section 4.1 Asymmetric Commander Deck Matrix initializes correctly for all commanders', () {
      // Lady Valeria (Ash Legion): 10 slips, 3 hand, 3 starting Focus
      final valeriaService = GeneralCommandService(
        tickManager: tickManager,
        generalType: GeneralType.valeria,
      );
      valeriaService.initializeGrimoire();
      expect(valeriaService.deckLimit, equals(10));
      expect(valeriaService.hand.length, equals(3));
      expect(valeriaService.grimoireDeck.length, equals(7));
      expect(valeriaService.currentFocus, equals(3));
      expect(valeriaService.maxFocus, equals(7));

      // Malakor (Mire Coven): 14 slips, 3 hand, 1 starting Focus
      final malakorService = GeneralCommandService(
        tickManager: tickManager,
        generalType: GeneralType.malakor,
      );
      malakorService.initializeGrimoire();
      expect(malakorService.deckLimit, equals(14));
      expect(malakorService.hand.length, equals(3));
      expect(malakorService.grimoireDeck.length, equals(11));
      expect(malakorService.currentFocus, equals(1));
      expect(malakorService.maxFocus, equals(8));

      // Morrigan (Calx Order): 20 slips, 4 hand, 3 starting Focus
      final morriganService = GeneralCommandService(
        tickManager: tickManager,
        generalType: GeneralType.morrigan,
      );
      morriganService.initializeGrimoire();
      expect(morriganService.deckLimit, equals(20));
      expect(morriganService.hand.length, equals(4));
      expect(morriganService.grimoireDeck.length, equals(16));
      expect(morriganService.currentFocus, equals(3));
      expect(morriganService.maxFocus, equals(5));
    });
  });
}
