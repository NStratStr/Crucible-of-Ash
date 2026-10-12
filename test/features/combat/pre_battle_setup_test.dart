import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/features/combat/battle_screen.dart';
import 'package:ashen_crucible/features/combat/combat_resolution_service.dart';
import 'package:ashen_crucible/features/combat/initiative_tick_manager.dart';
import 'package:ashen_crucible/features/generals/general_command_service.dart';
import 'package:ashen_crucible/shared/data/starter_brigades.dart';

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

    test('Lord Vladislav resolves to G1, G3, and G6 evolution assets based on generation tier', () {
      final baseVlad = StarterBrigades.createAshLegionPlayerSquad()[0];

      // G1
      final g1Vlad = baseVlad.copyWith(generation: 1);
      expect(g1Vlad.effectiveAvatarAsset, equals('assets/images/Crypt Stalkers/lord_vladislav_g1.png'));

      // G2
      final g2Vlad = baseVlad.copyWith(generation: 2);
      expect(g2Vlad.effectiveAvatarAsset, equals('assets/images/Crypt Stalkers/lord_vladislav_g1.png'));

      // G3
      final g3Vlad = baseVlad.copyWith(generation: 3);
      expect(g3Vlad.effectiveAvatarAsset, equals('assets/images/Crypt Stalkers/lord_vladislav_g3.png'));

      // G5
      final g5Vlad = baseVlad.copyWith(generation: 5);
      expect(g5Vlad.effectiveAvatarAsset, equals('assets/images/Crypt Stalkers/lord_vladislav_g3.png'));

      // G6 / Pureblood
      final g6Vlad = baseVlad.copyWith(generation: 6);
      expect(g6Vlad.isPureblood, isTrue);
      expect(g6Vlad.effectiveAvatarAsset, equals('assets/images/Crypt Stalkers/lord_vladislav_g6.png'));
    });

    testWidgets('BattleScreen pauses ticking tickManager when startInPreBattleSetup is true',
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

      // Prematurely start tick manager
      tickManager.start();
      expect(tickManager.phase, equals(CombatPhase.ticking));

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

      // Verified: BattleScreen forced tickManager to pause and renders COMMENCE BATTLE
      expect(tickManager.phase, equals(CombatPhase.idle));
      expect(find.text('COMMENCE BATTLE'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('BattleScreen displays Opening Hand cards in Pre-Battle Setup and allows card inspection',
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

      // 1. Verify Opening Hand header and cards are rendered
      expect(find.textContaining('OPENING HAND'), findsOneWidget);
      final cards = commandService.hand.isNotEmpty
          ? commandService.hand
          : commandService.currentProfile.orders;
      expect(cards.isNotEmpty, isTrue);

      // Verify the first card name is visible
      final firstCardName = cards.first.name.toUpperCase();
      expect(find.text(firstCardName), findsWidgets);

      // 2. Tap the first card in the opening hand to open pre-battle inspection sheet
      await tester.tap(find.text(firstCardName).first);
      await tester.pumpAndSettle();

      // Modal bottom sheet appears with focus cost & description
      expect(find.textContaining('FOCUS'), findsWidgets);
      expect(find.textContaining('Ready in Opening Hand'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('BattleScreen enables horizontal column repositioning (left/right nudge arrows and tap-to-swap)',
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

      // Initially unit 0 is Vladislav at Col 0
      expect(tickManager.allies[0].id, equals('ash_vladislav_01'));
      expect(tickManager.allies[0].columnIndex, equals(0));
      final unit1Id = tickManager.allies[1].id;

      // Verify ugly arrows are removed
      expect(find.byIcon(Icons.chevron_left), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNothing);

      // 1. Drag and drop: drag Vladislav (Col 0) onto unit 1 (Col 1)
      final firstUnitCenter = tester.getCenter(find.byKey(const Key('unit_card_ash_vladislav_01')));
      final targetUnitCenter = tester.getCenter(find.byKey(Key('unit_card_$unit1Id')));

      final TestGesture gesture = await tester.startGesture(firstUnitCenter);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(targetUnitCenter);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();

      // Vladislav and unit 1 swapped!
      expect(tickManager.allies[1].id, equals('ash_vladislav_01'));
      expect(tickManager.allies[1].columnIndex, equals(1));
      expect(tickManager.allies[0].id, equals(unit1Id));
      expect(tickManager.allies[0].columnIndex, equals(0));

      // 2. Direct Tap on unit: tapping unit immediately toggles Frontline <-> Backline
      final bool vladWasFront = tickManager.allies[1].isFrontline;
      await tester.tap(find.byKey(const Key('unit_card_ash_vladislav_01')));
      await tester.pump(const Duration(milliseconds: 400));

      // Vladislav immediately flipped lane depth on single tap!
      expect(tickManager.allies[1].isFrontline, equals(!vladWasFront));

      // 3. Drag and drop onto Col 3: swaps columns cleanly
      final unit3Id = tickManager.allies[3].id;
      final vladPos = tester.getCenter(find.byKey(const Key('unit_card_ash_vladislav_01')));
      final unit3Pos = tester.getCenter(find.byKey(Key('unit_card_$unit3Id')));

      final TestGesture dragTo3 = await tester.startGesture(vladPos);
      await tester.pump(const Duration(milliseconds: 100));
      await dragTo3.moveTo(unit3Pos);
      await tester.pump(const Duration(milliseconds: 100));
      await dragTo3.up();
      await tester.pumpAndSettle();

      expect(tickManager.allies[3].id, equals('ash_vladislav_01'));
      expect(tickManager.allies[3].columnIndex, equals(3));
      expect(tickManager.allies[1].id, equals(unit3Id));
      expect(tickManager.allies[1].columnIndex, equals(1));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('BattleScreen enables 2D Drag & Drop for Front/Back lane placement and tap-again lane toggling',
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

      // Initially Vladislav (Col 0) is in Frontline
      expect(tickManager.allies[0].id, equals('ash_vladislav_01'));
      expect(tickManager.allies[0].isFrontline, isTrue);

      // 1. Drag Vladislav downwards within his column (bottom half -> Backline)
      final vladCenter = tester.getCenter(find.byKey(const Key('unit_card_ash_vladislav_01')));
      final vladBottom = vladCenter + const Offset(0, 50);

      TestGesture gesture = await tester.startGesture(vladCenter);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(vladBottom);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();

      // Vladislav moved to Backline in Col 0!
      expect(tickManager.allies[0].id, equals('ash_vladislav_01'));
      expect(tickManager.allies[0].isFrontline, isFalse);
      expect(tickManager.allies[0].isBackline, isTrue);

      // 2. Drag Vladislav upwards within his column (top half -> Frontline)
      final vladNowCenter = tester.getCenter(find.byKey(const Key('unit_card_ash_vladislav_01')));
      final vladTop = vladNowCenter - const Offset(0, 50);

      gesture = await tester.startGesture(vladNowCenter);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(vladTop);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();

      // Vladislav restored to Frontline!
      expect(tickManager.allies[0].id, equals('ash_vladislav_01'));
      expect(tickManager.allies[0].isFrontline, isTrue);

      // 3. Tap Vladislav once -> directly flips to Backline!
      await tester.tap(find.byKey(const Key('unit_card_ash_vladislav_01')));
      await tester.pump(const Duration(milliseconds: 400));

      expect(tickManager.allies[0].isFrontline, isFalse);

      // Tap Vladislav again -> directly flips back to Frontline!
      await tester.tap(find.byKey(const Key('unit_card_ash_vladislav_01')));
      await tester.pump(const Duration(milliseconds: 400));

      expect(tickManager.allies[0].isFrontline, isTrue);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
