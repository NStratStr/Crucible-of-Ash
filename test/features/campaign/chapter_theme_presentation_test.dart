import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/features/campaign/campaign_map_generator.dart';
import 'package:ashen_crucible/features/campaign/campaign_map_screen.dart';
import 'package:ashen_crucible/features/campaign/campaign_node.dart';

void main() {
  group('Chapter Theme & World Titan Presentation Tests', () {
    testWidgets('Renders Chapter 2 Sunken Necropolis theme, icon, and subtitle', (tester) async {
      final ch2Nodes = CampaignMapGenerator.generateCampaignForChapter(2);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CampaignMapScreen(
              nodes: ch2Nodes,
              onSelectNode: (_) {},
              currentChapter: 2,
              maxUnlockedChapter: 3,
            ),
          ),
        ),
      );

      expect(find.text('CH. II: SUNKEN NECROPOLIS'), findsOneWidget);
      expect(find.text('The Submerged Tombs • Depths 0–5'), findsOneWidget);
    });

    testWidgets('Tapping Chapter World Titan node displays Boss Presentation Card', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final ch1Nodes = CampaignMapGenerator.generateCampaignForChapter(1);
      // Make the boss node reachable so it is tappable
      final updatedNodes = ch1Nodes.map((n) {
        if (n.type == CampaignNodeType.boss) {
          return n.copyWith(isReachable: true);
        }
        return n;
      }).toList();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CampaignMapScreen(
              nodes: updatedNodes,
              onSelectNode: (_) {},
              currentChapter: 1,
              initialViewMode: CampaignViewMode.catacombDelve,
            ),
          ),
        ),
      );

      // Tap on the boss node badge
      await tester.tap(find.text('Gorgoroth the Flayed'));
      await tester.pumpAndSettle();

      // Verify World Titan Presentation Card elements
      expect(find.text('WORLD TITAN'), findsOneWidget);
      expect(find.text('PUREBLOOD ASCENSION GATEWAY'), findsOneWidget);
      expect(find.text('GORGOROTH THE FLAYED'), findsOneWidget);
      expect(find.text('+2 SIGIL'), findsOneWidget);
    });
  });
}
