import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/features/combat_spatial/models/spatial_combat_models.dart';
import 'package:ashen_crucible/features/combat_spatial/spatial_combat_engine.dart';

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

    test('Unit movement is strictly constrained by moveRange stat', () {
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
  });
}
