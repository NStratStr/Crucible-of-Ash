import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/features/combat/initiative_tick_manager.dart';
import 'package:ashen_crucible/features/combat/combat_resolution_service.dart';
import 'package:ashen_crucible/features/generals/general_command_service.dart';
import 'package:ashen_crucible/shared/models/skill_entity.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';

void main() {
  group('GDD v2.6 Section 13.2: Multi-Phase Boss Timer Resets & Transitions', () {
    test('Boss crossing 66% HP resets Reckoning Clock and announces Phase II', () {
      final ally = const UnitEntity(
        id: 'ally_1',
        speciesId: 'iron_footman',
        name: 'Iron Footman',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 10,
        maxLevel: 30,
        currentHp: 1000,
        maxHp: 1000,
        attack: 100,
        defense: 100,
        speed: 90,
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      // Boss with 1000 Max HP starting at 1000 HP
      final boss = const UnitEntity(
        id: 'boss_gorgoroth',
        speciesId: 'gorgoroth_flayed',
        name: 'Gorgoroth the Flayed',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 15,
        maxLevel: 30,
        currentHp: 1000,
        maxHp: 1000,
        attack: 150,
        defense: 100,
        speed: 80,
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      final tickManager = InitiativeTickManager(
        initialAllies: [ally],
        initialEnemies: [boss],
      );

      // Advance clock to simulate mid-combat tick progression into warning phase
      while (tickManager.tickCount < 2300) {
        tickManager.advanceTick();
        if (tickManager.phase == CombatPhase.awaitingAction) {
          tickManager.consumeTurn();
        }
      }
      expect(tickManager.tickCount, equals(2300));
      expect(tickManager.reckoningPhase, equals(AshenReckoningPhase.warning));

      // Damage boss down to 650 HP (65% HP <= 66%)
      final damagedBoss = boss.copyWith(currentHp: 650);
      tickManager.updateSquads(enemies: [damagedBoss]);

      final bool shifted = tickManager.checkBossPhaseThresholds();
      expect(shifted, isTrue);

      // GDD Sec 13.2 requirement: Clock resets to 0, clearing active Reckoning penalties
      expect(tickManager.tickCount, equals(0));
      expect(tickManager.reckoningPhase, equals(AshenReckoningPhase.normal));
      expect(tickManager.reckoningDamageMultiplier, equals(1.0));
      expect(tickManager.lastPhaseShiftMessage, contains('Phase II'));
    });

    test('Boss crossing 33% HP triggers Critical Phase and resets Reckoning Clock again', () {
      final ally = const UnitEntity(
        id: 'ally_1',
        speciesId: 'iron_footman',
        name: 'Iron Footman',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 10,
        maxLevel: 30,
        currentHp: 1000,
        maxHp: 1000,
        attack: 100,
        defense: 100,
        speed: 90,
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      final boss = const UnitEntity(
        id: 'boss_gorgoroth',
        speciesId: 'gorgoroth_flayed',
        name: 'Gorgoroth the Flayed',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 15,
        maxLevel: 30,
        currentHp: 600, // In Phase 2
        maxHp: 1000,
        attack: 150,
        defense: 100,
        speed: 80,
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      final tickManager = InitiativeTickManager(
        initialAllies: [ally],
        initialEnemies: [boss],
      );

      // Cross 66% threshold first
      tickManager.checkBossPhaseThresholds();

      // Tick forward again into warning
      while (tickManager.tickCount < 2400) {
        tickManager.advanceTick();
        if (tickManager.phase == CombatPhase.awaitingAction) {
          tickManager.consumeTurn();
        }
      }
      expect(tickManager.tickCount, equals(2400));

      // Now drop boss to 300 HP (30% <= 33%)
      final criticalBoss = boss.copyWith(currentHp: 300);
      tickManager.updateSquads(enemies: [criticalBoss]);

      final bool shiftedAgain = tickManager.checkBossPhaseThresholds();
      expect(shiftedAgain, isTrue);

      // Clock resets back to 0!
      expect(tickManager.tickCount, equals(0));
      expect(tickManager.lastPhaseShiftMessage, contains('Blood Frenzy'));
    });
  });
}
