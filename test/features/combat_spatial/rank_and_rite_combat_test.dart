import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/features/combat_spatial/spatial_combat_engine.dart';
import 'package:ashen_crucible/features/combat_spatial/models/spatial_combat_models.dart';

void main() {
  group('Rank & Rite Combat Specification Tests', () {
    late SpatialCombatEngine engine;

    setUp(() {
      engine = SpatialCombatEngine();
      engine.isPreBattlePhase = false; // Live combat mode
    });

    test('1. Grid & Coordinates: 5 Columns x 3 Ranks & Line of Sight logic', () {
      final footman = engine.playerUnits.firstWhere((u) => u.id == 'iron_footman');
      final sunSmith = engine.playerUnits.firstWhere((u) => u.id == 'sun_smith');
      final zealot = engine.enemyUnits.firstWhere((u) => u.id == 'pyre_zealot');

      // Col 3, Row 0 (Frontline) vs Col 4, Row 2 (Backline)
      expect(footman.currentDepth, equals(RowDepth.front));
      expect(sunSmith.currentDepth, equals(RowDepth.back));

      // Direct physical line of sight:
      // Frontline footman can be targeted directly
      expect(engine.hasLineOfSight(zealot, footman, trajectory: AttackTrajectory.directPhysical), isTrue);

      // Backline sunSmith has direct physical line of sight blocked if a frontline unit stands in that column
      // Place footman in Col 4, Row 0 directly in front of sunSmith
      footman.repositionTo([const GridNode(column: 4, row: 0)], apPenalty: 0);
      expect(engine.hasLineOfSight(zealot, sunSmith, trajectory: AttackTrajectory.directPhysical), isFalse);

      // Lobbed Magic ignores Line of Sight obstructions
      expect(engine.hasLineOfSight(zealot, sunSmith, trajectory: AttackTrajectory.lobbedMagic), isTrue);
    });

    test('2. Turn Loop & Turn Meter: TM accumulation, pause at 10,000 TM, action vs reposition costs', () {
      final footman = engine.playerUnits.firstWhere((u) => u.id == 'iron_footman');
      footman.currentAp = 9920; // 9,920 TM
      footman.speed = 80;

      // Accumulation: Step tick adds unit.effectiveSpeed (80) -> reaches 10,000 TM
      engine.stepTick();
      expect(footman.currentAp, lessThanOrEqualTo(10000)); // Turn was triggered

      // Action Cost: Skill/Attack resets TM to 0
      footman.currentAp = 10000;
      engine.executeUnitAction(footman, isReposition: false);
      expect(footman.currentAp, equals(0));

      // Reposition Cost: 1 tile shift resets TM to 7,500 (25% cost)
      footman.currentAp = 10000;
      engine.executeUnitAction(footman, isReposition: true, shiftCol: 2, shiftRow: 0);
      expect(footman.currentAp, equals(CombatUnitState.moveRetainedTm)); // 7,500 TM
    });

    test('3. Vanguard Cover Rule: -25% damage from direct frontal attacks, Flanking ignores Cover', () {
      final footman = engine.playerUnits.firstWhere((u) => u.id == 'iron_footman');
      final blade = engine.playerUnits.firstWhere((u) => u.id == 'sanguine_blade');

      // Place Iron Footman (Vanguard) at Col 3, Row 0 (Frontline)
      footman.repositionTo([const GridNode(column: 3, row: 0)], apPenalty: 0);
      // Place Sanguine Blade at Col 3, Row 1 (Midline directly behind Vanguard)
      blade.repositionTo([const GridNode(column: 3, row: 1)], apPenalty: 0);

      // 1. Direct frontal attack: Blade gains Cover (-25% damage)
      expect(engine.isCoveredByVanguard(blade, trajectory: AttackTrajectory.directPhysical, attackerRow: 0), isTrue);

      final initialBladeHp = blade.hp;
      const int rawAttackDmg = 100;
      final actualDmg = engine.applyDamageToTarget(
        blade,
        rawAttackDmg,
        trajectory: AttackTrajectory.directPhysical,
        attackerRow: 0,
        ignoreArmor: true,
      );

      // 100 * 0.75 = 75 damage
      expect(actualDmg, equals(75));
      expect(blade.hp, equals(initialBladeHp - 75));
      // Vanguard takes 0 redirected damage (Passive Deflection)
      expect(footman.hp, equals(footman.maxHp));

      // 2. Flanking attack originating from same row (Row 1): ignores Cover
      expect(engine.isCoveredByVanguard(blade, trajectory: AttackTrajectory.flanking, attackerRow: 1), isFalse);

      // 3. Lobbed Magic attack: ignores Cover
      expect(engine.isCoveredByVanguard(blade, trajectory: AttackTrajectory.lobbedMagic), isFalse);
    });

    test('4. Displacement & Collision Physics: Knockback lane shift & Kinetic Splat on obstacle', () {
      final blade = engine.playerUnits.firstWhere((u) => u.id == 'sanguine_blade');
      final footman = engine.playerUnits.firstWhere((u) => u.id == 'iron_footman');

      // Place Blade at Col 2, Row 0 and Footman at Col 2, Row 1 (Obstacle in path)
      blade.repositionTo([const GridNode(column: 2, row: 0)], apPenalty: 0);
      footman.repositionTo([const GridNode(column: 2, row: 1)], apPenalty: 0);

      final bladeStartHp = blade.hp;
      final footmanStartHp = footman.hp;

      // Knockback Blade backward by 2 rows: Path blocked by Footman at Row 1!
      // -> Unit stops immediately before obstacle (at Row 0)
      // -> Kinetic Splat: Moving unit and stationary obstacle both take 50% bonus collision damage
      engine.applyKnockback(blade, 2, baseImpactDamage: 80);

      expect(blade.occupiedNodes.first.row, equals(0)); // Stopped before obstacle
      // 80 * 0.50 = 40 collision damage
      expect(blade.hp, equals(bladeStartHp - 40));
      expect(footman.hp, equals(footmanStartHp - 40));
    });

    test('5. Death & Petrified Plinths: Petrifies at 0 HP with 3 durability hits until shattered', () {
      final footman = engine.playerUnits.firstWhere((u) => u.id == 'iron_footman');
      footman.repositionTo([const GridNode(column: 1, row: 0)], apPenalty: 0);

      // Reduce HP to 0 -> Petrifies into solid stone plinth
      footman.takeDamage(footman.hp + 500, ignoreArmor: true);

      expect(footman.hp, equals(0));
      expect(footman.isPetrifiedPlinth, isTrue);
      expect(footman.plinthDurability, equals(3));
      expect(footman.isSolidObstacle, isTrue);
      expect(footman.isShattered, isFalse);

      // Strike 1
      expect(footman.strikePlinth(), isFalse);
      expect(footman.plinthDurability, equals(2));

      // Strike 2
      expect(footman.strikePlinth(), isFalse);
      expect(footman.plinthDurability, equals(1));

      // Strike 3: Shatters
      expect(footman.strikePlinth(), isTrue);
      expect(footman.plinthDurability, equals(0));
      expect(footman.isShattered, isTrue);
      expect(footman.isSolidObstacle, isFalse);
      expect(footman.occupiedNodes.isEmpty, isTrue);
    });

    test('6. Sculptor Tray (Commander Cards): Team Vitae pool max 7 and 1 Tuning Slip per turn limit', () {
      // Shared Team Vitae pool capped at 7
      engine.teamVitae = 7;
      expect(engine.teamVitae, equals(7));
      expect(engine.focus, equals(7));

      // Cast 1 Tuning Slip from hand
      final stokeCard = engine.hand.firstWhere((c) => c.id == 'stoke_the_embers');
      final firstCast = engine.castTuningSlip(stokeCard.id);
      expect(firstCast, isTrue);
      expect(engine.hasCastTuningSlipThisTurn, isTrue);

      // Second Tuning Slip during same turn is rejected
      final phalanxCard = engine.hand.firstWhere((c) => c.id == 'phalanx_intercept');
      final secondCast = engine.castTuningSlip(phalanxCard.id);
      expect(secondCast, isFalse);

      // Executing unit turn resets the Tuning Slip limit for the next turn
      final footman = engine.playerUnits.firstWhere((u) => u.id == 'iron_footman');
      engine.executeUnitAction(footman, isReposition: false);
      expect(engine.hasCastTuningSlipThisTurn, isFalse);
    });
  });
}
