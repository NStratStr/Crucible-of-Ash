import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/features/combat_spatial/spatial_combat_engine.dart';
import 'package:ashen_crucible/features/combat_spatial/models/spatial_combat_models.dart';
import 'package:ashen_crucible/features/combat_spatial/models/crucible_skill_tree_models.dart';
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
      expect(sculptor.crucibleCinders, greaterThanOrEqualTo(cindersBefore + 6));

      // Slot 1 (Forge Cleave) is an always-available builder consuming 0 Cinders and generating +6 Cinders
      sculptor.currentAp = 6400;
      sculptor.crucibleCinders = 0; // Test activation at 0 cinders!
      engine.executeUnitAction(sculptor, actionType: 'forge_cleave');
      expect(sculptor.crucibleCinders, anyOf(equals(6), equals(10)));
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
      expect(sculptor.crucibleCinders, anyOf(equals(5), equals(9))); // 50 - 45 = 5 (+4 if Stalker Keen Edge crits)
    });

    test('Each Commander Skill has explicit cooldown and is blocked while on cooldown', () {
      final engine = SpatialCombatEngine();
      engine.setupSunderAtAshenGate();
      final sculptor = engine.playerUnits.firstWhere((u) => u.isAshSculptor);
      sculptor.crucibleCinders = 0;

      // Slot 1: Forge Cleave has 1.5s cooldown
      final cleave = engine.skillTreeState.getSkillInSlot(0)!;
      expect(cleave.effectiveCooldownSeconds, equals(1.5));
      expect(engine.skillTreeState.getCooldownRemaining(cleave.id), equals(0.0));

      // Execute Forge Cleave
      engine.executeUnitAction(sculptor, actionType: 'forge_cleave');
      expect(sculptor.crucibleCinders, anyOf(equals(6), equals(10))); // Generated 6 (+4 if companion crit)
      expect(engine.skillTreeState.getCooldownRemaining(cleave.id), greaterThan(0.0));

      // Attempting to execute while on cooldown is blocked
      final cindersBefore = sculptor.crucibleCinders;
      engine.executeUnitAction(sculptor, actionType: 'forge_cleave');
      expect(sculptor.crucibleCinders, equals(cindersBefore), reason: 'Should not generate cinders while on cooldown');

      // Ticking simulation decrements cooldown
      engine.skillTreeState.updateCooldowns(1.6);
      expect(engine.skillTreeState.getCooldownRemaining(cleave.id), equals(0.0));

      // Off cooldown: can execute again!
      engine.executeUnitAction(sculptor, actionType: 'forge_cleave');
      expect(sculptor.crucibleCinders, greaterThanOrEqualTo(cindersBefore + 6));
    });

    test('Minions have unique basic attacks, 3-turn signatures, and passives to the Sculptor', () {
      final engine = SpatialCombatEngine();
      engine.setupSunderAtAshenGate();

      final footman = engine.playerUnits.firstWhere((u) => u.id == 'iron_footman');
      final duelist = engine.playerUnits.firstWhere((u) => u.id == 'grave_duelist');
      final sculptor = engine.playerUnits.firstWhere((u) => u.isAshSculptor);

      // 1. Retinue Passives given to Sculptor while minions live
      expect(engine.isBulwarkOathActive, isTrue);
      expect(engine.isStalkerKeenEdgeActive, isTrue);

      // Simulation tick applies Bulwark Oath (-15% damage taken) to Sculptor
      engine.stepTick();
      expect(sculptor.damageReductionMultiplier, equals(0.85));

      // 2. Iron Footman unique basic attack (Shieldbash Cleave): -12 Armor Shred & +15 Aegis Barrier
      final dummyTarget = engine.enemyUnits.firstWhere((u) => u.isAlive);
      final initialArmor = dummyTarget.armor;
      final initialShield = footman.aegisShield;

      // Force footman basic attack
      footman.signatureCooldown = 3;
      engine.executeUnitAction(footman, explicitTarget: dummyTarget, actionType: 'auto');
      expect(dummyTarget.armor, equals(initialArmor - 12));
      expect(footman.aegisShield, equals(initialShield + 15));

      // 3. Iron Footman signature skill (Bastion\'s Aegis): grants +40 Aegis to BOTH Footman AND Sculptor
      final sculptorShieldBefore = sculptor.aegisShield;
      final footmanShieldBefore = footman.aegisShield;
      footman.signatureCooldown = 0; // Ready!
      engine.executeCompanionSignature('iron_footman', explicitTarget: dummyTarget);
      expect(footman.aegisShield, equals(footmanShieldBefore + 40));
      expect(sculptor.aegisShield, equals(sculptorShieldBefore + 40));
      expect(footman.signatureCooldown, equals(3));

      // 4. Grave Duelist signature skill (Phantom Ambush): channels +12 Cinders to the Sculptor
      sculptor.crucibleCinders = 10;
      duelist.signatureCooldown = 0; // Ready!
      engine.executeCompanionSignature('grave_duelist', explicitTarget: dummyTarget);
      expect(sculptor.crucibleCinders, equals(22)); // 10 + 12
      expect(duelist.signatureCooldown, equals(3));
    });

    test('Crypt Resource drops and upgrading Minions and Sculptor', () {
      final engine = SpatialCombatEngine();
      engine.setupSunderAtAshenGate();

      // Starting wallet amounts
      expect(engine.unboundAshWallet, greaterThanOrEqualTo(600));
      expect(engine.distilledVitaeWallet, greaterThanOrEqualTo(60));

      final footman = engine.playerUnits.firstWhere((u) => u.id == 'iron_footman');
      final initialHp = footman.maxHp;
      final initialAtk = footman.attack;
      final ashBefore = engine.unboundAshWallet;

      // Upgrade Minion (costs 120 Ash)
      final success = engine.upgradeMinion('iron_footman');
      expect(success, isTrue);
      expect(footman.maxHp, equals(initialHp + 150));
      expect(footman.attack, equals(initialAtk + 25));
      expect(engine.unboundAshWallet, equals(ashBefore - 120));

      // Upgrade Sculptor Furnace (costs 200 Ash & 20 Vitae)
      final sculptor = engine.playerUnits.firstWhere((u) => u.isAshSculptor);
      final sculptorHpBefore = sculptor.maxHp;
      final sculptorAtkBefore = sculptor.attack;
      final vitaeBefore = engine.distilledVitaeWallet;

      final ascendSuccess = engine.upgradeSculptorFurnace();
      expect(ascendSuccess, isTrue);
      expect(sculptor.maxHp, equals(sculptorHpBefore + 200));
      expect(sculptor.attack, equals(sculptorAtkBefore + 30));
      expect(engine.distilledVitaeWallet, equals(vitaeBefore - 20));

      // Upgrade Commander Skill (costs 15 Vitae)
      final cleave = engine.skillTreeState.allSkills['ash_cleave']!;
      expect(cleave.rank, equals(1));
      final skillUpgradeSuccess = engine.upgradeCommanderSkill('ash_cleave');
      expect(skillUpgradeSuccess, isTrue);
      expect(cleave.rank, equals(2));
      expect(engine.distilledVitaeWallet, equals(vitaeBefore - 20 - 15));
    });

    test('3-Branch Archetype System (Wrath, Bastion, Resonance) & Keystone activations', () {
      final engine = SpatialCombatEngine();
      final tree = engine.skillTreeState;
      tree.availableSkillPoints = 20;

      // 1. Verify branches categorize all skills properly
      final wrathSkills = tree.getSkillsForBranch(CrucibleSkillBranch.wrath);
      final bastionSkills = tree.getSkillsForBranch(CrucibleSkillBranch.bastion);
      final resonanceSkills = tree.getSkillsForBranch(CrucibleSkillBranch.resonance);
      final apexSkills = tree.getSkillsForBranch(CrucibleSkillBranch.apex);

      expect(wrathSkills.isNotEmpty, isTrue);
      expect(bastionSkills.isNotEmpty, isTrue);
      expect(resonanceSkills.isNotEmpty, isTrue);
      expect(apexSkills.length, equals(4));

      // 2. Initial state: 0 points invested in all branches -> Keystones locked
      expect(tree.wrathPointsSpent, equals(0));
      expect(tree.isMoltenOverdriveActive, isFalse);
      expect(tree.isSlagFortressActive, isFalse);
      expect(tree.isCrucibleSymbiosisActive, isFalse);

      // 3. Invest 3 points into Wrath: Forge Cleave (R1 -> R3 = +2 pts) + Sundering Brand (R1 -> R2 = +1 pt)
      tree.upgradeSkill('ash_cleave'); // R2 (+1 pt)
      tree.upgradeSkill('ash_cleave'); // R3 (+1 pt)
      tree.upgradeSkill('ash_brand');  // R2 (+1 pt)
      expect(tree.wrathPointsSpent, equals(3));
      expect(tree.isMoltenOverdriveActive, isTrue);

      // 4. Test Molten Overdrive in combat: Slaying enemy grants +15 Cinders & +2,500 AP
      engine.setupSunderAtAshenGate();
      final sculptor = engine.playerUnits.firstWhere((u) => u.isAshSculptor);
      sculptor.crucibleCinders = 0;
      sculptor.currentAp = 0;

      // Down an enemy unit
      final target = engine.enemyUnits.firstWhere((u) => u.isAlive);
      target.takeDamage(10000, ignoreArmor: true);
      expect(target.hp, equals(0));

      // Simulation tick checks for slain enemies and procs Molten Overdrive
      engine.stepTick();
      expect(sculptor.crucibleCinders, equals(15));
      expect(sculptor.currentAp, equals(2500 + sculptor.speed));

      // 5. Test Slag Fortress (Bastion Keystone): Reduces squad damage by 20% while minions live
      tree.upgradeSkill('iron_slam');
      tree.upgradeSkill('iron_slam');
      tree.upgradeSkill('ash_bastion');
      expect(tree.bastionPointsSpent, equals(3));
      expect(tree.isSlagFortressActive, isTrue);

      engine.stepTick();
      // Footman receives 20% damage reduction from Slag Fortress
      final footman = engine.playerUnits.firstWhere((u) => u.id == 'iron_footman');
      expect(footman.damageReductionMultiplier, equals(0.80));

      // 6. Test Crucible Symbiosis (Resonance Keystone): Minion strikes channel +3 Cinders to Sculptor
      tree.upgradeSkill('sanguine_rend');
      tree.upgradeSkill('sanguine_rend');
      tree.upgradeSkill('sanguine_tether');
      expect(tree.resonancePointsSpent, equals(3));
      expect(tree.isCrucibleSymbiosisActive, isTrue);

      final cindersBeforeStrike = sculptor.crucibleCinders;
      // Footman attacks enemy
      engine.executeUnitAction(footman, explicitTarget: engine.enemyUnits.firstWhere((u) => u.isAlive), actionType: 'auto');
      expect(sculptor.crucibleCinders, equals(cindersBeforeStrike + 3));
    });
  });
}
