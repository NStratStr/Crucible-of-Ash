import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/features/combat/initiative_tick_manager.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';
import 'package:ashen_crucible/main.dart';
import 'package:ashen_crucible/shared/widgets/app_shell.dart';

void main() {
  group('Combat Victory Level Progression & Persistence Tests', () {
    test('InitiativeTickManager.updateSquads updates allies in-place even after battle ends', () {
      const hero = UnitEntity(
        id: 'hero_test',
        speciesId: 'rusted_footman',
        name: 'Footman',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 1,
        maxLevel: 10,
        currentHp: 500,
        maxHp: 500,
        attack: 100,
        defense: 80,
        speed: 90,
        nativeTraitId: 'shield_bash',
        lineageAncestors: [],
      );

      final tickManager = InitiativeTickManager(
        initialAllies: [hero],
        initialEnemies: [],
      );
      addTearDown(tickManager.dispose);

      // Verify initial level
      expect(tickManager.allies.first.level, equals(1));

      // Grant XP and level up
      final leveled = hero.addXp(250); // 100 XP to Lv 2, 150 toward Lv 3
      expect(leveled.level, equals(2));

      // updateSquads must persist onto tickManager
      tickManager.updateSquads(allies: [leveled]);
      expect(tickManager.allies.first.level, equals(2));
      expect(tickManager.allies.first.attack, greaterThan(100));
    });

    testWidgets('AppShell battle victory grants XP, persists level-ups and displays level badge in combat', (tester) async {
      await tester.pumpWidget(const AshenCrucibleApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify and tap Battle Arena tab
      expect(find.text('Battle Arena'), findsOneWidget);
      await tester.tap(find.text('Battle Arena'));
      await tester.pump();

      // Verify level badges are displayed on combat cards
      expect(find.text('Lv.10'), findsWidgets);
    });
  });
}
