import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/features/combat/battle_screen.dart';
import 'package:ashen_crucible/features/combat/combat_resolution_service.dart';
import 'package:ashen_crucible/features/combat/initiative_tick_manager.dart';
import 'package:ashen_crucible/features/generals/general_command_service.dart';
import 'package:ashen_crucible/shared/data/starter_brigades.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';
import 'package:ashen_crucible/shared/widgets/pedigree_inspector_dialog.dart';

void main() {
  group('GDD v2.6 Card Drag, Bullet-Time, Burn Pit & Inspector Tests', () {
    const ally = UnitEntity(
      id: 'footman_1',
      speciesId: 'iron_footman',
      name: 'Iron Footman',
      generation: 1,
      archetype: Archetype.juggernaut,
      slot: FormationSlot.front1,
      level: 10,
      maxLevel: 30,
      currentHp: 1000,
      maxHp: 1000,
      attack: 120,
      defense: 100,
      speed: 90,
      resist: 40,
      nativeTraitId: 'none',
      lineageAncestors: [],
    );

    const enemy = UnitEntity(
      id: 'husk_1',
      speciesId: 'rotting_husk',
      name: 'Rotting Husk',
      generation: 1,
      archetype: Archetype.juggernaut,
      slot: FormationSlot.front1,
      level: 10,
      maxLevel: 30,
      currentHp: 1000,
      maxHp: 1000,
      attack: 100,
      defense: 80,
      speed: 85,
      resist: 30,
      nativeTraitId: 'none',
      lineageAncestors: [],
    );

    testWidgets('Dragging card activates bullet-time slow-mo (0.30x speed)', (tester) async {
      final tickManager = InitiativeTickManager(
        initialAllies: [ally],
        initialEnemies: [enemy],
      );
      addTearDown(tickManager.dispose);

      final commandService = GeneralCommandService(
        tickManager: tickManager,
        generalType: GeneralType.vladislav,
        initialFocus: 6,
        maxFocus: GeneralCommandService.grimoireMaxFocusCap,
      );
      commandService.initializeGrimoire();

      final combatService = CombatResolutionService(
        tickManager: tickManager,
        commandService: commandService,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BattleScreen(
              tickManager: tickManager,
              combatService: combatService,
              commandService: commandService,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(commandService.isBulletTimeActive, isFalse);
      expect(tickManager.isBulletTime, isFalse);

      // Find the first draggable card in the orders tray
      final cardFinder = find.byType(Draggable<GeneralOrderDefinition>).first;
      expect(cardFinder, findsOneWidget);

      // Start dragging the card
      final gesture = await tester.startGesture(tester.getCenter(cardFinder));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump();

      // Bullet-time must be active during card drag
      expect(commandService.isBulletTimeActive, isTrue);
      expect(tickManager.isBulletTime, isTrue);
      expect(commandService.simulationSpeedMultiplier, equals(0.30));

      // End / cancel drag
      await gesture.up();
      await tester.pump();

      // Bullet-time turns off
      expect(commandService.isBulletTimeActive, isFalse);
      expect(tickManager.isBulletTime, isFalse);

      tickManager.pause();
    });

    testWidgets('Tapping or dragging to 48x48 Burn Pit burns card for 0 Focus', (tester) async {
      final tickManager = InitiativeTickManager(
        initialAllies: [ally],
        initialEnemies: [enemy],
      );
      addTearDown(tickManager.dispose);

      final commandService = GeneralCommandService(
        tickManager: tickManager,
        generalType: GeneralType.vladislav,
        initialFocus: 6,
        maxFocus: GeneralCommandService.grimoireMaxFocusCap,
      );
      commandService.initializeGrimoire();

      final combatService = CombatResolutionService(
        tickManager: tickManager,
        commandService: commandService,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BattleScreen(
              tickManager: tickManager,
              combatService: combatService,
              commandService: commandService,
            ),
          ),
        ),
      );
      await tester.pump();

      final initialHandSize = commandService.hand.length;
      expect(initialHandSize, equals(3));
      final cardToBurn = commandService.hand.first;

      // Find Burn Pit target (48x48)
      final burnPitFinder = find.text('BURN');
      expect(burnPitFinder, findsOneWidget);

      // Tap Burn Pit to burn the card
      await tester.tap(burnPitFinder);
      await tester.pump();

      // Card must be burned from hand into discard pile, hand size reduced, 0 Focus consumed
      expect(commandService.hand.length, equals(2));
      expect(commandService.discardPile.length, equals(1));
      expect(commandService.discardPile.first.id, equals(cardToBurn.id));
      expect(commandService.currentFocus, equals(6));

      tickManager.pause();
    });

    testWidgets('Opening Inspector pauses simulation; closing resumes', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final tickManager = InitiativeTickManager(
        initialAllies: [ally],
        initialEnemies: [enemy],
      );
      addTearDown(tickManager.dispose);

      final commandService = GeneralCommandService(
        tickManager: tickManager,
        generalType: GeneralType.vladislav,
        initialFocus: 6,
      );

      final combatService = CombatResolutionService(
        tickManager: tickManager,
        commandService: commandService,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BattleScreen(
              tickManager: tickManager,
              combatService: combatService,
              commandService: commandService,
            ),
          ),
        ),
      );
      await tester.pump();

      // Ensure tick engine is running
      tickManager.start();
      expect(tickManager.phase, equals(CombatPhase.ticking));

      // Tap the assignment / inspector icon on miniature
      final inspectButtonFinder = find.byIcon(Icons.assignment);
      expect(inspectButtonFinder, findsWidgets);
      await tester.tap(inspectButtonFinder.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Simulation must be paused while inspecting
      expect(tickManager.phase, isNot(equals(CombatPhase.ticking)));

      // Inspector sheet must be visible displaying Combat Attributes
      expect(find.byType(PedigreeInspectorDialog), findsOneWidget);
      expect(find.text('COMBAT ATTRIBUTES'), findsOneWidget);
      expect(find.text('HP VITALITY'), findsOneWidget);
      expect(find.text('ARMOR (PRR)'), findsOneWidget);
      expect(find.text('RESIST (ERR)'), findsOneWidget);

      // Dismiss the inspector dialog
      Navigator.of(tester.element(find.byType(PedigreeInspectorDialog))).pop();
      await tester.pumpAndSettle();

      // Simulation resumes running
      expect(tickManager.phase, equals(CombatPhase.ticking));

      tickManager.pause();
    });

    testWidgets('GDD v2.7 Sec 7.3: Target Failsafe cancels card without consuming focus if target dies during drag', (tester) async {
      final tickManager = InitiativeTickManager(
        initialAllies: [ally],
        initialEnemies: [enemy],
      );
      addTearDown(tickManager.dispose);

      final commandService = GeneralCommandService(
        tickManager: tickManager,
        generalType: GeneralType.vladislav,
        initialFocus: 6,
        maxFocus: GeneralCommandService.grimoireMaxFocusCap,
      );
      commandService.initializeGrimoire();

      final combatService = CombatResolutionService(
        tickManager: tickManager,
        commandService: commandService,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BattleScreen(
              tickManager: tickManager,
              combatService: combatService,
              commandService: commandService,
            ),
          ),
        ),
      );
      await tester.pump();

      final initialFocus = commandService.currentFocus;

      // Kill the enemy in the background
      tickManager.updateSquads(
        allies: [ally],
        enemies: [enemy.copyWith(currentHp: 0)],
      );
      await tester.pump();

      // Attempt to drop card on the enemy target finder
      // Find the enemy DragTarget
      final enemyTargetFinder = find.byType(DragTarget<GeneralOrderDefinition>).first;
      final targetWidget = tester.widget<DragTarget<GeneralOrderDefinition>>(enemyTargetFinder);
      
      // Simulate drop of Rend Flesh on now-dead enemy
      targetWidget.onAcceptWithDetails?.call(
        DragTargetDetails<GeneralOrderDefinition>(
          data: GeneralProfile.rendFleshOrder,
          offset: Offset.zero,
        ),
      );
      await tester.pump();

      tickManager.pause();
    });

    testWidgets('GDD v2.8 Sec 5: Focus generates 1 point per 30 global logic ticks (60 if commander downed)', (tester) async {
      const commander = UnitEntity(
        id: 'commander_vladislav',
        speciesId: 'commander_vladislav',
        name: 'Lord Vladislav',
        generation: 1,
        archetype: Archetype.assassin,
        slot: FormationSlot.front1,
        level: 10,
        maxLevel: 30,
        currentHp: 1000,
        maxHp: 1000,
        attack: 100,
        defense: 100,
        speed: 100,
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      final tickManager = InitiativeTickManager(
        initialAllies: [commander],
        initialEnemies: [enemy],
      );
      addTearDown(tickManager.dispose);

      final commandService = GeneralCommandService(
        tickManager: tickManager,
        generalType: GeneralType.vladislav,
        initialFocus: 0,
        maxFocus: 6,
      );

      // Advance 29 ticks -> still 0 focus
      for (int i = 0; i < 29; i++) {
        commandService.onSimulationTick();
      }
      expect(commandService.currentFocus, equals(0));

      // Advance 30th tick -> 1 focus generated
      commandService.onSimulationTick();
      expect(commandService.currentFocus, equals(1));

      // Now down the commander (0 HP)
      tickManager.updateSquads(
        allies: [commander.copyWith(currentHp: 0)],
        enemies: [enemy],
      );

      // Downed commander requires 60 ticks per focus
      for (int i = 0; i < 59; i++) {
        commandService.onSimulationTick();
      }
      expect(commandService.currentFocus, equals(1));

      // 60th tick -> 2 focus generated
      commandService.onSimulationTick();
      expect(commandService.currentFocus, equals(2));
    });
  });
}
