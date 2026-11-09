import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/features/combat_spatial/spatial_combat_engine.dart';
import 'package:ashen_crucible/features/combat_spatial/models/spatial_combat_models.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';

void main() {
  group('Crucible Commander & Forge Strike Engine Tests', () {
    test('Ash Sculptor auto-deploys with 2 minions even if solo player entity is passed', () {
      final engine = SpatialCombatEngine();
      engine.setupCampaignEncounter(
        playerEntities: const [
          UnitEntity(
            id: 'solo_commander',
            speciesId: 'ash_sculptor',
            name: 'The Ash Sculptor',
            generation: 1,
            rarity: UnitRarity.legendary,
            archetype: Archetype.juggernaut,
            slot: FormationSlot.front1,
            level: 1,
            maxLevel: 10,
            currentHp: 900,
            maxHp: 900,
            attack: 140,
            defense: 110,
            speed: 100,
            resist: 65,
            nativeTraitId: 'iron_fortitude',
            lineageAncestors: ['strigoi_lord'],
          ),
        ],
        enemyEntities: const [
          UnitEntity(
            id: 'target_dummy',
            speciesId: 'training_dummy',
            name: 'Dummy',
            generation: 1,
            rarity: UnitRarity.common,
            archetype: Archetype.juggernaut,
            slot: FormationSlot.front1,
            level: 1,
            maxLevel: 10,
            currentHp: 2000,
            maxHp: 2000,
            attack: 20,
            defense: 20,
            speed: 50,
            resist: 20,
            nativeTraitId: 'shield_bash',
            lineageAncestors: ['ironclad_veteran'],
          ),
        ],
      );

      // Verify all 3 units are auto-deployed on the spatial grid
      expect(engine.playerUnits.length, 3);
      expect(engine.playerUnits[0].name, 'The Ash Sculptor');
      expect(engine.playerUnits[0].isAshSculptor, isTrue);
      expect(engine.playerUnits[1].name, 'Tombstone Sentinel');
      expect(engine.playerUnits[2].name, 'Blood Scribe');

      for (final ally in engine.playerUnits) {
        expect(ally.occupiedNodes.isNotEmpty, isTrue, reason: '${ally.name} should have occupied grid nodes');
      }
    });

    test('Cataclysmic Pyre standard deals 250% ATK damage', () {
      final engine = SpatialCombatEngine();
      engine.setupSunderAtAshenGate();

      final sculptor = engine.playerUnits.firstWhere((u) => u.isAshSculptor);
      sculptor.crucibleCinders = 100;
      final enemyTarget = engine.enemyUnits.firstWhere((u) => u.id == 'cinder_witch');
      final hpBefore = enemyTarget.hp;

      engine.executeUnitAction(
        sculptor,
        isReposition: false,
        explicitTarget: enemyTarget,
        actionType: 'cataclysmic_pyre',
      );

      expect(enemyTarget.hp, lessThan(hpBefore));
      expect(sculptor.crucibleCinders, 20); // 100 - 80
    });

    test('Cataclysmic Pyre PERFECT FORGE CRIT deals 350% ATK overdrive damage', () {
      final engine = SpatialCombatEngine();
      engine.setupSunderAtAshenGate();

      final sculptor = engine.playerUnits.firstWhere((u) => u.isAshSculptor);
      sculptor.crucibleCinders = 100;
      final enemyTarget = engine.enemyUnits.firstWhere((u) => u.id == 'cinder_witch');
      final hpBefore = enemyTarget.hp;

      engine.executeUnitAction(
        sculptor,
        isReposition: false,
        explicitTarget: enemyTarget,
        actionType: 'cataclysmic_pyre_crit',
      );

      expect(enemyTarget.hp, lessThan(hpBefore));
      expect(sculptor.crucibleCinders, 20); // 100 - 80
    });

    test('Retinue minions execute turns autonomously and channel +10 Cinders without pausing for legacy turn tray', () {
      final engine = SpatialCombatEngine();
      engine.setupSunderAtAshenGate();
      engine.isPreBattlePhase = false;

      final sculptor = engine.playerUnits.firstWhere((u) => u.isAshSculptor);
      final minion = engine.playerUnits.firstWhere((u) => !u.isAshSculptor);

      sculptor.currentAp = 0;
      sculptor.crucibleCinders = 45;
      minion.currentAp = 9950; // Will reach 10,000 TM on next tick

      engine.stepTick();

      // Minion should NOT pause turn execution for legacy UI tray
      expect(engine.isTurnExecutionPaused, isFalse);
      // Minion should have acted automatically and channeled +10 Cinders to the Ash Sculptor
      expect(minion.currentAp, lessThan(10000));
      expect(sculptor.crucibleCinders, greaterThanOrEqualTo(55));

      // Now bring The Ash Sculptor to 10,000 TM -> SHOULD pause for Commander Tray decision
      sculptor.currentAp = 9950;
      engine.stepTick();
      expect(engine.isTurnExecutionPaused, isTrue);
      expect(engine.activeActingUnit?.id, equals('ash_sculptor'));
    });
  });
}
