import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/features/campaign/campaign_map_screen.dart';
import 'package:ashen_crucible/features/campaign/campaign_map_generator.dart';

void main() {
  group('CampaignMapScreen Chapter Navigation Tests', () {
    testWidgets('Renders Chapter 1 title and hides left navigation arrow', (tester) async {
      final nodes = CampaignMapGenerator.generateCampaignForChapter(1);

      await tester.pumpWidget(
        MaterialApp(
          home: CampaignMapScreen(
            nodes: nodes,
            onSelectNode: (_) {},
            currentChapter: 1,
            maxUnlockedChapter: 1,
          ),
        ),
      );

      expect(find.text('CH. I: ASHEN PERIMETER'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_left), findsNothing);
      expect(find.byIcon(Icons.arrow_right), findsNothing);
    });

    testWidgets('Shows right arrow when higher chapter is unlocked and triggers callback', (tester) async {
      final nodes = CampaignMapGenerator.generateCampaignForChapter(1);
      int switchedChapter = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: CampaignMapScreen(
            nodes: nodes,
            onSelectNode: (_) {},
            currentChapter: 1,
            maxUnlockedChapter: 2,
            onChapterChanged: (ch) => switchedChapter = ch,
          ),
        ),
      );

      expect(find.text('CH. I: ASHEN PERIMETER'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_left), findsNothing);
      expect(find.byIcon(Icons.arrow_right), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_right));
      await tester.pump();

      expect(switchedChapter, equals(2));
    });

    testWidgets('Shows left arrow on Chapter 2 allowing return to Chapter 1', (tester) async {
      final nodes = CampaignMapGenerator.generateCampaignForChapter(2);
      int switchedChapter = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: CampaignMapScreen(
            nodes: nodes,
            onSelectNode: (_) {},
            currentChapter: 2,
            maxUnlockedChapter: 2,
            onChapterChanged: (ch) => switchedChapter = ch,
          ),
        ),
      );

      expect(find.text('CH. II: SMOLDERING BARRICADE'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_left), findsOneWidget);
      expect(find.byIcon(Icons.arrow_right), findsNothing);

      await tester.tap(find.byIcon(Icons.arrow_left));
      await tester.pump();

      expect(switchedChapter, equals(1));
    });
  });
}
