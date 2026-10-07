import 'package:flutter_test/flutter_test.dart';
import 'package:ashen_crucible/features/campaign/campaign_map_generator.dart';
import 'package:ashen_crucible/features/campaign/campaign_node.dart';

void main() {
  group('CampaignMapGenerator Tests', () {
    test('Generates connected campaign nodes across depth tiers with no isolated links', () {
      final nodes = CampaignMapGenerator.generateCuratedCampaign();

      expect(nodes.isNotEmpty, isTrue);

      // Depth 0 nodes are reachable by default
      final startingNodes = nodes.where((n) => n.depth == 0).toList();
      expect(startingNodes.every((n) => n.isReachable), isTrue);

      // Verify that every forward link points to a real existing node
      final allNodeIds = nodes.map((n) => n.id).toSet();
      for (final node in nodes) {
        for (final nextId in node.nextNodeIds) {
          expect(allNodeIds.contains(nextId), isTrue,
              reason: 'Node ${node.id} links to unknown node $nextId');
        }
      }

      // Final node is the boss
      final bossNode = nodes.last;
      expect(bossNode.type, equals(CampaignNodeType.boss));
      expect(bossNode.depth, equals(4));
      expect(bossNode.nextNodeIds.isEmpty, isTrue);
    });

    test('Campaign includes both Rest Haven and Watchtower scouting nodes at Depth 3', () {
      final nodes = CampaignMapGenerator.generateCuratedCampaign();
      final depth3Nodes = nodes.where((n) => n.depth == 3).toList();

      expect(depth3Nodes.length, equals(2));
      expect(depth3Nodes.any((n) => n.type == CampaignNodeType.restHaven), isTrue);
      expect(depth3Nodes.any((n) => n.type == CampaignNodeType.watchtower), isTrue);

      // Both branch into boss
      for (final n in depth3Nodes) {
        expect(n.nextNodeIds, contains('node_4_boss'));
      }
    });
  });
}
