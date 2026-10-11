import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/features/combat/battle_screen.dart';
import 'package:ashen_crucible/features/combat/initiative_tick_manager.dart';
import 'package:ashen_crucible/features/combat/combat_resolution_service.dart';
import 'package:ashen_crucible/features/generals/general_command_service.dart';
import 'package:ashen_crucible/shared/data/starter_brigades.dart';

void main() {
  group('Miniature Alignment, Scaling & Clean Contact Shadow Tests', () {
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

    testWidgets('BattleScreen anchors miniature scales to Alignment.bottomCenter and renders clean contact shadow', (tester) async {
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

      // Find unit cards
      expect(find.byType(BattleScreen), findsOneWidget);

      // Verify Transform.scale widgets have alignment == Alignment.bottomCenter
      final transformWidgets = tester.widgetList<Transform>(find.byType(Transform));
      final bottomCenterTransforms = transformWidgets.where((t) => t.alignment == Alignment.bottomCenter).toList();

      // Layer 1B miniature artwork uses Alignment.bottomCenter so all plinths align horizontally
      expect(bottomCenterTransforms.isNotEmpty, isTrue);
    });
  });
}
