import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/features/campaign/campaign_node.dart';
import 'package:ashen_crucible/features/campaign/rest_haven_dialog.dart';
import 'package:ashen_crucible/features/campaign/watchtower_dialog.dart';
import 'package:ashen_crucible/features/combat/initiative_tick_manager.dart';
import 'package:ashen_crucible/features/generals/general_command_service.dart';
import 'package:ashen_crucible/features/relics/relic_service.dart';

void main() {
  group('Campaign Encounter Dialogs Layout Tests', () {
    testWidgets('RestHavenDialog renders safely without RenderIntrinsicWidth assertion failures', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final relicService = RelicService();
      const node = CampaignNode(
        id: 'node_haven_01',
        name: 'Sanctified Rest Haven',
        description: 'A quiet sanctuary to rest and mend.',
        depth: 3,
        verticalRatio: 0.5,
        type: CampaignNodeType.restHaven,
        nextNodeIds: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => RestHavenDialog(
                        node: node,
                        onDismiss: () {},
                        onHealSquad: () {},
                        onGrantXp: () {},
                        relicService: relicService,
                      ),
                    );
                  },
                  child: const Text('OPEN HAVEN'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN HAVEN'));
      await tester.pumpAndSettle();

      expect(find.text('SANCTIFIED REST HAVEN'), findsOneWidget);
      expect(find.text('Communion of Blood'), findsOneWidget);
      expect(find.text('Anvil of Refinement'), findsOneWidget);
      expect(find.text('Meditative Crucible'), findsOneWidget);
    });

    testWidgets('WatchtowerDialog renders safely without RenderIntrinsicWidth assertion failures', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final relicService = RelicService();
      final tickManager = InitiativeTickManager(initialAllies: [], initialEnemies: []);
      final commandService = GeneralCommandService(tickManager: tickManager);
      const node = CampaignNode(
        id: 'node_tower_01',
        name: 'Obsidian Watchtower',
        description: 'A tall obsidian spire to scout the path.',
        depth: 2,
        verticalRatio: 0.5,
        type: CampaignNodeType.watchtower,
        nextNodeIds: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => WatchtowerDialog(
                        node: node,
                        onDismiss: () {},
                        onGainIchor: (_) {},
                        relicService: relicService,
                        commandService: commandService,
                      ),
                    );
                  },
                  child: const Text('OPEN WATCHTOWER'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN WATCHTOWER'));
      await tester.pumpAndSettle();

      expect(find.text('OBSIDIAN WATCHTOWER'), findsOneWidget);
      expect(find.text('Deploy Forward Reconnaissance'), findsOneWidget);
      expect(find.text('Excavate Cursed Ore Vein'), findsOneWidget);
      expect(find.text('Chart Enemy Blindspots'), findsOneWidget);
      expect(find.text('War Horn of Command'), findsOneWidget);
      expect(find.text('Plunder Spire Armory'), findsOneWidget);
    });
  });
}
