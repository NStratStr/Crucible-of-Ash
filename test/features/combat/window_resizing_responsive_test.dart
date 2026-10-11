import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/features/combat/battle_screen.dart';
import 'package:ashen_crucible/features/combat/initiative_tick_manager.dart';
import 'package:ashen_crucible/features/combat/combat_resolution_service.dart';
import 'package:ashen_crucible/features/generals/general_command_service.dart';
import 'package:ashen_crucible/shared/data/starter_brigades.dart';

void main() {
  group('Window Resizing & Responsive Unit Card Layout Tests', () {
    late InitiativeTickManager tickManager;
    late GeneralCommandService commandService;
    late CombatResolutionService combatService;

    setUp(() {
      final allies = StarterBrigades.createAshLegionPlayerSquad();
      final enemies = StarterBrigades.createCryptStalkersEnemySquad();

      tickManager = InitiativeTickManager(
        initialAllies: allies,
        initialEnemies: enemies,
      );

      commandService = GeneralCommandService(
        tickManager: tickManager,
        generalType: GeneralType.vladislav,
      );

      combatService = CombatResolutionService(
        tickManager: tickManager,
        commandService: commandService,
      );
    });

    tearDown(() {
      tickManager.pause();
      tickManager.dispose();
      commandService.dispose();
    });

    testWidgets('Renders cleanly on desktop 1280x900 without overflows', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BattleScreen(
              tickManager: tickManager,
              combatService: combatService,
              commandService: commandService,
              startInPreBattleSetup: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(BattleScreen), findsOneWidget);
      expect(find.text('THE ASHEN FRONT'), findsOneWidget);
      expect(find.text('COMMENCE BATTLE'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Renders cleanly on compact 800x600 window without overflows or hidden units', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BattleScreen(
              tickManager: tickManager,
              combatService: combatService,
              commandService: commandService,
              startInPreBattleSetup: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(BattleScreen), findsOneWidget);
      expect(find.text('COMMENCE BATTLE'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Renders cleanly on ultra-compact 700x520 window without overflows', (tester) async {
      tester.view.physicalSize = const Size(700, 520);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BattleScreen(
              tickManager: tickManager,
              combatService: combatService,
              commandService: commandService,
              startInPreBattleSetup: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(BattleScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
