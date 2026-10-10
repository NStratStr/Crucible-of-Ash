import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/features/combat/battle_screen.dart';
import 'package:ashen_crucible/features/combat/combat_resolution_service.dart';
import 'package:ashen_crucible/features/combat/initiative_tick_manager.dart';
import 'package:ashen_crucible/features/generals/general_command_service.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';
import 'package:ashen_crucible/shared/widgets/app_shell.dart';

void main() {
  group('Boss Unit Presentation & Combat Impact Tests', () {
    const UnitEntity testPlayer = UnitEntity(
      id: 'ally_1',
      name: 'Ash Vanguard',
      level: 15,
      maxLevel: 30,
      currentHp: 800,
      maxHp: 800,
      attack: 120,
      defense: 60,
      speed: 55,
      generation: 2,
      archetype: Archetype.juggernaut,
      slot: FormationSlot.front1,
      speciesId: 'human_lineage',
      nativeTraitId: 'none',
      lineageAncestors: [],
    );

    const UnitEntity testBoss = UnitEntity(
      id: 'boss_c1_gorgoroth',
      name: 'Gorgoroth the Ash Colossus',
      level: 25,
      maxLevel: 50,
      currentHp: 5000,
      maxHp: 5000,
      attack: 240,
      defense: 120,
      speed: 40,
      generation: 1,
      archetype: Archetype.juggernaut,
      slot: FormationSlot.front1,
      speciesId: 'chapter_titan_fire',
      nativeTraitId: 'none',
      lineageAncestors: [],
    );

    const UnitEntity testMinion = UnitEntity(
      id: 'enemy_minion_1',
      name: 'Cultist Zealot',
      level: 10,
      maxLevel: 30,
      currentHp: 300,
      maxHp: 300,
      attack: 70,
      defense: 30,
      speed: 45,
      generation: 1,
      archetype: Archetype.assassin,
      slot: FormationSlot.front2,
      speciesId: 'corrupted_mortal',
      nativeTraitId: 'none',
      lineageAncestors: [],
    );

    test('UnitEntity isBoss accurately distinguishes bosses from minions', () {
      expect(testBoss.isBoss, isTrue);
      expect(testPlayer.isBoss, isFalse);
      expect(testMinion.isBoss, isFalse);

      const UnitEntity titanSovereign = UnitEntity(
        id: 'world_titan_1',
        name: 'The Abyssal Sovereign',
        level: 50,
        maxLevel: 50,
        currentHp: 20000,
        maxHp: 20000,
        attack: 400,
        defense: 200,
        speed: 50,
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        speciesId: 'titan_sovereign',
        nativeTraitId: 'none',
        lineageAncestors: [],
      );
      expect(titanSovereign.isBoss, isTrue);

      const UnitEntity bossGuard = UnitEntity(
        id: 'boss_guard_1',
        name: 'Royal Shieldguard',
        level: 12,
        maxLevel: 30,
        currentHp: 600,
        maxHp: 600,
        attack: 80,
        defense: 70,
        speed: 40,
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front2,
        speciesId: 'corrupted_mortal',
        nativeTraitId: 'none',
        lineageAncestors: [],
      );
      expect(bossGuard.isBoss, isFalse);
    });

    testWidgets('BattleScreen renders Grand Boss Health Gauge & Boss badges when boss present',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final tickManager = InitiativeTickManager(
        initialAllies: [testPlayer],
        initialEnemies: [testBoss, testMinion],
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
          ),
        ),
      );

      await tester.pump();

      // 1. Verify Grand Boss Bar at the top of the battlefield
      expect(find.textContaining('PRIMORDIAL BOSS:'), findsOneWidget);
      expect(find.textContaining('TITAN'), findsWidgets);
      expect(find.textContaining('5000 / 5000 HP'), findsOneWidget);

      // 2. Verify Boss badge on unit card and pedestal
      expect(find.text('☠ BOSS'), findsWidgets);

      // 3. Verify minion is present without boss badge
      expect(find.text('Cultist Zealot'), findsOneWidget);

      // Stop ticks before widget unmount
      tickManager.pause();
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Ascension Screen Navigation Tests', () {
    testWidgets('AppShell can be rendered without errors', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: AppShell(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // App Shell renders navigation items
      expect(find.text('Campaign Map'), findsOneWidget);
      expect(find.text('Crucible Altar'), findsOneWidget);
    });
  });
}
