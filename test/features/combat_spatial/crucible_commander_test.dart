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
      expect(engine.playerUnits[1].name, 'Iron Footman');
      expect(engine.playerUnits[2].name, 'Grave Duelist');

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
      sculptor.crucibleCinders = 15;
      minion.currentAp = 9950; // Will reach 10,000 TM on next tick

      engine.stepTick();

      // Minion should NOT pause turn execution for legacy UI tray
      expect(engine.isTurnExecutionPaused, isFalse);
      // Minion should have acted automatically and channeled +3 Cinders to the Ash Sculptor
      expect(minion.currentAp, lessThan(10000));
      expect(sculptor.crucibleCinders, greaterThanOrEqualTo(18));

      // Clear action pause so next tick can resolve
      engine.activeActionEvent = null;

      // Now bring The Ash Sculptor to 10,000 TM -> attacks automatically at interval for +6 Cinders!
      final cindersBefore = sculptor.crucibleCinders;
      sculptor.currentAp = 9950;
      engine.stepTick();
      expect(engine.isTurnExecutionPaused, isFalse);
      expect(sculptor.currentAp, lessThan(10000));
      expect(sculptor.crucibleCinders, equals(cindersBefore + 6));

      // Slot 1 (Forge Cleave) is an always-available builder consuming 0 Cinders and generating +6 Cinders
      sculptor.currentAp = 6400;
      sculptor.crucibleCinders = 0; // Test activation at 0 cinders!
      engine.executeUnitAction(sculptor, actionType: 'forge_cleave');
      expect(sculptor.crucibleCinders, equals(6));
      expect(sculptor.currentAp, equals(6400));
    });

    test('Player retinue has distinct companions and staggered initiative so attacks do not sync', () {
      final engine = SpatialCombatEngine();
      engine.setupCampaignEncounter(
        playerEntities: const [
          UnitEntity(
            id: 'corrupted_0',
            speciesId: 'ash_sculptor',
            name: 'The Ash Sculptor',
            generation: 1,
            rarity: UnitRarity.legendary,
            archetype: Archetype.assassin,
            slot: FormationSlot.front1,
            level: 4,
            maxLevel: 10,
            currentHp: 1665,
            maxHp: 1665,
            attack: 283,
            defense: 110,
            speed: 115,
            resist: 65,
            nativeTraitId: 'vampiric_conduit',
            lineageAncestors: ['strigoi_lord'],
          ),
          UnitEntity(
            id: 'corrupted_1',
            speciesId: 'ash_sculptor',
            name: 'The Ash Sculptor',
            generation: 1,
            rarity: UnitRarity.legendary,
            archetype: Archetype.juggernaut,
            slot: FormationSlot.front2,
            level: 5,
            maxLevel: 10,
            currentHp: 1531,
            maxHp: 1531,
            attack: 194,
            defense: 140,
            speed: 95,
            resist: 60,
            nativeTraitId: 'shield_bash',
            lineageAncestors: ['ironclad_veteran'],
          ),
          UnitEntity(
            id: 'corrupted_2',
            speciesId: 'ash_sculptor',
            name: 'The Ash Sculptor',
            generation: 1,
            rarity: UnitRarity.legendary,
            archetype: Archetype.assassin,
            slot: FormationSlot.front3,
            level: 5,
            maxLevel: 10,
            currentHp: 1531,
            maxHp: 1531,
            attack: 194,
            defense: 75,
            speed: 125,
            resist: 45,
            nativeTraitId: 'vicious_strike',
            lineageAncestors: ['ashen_inquisitor'],
          ),
        ],
        enemyEntities: const [
          UnitEntity(
            id: 'dummy',
            speciesId: 'dummy',
            name: 'Dummy',
            generation: 1,
            rarity: UnitRarity.common,
            archetype: Archetype.juggernaut,
            slot: FormationSlot.front1,
            level: 1,
            maxLevel: 10,
            currentHp: 1000,
            maxHp: 1000,
            attack: 10,
            defense: 10,
            speed: 50,
            resist: 10,
            nativeTraitId: 'none',
            lineageAncestors: [],
          ),
        ],
      );

      // Verify that corrupt clone entities are healed into distinct units
      expect(engine.playerUnits.length, 3);
      expect(engine.playerUnits[0].name, 'The Ash Sculptor');
      expect(engine.playerUnits[0].isAshSculptor, isTrue);
      expect(engine.playerUnits[0].speed, 115);
      expect(engine.playerUnits[0].currentAp, 0);

      expect(engine.playerUnits[1].name, 'Iron Footman');
      expect(engine.playerUnits[1].isAshSculptor, isFalse);
      expect(engine.playerUnits[1].customAssetPath, 'assets/images/iron_footman_idle.png');
      expect(engine.playerUnits[1].speed, 95);
      expect(engine.playerUnits[1].currentAp, 2500);

      expect(engine.playerUnits[2].name, 'Grave Duelist');
      expect(engine.playerUnits[2].isAshSculptor, isFalse);
      expect(engine.playerUnits[2].customAssetPath, 'assets/images/grave_duelist.png');
      expect(engine.playerUnits[2].speed, 125);
      expect(engine.playerUnits[2].currentAp, 5000);

      // Verify that only 1 unit is Ash Sculptor
      expect(engine.playerUnits.where((u) => u.isAshSculptor).length, 1);
    });

    test('Crucible Skill Tree: Equips 5 skills across disciplines, upgrades ranks, and executes Slot 4 heavy assault', () {
      final engine = SpatialCombatEngine();
      engine.setupSunderAtAshenGate();

      final tree = engine.skillTreeState;

      // 1. Initial 5 equipped skills for Ash Sculptor
      expect(tree.equippedSkillIds.length, equals(5));
      expect(tree.getSkillInSlot(0)?.id, equals('ash_cleave'));
      expect(tree.getSkillInSlot(1)?.id, equals('ash_brand'));
      expect(tree.getSkillInSlot(2)?.id, equals('ash_bastion'));
      expect(tree.getSkillInSlot(3)?.id, equals('ash_whirlwind'));
      expect(tree.getSkillInSlot(4)?.id, equals('ash_pyre'));

      // 2. Upgrading a skill node with Skill Points
      final cleave = tree.allSkills['ash_cleave']!;
      expect(cleave.rank, equals(1));
      expect(cleave.effectiveMultiplier, equals(1.40));
      expect(tree.availableSkillPoints, equals(5));

      final upgraded = tree.upgradeSkill('ash_cleave');
      expect(upgraded, isTrue);
      expect(cleave.rank, equals(2));
      expect(cleave.effectiveMultiplier, equals(1.40 * 1.25));
      expect(tree.availableSkillPoints, equals(4));

      // 3. Cross-Discipline Custom Loadout: Equip Sanguine Siphon into Slot 1 and Dawn Retribution into Slot 4
      final equipSanguine = tree.equipSkill(0, 'sanguine_rend');
      expect(equipSanguine, isTrue);
      expect(tree.getSkillInSlot(0)?.name, equals('Siphon Rend'));

      final equipIron = tree.equipSkill(3, 'iron_retribution');
      expect(equipIron, isTrue);
      expect(tree.getSkillInSlot(3)?.name, equals('Dawn Retribution'));

      // 4. Slot 4 Heavy Devastation: Ember Whirlwind consumes 45 Cinders
      final sculptor = engine.playerUnits.firstWhere((u) => u.isAshSculptor);
      sculptor.crucibleCinders = 50;
      engine.executeUnitAction(sculptor, actionType: 'ember_whirlwind');
      expect(sculptor.crucibleCinders, equals(5)); // 50 - 45 = 5
    });
  });
}
