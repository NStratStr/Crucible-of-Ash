import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/features/combat/battle_screen.dart';
import 'package:ashen_crucible/features/combat/combat_resolution_service.dart';
import 'package:ashen_crucible/features/combat/initiative_tick_manager.dart';
import 'package:ashen_crucible/features/generals/general_command_service.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';

void main() {
  group('General Focus Order Combat Presentation Tests', () {
    testWidgets('Executing Vladislav Siphon Order triggers Commander Cut-In Banner and combat log highlight', (tester) async {
      const ally = UnitEntity(
        id: 'ally_1',
        speciesId: 'blood_vanguard',
        name: 'Blood Vanguard',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 10,
        maxLevel: 30,
        currentHp: 400,
        maxHp: 800,
        attack: 120,
        defense: 100,
        speed: 90,
        turnMeter: 100.0,
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      const enemy = UnitEntity(
        id: 'enemy_1',
        speciesId: 'mire_fiend',
        name: 'Mire Fiend',
        generation: 1,
        archetype: Archetype.assassin,
        slot: FormationSlot.front1,
        level: 10,
        maxLevel: 30,
        currentHp: 600,
        maxHp: 600,
        attack: 100,
        defense: 50,
        speed: 85,
        turnMeter: 50.0,
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      final tickManager = InitiativeTickManager(
        initialAllies: [ally],
        initialEnemies: [enemy],
      );
      addTearDown(tickManager.dispose);
      tickManager.advanceTick(); // Put unit in awaitingAction

      final commandService = GeneralCommandService(
        tickManager: tickManager,
        generalType: GeneralType.vladislav,
        initialFocus: 2,
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

      await tester.pump();

      // Find SIPHON order button and tap it
      expect(find.text('SIPHON'), findsOneWidget);
      await tester.tap(find.text('SIPHON'));
      await tester.pump();

      // Verify Commander Order Banner appeared
      expect(find.text('COMMANDER ORDER: SIPHON'), findsOneWidget);
      expect(find.textContaining('1 FOCUS'), findsWidgets);

      // Verify Combat Log has commander styling
      expect(find.textContaining('[LORD VLADISLAV] SIPHON:'), findsOneWidget);
    });

    testWidgets('Locked high-rank order shows snackbar notice instructing player to anoint general', (tester) async {
      const ally = UnitEntity(
        id: 'ally_1',
        speciesId: 'blood_vanguard',
        name: 'Blood Vanguard',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 10,
        maxLevel: 30,
        currentHp: 800,
        maxHp: 800,
        attack: 120,
        defense: 100,
        speed: 90,
        turnMeter: 100.0,
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      const enemy = UnitEntity(
        id: 'enemy_1',
        speciesId: 'mire_fiend',
        name: 'Mire Fiend',
        generation: 1,
        archetype: Archetype.assassin,
        slot: FormationSlot.front1,
        level: 10,
        maxLevel: 30,
        currentHp: 600,
        maxHp: 600,
        attack: 100,
        defense: 50,
        speed: 85,
        turnMeter: 50.0,
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      final tickManager = InitiativeTickManager(
        initialAllies: [ally],
        initialEnemies: [enemy],
      );
      addTearDown(tickManager.dispose);
      tickManager.advanceTick();

      // Vladislav at Rank 1: Rank 3 EXECUTE order is locked
      final commandService = GeneralCommandService(
        tickManager: tickManager,
        generalType: GeneralType.vladislav,
        initialFocus: 3,
        initialPhylacteryRanks: {GeneralType.vladislav: 1},
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

      await tester.pump();

      // Tap locked EXECUTE button (shows RANK 3 lock)
      expect(find.text('RANK 3'), findsOneWidget);
      await tester.tap(find.text('EXECUTE'));
      await tester.pump();

      expect(find.textContaining('EXECUTE is sealed! Anoint Lord Vladislav to Phylactery Rank 3'), findsOneWidget);
    });
  });
}
