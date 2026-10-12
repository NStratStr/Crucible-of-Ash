import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/features/combat/initiative_tick_manager.dart';
import 'package:ashen_crucible/features/generals/general_command_service.dart';
import 'package:ashen_crucible/features/generals/grimoire_manager_dialog.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';

UnitEntity _dummyUnit(String id, FormationSlot slot) {
  return UnitEntity(
    id: id,
    speciesId: 'dummy',
    name: 'Unit $id',
    generation: 1,
    archetype: Archetype.juggernaut,
    slot: slot,
    level: 1,
    maxLevel: 30,
    currentHp: 500,
    maxHp: 500,
    attack: 50,
    defense: 30,
    speed: 100,
    turnMeter: 0.0,
    nativeTraitId: 'none',
    lineageAncestors: const [],
  );
}

void main() {
  group('GrimoireManagerDialog & Custom Grimoire Tests', () {
    late InitiativeTickManager tickManager;
    late GeneralCommandService commandService;

    setUp(() {
      tickManager = InitiativeTickManager(
        initialAllies: [_dummyUnit('u1', FormationSlot.front1)],
        initialEnemies: [_dummyUnit('e1', FormationSlot.front1)],
      );

      commandService = GeneralCommandService(
        tickManager: tickManager,
        generalType: GeneralType.vladislav,
        initialFocus: 6,
        maxFocus: GeneralCommandService.grimoireMaxFocusCap,
        initialPhylacteryRanks: {GeneralType.vladislav: 1},
      );
    });

    tearDown(() {
      tickManager.dispose();
      commandService.dispose();
    });

    test('Vladislav starting grimoire deck contains 12 cards', () {
      final deck = commandService.getActiveGrimoireDeck();
      expect(deck.length, 12);
      expect(deck.where((o) => o.id == 'siphon_vitality').length, 2);
    });

    test('Custom deck save and initialization works', () {
      final customDeck = [
        'siphon_vitality', 'siphon_vitality',
        'rend_flesh', 'rend_flesh',
        'iron_bulwark', 'iron_bulwark',
        'exsanguinating_strike', 'exsanguinating_strike',
        'sanguine_revival', 'sanguine_revival',
        'blood_boil', 'blood_boil',
      ];
      expect(customDeck.length, 12);

      commandService.saveCustomGrimoire(GeneralType.vladislav, customDeck);
      final activeDeck = commandService.getActiveGrimoireDeck();
      expect(activeDeck.map((o) => o.id).toList(), customDeck);

      commandService.initializeGrimoire();
      expect(commandService.hand.isNotEmpty, true);
      final totalCards = commandService.hand.length + commandService.grimoireDeck.length;
      expect(totalCards, 12);
    });

    testWidgets('GrimoireManagerDialog renders and displays deck info', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  GrimoireManagerDialog.show(
                    ctx,
                    commandService: commandService,
                    bloodlineSigils: 5,
                  );
                },
                child: const Text('Open Grimoire'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Grimoire'));
      await tester.pumpAndSettle();

      expect(find.text('GRIMOIRE ARCHIVES'), findsOneWidget);
      expect(find.textContaining('Lord Vladislav'), findsWidgets);
      expect(find.text('ORDER ARCHIVES'), findsOneWidget);
      expect(find.textContaining('SEAL GRIMOIRE'), findsOneWidget);
    });

    testWidgets('Phylactery upgrade button promotes rank and unlocks tier', (tester) async {
      int sigils = 5;
      GeneralType? upgradedType;
      int? newRankVal;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  GrimoireManagerDialog.show(
                    ctx,
                    commandService: commandService,
                    bloodlineSigils: sigils,
                    onSigilsChanged: (s) => sigils = s,
                    onPhylacteryUpgraded: (t, r) {
                      upgradedType = t;
                      newRankVal = r;
                    },
                  );
                },
                child: const Text('Open Grimoire'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Grimoire'));
      await tester.pumpAndSettle();

      // Look for the Anoint button
      final anointBtn = find.textContaining('ANOINT RANK 2');
      expect(anointBtn, findsOneWidget);

      await tester.tap(anointBtn);
      await tester.pumpAndSettle();

      expect(upgradedType, GeneralType.vladislav);
      expect(newRankVal, 2);
      expect(sigils, 4); // 5 - 1 = 4
      expect(commandService.activePhylacteryRank, 2);
    });
  });
}
