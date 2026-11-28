import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/features/combat_spatial/models/crucible_skill_tree_models.dart';
import 'package:ashen_crucible/features/combat_spatial/models/spatial_combat_models.dart';
import 'package:ashen_crucible/features/combat_spatial/spatial_combat_engine.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';
import 'package:ashen_crucible/shared/data/starter_brigades.dart';
import 'package:ashen_crucible/core/combat_math.dart';

void main() {
  group('SpatialCombatEngine — Ash Sculptor & Boss Combat Tests', () {
    late SpatialCombatEngine engine;

    setUp(() {
      engine = SpatialCombatEngine();
      engine.isAutoBattleMode = true;
    });

    test('Initializes default Gorgoroth encounter with Ash Sculptor protagonist and 2x2 Colossus boss', () {
      expect(engine.playerUnits, isNotEmpty);
      expect(engine.enemyUnits, isNotEmpty);

      final protagonist = engine.playerUnits.firstWhere((u) => u.isAshSculptor || u.id == 'ash_sculptor');
      expect(protagonist.isPlayer, isTrue);
      expect(protagonist.hp, greaterThan(0));

      final gorgoroth = engine.enemyUnits.firstWhere((u) => u.id == 'gorgoroth_boss');
      expect(gorgoroth.footprint, equals(UnitFootprint.quadColossus2x2));
      expect(gorgoroth.isDisplacementImmune, isTrue);
      expect(gorgoroth.occupiedNodes.length, equals(4));
      expect(gorgoroth.isSlagCarapaceActive, isTrue);
    });

    test('Pre-battle deployment phase allows free repositioning with 0 AP cost', () {
      expect(engine.isPreBattlePhase, isTrue);
      final hero = engine.playerUnits.first;
      hero.currentAp = 0;

      final moved = engine.movePlayerUnit(hero.id, 1, 1);
      expect(moved, isTrue);
      expect(hero.occupiedNodes.first.column, equals(1));
      expect(hero.occupiedNodes.first.row, equals(1));
      expect(hero.currentAp, equals(0));

      final projected = engine.resolveProjectedTarget(hero);
      expect(projected, isNotNull);
      expect(projected!.isPlayer, isFalse);
    });

    test('Live combat tick progression deals damage and updates boss HP / stagger', () {
      engine.isPreBattlePhase = false;
      final gorgoroth = engine.enemyUnits.firstWhere((u) => u.id == 'gorgoroth_boss');
      final initialHp = gorgoroth.hp;

      for (int i = 0; i < 200; i++) {
        engine.stepTick();
      }

      expect(engine.currentTick, greaterThanOrEqualTo(200));
      expect(gorgoroth.hp, lessThan(initialHp));
    });

    test('applyDamageToTarget reduces Boss Stagger Break Bar and triggers Staggered state at 0', () {
      engine.isPreBattlePhase = false;
      final hero = engine.playerUnits.first;
      final gorgoroth = engine.enemyUnits.firstWhere((u) => u.id == 'gorgoroth_boss');
      gorgoroth.maxStagger = 100;
      gorgoroth.stagger = 20;
      gorgoroth.isStaggered = false;

      engine.applyDamageToTarget(gorgoroth, 250, attacker: hero);

      expect(gorgoroth.stagger, equals(0));
      expect(gorgoroth.isStaggered, isTrue);
    });

    test('Live movement consumes 25% AP and repositions unit on the 2D grid', () {
      engine.isPreBattlePhase = false;
      final hero = engine.playerUnits.first;
      hero.currentAp = 6000;

      final moved = engine.movePlayerUnit(hero.id, 0, 1);
      expect(moved, isTrue);
      expect(hero.occupiedNodes.first.column, equals(0));
      expect(hero.occupiedNodes.first.row, equals(1));
      expect(hero.currentAp, equals(3500));
    });

    test('Burn Pit cycling exhausts Stoke the Embers for +1 Focus and draws Smite the Calcified', () {
      final initialFocus = engine.focus;
      expect(engine.hand.any((c) => c.id == 'stoke_the_embers'), isTrue);

      final burned = engine.burnCard('stoke_the_embers');
      expect(burned, isTrue);
      expect(engine.focus, equals(initialFocus + 1));
      expect(engine.hand.any((c) => c.id == 'smite_the_calcified'), isTrue);
    });

    test('Casting Smite the Calcified on Gorgoroth shatters Slag Carapace and reduces armor', () {
      engine.isPreBattlePhase = false;
      engine.burnCard('stoke_the_embers');
      expect(engine.focus, greaterThanOrEqualTo(4));

      final gorgoroth = engine.enemyUnits.firstWhere((u) => u.id == 'gorgoroth_boss');
      expect(gorgoroth.isSlagCarapaceActive, isTrue);
      final initialArmor = gorgoroth.armor;

      final cast = engine.castCard('smite_the_calcified');
      expect(cast, isTrue);
      expect(gorgoroth.isSlagCarapaceActive, isFalse);
      expect(gorgoroth.armor, lessThan(initialArmor));
    });

    test('claimVictoryRewards is idempotent and awards +1 Skill Point once', () {
      for (final e in engine.enemyUnits) {
        e.hp = 0;
      }
      expect(engine.isVictory, isTrue);
      final beforePoints = engine.skillTreeState.availableSkillPoints;

      engine.claimVictoryRewards();
      engine.claimVictoryRewards(); // Second call must be a no-op

      expect(engine.hasClaimedEncounterVictoryLoot, isTrue);
      expect(engine.skillTreeState.availableSkillPoints, equals(beforePoints + 1));
    });

    test('Custom campaign encounter preserves Ash Sculptor + companion and enemy wave', () {
      const protagonist = UnitEntity(
        id: 'ash_sculptor',
        name: 'The Ash Sculptor',
        speciesId: 'ash_sculptor',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 5,
        maxLevel: 20,
        currentHp: 900,
        maxHp: 900,
        attack: 85,
        defense: 45,
        speed: 55,
        nativeTraitId: 'ash_sculptor_core',
        lineageAncestors: [],
      );
      const companion = UnitEntity(
        id: 'iron_footman_1',
        name: 'Iron Footman',
        speciesId: 'iron_footman',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front2,
        level: 4,
        maxLevel: 20,
        currentHp: 650,
        maxHp: 650,
        attack: 60,
        defense: 40,
        speed: 50,
        nativeTraitId: 'iron_bastion',
        lineageAncestors: [],
      );
      const enemy = UnitEntity(
        id: 'enemy_1',
        name: 'Ash Raider',
        speciesId: 'ash_raider',
        generation: 1,
        archetype: Archetype.skirmisher,
        slot: FormationSlot.front1,
        level: 3,
        maxLevel: 20,
        currentHp: 450,
        maxHp: 450,
        attack: 45,
        defense: 20,
        speed: 48,
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      final customEngine = SpatialCombatEngine(
        initialPlayerEntities: const [protagonist, companion],
        initialEnemyEntities: const [enemy],
      );

      expect(customEngine.playerUnits.length, equals(2));
      expect(customEngine.playerUnits.any((u) => u.id == 'iron_footman_1'), isTrue);
      expect(customEngine.enemyUnits.length, equals(1));
      expect(customEngine.enemyUnits.first.name, equals('Ash Raider'));
    });

    test('Companion Retinue Passives, Signature Skills, and row-independent kits work across rows', () {
      const protagonist = UnitEntity(
        id: 'ash_sculptor',
        name: 'The Ash Sculptor',
        speciesId: 'ash_sculptor',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 5,
        maxLevel: 20,
        currentHp: 900,
        maxHp: 900,
        attack: 85,
        defense: 45,
        speed: 55,
        nativeTraitId: 'ash_sculptor_core',
        lineageAncestors: [],
      );
      const footman = UnitEntity(
        id: 'iron_footman_1',
        name: 'Iron Footman',
        speciesId: 'iron_footman',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.back1,
        level: 5,
        maxLevel: 20,
        currentHp: 680,
        maxHp: 680,
        attack: 65,
        defense: 40,
        speed: 50,
        nativeTraitId: 'iron_bastion',
        lineageAncestors: [],
      );
      const cleric = UnitEntity(
        id: 'cleric_1',
        name: 'Sun-Scorched Cleric',
        speciesId: 'sun_scorched_cleric',
        generation: 1,
        archetype: Archetype.support,
        slot: FormationSlot.front2,
        level: 5,
        maxLevel: 20,
        currentHp: 520,
        maxHp: 520,
        attack: 55,
        defense: 25,
        speed: 52,
        nativeTraitId: 'sanctified_censer',
        lineageAncestors: [],
      );
      const enemy = UnitEntity(
        id: 'enemy_1',
        name: 'Ash Raider',
        speciesId: 'ash_raider',
        generation: 1,
        archetype: Archetype.skirmisher,
        slot: FormationSlot.front1,
        level: 5,
        maxLevel: 20,
        currentHp: 1200,
        maxHp: 1200,
        attack: 50,
        defense: 30,
        speed: 45,
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      final customEngine = SpatialCombatEngine(
        initialPlayerEntities: const [protagonist, footman, cleric],
        initialEnemyEntities: const [enemy],
      );
      customEngine.isPreBattlePhase = false;

      expect(customEngine.isBulwarkOathActive, isTrue);
      expect(customEngine.isAuraOfVitalityActive, isTrue);
      expect(customEngine.activeRetinuePassiveLabels, containsAll(['BULWARK OATH', 'SANCTIFIED CENSER']));

      final footmanState = customEngine.playerUnits.firstWhere((u) => u.id == 'iron_footman_1');
      final raiderState = customEngine.enemyUnits.first;
      expect(footmanState.retinuePassiveName, equals('Bulwark Oath'));
      expect(footmanState.signatureSkillName, equals('Concussive Shield Bash'));

      // Place Footman in Backline (row 2): should still execute full Signature & basic damage (no 0-DMG Braced Bulwark)
      footmanState.occupiedNodes = [const GridNode(column: 0, row: 2, occupantUnitId: 'iron_footman_1')];
      expect(footmanState.isSignatureReady, isTrue);

      final hpBeforeSig = raiderState.hp;
      customEngine.executeCompanionSignature('iron_footman_1');
      expect(raiderState.hp, lessThan(hpBeforeSig));
      expect(raiderState.stunDuration, greaterThan(0));
      expect(footmanState.signatureCooldown, equals(3));

      // Ordering again while on cooldown is a safe no-op
      final hpDuringCd = raiderState.hp;
      customEngine.executeCompanionSignature('iron_footman_1');
      expect(raiderState.hp, equals(hpDuringCd));

      // Basic attack from Backline deals real damage and ticks down signatureCooldown
      customEngine.executeUnitAction(footmanState, actionType: 'basic');
      expect(raiderState.hp, lessThan(hpDuringCd));
      expect(footmanState.signatureCooldown, equals(2));
    });

    test('Stage 1-1 spawns varied new-style enemy patrol and Chapter 1 Boss uses dedicated Gorgoroth sprite', () {
      final stage1Enemies = StarterBrigades.createEnemiesForStage(chapter: 1, stageNumber: 1);
      expect(stage1Enemies.length, equals(3));
      expect(
        stage1Enemies.map((e) => e.customAvatarAsset),
        containsAll([
          'assets/images/ashen_huskarl.png',
          'assets/images/ashfire_skirmisher.png',
          'assets/images/pyre_sentry_arbalest.png',
        ]),
      );

      final ch1BossSquad = StarterBrigades.createChapterBossEnemies(1);
      expect(ch1BossSquad.first.customAvatarAsset, equals('assets/images/gorgoroth_the_flayed.png'));
      expect(
        engine.enemyUnits.firstWhere((u) => u.id == 'gorgoroth_boss').assetPath,
        equals('assets/images/gorgoroth_the_flayed.png'),
      );
    });

    test('Blood Alchemist exposes both Sanguine (Resonance) and Miasma (AoE) paths and executes AoE Plague Nova', () {
      final enemies = StarterBrigades.createEnemiesForStage(chapter: 1, stageNumber: 1);
      final alchEngine = SpatialCombatEngine(
        initialEnemyEntities: enemies,
      );
      alchEngine.isPreBattlePhase = false;
      alchEngine.skillTreeState.configureStartingDiscipline(CrucibleSkillBranch.resonance);

      expect(alchEngine.skillTreeState.activeClass, equals(SculptorClassArchetype.bloodAlchemist));
      expect(
        alchEngine.skillTreeState.visibleBranchesForActiveClass,
        equals([CrucibleSkillBranch.resonance, CrucibleSkillBranch.miasma, CrucibleSkillBranch.apex]),
      );

      alchEngine.skillTreeState.sculptorLevel = 2;
      alchEngine.skillTreeState.availableSkillPoints = 4;
      expect(alchEngine.skillTreeState.canUpgradeSkill('miasma_plague_nova'), isTrue);
      expect(alchEngine.skillTreeState.upgradeSkill('miasma_plague_nova'), isTrue);

      final sculptor = alchEngine.playerUnits.firstWhere((u) => u.isAshSculptor);
      sculptor.crucibleCinders = 60;
      final beforeHps = alchEngine.enemyUnits.map((e) => e.hp).toList();

      alchEngine.executeUnitAction(sculptor, actionType: 'miasma_plague_nova');
      for (int i = 0; i < alchEngine.enemyUnits.length; i++) {
        expect(alchEngine.enemyUnits[i].hp, lessThan(beforeHps[i]));
        expect(alchEngine.enemyUnits[i].bleedStacks, greaterThanOrEqualTo(2));
        expect(alchEngine.enemyUnits[i].poisonStacks, greaterThanOrEqualTo(2));
      }
    });
  });
}
