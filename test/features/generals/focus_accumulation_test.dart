import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/features/combat/initiative_tick_manager.dart';
import 'package:ashen_crucible/features/generals/general_command_service.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';

void main() {
  group('General Command Focus Accumulation Tests', () {
    test('GeneralCommandService charges Focus every 500 damage and respects max cap of 3', () {
      const hero = UnitEntity(
        id: 'hero',
        speciesId: 'feral_hound',
        name: 'Hound',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 10,
        maxLevel: 30,
        currentHp: 800,
        maxHp: 800,
        attack: 100,
        defense: 100,
        speed: 100,
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      final tickManager = InitiativeTickManager(
        initialAllies: [hero],
        initialEnemies: [],
      );
      addTearDown(tickManager.dispose);

      final commandService = GeneralCommandService(
        tickManager: tickManager,
        generalType: GeneralType.vladislav,
        initialFocus: 0,
      );

      expect(commandService.currentFocus, 0);

      // Register 300 damage (below 500 threshold)
      commandService.registerCombatDamage(300);
      expect(commandService.currentFocus, 0);
      expect(commandService.focusChargeProgress, closeTo(300.0 / 500.0, 0.01));

      // Register another 250 damage (total 550 -> 1 Focus point, 50 rollover)
      commandService.registerCombatDamage(250);
      expect(commandService.currentFocus, 1);
      expect(commandService.focusChargeProgress, closeTo(50.0 / 500.0, 0.01));

      // Register 1000 damage -> adds 2 Focus points -> reaches max cap 3
      commandService.registerCombatDamage(1000);
      expect(commandService.currentFocus, 3);
      expect(commandService.isFocusMaxed, isTrue);

      // Extra damage beyond cap does not exceed max cap
      commandService.registerCombatDamage(500);
      expect(commandService.currentFocus, 3);
    });
  });
}
