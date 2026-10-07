import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/features/campaign/campaign_node.dart';
import 'package:ashen_crucible/features/campaign/rest_haven_dialog.dart';
import 'package:ashen_crucible/features/relics/relic_service.dart';

void main() {
  testWidgets('RestHavenDialog renders without assertion error on desktop window sizes', (tester) async {
    // Set a desktop window physical size
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final node = CampaignNode(
      id: 'node_haven_1',
      name: 'Haven',
      type: CampaignNodeType.restHaven,
      description: 'Rest Haven Test',
      depth: 3,
      verticalRatio: 0.5,
      nextNodeIds: const [],
    );
    final relicService = RelicService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                RestHavenDialog.show(
                  context: context,
                  node: node,
                  onHealSquad: () {},
                  relicService: relicService,
                  onGrantXp: () {},
                  onDismiss: () {},
                );
              },
              child: const Text('Open Haven'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Haven'));
    await tester.pumpAndSettle();

    expect(find.text('SANCTIFIED REST HAVEN'), findsOneWidget);
    expect(find.text('Communion of Blood'), findsOneWidget);
    expect(find.text('Anvil of Refinement'), findsOneWidget);
    expect(find.text('Meditative Crucible'), findsOneWidget);
  });
}
