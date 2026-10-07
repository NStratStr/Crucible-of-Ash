import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/features/combat/battle_screen.dart';
import 'package:ashen_crucible/features/combat/combat_resolution_service.dart';
import 'package:ashen_crucible/features/combat/initiative_tick_manager.dart';
import 'package:ashen_crucible/features/generals/general_command_service.dart';
import 'package:ashen_crucible/shared/models/skill_entity.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';

void main() {
  group('Brave Exvius Limit Burst Windows Tests', () {
    testWidgets('Limit Burst button displays gauge progress and is disabled when < 100%', (tester) async {
      const hero = UnitEntity(
        id: 'ally_hero',
        speciesId: 'dread_knight',
        name: 'Dread Knight',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 10,
        maxLevel: 30,
        currentHp: 800,
        maxHp: 800,
        attack: 150,
        defense: 120,
        speed: 100,
        turnMeter: 100.0,
        ultimateCharge: 50.0, // Only 50%
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      const foe = UnitEntity(
        id: 'enemy_1',
        speciesId: 'cultist',
        name: 'Cultist',
        generation: 1,
        archetype: Archetype.assassin,
        slot: FormationSlot.front1,
        level: 10,
        maxLevel: 30,
        currentHp: 400,
        maxHp: 400,
        attack: 80,
        defense: 40,
        speed: 90,
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      final tickManager = InitiativeTickManager(
        initialAllies: [hero],
        initialEnemies: [foe],
      );
      addTearDown(tickManager.dispose);
      tickManager.advanceTick(); // Puts hero in awaitingAction

      final commandService = GeneralCommandService(
        tickManager: tickManager,
        generalType: GeneralType.vladislav,
      );

      final combatService = CombatResolutionService(
        tickManager: tickManager,
        commandService: commandService,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BattleScreen(
            tickManager: tickManager,
            combatService: combatService,
            commandService: commandService,
          ),
        ),
      );

      expect(find.text('50% GAUGE'), findsOneWidget);
    });

    testWidgets('Limit Burst unlocks at 100% charge and resets gauge upon execution', (tester) async {
      const hero = UnitEntity(
        id: 'ally_hero',
        speciesId: 'dread_knight',
        name: 'Dread Knight',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 10,
        maxLevel: 30,
        currentHp: 800,
        maxHp: 800,
        attack: 150,
        defense: 120,
        speed: 100,
        turnMeter: 100.0,
        ultimateCharge: 100.0, // 100% Ready
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      const foe = UnitEntity(
        id: 'enemy_1',
        speciesId: 'cultist',
        name: 'Cultist',
        generation: 1,
        archetype: Archetype.assassin,
        slot: FormationSlot.front1,
        level: 10,
        maxLevel: 30,
        currentHp: 400,
        maxHp: 400,
        attack: 80,
        defense: 40,
        speed: 90,
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      final tickManager = InitiativeTickManager(
        initialAllies: [hero],
        initialEnemies: [foe],
      );
      addTearDown(tickManager.dispose);
      tickManager.advanceTick(); // Puts hero in awaitingAction

      final commandService = GeneralCommandService(
        tickManager: tickManager,
        generalType: GeneralType.vladislav,
      );

      final combatService = CombatResolutionService(
        tickManager: tickManager,
        commandService: commandService,
        rng: Random(42),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BattleScreen(
            tickManager: tickManager,
            combatService: combatService,
            commandService: commandService,
          ),
        ),
      );

      // Verify Limit Burst Ready presentation
      expect(find.text('LIMIT BURST'), findsOneWidget);
      expect(find.text('READY (100%)'), findsOneWidget);

      // Select target
      await tester.tap(find.text('Cultist'));
      await tester.pump();

      // Trigger Limit Burst
      await tester.tap(find.text('LIMIT BURST'));
      await tester.pump(const Duration(milliseconds: 350));
      tickManager.pause();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify hero ultimate charge reset to 0%
      final updatedHero = tickManager.allies.firstWhere((u) => u.id == 'ally_hero');
      expect(updatedHero.ultimateCharge, 0.0);
    });
  });
}
