import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/core/combat_math.dart';
import 'package:ashen_crucible/features/campaign/campaign_map_screen.dart';
import 'package:ashen_crucible/features/campaign/campaign_node.dart';
import 'package:ashen_crucible/features/campaign/watchtower_dialog.dart';
import 'package:ashen_crucible/features/combat/initiative_tick_manager.dart';
import 'package:ashen_crucible/features/generals/general_command_service.dart';
import 'package:ashen_crucible/features/generals/general_selection_dialog.dart';
import 'package:ashen_crucible/features/relics/relic_forge_screen.dart';
import 'package:ashen_crucible/features/relics/relic_service.dart';
import 'package:ashen_crucible/shared/models/unit_entity.dart';

void main() {
  group('Tri-Currency Economy & Hex Wheel Scouting Tests', () {
    testWidgets('Watchtower reconnaissance reveals forward nodes and triggers onScoutForwardNodes', (tester) async {
      bool scoutedCalled = false;
      int gainedOre = 0;

      final watchtowerNode = const CampaignNode(
        id: 'node_watch',
        depth: 2,
        verticalRatio: 0.5,
        type: CampaignNodeType.watchtower,
        name: 'Obsidian Watchtower',
        description: 'Vantage point overlooking enemy movements.',
        nextNodeIds: ['node_forward'],
      );

      final dummyTickManager = InitiativeTickManager(initialAllies: const [], initialEnemies: const []);
      final dummyCommandService = GeneralCommandService(
        tickManager: dummyTickManager,
        generalType: GeneralType.vladislav,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  WatchtowerDialog.show(
                    context: context,
                    node: watchtowerNode,
                    relicService: RelicService(),
                    commandService: dummyCommandService,
                    onGainIchor: (_) {},
                    onGainOre: (amt) => gainedOre += amt,
                    onScoutForwardNodes: () => scoutedCalled = true,
                    onDismiss: () {},
                  );
                },
                child: const Text('OPEN WATCHTOWER'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN WATCHTOWER'));
      await tester.pumpAndSettle();

      expect(find.text('OBSIDIAN WATCHTOWER'), findsOneWidget);
      expect(find.text('Deploy Forward Reconnaissance'), findsOneWidget);
      expect(find.text('Excavate Cursed Ore Vein'), findsOneWidget);

      // Tap deploy reconnaissance
      await tester.tap(find.text('Deploy Forward Reconnaissance'));
      await tester.pumpAndSettle();

      expect(scoutedCalled, isTrue);
    });

    testWidgets('CampaignMapScreen renders SCOUTED chip and enemy archetype affinities', (tester) async {
      final scoutedNode = const CampaignNode(
        id: 'scouted_fight',
        depth: 1,
        verticalRatio: 0.4,
        type: CampaignNodeType.skirmish,
        name: 'Ambush Hollow',
        description: 'Scouted enemy platoon waiting in the mist.',
        nextNodeIds: [],
        isScouted: true,
        scoutedAffinities: [Archetype.juggernaut, Archetype.occultist],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CampaignMapScreen(
            nodes: [scoutedNode],
            onSelectNode: (_) {},
            totalIchor: 450,
            cursedOre: 75,
            bloodlineSigils: 2,
          ),
        ),
      );

      // Verify tri-currency display in app bar
      expect(find.text('450'), findsOneWidget);
      expect(find.text('75'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      // Verify SCOUTED badge
      expect(find.text('SCOUTED'), findsOneWidget);
      // Verify archetype abbreviation chips
      expect(find.text('JUG'), findsOneWidget);
      expect(find.text('OCC'), findsOneWidget);
    });

    testWidgets('RelicForgeScreen checks Cursed Ore requirement before forging', (tester) async {
      final relicService = RelicService();
      int currentIchor = 500;
      int currentOre = 10; // Less than 25 required

      const dummyUnit = UnitEntity(
        id: 'ally_1',
        speciesId: 'hound',
        name: 'War Hound',
        generation: 1,
        archetype: Archetype.juggernaut,
        slot: FormationSlot.front1,
        level: 10,
        maxLevel: 30,
        currentHp: 500,
        maxHp: 500,
        attack: 100,
        defense: 100,
        speed: 100,
        nativeTraitId: 'none',
        lineageAncestors: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RelicForgeScreen(
            relicService: relicService,
            brigadeUnits: const [dummyUnit],
            totalIchor: currentIchor,
            cursedOre: currentOre,
            onIchorChanged: (v) => currentIchor = v,
            onOreChanged: (v) => currentOre = v,
          ),
        ),
      );

      expect(find.text('500 ICHOR'), findsOneWidget);
      expect(find.text('10 ORE'), findsOneWidget);

      // Tap FORGE button
      await tester.tap(find.text('FORGE (100 / 25)'));
      await tester.pumpAndSettle();

      // Verify blocked with message
      expect(find.textContaining('Insufficient Cursed Ore'), findsOneWidget);
      expect(currentIchor, 500); // No ichor deducted
      expect(currentOre, 10);   // No ore deducted
    });

    testWidgets('GeneralSelectionDialog blocks anointing when lacking Bloodline Sigils', (tester) async {
      int currentSigils = 0; // Has 0 sigils

      final dummyTickManager = InitiativeTickManager(initialAllies: const [], initialEnemies: const []);
      final commandService = GeneralCommandService(
        tickManager: dummyTickManager,
        generalType: GeneralType.vladislav,
        initialPhylacteryRanks: {
          GeneralType.vladislav: 1,
          GeneralType.valeria: 1,
          GeneralType.malakor: 1,
          GeneralType.morrigan: 1,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  GeneralSelectionDialog.show(
                    context,
                    currentGeneralType: GeneralType.vladislav,
                    commandService: commandService,
                    bloodlineSigils: currentSigils,
                    onSigilsChanged: (val) => currentSigils = val,
                  );
                },
                child: const Text('OPEN GENERALS'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN GENERALS'));
      await tester.pumpAndSettle();

      expect(find.text('PHYLACTERY OF COMMANDERS'), findsOneWidget);
      expect(find.text('0 SIGILS'), findsOneWidget);
      expect(find.text('ANOINT (1 SIGIL)'), findsWidgets);

      // Tap Anoint button on Vladislav
      await tester.tap(find.text('ANOINT (1 SIGIL)').first);
      await tester.pumpAndSettle();

      // Verify blocked notification
      expect(find.textContaining('Insufficient Bloodline Sigils'), findsOneWidget);
      expect(commandService.getPhylacteryRank(GeneralType.vladislav), 1); // Remains rank 1
    });
  });
}
