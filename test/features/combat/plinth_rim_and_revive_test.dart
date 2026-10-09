import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/features/combat/plinth_rim_status_painter.dart';
import 'package:ashen_crucible/features/combat/initiative_tick_manager.dart';
import 'package:ashen_crucible/features/combat/combat_resolution_service.dart';
import 'package:ashen_crucible/features/generals/general_command_service.dart';
import 'package:ashen_crucible/shared/models/skill_entity.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';

void main() {
  group('GDD v2.6 Section 4: Procedural Compositing & Plinth Rim Status', () {
    test('UnitEntity computes bleedStacks, blightStacks, and shieldPoints properly', () {
      const unit = UnitEntity(
        id: 'ally_1',
        speciesId: 'iron_footman',
        name: 'Iron Footman',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 1,
        maxLevel: 30,
        currentHp: 1000,
        maxHp: 1000,
        attack: 100,
        defense: 100,
        speed: 90,
        nativeTraitId: 'none',
        lineageAncestors: [],
        activeEffects: [
          StatusEffect(type: StatusEffectType.bleed, durationTurns: 2, value: 3),
          StatusEffect(type: StatusEffectType.bleed, durationTurns: 1, value: 2),
          StatusEffect(type: StatusEffectType.blight, durationTurns: 3, value: 4),
          StatusEffect(type: StatusEffectType.shield, durationTurns: 2, value: 250),
        ],
      );

      expect(unit.isBleeding, isTrue);
      expect(unit.bleedStacks, equals(5));
      expect(unit.isBlighted, isTrue);
      expect(unit.blightStacks, equals(4));
      expect(unit.hasShield, isTrue);
      expect(unit.shieldPoints, equals(250));
    });

    testWidgets('PlinthRimStatusPainter paints without throwing errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 120,
                height: 18,
                child: CustomPaint(
                  key: const ValueKey('plinth_rim_painter'),
                  painter: const PlinthRimStatusPainter(
                    bleedStacks: 4,
                    blightStacks: 3,
                    shieldIntegrity: 0.60,
                    isAlive: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('plinth_rim_painter')), findsOneWidget);
    });
  });

  group('GDD v2.6 Section 3.4: Downing & Infused Vitae Revive Lifecycle', () {
    test('Revive applies stacking -20% Max HP Soul Fracture penalty, 6-tick grace, and shield overflow', () {
      const initialAlly = UnitEntity(
        id: 'fallen_footman',
        speciesId: 'iron_footman',
        name: 'Iron Footman',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 1,
        maxLevel: 30,
        currentHp: 0, // Fallen Inert Vessel
        maxHp: 1000,
        attack: 100,
        defense: 80,
        speed: 85,
        reviveCount: 0,
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      final tickManager = InitiativeTickManager(
        initialAllies: [initialAlly],
        initialEnemies: const [
          UnitEntity(
            id: 'enemy_husk',
            speciesId: 'rotting_husk',
            name: 'Rotting Husk',
            generation: 1,
            archetype: Archetype.juggernaut,
            slot: FormationSlot.front1,
            level: 1,
            maxLevel: 30,
            currentHp: 800,
            maxHp: 800,
            attack: 90,
            defense: 70,
            speed: 75,
            nativeTraitId: 'none',
            lineageAncestors: [],
          ),
        ],
      );

      final commandService = GeneralCommandService(
        tickManager: tickManager,
        maxFocus: 6,
        initialFocus: 6,
      );

      // Play Sanguine Revival
      final result = commandService.executeSanguineRevival('fallen_footman');
      expect(result.orderId, equals('sanguine_revival'));

      final revived = tickManager.allies.first;
      expect(revived.isAlive, isTrue);
      expect(revived.reviveCount, equals(1));

      // Effective max HP with 1 revive = 1000 * 0.80 = 800
      expect(revived.effectiveMaxHp, equals(800));

      // Revived unit has 6-tick invulnerability grace window
      final hasInvulnerable = revived.activeEffects.any(
        (e) => e.type == StatusEffectType.invulnerable && e.value == 6,
      );
      expect(hasInvulnerable, isTrue);

      // AP / Turn Meter reset to 0
      expect(revived.turnMeter, equals(0.0));
    });

    test('Second revive stacks Soul Fracture penalty to -36% (0.8^2 = 0.64)', () {
      final unitG1 = const UnitEntity(
        id: 'rebound_footman',
        speciesId: 'iron_footman',
        name: 'Iron Footman',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 1,
        maxLevel: 30,
        currentHp: 0,
        maxHp: 1000,
        attack: 100,
        defense: 80,
        speed: 85,
        reviveCount: 1, // Already revived once
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      final tickManager = InitiativeTickManager(
        initialAllies: [unitG1],
        initialEnemies: const [
          UnitEntity(
            id: 'enemy_1',
            speciesId: 'rotting_husk',
            name: 'Rotting Husk',
            generation: 1,
            archetype: Archetype.juggernaut,
            slot: FormationSlot.front1,
            level: 1,
            maxLevel: 30,
            currentHp: 800,
            maxHp: 800,
            attack: 90,
            defense: 70,
            speed: 75,
            nativeTraitId: 'none',
            lineageAncestors: [],
          ),
        ],
      );

      final commandService = GeneralCommandService(
        tickManager: tickManager,
        maxFocus: 6,
        initialFocus: 6,
      );
      commandService.executeSanguineRevival('rebound_footman');

      final twiceRevived = tickManager.allies.first;
      expect(twiceRevived.reviveCount, equals(2));
      expect(twiceRevived.effectiveMaxHp, equals(640)); // 1000 * 0.64 = 640
    });
  });
}
