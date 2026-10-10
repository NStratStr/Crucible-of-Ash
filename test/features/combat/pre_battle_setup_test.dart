import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/features/combat/battle_screen.dart';
import 'package:ashen_crucible/features/combat/combat_resolution_service.dart';
import 'package:ashen_crucible/features/combat/initiative_tick_manager.dart';
import 'package:ashen_crucible/features/generals/general_command_service.dart';
import 'package:ashen_crucible/shared/data/starter_brigades.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';

void main() {
  group('Pre-Battle Setup & Flexible Formations Tests (GDD v2.8 Sec 3.4)', () {
    test('UnitEntity supports arbitrary isFrontlineOverride (all front, all back, or mix)', () {
      final unit = StarterBrigades.createAshLegionPlayerSquad()[0]; // Lord Vladislav, default slot front1

      // Default: slot front1 is frontline
      expect(unit.isFrontline, isTrue);
      expect(unit.isBackline, isFalse);

      // Override to backline
      final backUnit = unit.copyWith(isFrontlineOverride: false);
      expect(backUnit.isFrontline, isFalse);
      expect(backUnit.isBackline, isTrue);

      // Override back to frontline
      final frontUnit = backUnit.copyWith(isFrontlineOverride: true);
      expect(frontUnit.isFrontline, isTrue);
      expect(frontUnit.isBackline, isFalse);
    });

    testWidgets('BattleScreen starts in Pre-Battle Setup and allows toggling all units to frontline or backline',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final allies = StarterBrigades.createAshLegionPlayerSquad();
      final enemies = StarterBrigades.createCryptStalkersEnemySquad();

      final tickManager = InitiativeTickManager(
        initialAllies: allies,
        initialEnemies: enemies,
      );
      addTearDown(tickManager.dispose);

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
            startInPreBattleSetup: true,
          ),
        ),
      );
      await tester.pump();

      // 1. Verify Pre-Battle Setup UI is rendered
      expect(find.text('COMMENCE BATTLE'), findsOneWidget);
      expect(find.textContaining('PRE-BATTLE:'), findsOneWidget);
      expect(find.text('ALL FRONT'), findsOneWidget);
      expect(find.text('BALANCED'), findsOneWidget);
      expect(find.text('ALL REAR'), findsOneWidget);

      // Default squad has 3 frontline (slots 0, 1, 2) and 2 backline (slots 3, 4)
      expect(find.text('🛡️ FRONT: 3'), findsOneWidget);
      expect(find.text('🔮 REAR: 2'), findsOneWidget);

      // 2. Tap 'ALL FRONT' preset -> all 5 units become frontline
      await tester.tap(find.text('ALL FRONT'));
      await tester.pump();

      expect(find.text('🛡️ FRONT: 5'), findsOneWidget);
      expect(find.text('🔮 REAR: 0'), findsOneWidget);
      expect(tickManager.allies.every((u) => u.isFrontline), isTrue);

      // 3. Tap 'ALL REAR' preset -> all 5 units become backline
      await tester.tap(find.text('ALL REAR'));
      await tester.pump();

      expect(find.text('🛡️ FRONT: 0'), findsOneWidget);
      expect(find.text('🔮 REAR: 5'), findsOneWidget);
      expect(tickManager.allies.every((u) => u.isBackline), isTrue);

      // 4. Tap 'BALANCED' preset -> restored to 3 front, 2 back
      await tester.tap(find.text('BALANCED'));
      await tester.pump();

      expect(find.text('🛡️ FRONT: 3'), findsOneWidget);
      expect(find.text('🔮 REAR: 2'), findsOneWidget);

      // 5. Tap unit formation badge during pre-battle setup to toggle individual unit lane
      await tester.tap(find.byKey(const Key('unit_lane_badge_ash_vladislav_01')));
      // Allow GestureDetector double-tap disambiguation timer to resolve
      await tester.pump(const Duration(milliseconds: 400));

      // Vladislav toggled to rear -> 2 front, 3 rear
      expect(find.text('🛡️ FRONT: 2'), findsOneWidget);
      expect(find.text('🔮 REAR: 3'), findsOneWidget);

      // 6. Tap 'COMMENCE BATTLE' -> transitions to active battle and starts ticks
      await tester.tap(find.text('COMMENCE BATTLE'));
      await tester.pump();

      expect(tickManager.phase, equals(CombatPhase.ticking));
      expect(find.text('COMMENCE BATTLE'), findsNothing);

      tickManager.pause();
      await tester.pumpWidget(const SizedBox());
    });
  });
}
