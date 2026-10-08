import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/features/combat/battle_screen.dart';
import 'package:ashen_crucible/features/combat/combat_resolution_service.dart';
import 'package:ashen_crucible/features/combat/initiative_tick_manager.dart';
import 'package:ashen_crucible/features/generals/general_command_service.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';

void main() {
  group('Combat Affinity Badges & Speed Controls Tests', () {
    testWidgets('1x/2x Speed Toggle dynamically switches tick speed and UI state', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

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
        speed: 100,
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
        turnMeter: 20.0,
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
      );
      addTearDown(commandService.dispose);

      final combatService = CombatResolutionService(tickManager: tickManager);

      await tester.pumpWidget(
        MaterialApp(
          home: BattleScreen(
            tickManager: tickManager,
            commandService: commandService,
            combatService: combatService,
          ),
        ),
      );
      await tester.pump();

      // Verify default 1X speed
      expect(find.text('1X'), findsOneWidget);
      expect(tickManager.speedMultiplier, equals(1.0));

      // Tap 1X speed toggle to switch to 2X
      await tester.tap(find.text('1X'));
      await tester.pump();

      expect(find.text('2X'), findsOneWidget);
      expect(tickManager.speedMultiplier, equals(2.0));

      // Tap again to switch back to 1X
      await tester.tap(find.text('2X'));
      await tester.pump();

      expect(find.text('1X'), findsOneWidget);
      expect(tickManager.speedMultiplier, equals(1.0));
    });

    testWidgets('Tapping WHEEL button opens Hexagonal Affinity Wheel Modal', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

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
        speed: 100,
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
        turnMeter: 20.0,
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      final tickManager = InitiativeTickManager(
        initialAllies: [ally],
        initialEnemies: [enemy],
      );
      addTearDown(tickManager.dispose);
      tickManager.advanceTick();

      final commandService = GeneralCommandService(
        tickManager: tickManager,
        generalType: GeneralType.vladislav,
      );
      addTearDown(commandService.dispose);

      final combatService = CombatResolutionService(tickManager: tickManager);

      await tester.pumpWidget(
        MaterialApp(
          home: BattleScreen(
            tickManager: tickManager,
            commandService: commandService,
            combatService: combatService,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('WHEEL'), findsOneWidget);

      await tester.tap(find.text('WHEEL'));
      await tester.pumpAndSettle();

      expect(find.text('HEXAGONAL AFFINITY WHEEL'), findsOneWidget);
      expect(find.text('DISMISS'), findsOneWidget);

      await tester.tap(find.text('DISMISS'));
      await tester.pumpAndSettle();

      expect(find.text('HEXAGONAL AFFINITY WHEEL'), findsNothing);
    });

    testWidgets('Target reticle and skill action bar display tactical affinity advantage feedback', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Juggernaut attacks Assassin -> Clockwise delta 1 = Advantage (+30% DMG)
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
        speed: 100,
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
        turnMeter: 20.0,
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      final tickManager = InitiativeTickManager(
        initialAllies: [ally],
        initialEnemies: [enemy],
      );
      addTearDown(tickManager.dispose);
      tickManager.advanceTick();

      final commandService = GeneralCommandService(
        tickManager: tickManager,
        generalType: GeneralType.vladislav,
      );
      addTearDown(commandService.dispose);

      final combatService = CombatResolutionService(tickManager: tickManager);

      await tester.pumpWidget(
        MaterialApp(
          home: BattleScreen(
            tickManager: tickManager,
            commandService: commandService,
            combatService: combatService,
          ),
        ),
      );
      await tester.pump();

      // Enemy card target reticle should show advantage badge TARGET (▲+30%)
      expect(find.text('TARGET (▲+30%)'), findsOneWidget);

      // Skill action button should indicate amplified multiplier (▲ 1.3x)
      expect(find.textContaining('(▲ 1.3x)'), findsWidgets);
    });
  });
}
