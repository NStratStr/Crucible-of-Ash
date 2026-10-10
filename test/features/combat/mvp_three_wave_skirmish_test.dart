import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/features/combat/combat_resolution_service.dart';
import 'package:ashen_crucible/features/combat/initiative_tick_manager.dart';
import 'package:ashen_crucible/features/generals/general_command_service.dart';
import 'package:ashen_crucible/shared/data/starter_brigades.dart';
import 'package:ashen_crucible/shared/models/skill_entity.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';

void main() {
  group('GDD v2.6 Sec 14.1: MVP 3-Wave Skirmish Loop Tests', () {
    test('createMvpThreeWaveSkirmish generates 3 escalating waves up to Gorgoroth the Flayed', () {
      final waves = StarterBrigades.createMvpThreeWaveSkirmish();

      expect(waves.length, equals(3));

      // Wave 1: 3 units
      expect(waves[0].length, equals(3));
      expect(waves[0][0].name, contains('Rotting Husk'));
      expect(waves[0][1].name, contains('Grave Ghoul'));
      expect(waves[0][2].name, contains('Blood Alchemist'));

      // Wave 2: 4 units
      expect(waves[1].length, equals(4));
      expect(waves[1][3].name, contains('Blight Necromancer'));

      // Wave 3: 5 units with Titanic Boss
      expect(waves[2].length, equals(5));
      final boss = waves[2].firstWhere((u) => u.isBoss);
      expect(boss.name, equals('Gorgoroth the Flayed'));
      expect(boss.archetype, equals(Archetype.juggernaut));
      expect(boss.nativeTraitId, equals('titanic_cleave'));
      expect(boss.maxHp, equals(2200));
    });

    test('3-Wave combat advances smoothly through Wave 1, Wave 2, and Boss Wave with clock resets', () {
      final waves = StarterBrigades.createMvpThreeWaveSkirmish();
      final allies = StarterBrigades.createAshLegionPlayerSquad();

      final tickManager = InitiativeTickManager(
        initialAllies: allies,
        initialEnemies: waves[0],
      );

      final commandService = GeneralCommandService(
        tickManager: tickManager,
        generalType: GeneralType.vladislav,
        initialFocus: 6,
        maxFocus: GeneralCommandService.grimoireMaxFocusCap,
      );
      commandService.initializeGrimoire();

      // Start Wave 1
      expect(tickManager.enemies.length, equals(3));
      expect(tickManager.tickCount, equals(0));

      // Advance ticks to trigger warning phase
      while (tickManager.tickCount < 2300) {
        tickManager.advanceTick();
        if (tickManager.phase == CombatPhase.awaitingAction) {
          tickManager.consumeTurn();
        }
      }
      expect(tickManager.reckoningPhase, equals(AshenReckoningPhase.warning));

      // Defeat Wave 1
      final defeatedWave1 = tickManager.enemies.map((e) => e.copyWith(currentHp: 0)).toList();
      tickManager.updateSquads(enemies: defeatedWave1);

      // Advance to Wave 2 via advanceWave
      tickManager.advanceWave(waves[1]);
      expect(tickManager.enemies.length, equals(4));
      // GDD Sec 13.2: Reckoning clock reset
      expect(tickManager.tickCount, equals(0));
      expect(tickManager.reckoningPhase, equals(AshenReckoningPhase.normal));

      // Defeat Wave 2
      final defeatedWave2 = tickManager.enemies.map((e) => e.copyWith(currentHp: 0)).toList();
      tickManager.updateSquads(enemies: defeatedWave2);

      // Advance to Wave 3 (Boss)
      tickManager.advanceWave(waves[2]);
      expect(tickManager.enemies.length, equals(5));
      expect(tickManager.tickCount, equals(0));
      expect(tickManager.enemies.any((e) => e.isBoss), isTrue);

      // Defeat Boss Wave
      final defeatedWave3 = tickManager.enemies.map((e) => e.copyWith(currentHp: 0)).toList();
      tickManager.updateSquads(enemies: defeatedWave3);

      // Final check: All enemies defeated
      expect(tickManager.enemies.every((e) => !e.isAlive), isTrue);
      expect(tickManager.allies.every((a) => a.isAlive), isTrue);

      tickManager.dispose();
      commandService.dispose();
    });
  });
}
