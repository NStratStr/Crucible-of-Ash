import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/features/combat_spatial/models/spatial_combat_models.dart';
import 'package:ashen_crucible/features/combat_spatial/spatial_combat_engine.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';
import 'package:ashen_crucible/core/combat_math.dart';

void main() {
  group('GDD v3.2 Spatial Combat Engine & Encounter Tests', () {
    late SpatialCombatEngine engine;

    setUp(() {
      engine = SpatialCombatEngine();
    });

    test('Initializes "The Sunder at Ashen Gate" with multi-node behemoth and player squad', () {
      expect(engine.enemyUnits.length, equals(3));
      expect(engine.playerUnits.length, equals(4));

      final gorgoroth = engine.enemyUnits.firstWhere((u) => u.id == 'gorgoroth_boss');
      expect(gorgoroth.footprint, equals(UnitFootprint.quadColossus2x2));
      expect(gorgoroth.isDisplacementImmune, isTrue);
      expect(gorgoroth.occupiedNodes.length, equals(4));
      expect(gorgoroth.isSlagCarapaceActive, isTrue);

      final valeria = engine.playerUnits.firstWhere((u) => u.id == 'lady_valeria');
      expect(valeria.occupiedNodes.first.column, equals(1)); // Col 2 (0-indexed 1)
      expect(valeria.occupiedNodes.first.row, equals(0)); // Frontline
    });

    test('Tick progression executes Pyre Zealot strike on Backline Sun-Smith and Sanguine Blade bleed on Gorgoroth', () {
      // Step until tick 145 (Zealot winds up at 80, executes at 140; Sanguine Blade hits at 83)
      while (engine.currentTick < 145) {
        engine.stepTick();
      }

      final sunSmith = engine.playerUnits.firstWhere((u) => u.id == 'sun_smith');
      expect(sunSmith.hp, lessThan(280)); // Pyre Zealot 2s telegraphed hit

      final gorgoroth = engine.enemyUnits.firstWhere((u) => u.id == 'gorgoroth_boss');
      expect(gorgoroth.bleedStacks, equals(2)); // Sanguine Blade Flensing Thrust
      expect(gorgoroth.hp, lessThan(2400));
    });

    test('Tick 135 telegraphs Gorgoroth Molten Great-Cleaver and dodging avoids damage', () {
      // Step to Tick 135
      while (engine.currentTick < 135) {
        engine.stepTick();
      }

      final gorgoroth = engine.enemyUnits.firstWhere((u) => u.id == 'gorgoroth_boss');
      expect(gorgoroth.pendingIntent, isNotNull);
      expect(gorgoroth.pendingIntent!.skillName, equals('Molten Great-Cleaver'));

      // Player Reposition Triage: Shift Lady Valeria from Col 2 (index 1) to Col 1 (index 0)
      // Valeria speed = 85. At tick 135, her accumulated AP = 135 * 85 = 11,475 AP % 10000 = 1475 AP.
      // Granting 5,000 AP so she satisfies the 50% AP movement cost
      final valeria = engine.playerUnits.firstWhere((u) => u.id == 'lady_valeria');
      valeria.currentAp = 5000;
      final moved = engine.movePlayerUnit('lady_valeria', 0, 0);
      expect(moved, isTrue);
      expect(valeria.occupiedNodes.first.column, equals(0));

      final hpBeforeCleave = valeria.hp;

      // Step past Tick 150 (Cleave execution tick)
      while (engine.currentTick < 155) {
        engine.stepTick();
      }

      // Cleave dealt 280 raw damage. Valeria dodging means she avoided the 280 lethal cleave!
      final cleaveDamageTaken = hpBeforeCleave - valeria.hp;
      expect(cleaveDamageTaken, lessThan(200)); // Cleave was completely avoided
    });

    test('Burn Pit cycling exhausts Stoke the Embers for +1 Focus and draws Smite the Calcified', () {
      final initialFocus = engine.focus;
      expect(engine.hand.any((c) => c.id == 'stoke_the_embers'), isTrue);

      final burned = engine.burnCard('stoke_the_embers');
      expect(burned, isTrue);
      expect(engine.focus, equals(initialFocus + 1));
      expect(engine.hand.any((c) => c.id == 'smite_the_calcified'), isTrue);
    });

    test('Casting Smite the Calcified on Gorgoroth shatters Slag Carapace and halves armor', () {
      // Ensure we have Smite and 4 Focus
      engine.burnCard('stoke_the_embers'); // Focus: 3 -> 4, draws Smite the Calcified
      expect(engine.focus, equals(4));

      final gorgoroth = engine.enemyUnits.firstWhere((u) => u.id == 'gorgoroth_boss');
      expect(gorgoroth.isSlagCarapaceActive, isTrue);
      expect(gorgoroth.armor, equals(75));

      final cast = engine.castCard('smite_the_calcified');
      expect(cast, isTrue);
      expect(gorgoroth.isSlagCarapaceActive, isFalse);
      expect(gorgoroth.armor, lessThan(40)); // Halved to ~37
      expect(engine.activeActionEvent, isNotNull);
      expect(engine.activeActionEvent!.skillName, equals('Smite the Calcified'));
    });

    test('Pre-battle deployment phase allows free repositioning with 0 AP cost', () {
      expect(engine.isPreBattlePhase, isTrue);
      final valeria = engine.playerUnits.firstWhere((u) => u.id == 'lady_valeria');
      valeria.currentAp = 0; // 0 AP
      // In pre-battle, can move anywhere on player squad grid for 0 AP
      final success = engine.movePlayerUnit('lady_valeria', 3, 2);
      expect(success, isTrue);
      expect(valeria.occupiedNodes.first.column, equals(3));
      expect(valeria.occupiedNodes.first.row, equals(2));
      expect(valeria.currentAp, equals(0)); // 0 AP cost

      // Projected basic attack target is resolved
      final projected = engine.resolveProjectedTarget(valeria);
      expect(projected, isNotNull);
      expect(projected!.isPlayer, isFalse);
    });

    test('Unit movement is strictly constrained by moveRange stat in live combat', () {
      engine.startBattle();
      expect(engine.isPreBattlePhase, isFalse);
      expect(engine.isRunning, isTrue);

      final valeria = engine.playerUnits.firstWhere((u) => u.id == 'lady_valeria');
      expect(valeria.moveRange, equals(1));
      expect(valeria.occupiedNodes.first.column, equals(1)); // Col 2, Row 0

      // Rejects move exceeding range: moving from Col 2, Row 0 to Col 4, Row 2 (distance = 2)
      valeria.currentAp = 6000; // Has sufficient AP (>= 5,000 / 50%)
      final invalidMove = engine.movePlayerUnit('lady_valeria', 3, 2);
      expect(invalidMove, isFalse);
      expect(valeria.occupiedNodes.first.column, equals(1)); // Remained at original tile

      // Accepts move within range: moving from Col 2, Row 0 to Col 1, Row 0 (distance = 1)
      final validMove = engine.movePlayerUnit('lady_valeria', 0, 0);
      expect(validMove, isTrue);
      expect(valeria.occupiedNodes.first.column, equals(0));
      expect(valeria.currentAp, equals(1000)); // 6000 - 5000 (50% AP cost) = 1000 AP
    });

    test('Adaptive Posture System: Vanguard in Midline performs Shockwave Tremor and advances forward', () {
      final footman = engine.playerUnits.firstWhere((u) => u.id == 'iron_footman');
      // Shift Footman to Midline (Col 2, Row 1)
      footman.occupiedNodes.clear();
      footman.occupiedNodes.add(const GridNode(column: 1, row: 1, occupantUnitId: 'iron_footman'));
      expect(footman.currentDepth, equals(RowDepth.mid));
      expect(footman.postureLabel, contains('Advancing Stride'));

      // Ensure Row 0 in Col 2 (index 1) is empty for automated advance
      engine.playerUnits.removeWhere((u) => u.id == 'lady_valeria'); // Clear row 0 in Col 2

      final gorgoroth = engine.enemyUnits.firstWhere((u) => u.id == 'gorgoroth_boss');
      final initialArmor = gorgoroth.armor;

      // Give Footman 10,000 AP to trigger action
      footman.currentAp = SpatialCombatEngine.tickThreshold;
      engine.stepTick();

      // Verify Shockwave dealt 60% DMG (55 * 0.60 = 33) and chipped 15 armor
      expect(gorgoroth.armor, equals(initialArmor - 15));
      // Verify Footman stepped forward into vacant Frontline (Row 0)
      expect(footman.occupiedNodes.first.row, equals(0));
      expect(footman.currentDepth, equals(RowDepth.front));
    });

    test('Adaptive Posture System: Vanguard knocked to Backline casts Braced Bulwark and fills Ultimate gauge', () {
      final footman = engine.playerUnits.firstWhere((u) => u.id == 'iron_footman');
      final valeria = engine.playerUnits.firstWhere((u) => u.id == 'lady_valeria');

      // Place Valeria at Frontline Col 2 (Row 0) and Footman at Backline Col 2 (Row 2)
      valeria.occupiedNodes.clear();
      valeria.occupiedNodes.add(const GridNode(column: 1, row: 0, occupantUnitId: 'lady_valeria'));
      footman.occupiedNodes.clear();
      footman.occupiedNodes.add(const GridNode(column: 1, row: 2, occupantUnitId: 'iron_footman'));

      expect(footman.currentDepth, equals(RowDepth.back));
      expect(footman.postureLabel, contains('Braced Bulwark'));

      final initialValeriaArmor = valeria.armor;
      final initialValeriaAegis = valeria.aegisShield;
      expect(footman.ultimateGauge, equals(0));

      // Trigger Footman turn
      footman.currentAp = SpatialCombatEngine.tickThreshold;
      engine.stepTick();

      // Valeria gains +25 Armor & +30 Aegis Shield
      expect(valeria.armor, equals(initialValeriaArmor + 25));
      expect(valeria.aegisShield, equals(initialValeriaAegis + 30));
      // Footman gains +20% Ultimate gauge
      expect(footman.ultimateGauge, equals(20));
    });

    test('Adaptive Posture System: Displaced Caster in Frontline fires Point-Blank Panic Discharge', () {
      final sunSmith = engine.playerUnits.firstWhere((u) => u.id == 'sun_smith');
      // Drag Sun-Smith into Frontline (Col 2, Row 0) facing Gorgoroth
      sunSmith.occupiedNodes.clear();
      sunSmith.occupiedNodes.add(const GridNode(column: 1, row: 0, occupantUnitId: 'sun_smith'));

      expect(sunSmith.currentDepth, equals(RowDepth.front));
      expect(sunSmith.postureLabel, contains('Point-Blank Panic'));

      sunSmith.currentAp = SpatialCombatEngine.tickThreshold;
      engine.stepTick();

      expect(engine.activeActionEvent, isNotNull);
      expect(engine.activeActionEvent!.skillName, equals('Panic Discharge'));
    });

    test('Unit Combat Triad: Hold the Line triggers lateral cleave and resets enemy AP after 2 cycles stationary', () {
      final valeria = engine.playerUnits.firstWhere((u) => u.id == 'lady_valeria');
      expect(valeria.activeStance, equals(StanceType.holdTheLine));

      // Turn 1 stationary on Frontline
      valeria.currentAp = SpatialCombatEngine.tickThreshold;
      engine.stepTick();
      expect(valeria.consecutiveTurnsStationary, equals(1));
      expect(valeria.hasStanceBonusReady, isFalse);

      // Turn 2 stationary on Frontline -> triggers Hold the Line
      valeria.currentAp = SpatialCombatEngine.tickThreshold;
      engine.stepTick();
      expect(valeria.consecutiveTurnsStationary, equals(2));

      final gorgoroth = engine.enemyUnits.firstWhere((u) => u.id == 'gorgoroth_boss');
      gorgoroth.currentAp = 4000;

      // Turn 3: Unleashes Solar Sunder Cleave with AP reset (-1,500 AP)
      // Note: stepTick also accumulates Gorgoroth speed (+70 AP), so net is 4000 + 70 - 1500 = 2570
      valeria.currentAp = SpatialCombatEngine.tickThreshold;
      engine.stepTick();
      expect(gorgoroth.currentAp, equals(2570)); // 4000 + 70 speed - 1500 AP reset = 2570
    });

    test('Unit Combat Triad: Sanguine Blade Flanking Momentum grants Crit and refunds 3,000 AP on bleeding target', () {
      final sanguine = engine.playerUnits.firstWhere((u) => u.id == 'sanguine_blade');
      final gorgoroth = engine.enemyUnits.firstWhere((u) => u.id == 'gorgoroth_boss');
      gorgoroth.bleedStacks = 2; // Target has bleed

      sanguine.currentAp = SpatialCombatEngine.tickThreshold;
      engine.stepTick();

      // Flanking Momentum refunds 3,000 AP
      expect(sanguine.currentAp, greaterThanOrEqualTo(3000));
      expect(gorgoroth.bleedStacks, greaterThanOrEqualTo(4)); // Added 4 stacks
    });

    test('Unit Combat Triad: Manual Ultimate Burst execution consumes meter and shatters defenses', () {
      final valeria = engine.playerUnits.firstWhere((u) => u.id == 'lady_valeria');
      final gorgoroth = engine.enemyUnits.firstWhere((u) => u.id == 'gorgoroth_boss');
      expect(gorgoroth.isSlagCarapaceActive, isTrue);

      valeria.ultimateGauge = 100;
      expect(valeria.isUltimateReady, isTrue);

      final castSuccess = engine.castUltimate('lady_valeria', targetCol: 1);
      expect(castSuccess, isTrue);
      expect(valeria.ultimateGauge, equals(0)); // Meter consumed
      expect(gorgoroth.isSlagCarapaceActive, isFalse); // Carapace shattered by Wrath of Dawnbound
      expect(engine.activeActionEvent?.skillName, equals('Wrath of the Dawnbound'));
    });

    test('Tactical Formation Swap: Swaps two friendly units for 0 AP in Pre-Battle and 50% AP in Live Combat', () {
      expect(engine.isPreBattlePhase, isTrue);
      final valeria = engine.playerUnits.firstWhere((u) => u.id == 'lady_valeria'); // Col 1, Row 0
      final footman = engine.playerUnits.firstWhere((u) => u.id == 'iron_footman'); // Col 3, Row 0
      final sanguine = engine.playerUnits.firstWhere((u) => u.id == 'sanguine_blade'); // Col 3, Row 1

      // Pre-Battle Swap across columns (0 AP)
      final preBattleSwap = engine.movePlayerUnit('lady_valeria', 3, 0);
      expect(preBattleSwap, isTrue);
      expect(valeria.occupiedNodes.first.column, equals(3));
      expect(footman.occupiedNodes.first.column, equals(1));

      // Live Combat Swap (requires 50% AP and within moveRange = 1)
      // Valeria is now at (Col 3, Row 0) and Sanguine Blade is at (Col 3, Row 1)
      engine.startBattle();
      valeria.currentAp = 6000;
      final liveSwap = engine.movePlayerUnit('lady_valeria', 3, 1);
      expect(liveSwap, isTrue);
      expect(valeria.occupiedNodes.first.row, equals(1));
      expect(sanguine.occupiedNodes.first.row, equals(0));
      expect(valeria.currentAp, equals(1000)); // 6000 - 5000 = 1000 AP
    });

    test('Multi-Target Trajectory Projection: Resolves secondary cleave targets when Hold the Line is active', () {
      final footman = engine.playerUnits.firstWhere((u) => u.id == 'iron_footman');
      // Place Footman at Col 0, Row 0 (adjacent to Gorgoroth at Col 1, Row 0)
      footman.occupiedNodes.clear();
      footman.occupiedNodes.add(const GridNode(column: 0, row: 0, occupantUnitId: 'iron_footman'));
      footman.consecutiveTurnsStationary = 2; // Hold the Line active!

      final secondaryTargets = engine.resolveSecondaryProjectedTargets(footman);
      expect(secondaryTargets, isNotEmpty);
      expect(secondaryTargets.any((t) => t.id == 'gorgoroth_boss'), isTrue);
    });

    test('Inert Vessel Downed State: Unit converts to 0 HP inert vessel, AP freezes, and blocks direct walk', () {
      final footman = engine.playerUnits.firstWhere((u) => u.id == 'iron_footman');
      footman.currentAp = 4000;
      footman.takeDamage(1000, ignoreArmor: true); // Lethal damage

      expect(footman.hp, equals(0));
      expect(footman.isDowned, isTrue);
      expect(footman.currentAp, equals(0)); // AP frozen/cleared

      // Moving another friendly unit directly onto an inert vessel is blocked
      final valeria = engine.playerUnits.firstWhere((u) => u.id == 'lady_valeria');
      valeria.currentAp = 6000;
      // Valeria is at (Col 1, Row 0), Footman is at (Col 3, Row 0)
      // Moving to Footman's tile fails because tile has an Inert Vessel
      final walkBlocked = engine.movePlayerUnit('lady_valeria', 3, 0);
      expect(walkBlocked, isFalse);
    });

    test('Severed Resonance: Commander in Downed State throttles Focus accumulation by 50%', () {
      final valeria = engine.playerUnits.firstWhere((u) => u.id == 'lady_valeria');
      // Freeze unit turns so only passive tick accumulation is tested
      for (final u in engine.playerUnits) {
        u.speed = 0;
      }
      engine.focus = 2;

      // When Valeria is alive, focus generates every 40 ticks
      while (engine.currentTick < 40) {
        engine.stepTick();
      }
      expect(engine.focus, equals(3)); // 2 -> 3 at tick 40

      // Now down Valeria
      valeria.takeDamage(2000, ignoreArmor: true);
      expect(valeria.isDowned, isTrue);

      // Throttled to 80 ticks (50% slower generation)
      // At tick 80: 80 % 80 == 0 -> generates 1 Focus (focus becomes 4)
      while (engine.currentTick < 80) {
        engine.stepTick();
      }
      expect(engine.focus, equals(4));

      // At tick 120 (40 ticks later): 120 % 80 != 0 -> no focus generated! Still 4.
      while (engine.currentTick < 120) {
        engine.stepTick();
      }
      expect(engine.focus, equals(4)); // Throttled! Would have been 5 if alive.

      // At tick 160 (80 ticks since tick 80): 160 % 80 == 0 -> focus becomes 5.
      while (engine.currentTick < 160) {
        engine.stepTick();
      }
      expect(engine.focus, equals(5));
    });

    test('Infused Vitae Revive Mechanics: Revives downed unit, applies Soul Fracture, and grants 6-tick invulnerability', () {
      final footman = engine.playerUnits.firstWhere((u) => u.id == 'iron_footman');
      final originalMaxHp = footman.maxHp;
      footman.takeDamage(1000, ignoreArmor: true); // Downed
      expect(footman.isDowned, isTrue);

      // Put Revive Vitae in hand if in drawPile
      if (!engine.hand.any((c) => c.id == 'revive_vitae')) {
        final reviveCard = engine.drawPile.firstWhere((c) => c.id == 'revive_vitae');
        engine.drawPile.remove(reviveCard);
        engine.hand.add(reviveCard);
      }

      engine.focus = 3;
      final castSuccess = engine.castCard('revive_vitae', targetUnit: footman);
      expect(castSuccess, isTrue);

      expect(footman.isAlive, isTrue);
      expect(footman.reviveCount, equals(1));
      expect(footman.maxHp, equals((originalMaxHp * 0.80).round())); // -20% Soul Fracture
      expect(footman.currentAp, equals(0));
      expect(footman.invulnerabilityTicks, equals(6));
      expect(footman.isInvulnerable, isTrue);

      // Invulnerable unit takes 0 damage
      final hpBefore = footman.hp;
      footman.takeDamage(100);
      expect(footman.hp, equals(hpBefore));

      // After 6 ticks, invulnerability expires
      for (int i = 0; i < 6; i++) {
        engine.stepTick();
      }
      expect(footman.invulnerabilityTicks, equals(0));
      expect(footman.isInvulnerable, isFalse);
    });

    test('Status Effect Matrix: Poison deals true damage, decays Attack and Speed by 2% per stack', () {
      final footman = engine.playerUnits.firstWhere((u) => u.id == 'iron_footman');
      final baseAtk = footman.attack;
      final baseSpd = footman.speed;

      footman.poisonStacks = 5; // 5 stacks = 10% ATK & SPD penalty
      expect(footman.effectiveAttack, equals((baseAtk * 0.90).round()));
      expect(footman.effectiveSpeed, equals((baseSpd * 0.90).round()));

      final hpBefore = footman.hp;
      // Step 30 ticks (1 second) to trigger Poison DoT
      for (int i = 0; i < 30; i++) {
        engine.stepTick();
      }
      // 5 stacks * 14 = 70 true damage (ignoring armor)
      expect(footman.hp, equals(hpBefore - 70));
    });

    test('Status Effect Matrix: Freeze pauses AP, and physical strike shatters for 15% Max HP bonus damage', () {
      final footman = engine.playerUnits.firstWhere((u) => u.id == 'iron_footman');
      footman.freezeDuration = 90; // 3 seconds freeze
      expect(footman.isFrozen, isTrue);

      final initialAp = footman.currentAp;
      // Step 1 tick: AP does not accumulate while frozen
      engine.stepTick();
      expect(footman.currentAp, equals(initialAp));

      // Physical hit shatters freeze for 15% Max HP bonus
      footman.armor = 0; // Pure damage comparison
      final hpBefore = footman.hp;
      final dealt = footman.takeDamage(100, isPhysical: true);
      expect(footman.isFrozen, isFalse); // Shattered!
      expect(dealt, equals(100 + (footman.maxHp * 0.15).round())); // 100 base + 68 shatter = 168
      expect(footman.hp, equals(hpBefore - dealt));
    });

    test('Status Effect Matrix: Vulnerable amplifies incoming damage by 25%', () {
      final footman = engine.playerUnits.firstWhere((u) => u.id == 'iron_footman');
      footman.armor = 0; // Remove armor reduction to test pure multiplier

      final normalDmg = footman.takeDamage(100);
      expect(normalDmg, equals(100));

      footman.vulnerableDuration = 90; // 3 seconds vulnerable
      expect(footman.isVulnerable, isTrue);
      final vulnDmg = footman.takeDamage(100);
      expect(vulnDmg, equals(125)); // +25% amplified damage
    });

    test('setupCampaignEncounter correctly maps UnitEntity cohorts for Skirmish and Boss encounters', () {
      final customEngine = SpatialCombatEngine();

      final playerCohort = [
        const UnitEntity(
          id: 'test_player_vanguard',
          speciesId: 'iron_legionary',
          name: 'Front Vanguard',
          generation: 1,
          archetype: Archetype.juggernaut,
          slot: FormationSlot.front2,
          level: 5,
          maxLevel: 20,
          currentHp: 600,
          maxHp: 600,
          attack: 45,
          defense: 120,
          speed: 80,
          nativeTraitId: 'iron_clad',
          lineageAncestors: [],
        ),
        const UnitEntity(
          id: 'test_player_caster',
          speciesId: 'blood_witch',
          name: 'Back Caster',
          generation: 1,
          archetype: Archetype.occultist,
          slot: FormationSlot.back1,
          level: 5,
          maxLevel: 20,
          currentHp: 320,
          maxHp: 320,
          attack: 75,
          defense: 30,
          speed: 95,
          nativeTraitId: 'blood_boil',
          lineageAncestors: [],
        ),
      ];

      final skirmishEnemies = [
        const UnitEntity(
          id: 'enemy_ghoul',
          speciesId: 'ash_ghoul',
          name: 'Ash Ghoul',
          generation: 1,
          archetype: Archetype.assassin,
          slot: FormationSlot.front1,
          level: 4,
          maxLevel: 20,
          currentHp: 280,
          maxHp: 280,
          attack: 38,
          defense: 40,
          speed: 90,
          nativeTraitId: 'feral',
          lineageAncestors: [],
        ),
      ];

      // 1. Skirmish Encounter setup
      customEngine.setupCampaignEncounter(
        playerEntities: playerCohort,
        enemyEntities: skirmishEnemies,
        isBoss: false,
        title: 'Ashen Wastes Skirmish',
        description: 'Vile scavengers prowl the volcanic ridge.',
      );

      expect(customEngine.encounterTitle, equals('Ashen Wastes Skirmish'));
      expect(customEngine.playerUnits.length, equals(2));
      expect(customEngine.enemyUnits.length, equals(1));
      expect(customEngine.playerUnits.first.archetype, equals(UnitArchetype.vanguardMelee));
      expect(customEngine.playerUnits.last.archetype, equals(UnitArchetype.backlineCaster));

      // 2. Boss Encounter setup with 2x2 Colossus
      final bossEnemies = [
        const UnitEntity(
          id: 'boss_behemoth',
          speciesId: 'gorgoroth_titan',
          name: 'Gorgoroth the Unbroken',
          generation: 4,
          archetype: Archetype.juggernaut,
          slot: FormationSlot.front2,
          level: 10,
          maxLevel: 20,
          currentHp: 3500,
          maxHp: 3500,
          attack: 95,
          defense: 200,
          speed: 70,
          nativeTraitId: 'unyielding',
          lineageAncestors: [],
        ),
        const UnitEntity(
          id: 'boss_flank_minion',
          speciesId: 'pyre_acolyte',
          name: 'Pyre Acolyte',
          generation: 1,
          archetype: Archetype.support,
          slot: FormationSlot.back2,
          level: 8,
          maxLevel: 20,
          currentHp: 300,
          maxHp: 300,
          attack: 30,
          defense: 25,
          speed: 85,
          nativeTraitId: 'pyre_aura',
          lineageAncestors: [],
        ),
      ];

      customEngine.setupCampaignEncounter(
        playerEntities: playerCohort,
        enemyEntities: bossEnemies,
        isBoss: true,
        title: 'Chamber of the Titan',
      );

      expect(customEngine.enemyUnits.length, equals(2));
      final boss = customEngine.enemyUnits.firstWhere((u) => u.id == 'boss_behemoth');
      expect(boss.footprint, equals(UnitFootprint.quadColossus2x2));
      expect(boss.isDisplacementImmune, isTrue);
      expect(boss.occupiedNodes.length, equals(4));
      expect(boss.occupiedNodes.any((n) => n.column == 1 && n.row == 0), isTrue);
      expect(boss.occupiedNodes.any((n) => n.column == 2 && n.row == 1), isTrue);

      final minion = customEngine.enemyUnits.firstWhere((u) => u.id == 'boss_flank_minion');
      expect(minion.footprint, equals(UnitFootprint.single1x1));
      expect(minion.occupiedNodes.first.column, equals(0)); // First flank minion placed on Col 0
    });
  });
}


